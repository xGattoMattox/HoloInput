//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Updater
//** Scopo: Aggiornamento automatico dalla pagina delle release su GitHub (controllo, download con barra
//**        di progresso, verifica SHA-256, installazione e riavvio).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento:
//**   1. CheckForUpdate legge l'ultima release del repository ufficiale
//**      (API di GitHub, HTTPS con THTTPClient: nessuna DLL esterna) e trova
//**      lo zip "HoloInput-v<versione>-win64.zip" e il suo file di verifica
//**      "<zip>.sha256" creati da TOOLS\make_release.bat.
//**   2. UpdateAvailable confronta la versione della release con quella
//**      dell'exe (numeri separati da punti). Se la release e' piu' recente
//**      CheckForUpdate legge anche le novita': le sezioni di CHANGELOG.md (al
//**      tag della release) delle versioni successive a quella in uso, oppure,
//**      se mancano, il testo della release; AskUpdate le mostra nella finestra
//**      che chiede se aggiornare.
//**   3. RunUpdate mostra la finestra con la barra di progresso e, in un thread,
//**      scarica il codice di verifica e lo zip, controlla lo SHA-256, estrae lo
//**      zip in una cartella temporanea e installa: l'exe in uso viene rinominato
//**      in "HoloInput.exe.old" (Windows lo consente anche mentre e' in
//**      esecuzione) e al suo posto viene copiato quello nuovo, insieme ai
//**      documenti dello zip (LICENSE, README, CHANGELOG). Senza file di
//**      verifica o con un'impronta diversa l'aggiornamento viene annullato.
//**   4. RestartAfterUpdate avvia il nuovo exe con "--after-update <pid>": il
//**      nuovo processo (FinishPendingUpdate, chiamata dal .dpr) aspetta che il
//**      vecchio sia chiuso, cosi' le hotkey globali si registrano senza
//**      conflitti, e cancella il vecchio exe e i file temporanei.
//** Il file HoloInput.ini non fa parte dello zip: la configurazione resta.
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.Updater;

interface

uses
    System.SysUtils, System.Types, System.UITypes, System.Classes,
    Holo.Skins;

const
    UPDATE_REPO = 'xGattoMattox/HoloInput';
    UPDATE_API_URL = 'https://api.github.com/repos/' + UPDATE_REPO + '/releases/latest';
    UPDATE_PAGE_URL = 'https://github.com/' + UPDATE_REPO + '/releases/latest';
    /// Parametro con cui il nuovo exe viene avviato dopo l'aggiornamento (seguito dal pid del vecchio).
    OPT_AFTER_UPDATE = '--after-update';

type
    /// Ultima release trovata su GitHub.
    TUpdateInfo = record
        Version: string;          // es. "0.2026.11.8" (tag senza la "v" iniziale)
        Tag: string;              // es. "v0.2026.11.8"
        PageUrl: string;          // pagina della release
        ZipName: string;
        ZipUrl: string;
        ZipSize: Int64;
        HashUrl: string;          // file "<zip>.sha256" ('' se manca)
        Body: string;             // testo della release (Markdown)
        Notes: string;            // novita' rispetto alla versione in uso (testo semplice)
    end;

/// Confronta due versioni "a.b.c.d": <0 se A e' precedente a B, 0 se uguali, >0 se successiva.
function CompareVersions(const A, B: string): Integer;
/// Legge l'ultima release da GitHub (e, se e' piu' recente di ACurrentVersion, le novita');
/// False (con AError) se la richiesta non riesce.
function CheckForUpdate(const ACurrentVersion: string; out AInfo: TUpdateInfo;
    out AError: string): Boolean;
/// True se la release trovata e' piu' recente della versione in uso e ha lo zip da scaricare.
function UpdateAvailable(const AInfo: TUpdateInfo; const ACurrentVersion: string): Boolean;
/// Chiede se aggiornare mostrando le novita' (Aggiorna / Piu' tardi); True = Aggiorna.
function AskUpdate(const AInfo: TUpdateInfo; const ACurrentVersion: string;
    const AColors: TSkinColors): Boolean;
/// Scarica e installa l'aggiornamento mostrando la barra di progresso. True = installato
/// (va chiamata RestartAfterUpdate); False con AError = '' se l'utente ha annullato.
function RunUpdate(const AInfo: TUpdateInfo; const AColors: TSkinColors; out AError: string): Boolean;
/// Avvia il nuovo exe (che aspetta la chiusura di questo processo); poi l'app va chiusa.
function RestartAfterUpdate: Boolean;
/// Da chiamare all'avvio (HoloInput.dpr): completa un aggiornamento appena installato.
procedure FinishPendingUpdate;
/// True se questo avvio segue un aggiornamento appena installato.
function JustUpdated: Boolean;

implementation

uses
    Winapi.Windows, Winapi.ShellAPI,
    System.Math, System.IOUtils, System.JSON, System.Hash, System.Zip, System.Diagnostics,
    System.Net.URLClient, System.Net.HttpClient,
    FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls, FMX.Controls.Presentation,
    FMX.Layouts,
    Holo.UI, Holo.Lang;

const
    UPD_W = 520;
    UPD_H = 236;
    UPD_PAD = 24;
    UPD_TITLE_LINE_Y = 56;
    UPD_BTN_W = 130;
    UPD_BTN_H = 34;
    UPD_USER_AGENT = 'HoloInput-Updater';
    UPD_UI_INTERVAL_MS = 80;     // aggiornamento della barra di progresso durante il download

type
    /// Fasi dell'aggiornamento mostrate nella finestra.
    TUpdateStage = (usHash, usDownload, usVerify, usExtract, usInstall);

    /// Sfondo della finestra: pannello smussato con bordo accento e riga sotto il titolo.
    THoloUpdatePanel = class(TControl)
    private
        FColors: TSkinColors;
    protected
        procedure Paint; override;
    end;

    /// Barra di progresso nei colori della skin (Position 0..1).
    THoloProgressBar = class(TControl)
    private
        FColors: TSkinColors;
        FPosition: Single;
        procedure SetPosition(AValue: Single);
    protected
        procedure Paint; override;
    public
        property Position: Single read FPosition write SetPosition;
    end;

    THoloUpdateForm = class;

    /// Thread che scarica, verifica e installa l'aggiornamento.
    TUpdateWorker = class(TThread)
    private
        FForm: THoloUpdateForm;
        FInfo: TUpdateInfo;
        FError: string;
        FSuccess: Boolean;
        FCancel: Boolean;
        FClock: TStopwatch;
        FLastUi: Int64;
        FStage: TUpdateStage;
        FDone, FTotal: Int64;
        procedure ReceiveData(const Sender: TObject; AContentLength: Int64; AReadCount: Int64;
            var AAbort: Boolean);
        procedure SetStage(AStage: TUpdateStage);
        procedure ShowProgress;
        function DownloadText(const AUrl: string): string;
        procedure DownloadFile(const AUrl, AFileName: string);
        procedure Install(const ASourceDir: string);
    protected
        procedure Execute; override;
    end;

    /// Finestra dell'aggiornamento (creata da codice, senza .fmx).
    THoloUpdateForm = class(TForm)
    private
        FWorker: TUpdateWorker;
        FStatus, FDetail: TLabel;
        FBar: THoloProgressBar;
        FCancelBtn: THoloButton;
        FVersion: string;
        FStarted: Boolean;
        procedure CancelClick(Sender: TObject);
        procedure WorkerDone(Sender: TObject);
        procedure ShowStage(AStage: TUpdateStage; ADone, ATotal: Int64);
    protected
        procedure DoShow; override;
        procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    public
        destructor Destroy; override;
    end;

    /// Finestra che chiede se aggiornare, con le novita' (creata da codice, senza .fmx).
    THoloAskUpdateForm = class(TForm)
    private
        procedure OkClick(Sender: TObject);
        procedure LaterClick(Sender: TObject);
    protected
        procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    end;

var
    GJustUpdated: Boolean = False;

//** funzioni di servizio ***********************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: UpdateTempDir
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Cartella temporanea dell'aggiornamento (%TEMP%\HoloInput-update).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
function UpdateTempDir: string;
begin
    Result := TPath.Combine(TPath.GetTempPath, 'HoloInput-update');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: NewClient
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: THTTPClient
//** Scopo: Creare il client HTTPS (WinHTTP di Windows) con user agent e tempi di attesa.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: GitHub rifiuta le richieste all'API senza user agent; i
//** redirect (lo zip si scarica da un altro dominio di GitHub) sono seguiti.
//***********************************************************************************************************
//***********************************************************************************************************
function NewClient: THTTPClient;
begin
    Result := THTTPClient.Create;
    Result.UserAgent := UPD_USER_AGENT;
    Result.HandleRedirects := True;
    Result.ConnectionTimeout := 8000;
    Result.ResponseTimeout := 20000;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: CompareVersions
//** Parametri di ingresso: A, B: string
//** Parametri di uscita: Result: Integer
//** Scopo: Confrontare due versioni "a.b.c.d" (una "v" iniziale viene ignorata).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: confronta i numeri da sinistra; le parti mancanti valgono 0
//** ("1.2" = "1.2.0.0"), le parti non numeriche valgono 0.
//***********************************************************************************************************
//***********************************************************************************************************
function CompareVersions(const A, B: string): Integer;
var
    PA, PB: TArray<string>;
    I, NA, NB: Integer;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: Clean
    //** Parametri di ingresso: S: string
    //** Parametri di uscita: Result: string
    //** Scopo: Togliere spazi e la "v" iniziale da una versione.
    //** Data Ultima Modifica: 06/11/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function Clean(const S: string): string;
    begin
        Result := Trim(S);
        if (Result <> '') and CharInSet(Result[1], ['v', 'V']) then
            Delete(Result, 1, 1);
    end;

begin
    PA := Clean(A).Split(['.']);
    PB := Clean(B).Split(['.']);
    for I := 0 to Max(Length(PA), Length(PB)) - 1 do
    begin
        NA := 0;
        NB := 0;
        if I < Length(PA) then
            NA := StrToIntDef(PA[I], 0);
        if I < Length(PB) then
            NB := StrToIntDef(PB[I], 0);
        if NA <> NB then
            Exit(CompareValue(NA, NB));
    end;
    Result := 0;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: MarkdownToText
//** Parametri di ingresso: AText: string
//** Parametri di uscita: Result: string
//** Scopo: Rendere leggibile come testo semplice un estratto Markdown (CHANGELOG o testo della
//**        release).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: "## [x] - data" diventa "x  -  data" preceduto da un
//** quadratino, "### Titolo" diventa "Titolo:", gli elenchi "- " diventano
//** "  * "; toglie grassetti, corsivi, apici inversi e i link (resta il testo),
//** e riduce a una le righe vuote consecutive.
//***********************************************************************************************************
//***********************************************************************************************************
function MarkdownToText(const AText: string): string;
var
    Lines: TStringList;
    Res: TStringBuilder;
    L, T: string;
    I, P, Q: Integer;
    LastBlank: Boolean;
begin
    Lines := TStringList.Create;
    Res := TStringBuilder.Create;
    try
        Lines.Text := AText;
        LastBlank := True;
        for I := 0 to Lines.Count - 1 do
        begin
            L := TrimRight(Lines[I]);
            // link [testo](indirizzo) -> testo
            P := Pos('](', L);
            while P > 0 do
            begin
                Q := Pos(')', L, P);
                if Q = 0 then
                    Break;
                Delete(L, P + 1, Q - P);
                P := Pos('](', L);
            end;
            L := L.Replace('**', '').Replace('`', '').Replace('*', '').Replace('[', '').Replace(']', '');
            T := Trim(L);
            if T.StartsWith('## ') then
                L := #$25A0 + ' ' + Trim(Copy(T, 4, MaxInt)).Replace(' - ', '  -  ')
            else if T.StartsWith('### ') then
                L := Trim(Copy(T, 5, MaxInt)) + ':'
            else if T.StartsWith('# ') then
                L := Trim(Copy(T, 3, MaxInt))
            else if T.StartsWith('- ') then
                L := '  ' + #$2022 + ' ' + Trim(Copy(T, 3, MaxInt))
            else
                L := T;
            if L = '' then
            begin
                if not LastBlank then
                    Res.AppendLine;
                LastBlank := True;
            end
            else
            begin
                Res.AppendLine(L);
                LastBlank := False;
            end;
        end;
        Result := Trim(Res.ToString);
    finally
        Res.Free;
        Lines.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: ReleaseNotes
//** Parametri di ingresso: AInfo: TUpdateInfo; ACurrentVersion: string
//** Parametri di uscita: Result: string
//** Scopo: Novita' della release rispetto alla versione in uso, come testo semplice.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: scarica CHANGELOG.md dal repository al tag della release
//** e tiene le sezioni "## [versione]" successive a ACurrentVersion e non oltre
//** la versione della release (la sezione [Unreleased] viene ignorata). Se il
//** file non si legge o non contiene quelle sezioni usa il testo della release.
//** Gli errori di rete non interrompono il controllo degli aggiornamenti.
//***********************************************************************************************************
//***********************************************************************************************************
function ReleaseNotes(const AInfo: TUpdateInfo; const ACurrentVersion: string): string;
var
    Client: THTTPClient;
    Resp: IHTTPResponse;
    Lines: TStringList;
    Picked: TStringBuilder;
    I, P: Integer;
    L, Ver: string;
    Keep: Boolean;
begin
    Result := '';
    try
        Client := NewClient;
        try
            Resp := Client.Get('https://raw.githubusercontent.com/' + UPDATE_REPO + '/' + AInfo.Tag +
                '/CHANGELOG.md');
            if Resp.StatusCode = 200 then
            begin
                Lines := TStringList.Create;
                Picked := TStringBuilder.Create;
                try
                    Lines.Text := Resp.ContentAsString(TEncoding.UTF8);
                    Keep := False;
                    for I := 0 to Lines.Count - 1 do
                    begin
                        L := Lines[I];
                        if L.StartsWith('## ') then
                        begin
                            // "## [0.2026.11.8] - 2026-11-08"
                            Ver := '';
                            P := Pos('[', L);
                            if P > 0 then
                                Ver := Copy(L, P + 1, Pos(']', L) - P - 1);
                            Keep := (Ver <> '') and not SameText(Ver, 'Unreleased') and
                                (CompareVersions(Ver, ACurrentVersion) > 0) and
                                (CompareVersions(Ver, AInfo.Version) <= 0);
                        end;
                        if Keep then
                            Picked.AppendLine(L);
                    end;
                    Result := MarkdownToText(Picked.ToString);
                finally
                    Picked.Free;
                    Lines.Free;
                end;
            end;
        finally
            Client.Free;
        end;
    except
        Result := '';
    end;
    if Result = '' then
        Result := MarkdownToText(AInfo.Body);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: CheckForUpdate
//** Parametri di ingresso: ACurrentVersion: string
//** Parametri di uscita: AInfo: TUpdateInfo; AError: string; Result: Boolean
//** Scopo: Leggere da GitHub l'ultima release pubblicata e, se e' piu' recente della versione in
//**        uso, le sue novita'.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: chiama l'API "releases/latest" del repository ufficiale e
//** cerca tra gli allegati lo zip "HoloInput-...-win64.zip" e il file
//** "<zip>.sha256". Se la release e' piu' recente di ACurrentVersion legge le
//** novita' (ReleaseNotes). Puo' essere chiamata da un thread secondario (non
//** usa l'interfaccia). False con AError se la rete o GitHub non rispondono.
//***********************************************************************************************************
//***********************************************************************************************************
function CheckForUpdate(const ACurrentVersion: string; out AInfo: TUpdateInfo;
    out AError: string): Boolean;
var
    Client: THTTPClient;
    Resp: IHTTPResponse;
    Root: TJSONValue;
    Obj, Asset: TJSONObject;
    Assets: TJSONArray;
    I: Integer;
    Name, Url: string;
begin
    Result := False;
    AInfo := Default(TUpdateInfo);
    AError := '';
    Root := nil;
    try
        Client := NewClient;
        try
            Client.Accept := 'application/vnd.github+json';
            Resp := Client.Get(UPDATE_API_URL);
            if Resp.StatusCode <> 200 then
            begin
                AError := Format('HTTP %d %s', [Resp.StatusCode, Resp.StatusText]);
                Exit;
            end;
            Root := TJSONObject.ParseJSONValue(Resp.ContentAsString(TEncoding.UTF8));
        finally
            Client.Free;
        end;
        if not (Root is TJSONObject) then
        begin
            Root.Free;
            AError := 'risposta di GitHub non valida';
            Exit;
        end;
        try
            Obj := TJSONObject(Root);
            AInfo.Tag := Obj.GetValue<string>('tag_name', '');
            AInfo.Version := AInfo.Tag;
            if (AInfo.Version <> '') and CharInSet(AInfo.Version[1], ['v', 'V']) then
                Delete(AInfo.Version, 1, 1);
            AInfo.PageUrl := Obj.GetValue<string>('html_url', UPDATE_PAGE_URL);
            AInfo.Body := Obj.GetValue<string>('body', '');
            if Obj.TryGetValue<TJSONArray>('assets', Assets) then
            begin
                // prima lo zip, poi il suo file di verifica
                for I := 0 to Assets.Count - 1 do
                    if Assets.Items[I] is TJSONObject then
                    begin
                        Asset := TJSONObject(Assets.Items[I]);
                        Name := Asset.GetValue<string>('name', '');
                        if Name.StartsWith('HoloInput', True) and Name.EndsWith('-win64.zip', True) then
                        begin
                            AInfo.ZipName := Name;
                            AInfo.ZipUrl := Asset.GetValue<string>('browser_download_url', '');
                            AInfo.ZipSize := Asset.GetValue<Int64>('size', 0);
                        end;
                    end;
                if AInfo.ZipName <> '' then
                    for I := 0 to Assets.Count - 1 do
                        if Assets.Items[I] is TJSONObject then
                        begin
                            Asset := TJSONObject(Assets.Items[I]);
                            Name := Asset.GetValue<string>('name', '');
                            Url := Asset.GetValue<string>('browser_download_url', '');
                            if SameText(Name, AInfo.ZipName + '.sha256') then
                                AInfo.HashUrl := Url;
                        end;
            end;
        finally
            Root.Free;
        end;
        if AInfo.Version = '' then
        begin
            AError := 'nessuna release trovata';
            Exit;
        end;
        if UpdateAvailable(AInfo, ACurrentVersion) then
            AInfo.Notes := ReleaseNotes(AInfo, ACurrentVersion);
        Result := True;
    except
        on E: Exception do
            AError := E.Message;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: UpdateAvailable
//** Parametri di ingresso: AInfo: TUpdateInfo; ACurrentVersion: string
//** Parametri di uscita: Result: Boolean
//** Scopo: Indicare se la release trovata e' piu' recente della versione in uso e si puo' scaricare.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
function UpdateAvailable(const AInfo: TUpdateInfo; const ACurrentVersion: string): Boolean;
begin
    Result := (AInfo.ZipUrl <> '') and (CompareVersions(AInfo.Version, ACurrentVersion) > 0);
end;

//** THoloUpdatePanel ***************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloUpdatePanel.Paint
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare lo sfondo della finestra (come gli avvisi di Holo.Dialog).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloUpdatePanel.Paint;
var
    R: TRectF;
    P: TPathData;
begin
    R := LocalRect;
    R.Inflate(-1.5, -1.5);
    P := ChamferPath(R, 18);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.Fill.Color := WithAlpha(MixColors(FColors.PanelBack, TAlphaColors.Black, 0.35), $F4);
        Canvas.FillPath(P, AbsoluteOpacity);
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 2;
        Canvas.Stroke.Color := FColors.Accent;
        Canvas.DrawPath(P, AbsoluteOpacity);
    finally
        P.Free;
    end;
    Canvas.Stroke.Thickness := 1;
    Canvas.Stroke.Color := FColors.PanelBorder;
    Canvas.DrawLine(PointF(UPD_PAD, UPD_TITLE_LINE_Y), PointF(Width - UPD_PAD, UPD_TITLE_LINE_Y),
        AbsoluteOpacity);
end;

//** THoloProgressBar ***************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloProgressBar.SetPosition
//** Parametri di ingresso: AValue: Single
//** Parametri di uscita: nessuno
//** Scopo: Impostare l'avanzamento (0..1) e ridisegnare la barra.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloProgressBar.SetPosition(AValue: Single);
begin
    AValue := EnsureRange(AValue, 0, 1);
    if SameValue(AValue, FPosition, 0.001) then
        Exit;
    FPosition := AValue;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloProgressBar.Paint
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare la barra: contorno smussato nel colore delle cornici e riempimento nel colore
//**        principale della skin.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloProgressBar.Paint;
var
    R, F: TRectF;
    P: TPathData;
begin
    R := LocalRect;
    R.Inflate(-1, -1);
    P := ChamferPath(R, 6);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.Fill.Color := WithAlpha(FColors.Primary, $18);
        Canvas.FillPath(P, AbsoluteOpacity);
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 1;
        Canvas.Stroke.Color := FColors.PanelBorder;
        Canvas.DrawPath(P, AbsoluteOpacity);
    finally
        P.Free;
    end;
    if FPosition > 0 then
    begin
        F := R;
        F.Inflate(-3, -3);
        F.Right := F.Left + F.Width * FPosition;
        Canvas.Fill.Color := WithAlpha(FColors.Primary, $D0);
        Canvas.FillRect(F, 0, 0, [], AbsoluteOpacity);
    end;
end;

//** TUpdateWorker ******************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TUpdateWorker.SetStage
//** Parametri di ingresso: AStage: TUpdateStage
//** Parametri di uscita: nessuno
//** Scopo: Passare a una nuova fase e mostrarla nella finestra.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TUpdateWorker.SetStage(AStage: TUpdateStage);
begin
    FStage := AStage;
    FDone := 0;
    FTotal := 0;
    Synchronize(ShowProgress);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TUpdateWorker.ShowProgress
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Aggiornare la finestra con fase e avanzamento (eseguita nel thread principale).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TUpdateWorker.ShowProgress;
begin
    FForm.ShowStage(FStage, FDone, FTotal);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TUpdateWorker.ReceiveData
//** Parametri di ingresso: Sender: TObject; AContentLength, AReadCount: Int64; AAbort: Boolean (var)
//** Parametri di uscita: AAbort: Boolean (var)
//** Scopo: Avanzamento del download: aggiorna la barra (al massimo ogni UPD_UI_INTERVAL_MS) e
//**        interrompe il download se l'utente ha annullato.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TUpdateWorker.ReceiveData(const Sender: TObject; AContentLength: Int64; AReadCount: Int64;
    var AAbort: Boolean);
begin
    AAbort := FCancel or Terminated;
    if FStage <> usDownload then
        Exit;
    FDone := AReadCount;
    if AContentLength > 0 then
        FTotal := AContentLength
    else
        FTotal := FInfo.ZipSize;
    if (FClock.ElapsedMilliseconds - FLastUi >= UPD_UI_INTERVAL_MS) or
        ((FTotal > 0) and (FDone >= FTotal)) then
    begin
        FLastUi := FClock.ElapsedMilliseconds;
        Synchronize(ShowProgress);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TUpdateWorker.DownloadText
//** Parametri di ingresso: AUrl: string
//** Parametri di uscita: Result: string
//** Scopo: Scaricare un file di testo piccolo (il codice di verifica).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TUpdateWorker.DownloadText(const AUrl: string): string;
var
    Client: THTTPClient;
    Resp: IHTTPResponse;
begin
    Client := NewClient;
    try
        Resp := Client.Get(AUrl);
        if Resp.StatusCode <> 200 then
            raise Exception.CreateFmt('HTTP %d %s', [Resp.StatusCode, Resp.StatusText]);
        Result := Resp.ContentAsString(TEncoding.UTF8);
    finally
        Client.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TUpdateWorker.DownloadFile
//** Parametri di ingresso: AUrl, AFileName: string
//** Parametri di uscita: nessuno
//** Scopo: Scaricare lo zip in AFileName mostrando l'avanzamento.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TUpdateWorker.DownloadFile(const AUrl, AFileName: string);
var
    Client: THTTPClient;
    Resp: IHTTPResponse;
    FS: TFileStream;
begin
    Client := NewClient;
    try
        Client.OnReceiveData := ReceiveData;
        FS := TFileStream.Create(AFileName, fmCreate);
        try
            Resp := Client.Get(AUrl, FS);
        finally
            FS.Free;
        end;
        if FCancel then
            Abort;
        if Resp.StatusCode <> 200 then
            raise Exception.CreateFmt('HTTP %d %s', [Resp.StatusCode, Resp.StatusText]);
    finally
        Client.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TUpdateWorker.Install
//** Parametri di ingresso: ASourceDir: string
//** Parametri di uscita: nessuno
//** Scopo: Sostituire l'exe in uso con quello estratto e copiare i documenti dello zip.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: cerca HoloInput.exe nella cartella estratta; rinomina l'exe
//** in uso in "<exe>.old" (se un vecchio .old non si cancella usa un nome con
//** un numero) e copia al suo posto quello nuovo; se la copia non riesce
//** rimette a posto l'exe originale. Poi copia accanto all'exe gli altri file
//** della stessa cartella dello zip (LICENSE, README, CHANGELOG), tranne il .ini.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TUpdateWorker.Install(const ASourceDir: string);
var
    Found: TArray<string>;
    NewExe, Exe, Old, AppDir, SrcDir, F: string;
begin
    Found := TDirectory.GetFiles(ASourceDir, 'HoloInput.exe', TSearchOption.soAllDirectories);
    if Length(Found) = 0 then
        raise Exception.Create(Tr('update.err.noexe', 'Lo zip non contiene HoloInput.exe.'));
    NewExe := Found[0];
    SrcDir := ExtractFilePath(NewExe);
    Exe := ParamStr(0);
    AppDir := ExtractFilePath(Exe);

    Old := Exe + '.old';
    if FileExists(Old) and not System.SysUtils.DeleteFile(Old) then
        Old := Exe + '.' + IntToStr(GetTickCount) + '.old';
    if not RenameFile(Exe, Old) then
        raise Exception.Create(Format(Tr('update.err.write', 'Impossibile sostituire HoloInput.exe ' +
            '(la cartella non e'' scrivibile?): %s'), [SysErrorMessage(GetLastError)]));
    if not CopyFile(PChar(NewExe), PChar(Exe), False) then
    begin
        F := SysErrorMessage(GetLastError);
        RenameFile(Old, Exe);
        raise Exception.Create(Format(Tr('update.err.write', 'Impossibile sostituire HoloInput.exe ' +
            '(la cartella non e'' scrivibile?): %s'), [F]));
    end;

    // documenti dello zip (best effort: un errore qui non annulla l'aggiornamento)
    for F in TDirectory.GetFiles(SrcDir) do
        if not SameText(ExtractFileName(F), 'HoloInput.exe') and
            not SameText(ExtractFileExt(F), '.ini') then
        try
            TFile.Copy(F, TPath.Combine(AppDir, ExtractFileName(F)), True);
        except
        end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TUpdateWorker.Execute
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Eseguire tutte le fasi dell'aggiornamento.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: svuota la cartella temporanea; scarica il file .sha256
//** (obbligatorio) e ne legge l'impronta; scarica lo zip con l'avanzamento;
//** confronta lo SHA-256 dello zip con l'impronta; estrae lo zip e installa.
//** Ogni errore (o l'annullamento) interrompe l'aggiornamento senza toccare
//** l'exe in uso, salvo nella fase di installazione, che lo ripristina da sola.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TUpdateWorker.Execute;
var
    Dir, ZipFile, ExtractDir, Expected, Actual: string;
    Parts: TArray<string>;
begin
    if FCancel then
        Exit;   // thread mai avviato (finestra distrutta prima di comparire)
    FClock := TStopwatch.StartNew;
    try
        Dir := UpdateTempDir;
        if TDirectory.Exists(Dir) then
            TDirectory.Delete(Dir, True);
        TDirectory.CreateDirectory(Dir);

        // 1. codice di verifica (obbligatorio)
        SetStage(usHash);
        if FInfo.HashUrl = '' then
            raise Exception.Create(Tr('update.err.nohash', 'Nella release manca il file di verifica ' +
                '(.sha256): aggiornamento annullato.'));
        Parts := Trim(DownloadText(FInfo.HashUrl)).Split([' ', #9, #13, #10],
            TStringSplitOptions.ExcludeEmpty);
        if (Length(Parts) = 0) or (Length(Parts[0]) <> 64) then
            raise Exception.Create(Tr('update.err.nohash', 'Nella release manca il file di verifica ' +
                '(.sha256): aggiornamento annullato.'));
        Expected := LowerCase(Parts[0]);
        if FCancel then
            Abort;

        // 2. download dello zip
        SetStage(usDownload);
        ZipFile := TPath.Combine(Dir, FInfo.ZipName);
        DownloadFile(FInfo.ZipUrl, ZipFile);

        // 3. verifica dello SHA-256
        SetStage(usVerify);
        Actual := LowerCase(THashSHA2.GetHashStringFromFile(ZipFile));
        if Actual <> Expected then
            raise Exception.Create(Tr('update.err.hash', 'Il file scaricato non corrisponde al codice ' +
                'di verifica (SHA-256): aggiornamento annullato.'));
        if FCancel then
            Abort;

        // 4. estrazione
        SetStage(usExtract);
        ExtractDir := TPath.Combine(Dir, 'files');
        TZipFile.ExtractZipFile(ZipFile, ExtractDir);
        if FCancel then
            Abort;

        // 5. installazione (da qui in poi non si annulla piu')
        SetStage(usInstall);
        Install(ExtractDir);
        FSuccess := True;
    except
        on E: EAbort do
            FError := '';
        on E: Exception do
            if FCancel then
                FError := ''
            else
                FError := E.Message;
    end;
end;

//** THoloUpdateForm ****************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloUpdateForm.DoShow
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Avviare il thread dell'aggiornamento quando la finestra compare.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloUpdateForm.DoShow;
begin
    inherited;
    if (FWorker <> nil) and not FStarted then
    begin
        FStarted := True;
        FWorker.Start;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloUpdateForm.ShowStage
//** Parametri di ingresso: AStage: TUpdateStage; ADone, ATotal: Int64
//** Parametri di uscita: nessuno
//** Scopo: Mostrare la fase in corso, la barra di progresso e i MB scaricati.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: la barra indica il download; nelle fasi successive resta
//** piena. Durante l'installazione il pulsante Annulla viene disattivato.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloUpdateForm.ShowStage(AStage: TUpdateStage; ADone, ATotal: Int64);
begin
    case AStage of
        usHash:
            FStatus.Text := Tr('update.stage.hash', 'Lettura del codice di verifica...');
        usDownload:
            FStatus.Text := Format(Tr('update.stage.download', 'Download di HoloInput %s...'), [FVersion]);
        usVerify:
            FStatus.Text := Tr('update.stage.verify', 'Verifica del file scaricato (SHA-256)...');
        usExtract:
            FStatus.Text := Tr('update.stage.extract', 'Estrazione dei file...');
        usInstall:
            FStatus.Text := Tr('update.stage.install', 'Installazione...');
    end;
    if AStage = usDownload then
    begin
        if ATotal > 0 then
        begin
            FBar.Position := ADone / ATotal;
            FDetail.Text := Format(Tr('update.size', '%.1f / %.1f MB'),
                [ADone / 1048576, ATotal / 1048576]);
        end
        else
            FDetail.Text := Format(Tr('update.size.unknown', '%.1f MB'), [ADone / 1048576]);
    end
    else if AStage > usDownload then
    begin
        FBar.Position := 1;
        FDetail.Text := '';
    end;
    if AStage = usInstall then
    begin
        FCancelBtn.Enabled := False;
        FCancelBtn.Opacity := 0.35;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloUpdateForm.CancelClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiedere l'annullamento: la finestra si chiude quando il thread si e' fermato.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloUpdateForm.CancelClick(Sender: TObject);
begin
    if (FWorker = nil) or not FCancelBtn.Enabled then
        Exit;
    FWorker.FCancel := True;
    FCancelBtn.Enabled := False;
    FCancelBtn.Opacity := 0.35;
    FStatus.Text := Tr('update.stage.cancel', 'Annullamento in corso...');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloUpdateForm.WorkerDone
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiudere la finestra al termine del thread (OnTerminate, nel thread principale).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloUpdateForm.WorkerDone(Sender: TObject);
begin
    if FWorker.FSuccess then
        ModalResult := mrOk
    else
        ModalResult := mrCancel;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloUpdateForm.KeyDown
//** Parametri di ingresso: Key: Word (var); KeyChar: WideChar (var); Shift: TShiftState
//** Parametri di uscita: Key: Word (var); KeyChar: WideChar (var)
//** Scopo: Esc = Annulla.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloUpdateForm.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
    if Key = vkEscape then
    begin
        Key := 0;
        CancelClick(nil);
    end
    else
        inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloUpdateForm.Destroy
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Fermare e liberare il thread prima di distruggere la finestra.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
destructor THoloUpdateForm.Destroy;
begin
    if FWorker <> nil then
    begin
        FWorker.FCancel := True;
        FWorker.OnTerminate := nil;
        if FStarted and not FWorker.Finished then
            FWorker.WaitFor;
        FreeAndNil(FWorker);
    end;
    inherited;
end;

//** AskUpdate **********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: MakeText
//** Parametri di ingresso: AParent: TFmxObject; X, Y, W, H, ASize: Single; ABold: Boolean; AColor:
//**                        TAlphaColor; AText: string
//** Parametri di uscita: Result: TLabel
//** Scopo: Creare un testo della finestra con il font dell'app.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
function MakeText(AParent: TFmxObject; X, Y, W, H, ASize: Single; ABold: Boolean; AColor: TAlphaColor;
    const AText: string): TLabel;
begin
    Result := TLabel.Create(AParent);
    Result.Parent := AParent;
    Result.SetBounds(X, Y, W, H);
    Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Family,
        TStyledSetting.Size, TStyledSetting.Style, TStyledSetting.FontColor];
    Result.TextSettings.Font.Family := HOLO_FONT;
    Result.TextSettings.Font.Size := ASize;
    if ABold then
        Result.TextSettings.Font.Style := [TFontStyle.fsBold];
    Result.TextSettings.FontColor := AColor;
    Result.TextSettings.VertAlign := TTextAlign.Leading;
    Result.WordWrap := True;
    Result.Text := AText;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloAskUpdateForm.OkClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Scegliere Aggiorna.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloAskUpdateForm.OkClick(Sender: TObject);
begin
    ModalResult := mrOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloAskUpdateForm.LaterClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Scegliere Piu' tardi.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloAskUpdateForm.LaterClick(Sender: TObject);
begin
    ModalResult := mrCancel;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloAskUpdateForm.KeyDown
//** Parametri di ingresso: Key: Word (var); KeyChar: WideChar (var); Shift: TShiftState
//** Parametri di uscita: Key: Word (var); KeyChar: WideChar (var)
//** Scopo: Tastiera: Invio = Aggiorna, Esc = Piu' tardi.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloAskUpdateForm.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
    if Key = vkReturn then
    begin
        Key := 0;
        ModalResult := mrOk;
    end
    else if Key = vkEscape then
    begin
        Key := 0;
        ModalResult := mrCancel;
    end
    else
        inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: AskUpdate
//** Parametri di ingresso: AInfo: TUpdateInfo; ACurrentVersion: string; AColors: TSkinColors
//** Parametri di uscita: Result: Boolean
//** Scopo: Chiedere se aggiornare, mostrando le novita' della nuova versione.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: finestra senza bordi nello stile degli avvisi, piu' grande:
//** titolo, versione nuova e in uso, riquadro scorrevole con le novita'
//** (AInfo.Notes; se mancano un rimando alla pagina della release) e i pulsanti
//** Aggiorna e Piu' tardi. Invio = Aggiorna, Esc = Piu' tardi.
//***********************************************************************************************************
//***********************************************************************************************************
function AskUpdate(const AInfo: TUpdateInfo; const ACurrentVersion: string;
    const AColors: TSkinColors): Boolean;
const
    ASK_W = 680;
    ASK_H = 520;
var
    F: THoloAskUpdateForm;
    Panel: THoloUpdatePanel;
    Box: TVertScrollBox;
    Notes: TLabel;
    BOk, BLater: THoloButton;
    Txt: string;
begin
    F := THoloAskUpdateForm.CreateNew(nil);
    try
        F.BorderStyle := TFmxFormBorderStyle.None;
        F.Transparency := True;
        F.FormStyle := TFormStyle.StayOnTop;
        F.Position := TFormPosition.ScreenCenter;
        F.Caption := Tr('update.found.title', 'Aggiornamento disponibile');
        F.Width := ASK_W;
        F.Height := ASK_H;

        Panel := THoloUpdatePanel.Create(F);
        Panel.FColors := AColors;
        Panel.Parent := F;
        Panel.Align := TAlignLayout.Client;
        Panel.HitTest := False;

        MakeText(Panel, UPD_PAD, 16, ASK_W - 2 * UPD_PAD, 32, 16, True, AColors.Accent,
            UpperCase(Tr('update.found.title', 'Aggiornamento disponibile')));
        MakeText(Panel, UPD_PAD, UPD_TITLE_LINE_Y + 12, ASK_W - 2 * UPD_PAD, 44, 12, False, AColors.Text,
            Format(Tr('update.found.text', 'E'' disponibile HoloInput %s (versione in uso: %s).' +
            sLineBreak + sLineBreak + 'Scaricarla e installarla ora? Al termine HoloInput si riavvia ' +
            'da solo.'), [AInfo.Version, ACurrentVersion]));
        MakeText(Panel, UPD_PAD, UPD_TITLE_LINE_Y + 70, ASK_W - 2 * UPD_PAD, 20, 11, True,
            WithAlpha(AColors.Primary, $D0), UpperCase(Tr('update.notes.title', 'Novita''')));

        // riquadro scorrevole con le novita'
        Box := TVertScrollBox.Create(F);
        Box.Parent := Panel;
        Box.SetBounds(UPD_PAD, UPD_TITLE_LINE_Y + 94, ASK_W - 2 * UPD_PAD,
            ASK_H - (UPD_TITLE_LINE_Y + 94) - UPD_BTN_H - 2 * UPD_PAD);
        Txt := AInfo.Notes;
        if Txt = '' then
            Txt := Format(Tr('update.notes.none', 'Le novita'' sono descritte nella pagina della ' +
                'release: %s'), [AInfo.PageUrl]);
        Notes := MakeText(Box, 4, 4, Box.Width - 28, 20, 11, False, WithAlpha(AColors.Text, $E0), Txt);
        Notes.TextSettings.Font.Family := 'Segoe UI';
        Notes.AutoSize := True;

        BLater := THoloButton.Create(F);
        BLater.Parent := Panel;
        BLater.SetBounds(ASK_W - UPD_PAD - UPD_BTN_W, ASK_H - UPD_PAD - UPD_BTN_H, UPD_BTN_W, UPD_BTN_H);
        BLater.Text := Tr('update.found.later', 'Piu'' tardi');
        BLater.SetColors(AColors);
        BLater.OnClick := F.LaterClick;

        BOk := THoloButton.Create(F);
        BOk.Parent := Panel;
        BOk.SetBounds(ASK_W - UPD_PAD - 2 * UPD_BTN_W - 12, ASK_H - UPD_PAD - UPD_BTN_H, UPD_BTN_W,
            UPD_BTN_H);
        BOk.Text := Tr('update.found.ok', 'Aggiorna');
        BOk.SetColors(AColors);
        BOk.OnClick := F.OkClick;

        Result := F.ShowModal = mrOk;
    finally
        F.Free;
    end;
end;

//** RunUpdate **********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: RunUpdate
//** Parametri di ingresso: AInfo: TUpdateInfo; AColors: TSkinColors
//** Parametri di uscita: AError: string; Result: Boolean
//** Scopo: Mostrare la finestra con la barra di progresso ed eseguire l'aggiornamento.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: finestra senza bordi nello stile degli avvisi, sempre in
//** primo piano e centrata sullo schermo: titolo, fase in corso, barra di
//** progresso, MB scaricati e pulsante Annulla. Il thread parte quando la
//** finestra compare e la chiude al termine. True se l'aggiornamento e' stato
//** installato; False con AError = '' se l'utente ha annullato.
//***********************************************************************************************************
//***********************************************************************************************************
function RunUpdate(const AInfo: TUpdateInfo; const AColors: TSkinColors; out AError: string): Boolean;
var
    F: THoloUpdateForm;
    Panel: THoloUpdatePanel;
begin
    AError := '';
    F := THoloUpdateForm.CreateNew(nil);
    try
        F.BorderStyle := TFmxFormBorderStyle.None;
        F.Transparency := True;
        F.FormStyle := TFormStyle.StayOnTop;
        F.Position := TFormPosition.ScreenCenter;
        F.Caption := Tr('update.title', 'Aggiornamento di HoloInput');
        F.Width := UPD_W;
        F.Height := UPD_H;
        F.FVersion := AInfo.Version;

        Panel := THoloUpdatePanel.Create(F);
        Panel.FColors := AColors;
        Panel.Parent := F;
        Panel.Align := TAlignLayout.Client;
        Panel.HitTest := False;

        MakeText(Panel, UPD_PAD, 16, UPD_W - 2 * UPD_PAD, 32, 16, True, AColors.Accent,
            UpperCase(Tr('update.title', 'Aggiornamento di HoloInput')));
        F.FStatus := MakeText(Panel, UPD_PAD, UPD_TITLE_LINE_Y + 16, UPD_W - 2 * UPD_PAD, 22, 12, False,
            AColors.Text, '');
        F.FBar := THoloProgressBar.Create(F);
        F.FBar.Parent := Panel;
        F.FBar.FColors := AColors;
        F.FBar.SetBounds(UPD_PAD, UPD_TITLE_LINE_Y + 46, UPD_W - 2 * UPD_PAD, 20);
        F.FDetail := MakeText(Panel, UPD_PAD, UPD_TITLE_LINE_Y + 72, UPD_W - 2 * UPD_PAD, 20, 11, False,
            WithAlpha(AColors.Text, $B0), '');

        F.FCancelBtn := THoloButton.Create(F);
        F.FCancelBtn.Parent := Panel;
        F.FCancelBtn.SetBounds(UPD_W - UPD_PAD - UPD_BTN_W, UPD_H - UPD_PAD - UPD_BTN_H,
            UPD_BTN_W, UPD_BTN_H);
        F.FCancelBtn.Text := Tr('dialog.cancel', 'Annulla');
        F.FCancelBtn.SetColors(AColors);
        F.FCancelBtn.OnClick := F.CancelClick;

        F.FWorker := TUpdateWorker.Create(True);
        F.FWorker.FreeOnTerminate := False;
        F.FWorker.FForm := F;
        F.FWorker.FInfo := AInfo;
        F.FWorker.OnTerminate := F.WorkerDone;

        Result := F.ShowModal = mrOk;
        if not Result and (F.FWorker <> nil) then
        begin
            // finestra chiusa in altro modo (es. Alt+F4): si ferma il thread, a meno che
            // non stia gia' installando (in quel caso l'installazione si completa)
            F.FWorker.FCancel := True;
            if F.FStarted and not F.FWorker.Finished then
                F.FWorker.WaitFor;
            Result := F.FWorker.FSuccess;
            if not Result then
                AError := F.FWorker.FError;
        end;
    finally
        F.Free;
    end;
end;

//** riavvio ************************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: RestartAfterUpdate
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Avviare il nuovo exe passando il pid di questo processo.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: il nuovo processo aspetta la chiusura di questo prima di
//** partire davvero (FinishPendingUpdate); il chiamante deve poi chiudere l'app.
//***********************************************************************************************************
//***********************************************************************************************************
function RestartAfterUpdate: Boolean;
var
    Exe, Params: string;
begin
    Exe := ParamStr(0);
    Params := OPT_AFTER_UPDATE + ' ' + IntToStr(GetCurrentProcessId);
    Result := ShellExecute(0, 'open', PChar(Exe), PChar(Params), PChar(ExtractFilePath(Exe)),
        SW_SHOWNORMAL) > 32;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: FinishPendingUpdate
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Completare un aggiornamento appena installato (chiamata all'inizio di HoloInput.dpr).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: se l'exe e' stato avviato con "--after-update <pid>"
//** aspetta (al massimo 20 secondi) che il vecchio processo sia chiuso, poi
//** cancella i vecchi exe "HoloInput.exe*.old" (riprovando per qualche istante)
//** e la cartella temporanea, e segna l'aggiornamento (JustUpdated). Senza il
//** parametro cancella comunque eventuali .old rimasti da un aggiornamento
//** precedente.
//***********************************************************************************************************
//***********************************************************************************************************
procedure FinishPendingUpdate;
var
    I, Pid, Try_: Integer;
    H: THandle;
    Exe, F: string;
    Left: Boolean;
begin
    Pid := 0;
    for I := 1 to ParamCount - 1 do
        if SameText(ParamStr(I), OPT_AFTER_UPDATE) then
            Pid := StrToIntDef(ParamStr(I + 1), 0);
    if Pid > 0 then
    begin
        GJustUpdated := True;
        H := OpenProcess(SYNCHRONIZE, False, DWORD(Pid));
        if H <> 0 then
        try
            WaitForSingleObject(H, 20000);
        finally
            CloseHandle(H);
        end;
    end;
    Exe := ParamStr(0);
    try
        for Try_ := 1 to 10 do
        begin
            Left := False;
            for F in TDirectory.GetFiles(ExtractFilePath(Exe), ExtractFileName(Exe) + '*.old') do
                if not System.SysUtils.DeleteFile(F) then
                    Left := True;
            if not Left or (Pid = 0) then
                Break;
            Sleep(200);
        end;
        if (Pid > 0) and TDirectory.Exists(UpdateTempDir) then
            TDirectory.Delete(UpdateTempDir, True);
    except
        // pulizia best effort: i file rimasti verranno cancellati al prossimo avvio
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: JustUpdated
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: True se questo avvio segue un aggiornamento appena installato.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
function JustUpdated: Boolean;
begin
    Result := GJustUpdated;
end;

end.
