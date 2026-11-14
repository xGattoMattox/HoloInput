//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Updater
//** Scopo: Aggiornamento automatico dalla pagina delle release su GitHub (controllo, download con barra
//**        di progresso, verifica SHA-256, installazione e riavvio).
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento:
//**   1. bCheckForUpdate legge l'ultima release del repository ufficiale
//**      (API di GitHub, HTTPS con THTTPClient: nessuna DLL esterna) e trova
//**      lo zip "HoloInput-v<versione>-win64.zip" e il suo file di verifica
//**      "<zip>.sha256" creati da TOOLS\make_release.bat.
//**   2. bUpdateAvailable confronta la versione della release con quella
//**      dell'exe (numeri separati da punti). Se la release e' piu' recente
//**      bCheckForUpdate legge anche le novita': le sezioni di CHANGELOG.md (al
//**      tag della release) delle versioni successive a quella in uso, oppure,
//**      se mancano, il testo della release; bAskUpdate le mostra nella finestra
//**      che chiede se aggiornare.
//**   3. bRunUpdate mostra la finestra con la barra di progresso e, in un thread,
//**      scarica il codice di verifica e lo zip, controlla lo SHA-256, estrae lo
//**      zip in una cartella temporanea e installa: l'exe in uso viene rinominato
//**      in "HoloInput.exe.old" (Windows lo consente anche mentre e' in
//**      esecuzione) e al suo posto viene copiato quello nuovo, insieme ai
//**      documenti dello zip (LICENSE, README, CHANGELOG). Senza file di
//**      verifica o con un'impronta diversa l'aggiornamento viene annullato.
//**   4. bRestartAfterUpdate avvia il nuovo exe con "--after-update <pid>": il
//**      nuovo processo (FinishPendingUpdate, chiamata dal .dpr) aspetta che il
//**      vecchio sia chiuso, cosi' le hotkey globali si registrano senza
//**      conflitti, e cancella il vecchio exe e i file temporanei.
//** Il file HoloInput.ini non fa parte dello zip: la configurazione resta.
//** Sicurezza: si scaricano solo file con indirizzo che inizia con
//** UPD_DOWNLOAD_PREFIX (gli allegati delle release del repository ufficiale)
//** e si apre nel browser solo una pagina del repository (bUrlAllowed); lo zip
//** scaricato viene salvato con il nome fisso UPD_TEMP_FILE, mai con il nome
//** indicato da GitHub. Download limitati: lo zip a UPD_MAX_ZIP byte, il file
//** di verifica a UPD_MAX_TEXT (oltre, l'aggiornamento viene annullato).
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
        sVersion: string;          // es. "0.2026.11.8" (tag senza la "v" iniziale)
        sTag: string;              // es. "v0.2026.11.8"
        sPageUrl: string;          // pagina della release
        sZipName: string;
        sZipUrl: string;
        iZipSize: Int64;
        sHashUrl: string;          // file "<zip>.sha256" ('' se manca)
        sBody: string;             // testo della release (Markdown)
        sNotes: string;            // novita' rispetto alla versione in uso (testo semplice)
    end;

/// Confronta due versioni "a.b.c.d": <0 se sAVersionA e' precedente a sAVersionB, 0 se uguali, >0 se
/// successiva.
function iCompareVersions(const sAVersionA, sAVersionB: string): Integer;
/// Legge l'ultima release da GitHub (e, se e' piu' recente di sACurrentVersion, le novita');
/// False (con sAError) se la richiesta non riesce.
function bCheckForUpdate(const sACurrentVersion: string; out rAInfo: TUpdateInfo;
    out sAError: string): Boolean;
/// True se la release trovata e' piu' recente della versione in uso e ha lo zip da scaricare.
function bUpdateAvailable(const rAInfo: TUpdateInfo; const sACurrentVersion: string): Boolean;
/// Chiede se aggiornare mostrando le novita' (Aggiorna / Piu' tardi); True = Aggiorna.
function bAskUpdate(const rAInfo: TUpdateInfo; const sACurrentVersion: string;
    const rAColors: TSkinColors): Boolean;
/// Scarica e installa l'aggiornamento mostrando la barra di progresso. True = installato
/// (va chiamata bRestartAfterUpdate); False con sAError = '' se l'utente ha annullato.
function bRunUpdate(const rAInfo: TUpdateInfo; const rAColors: TSkinColors; out sAError: string): Boolean;
/// Avvia il nuovo exe (che aspetta la chiusura di questo processo); poi l'app va chiusa.
function bRestartAfterUpdate: Boolean;
/// Da chiamare all'avvio (HoloInput.dpr): completa un aggiornamento appena installato.
procedure FinishPendingUpdate;
/// True se questo avvio segue un aggiornamento appena installato.
function bJustUpdated: Boolean;

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
    // unici indirizzi accettati: allegati delle release e pagine del repository ufficiale
    UPD_DOWNLOAD_PREFIX = 'https://github.com/' + UPDATE_REPO + '/releases/download/';
    UPD_PAGE_PREFIX = 'https://github.com/' + UPDATE_REPO + '/';
    UPD_TEMP_FILE = 'TempGatto.nuovaversione';   // nome dello zip scaricato nella cartella temporanea
    UPD_MAX_ZIP = 200 * 1024 * 1024;   // dimensione massima dello zip della release (byte)
    UPD_MAX_TEXT = 64 * 1024;          // dimensione massima del file .sha256 (byte)

type
    /// Fasi dell'aggiornamento mostrate nella finestra.
    TUpdateStage = (usHash, usDownload, usVerify, usExtract, usInstall);

    /// Sfondo della finestra: pannello smussato con bordo accento e riga sotto il titolo.
    THoloUpdatePanel = class(TControl)
    private
        rFColors: TSkinColors;
    protected
        procedure Paint; override;
    end;

    /// Barra di progresso nei colori della skin (Position 0..1).
    THoloProgressBar = class(TControl)
    private
        rFColors: TSkinColors;
        dFPosition: Single;
        procedure SetPosition(dAValue: Single);
    protected
        procedure Paint; override;
    public
        property dPosition: Single read dFPosition write SetPosition;
    end;

    THoloUpdateForm = class;

    /// Thread che scarica, verifica e installa l'aggiornamento.
    TUpdateWorker = class(TThread)
    private
        oFForm: THoloUpdateForm;
        rFInfo: TUpdateInfo;
        sFError: string;
        bFSuccess: Boolean;
        bFCancel: Boolean;
        rFClock: TStopwatch;
        iFLastUi: Int64;
        eFStage: TUpdateStage;
        iFDone, iFTotal: Int64;
        iFLimit: Int64;                 // byte massimi del download in corso
        bFTooBig: Boolean;              // download interrotto perche' oltre iFLimit
        procedure ReceiveData(const oSender: TObject; iAContentLength: Int64; iAReadCount: Int64;
            var bAAbort: Boolean);
        procedure SetStage(eAStage: TUpdateStage);
        procedure ShowProgress;
        procedure RaiseTooBig;
        function sDownloadText(const sAUrl: string): string;
        procedure DownloadFile(const sAUrl, sAFileName: string);
        procedure Install(const sASourceDir: string);
    protected
        procedure Execute; override;
    end;

    /// Finestra dell'aggiornamento (creata da codice, senza .fmx).
    THoloUpdateForm = class(TForm)
    private
        oFWorker: TUpdateWorker;
        oFStatus, oFDetail: TLabel;
        oFBar: THoloProgressBar;
        oFCancelBtn: THoloButton;
        sFVersion: string;
        bFStarted: Boolean;
        procedure CancelClick(oSender: TObject);
        procedure WorkerDone(oSender: TObject);
        procedure ShowStage(eAStage: TUpdateStage; iADone, iATotal: Int64);
    protected
        procedure DoShow; override;
        procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    public
        destructor Destroy; override;
    end;

    /// Finestra che chiede se aggiornare, con le novita' (creata da codice, senza .fmx).
    THoloAskUpdateForm = class(TForm)
    private
        procedure OkClick(oSender: TObject);
        procedure LaterClick(oSender: TObject);
    protected
        procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    end;

var
    bGJustUpdated: Boolean = False;

//** funzioni di servizio ***********************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sUpdateTempDir
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Cartella temporanea dell'aggiornamento (%TEMP%\HoloInput-update).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
function sUpdateTempDir: string;
begin
    Result := TPath.Combine(TPath.GetTempPath, 'HoloInput-update');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: oNewClient
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: THTTPClient
//** Scopo: Creare il client HTTPS (WinHTTP di Windows) con user agent e tempi di attesa.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: GitHub rifiuta le richieste all'API senza user agent; i
//** redirect (lo zip si scarica da un altro dominio di GitHub) sono seguiti.
//***********************************************************************************************************
//***********************************************************************************************************
function oNewClient: THTTPClient;
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
//** Nome funzione: iCompareVersions
//** Parametri di ingresso: sAVersionA, sAVersionB: string
//** Parametri di uscita: Result: Integer
//** Scopo: Confrontare due versioni "a.b.c.d" (una "v" iniziale viene ignorata).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: confronta i numeri da sinistra; le parti mancanti valgono 0
//** ("1.2" = "1.2.0.0"), le parti non numeriche valgono 0.
//***********************************************************************************************************
//***********************************************************************************************************
function iCompareVersions(const sAVersionA, sAVersionB: string): Integer;
var
    aPartsA, aPartsB: TArray<string>;
    iPart, iNumA, iNumB: Integer;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: sClean
    //** Parametri di ingresso: sAVersion: string
    //** Parametri di uscita: Result: string
    //** Scopo: Togliere spazi e la "v" iniziale da una versione.
    //** Data Ultima Modifica: 06/11/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function sClean(const sAVersion: string): string;
    begin
        Result := Trim(sAVersion);
        if (Result <> '') and CharInSet(Result[1], ['v', 'V']) then
            Delete(Result, 1, 1);
    end;

begin
    aPartsA := sClean(sAVersionA).Split(['.']);
    aPartsB := sClean(sAVersionB).Split(['.']);
    for iPart := 0 to Max(Length(aPartsA), Length(aPartsB)) - 1 do
    begin
        iNumA := 0;
        iNumB := 0;
        if iPart < Length(aPartsA) then
            iNumA := StrToIntDef(aPartsA[iPart], 0);
        if iPart < Length(aPartsB) then
            iNumB := StrToIntDef(aPartsB[iPart], 0);
        if iNumA <> iNumB then
            Exit(CompareValue(iNumA, iNumB));
    end;
    Result := 0;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sMarkdownToText
//** Parametri di ingresso: sAText: string
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
function sMarkdownToText(const sAText: string): string;
var
    oLines: TStringList;
    oRes: TStringBuilder;
    sLine, sTrimmed: string;
    iLineIndex, iLinkStart, iLinkEnd: Integer;
    bLastBlank: Boolean;
begin
    oLines := TStringList.Create;
    oRes := TStringBuilder.Create;
    try
        oLines.Text := sAText;
        bLastBlank := True;
        for iLineIndex := 0 to oLines.Count - 1 do
        begin
            sLine := TrimRight(oLines[iLineIndex]);
            // link [testo](indirizzo) -> testo
            iLinkStart := Pos('](', sLine);
            while iLinkStart > 0 do
            begin
                iLinkEnd := Pos(')', sLine, iLinkStart);
                if iLinkEnd = 0 then
                    Break;
                Delete(sLine, iLinkStart + 1, iLinkEnd - iLinkStart);
                iLinkStart := Pos('](', sLine);
            end;
            sLine := sLine.Replace('**', '').Replace('`', '').Replace('*', '').Replace('[', '').Replace(']',
                '');
            sTrimmed := Trim(sLine);
            if sTrimmed.StartsWith('## ') then
                sLine := #$25A0 + ' ' + Trim(Copy(sTrimmed, 4, MaxInt)).Replace(' - ', '  -  ')
            else if sTrimmed.StartsWith('### ') then
                sLine := Trim(Copy(sTrimmed, 5, MaxInt)) + ':'
            else if sTrimmed.StartsWith('# ') then
                sLine := Trim(Copy(sTrimmed, 3, MaxInt))
            else if sTrimmed.StartsWith('- ') then
                sLine := '  ' + #$2022 + ' ' + Trim(Copy(sTrimmed, 3, MaxInt))
            else
                sLine := sTrimmed;
            if sLine = '' then
            begin
                if not bLastBlank then
                    oRes.AppendLine;
                bLastBlank := True;
            end
            else
            begin
                oRes.AppendLine(sLine);
                bLastBlank := False;
            end;
        end;
        Result := Trim(oRes.ToString);
    finally
        oRes.Free;
        oLines.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sReleaseNotes
//** Parametri di ingresso: rAInfo: TUpdateInfo; sACurrentVersion: string
//** Parametri di uscita: Result: string
//** Scopo: Novita' della release rispetto alla versione in uso, come testo semplice.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: scarica CHANGELOG.md dal repository al tag della release
//** e tiene le sezioni "## [versione]" successive a sACurrentVersion e non oltre
//** la versione della release (la sezione [Unreleased] viene ignorata). Se il
//** file non si legge o non contiene quelle sezioni usa il testo della release.
//** Gli errori di rete non interrompono il controllo degli aggiornamenti.
//***********************************************************************************************************
//***********************************************************************************************************
function sReleaseNotes(const rAInfo: TUpdateInfo; const sACurrentVersion: string): string;
var
    oClient: THTTPClient;
    xResp: IHTTPResponse;
    oLines: TStringList;
    oPicked: TStringBuilder;
    iLineIndex, iBracketPos: Integer;
    sLine, sVer: string;
    bKeep: Boolean;
begin
    Result := '';
    try
        oClient := oNewClient;
        try
            xResp := oClient.Get('https://raw.githubusercontent.com/' + UPDATE_REPO + '/' + rAInfo.sTag +
                '/CHANGELOG.md');
            if xResp.StatusCode = 200 then
            begin
                oLines := TStringList.Create;
                oPicked := TStringBuilder.Create;
                try
                    oLines.Text := xResp.ContentAsString(TEncoding.UTF8);
                    bKeep := False;
                    for iLineIndex := 0 to oLines.Count - 1 do
                    begin
                        sLine := oLines[iLineIndex];
                        if sLine.StartsWith('## ') then
                        begin
                            // "## [0.2026.11.8] - 2026-11-08"
                            sVer := '';
                            iBracketPos := Pos('[', sLine);
                            if iBracketPos > 0 then
                                sVer := Copy(sLine, iBracketPos + 1, Pos(']', sLine) - iBracketPos - 1);
                            bKeep := (sVer <> '') and not SameText(sVer, 'Unreleased') and
                                (iCompareVersions(sVer, sACurrentVersion) > 0) and
                                (iCompareVersions(sVer, rAInfo.sVersion) <= 0);
                        end;
                        if bKeep then
                            oPicked.AppendLine(sLine);
                    end;
                    Result := sMarkdownToText(oPicked.ToString);
                finally
                    oPicked.Free;
                    oLines.Free;
                end;
            end;
        finally
            oClient.Free;
        end;
    except
        Result := '';
    end;
    if Result = '' then
        Result := sMarkdownToText(rAInfo.sBody);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: bUrlAllowed
//** Parametri di ingresso: sAUrl, sAPrefix: string
//** Parametri di uscita: Result: Boolean
//** Scopo: Verificare che un indirizzo letto da GitHub appartenga al repository ufficiale.
//** Data Ultima Modifica: 10/11/2026
//***********************************************************************************************************
//** Funzionamento: l'indirizzo deve iniziare con sAPrefix (maiuscole e
//** minuscole indifferenti) e continuare dopo il prefisso; non puo' contenere
//** "..", "\" o "%" (niente salti ad altre cartelle del sito, neppure
//** codificati).
//***********************************************************************************************************
//***********************************************************************************************************
function bUrlAllowed(const sAUrl, sAPrefix: string): Boolean;
begin
    Result := sAUrl.StartsWith(sAPrefix, True) and (Length(sAUrl) > Length(sAPrefix)) and
        not sAUrl.Contains('..') and not sAUrl.Contains('\') and not sAUrl.Contains('%');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: bCheckForUpdate
//** Parametri di ingresso: sACurrentVersion: string
//** Parametri di uscita: rAInfo: TUpdateInfo; sAError: string; Result: Boolean
//** Scopo: Leggere da GitHub l'ultima release pubblicata e, se e' piu' recente della versione in
//**        uso, le sue novita'.
//** Data Ultima Modifica: 10/11/2026
//***********************************************************************************************************
//** Funzionamento: chiama l'API "releases/latest" del repository ufficiale e
//** cerca tra gli allegati lo zip "HoloInput-...-win64.zip" e il file
//** "<zip>.sha256", accettando solo indirizzi di download del repository
//** ufficiale (bUrlAllowed); la pagina della release, se non e' del
//** repository, diventa UPDATE_PAGE_URL. Se la release e' piu' recente di sACurrentVersion legge le
//** novita' (sReleaseNotes). Puo' essere chiamata da un thread secondario (non
//** usa l'interfaccia). False con sAError se la rete o GitHub non rispondono.
//***********************************************************************************************************
//***********************************************************************************************************
function bCheckForUpdate(const sACurrentVersion: string; out rAInfo: TUpdateInfo;
    out sAError: string): Boolean;
var
    oClient: THTTPClient;
    xResp: IHTTPResponse;
    oRoot: TJSONValue;
    oObj, oAsset: TJSONObject;
    oAssets: TJSONArray;
    iAsset: Integer;
    sName, sUrl: string;
begin
    Result := False;
    rAInfo := Default(TUpdateInfo);
    sAError := '';
    oRoot := nil;
    try
        oClient := oNewClient;
        try
            oClient.Accept := 'application/vnd.github+json';
            xResp := oClient.Get(UPDATE_API_URL);
            if xResp.StatusCode <> 200 then
            begin
                sAError := Format('HTTP %d %s', [xResp.StatusCode, xResp.StatusText]);
                Exit;
            end;
            oRoot := TJSONObject.ParseJSONValue(xResp.ContentAsString(TEncoding.UTF8));
        finally
            oClient.Free;
        end;
        if not (oRoot is TJSONObject) then
        begin
            oRoot.Free;
            sAError := 'risposta di GitHub non valida';
            Exit;
        end;
        try
            oObj := TJSONObject(oRoot);
            rAInfo.sTag := oObj.GetValue<string>('tag_name', '');
            rAInfo.sVersion := rAInfo.sTag;
            if (rAInfo.sVersion <> '') and CharInSet(rAInfo.sVersion[1], ['v', 'V']) then
                Delete(rAInfo.sVersion, 1, 1);
            rAInfo.sPageUrl := oObj.GetValue<string>('html_url', UPDATE_PAGE_URL);
            if not bUrlAllowed(rAInfo.sPageUrl, UPD_PAGE_PREFIX) then
                rAInfo.sPageUrl := UPDATE_PAGE_URL;
            rAInfo.sBody := oObj.GetValue<string>('body', '');
            if oObj.TryGetValue<TJSONArray>('assets', oAssets) then
            begin
                // prima lo zip, poi il suo file di verifica
                for iAsset := 0 to oAssets.Count - 1 do
                    if oAssets.Items[iAsset] is TJSONObject then
                    begin
                        oAsset := TJSONObject(oAssets.Items[iAsset]);
                        sName := oAsset.GetValue<string>('name', '');
                        sUrl := oAsset.GetValue<string>('browser_download_url', '');
                        if sName.StartsWith('HoloInput', True) and sName.EndsWith('-win64.zip', True) and
                            bUrlAllowed(sUrl, UPD_DOWNLOAD_PREFIX) then
                        begin
                            rAInfo.sZipName := sName;
                            rAInfo.sZipUrl := sUrl;
                            rAInfo.iZipSize := oAsset.GetValue<Int64>('size', 0);
                        end;
                    end;
                if rAInfo.sZipName <> '' then
                    for iAsset := 0 to oAssets.Count - 1 do
                        if oAssets.Items[iAsset] is TJSONObject then
                        begin
                            oAsset := TJSONObject(oAssets.Items[iAsset]);
                            sName := oAsset.GetValue<string>('name', '');
                            sUrl := oAsset.GetValue<string>('browser_download_url', '');
                            if SameText(sName, rAInfo.sZipName + '.sha256') and
                                bUrlAllowed(sUrl, UPD_DOWNLOAD_PREFIX) then
                                rAInfo.sHashUrl := sUrl;
                        end;
            end;
        finally
            oRoot.Free;
        end;
        if rAInfo.sVersion = '' then
        begin
            sAError := 'nessuna release trovata';
            Exit;
        end;
        if bUpdateAvailable(rAInfo, sACurrentVersion) then
            rAInfo.sNotes := sReleaseNotes(rAInfo, sACurrentVersion);
        Result := True;
    except
        on oError: Exception do
            sAError := oError.Message;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: bUpdateAvailable
//** Parametri di ingresso: rAInfo: TUpdateInfo; sACurrentVersion: string
//** Parametri di uscita: Result: Boolean
//** Scopo: Indicare se la release trovata e' piu' recente della versione in uso e si puo' scaricare.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
function bUpdateAvailable(const rAInfo: TUpdateInfo; const sACurrentVersion: string): Boolean;
begin
    Result := (rAInfo.sZipUrl <> '') and (iCompareVersions(rAInfo.sVersion, sACurrentVersion) > 0);
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
    rRect: TRectF;
    oPath: TPathData;
begin
    rRect := LocalRect;
    rRect.Inflate(-1.5, -1.5);
    oPath := oChamferPath(rRect, 18);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.Fill.Color := iWithAlpha(iMixColors(rFColors.iPanelBack, TAlphaColors.Black, 0.35), $F4);
        Canvas.FillPath(oPath, AbsoluteOpacity);
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 2;
        Canvas.Stroke.Color := rFColors.iAccent;
        Canvas.DrawPath(oPath, AbsoluteOpacity);
    finally
        oPath.Free;
    end;
    Canvas.Stroke.Thickness := 1;
    Canvas.Stroke.Color := rFColors.iPanelBorder;
    Canvas.DrawLine(PointF(UPD_PAD, UPD_TITLE_LINE_Y), PointF(Width - UPD_PAD, UPD_TITLE_LINE_Y),
        AbsoluteOpacity);
end;

//** THoloProgressBar ***************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloProgressBar.SetPosition
//** Parametri di ingresso: dAValue: Single
//** Parametri di uscita: nessuno
//** Scopo: Impostare l'avanzamento (0..1) e ridisegnare la barra.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloProgressBar.SetPosition(dAValue: Single);
begin
    dAValue := EnsureRange(dAValue, 0, 1);
    if SameValue(dAValue, dFPosition, 0.001) then
        Exit;
    dFPosition := dAValue;
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
    rRect, rFillRect: TRectF;
    oPath: TPathData;
begin
    rRect := LocalRect;
    rRect.Inflate(-1, -1);
    oPath := oChamferPath(rRect, 6);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.Fill.Color := iWithAlpha(rFColors.iPrimary, $18);
        Canvas.FillPath(oPath, AbsoluteOpacity);
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 1;
        Canvas.Stroke.Color := rFColors.iPanelBorder;
        Canvas.DrawPath(oPath, AbsoluteOpacity);
    finally
        oPath.Free;
    end;
    if dFPosition > 0 then
    begin
        rFillRect := rRect;
        rFillRect.Inflate(-3, -3);
        rFillRect.Right := rFillRect.Left + rFillRect.Width * dFPosition;
        Canvas.Fill.Color := iWithAlpha(rFColors.iPrimary, $D0);
        Canvas.FillRect(rFillRect, 0, 0, [], AbsoluteOpacity);
    end;
end;

//** TUpdateWorker ******************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TUpdateWorker.SetStage
//** Parametri di ingresso: eAStage: TUpdateStage
//** Parametri di uscita: nessuno
//** Scopo: Passare a una nuova fase e mostrarla nella finestra.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TUpdateWorker.SetStage(eAStage: TUpdateStage);
begin
    eFStage := eAStage;
    iFDone := 0;
    iFTotal := 0;
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
    oFForm.ShowStage(eFStage, iFDone, iFTotal);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TUpdateWorker.ReceiveData
//** Parametri di ingresso: oSender: TObject; iAContentLength, iAReadCount: Int64; bAAbort: Boolean (var)
//** Parametri di uscita: bAAbort: Boolean (var)
//** Scopo: Avanzamento del download: aggiorna la barra (al massimo ogni UPD_UI_INTERVAL_MS) e
//**        interrompe il download se l'utente ha annullato.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento: se il download supera iFLimit (o lo annuncia) viene
//** interrotto e bFTooBig diventa True.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TUpdateWorker.ReceiveData(const oSender: TObject; iAContentLength: Int64; iAReadCount: Int64;
    var bAAbort: Boolean);
begin
    bAAbort := bFCancel or Terminated;
    if (iAReadCount > iFLimit) or (iAContentLength > iFLimit) then
    begin
        bFTooBig := True;
        bAAbort := True;
        Exit;
    end;
    if eFStage <> usDownload then
        Exit;
    iFDone := iAReadCount;
    if iAContentLength > 0 then
        iFTotal := iAContentLength
    else
        iFTotal := rFInfo.iZipSize;
    if (rFClock.ElapsedMilliseconds - iFLastUi >= UPD_UI_INTERVAL_MS) or
        ((iFTotal > 0) and (iFDone >= iFTotal)) then
    begin
        iFLastUi := rFClock.ElapsedMilliseconds;
        Synchronize(ShowProgress);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sTooBigMessage
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Messaggio mostrato quando un file della release supera la dimensione massima.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
function sTooBigMessage: string;
begin
    Result := sTr('update.err.size', 'Un file della release e'' troppo grande: aggiornamento annullato.');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TUpdateWorker.RaiseTooBig
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Annullare l'aggiornamento perche' un file della release e' troppo grande.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TUpdateWorker.RaiseTooBig;
begin
    raise Exception.Create(sTooBigMessage);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TUpdateWorker.sDownloadText
//** Parametri di ingresso: sAUrl: string
//** Parametri di uscita: Result: string
//** Scopo: Scaricare un file di testo piccolo (il codice di verifica).
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TUpdateWorker.sDownloadText(const sAUrl: string): string;
var
    oClient: THTTPClient;
    xResp: IHTTPResponse;
begin
    oClient := oNewClient;
    try
        iFLimit := UPD_MAX_TEXT;
        bFTooBig := False;
        oClient.OnReceiveData := ReceiveData;
        xResp := oClient.Get(sAUrl);
        if bFTooBig then
            RaiseTooBig;
        if bFCancel then
            Abort;
        if xResp.StatusCode <> 200 then
            raise Exception.CreateFmt('HTTP %d %s', [xResp.StatusCode, xResp.StatusText]);
        Result := xResp.ContentAsString(TEncoding.UTF8);
    finally
        oClient.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TUpdateWorker.DownloadFile
//** Parametri di ingresso: sAUrl, sAFileName: string
//** Parametri di uscita: nessuno
//** Scopo: Scaricare lo zip in sAFileName mostrando l'avanzamento.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TUpdateWorker.DownloadFile(const sAUrl, sAFileName: string);
var
    oClient: THTTPClient;
    xResp: IHTTPResponse;
    oStream: TFileStream;
begin
    oClient := oNewClient;
    try
        iFLimit := UPD_MAX_ZIP;
        bFTooBig := False;
        oClient.OnReceiveData := ReceiveData;
        oStream := TFileStream.Create(sAFileName, fmCreate);
        try
            xResp := oClient.Get(sAUrl, oStream);
        finally
            oStream.Free;
        end;
        if bFTooBig then
            RaiseTooBig;
        if bFCancel then
            Abort;
        if xResp.StatusCode <> 200 then
            raise Exception.CreateFmt('HTTP %d %s', [xResp.StatusCode, xResp.StatusText]);
    finally
        oClient.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TUpdateWorker.Install
//** Parametri di ingresso: sASourceDir: string
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
procedure TUpdateWorker.Install(const sASourceDir: string);
var
    aFound: TArray<string>;
    sNewExe, sExe, sOld, sAppDir, sSrcDir, sFileName: string;
begin
    aFound := TDirectory.GetFiles(sASourceDir, 'HoloInput.exe', TSearchOption.soAllDirectories);
    if Length(aFound) = 0 then
        raise Exception.Create(sTr('update.err.noexe', 'Lo zip non contiene HoloInput.exe.'));
    sNewExe := aFound[0];
    sSrcDir := ExtractFilePath(sNewExe);
    sExe := ParamStr(0);
    sAppDir := ExtractFilePath(sExe);

    sOld := sExe + '.old';
    if FileExists(sOld) and not System.SysUtils.DeleteFile(sOld) then
        sOld := sExe + '.' + IntToStr(GetTickCount) + '.old';
    if not RenameFile(sExe, sOld) then
        raise Exception.Create(Format(sTr('update.err.write', 'Impossibile sostituire HoloInput.exe ' +
            '(la cartella non e'' scrivibile?): %s'), [SysErrorMessage(GetLastError)]));
    if not CopyFile(PChar(sNewExe), PChar(sExe), False) then
    begin
        sFileName := SysErrorMessage(GetLastError);
        RenameFile(sOld, sExe);
        raise Exception.Create(Format(sTr('update.err.write', 'Impossibile sostituire HoloInput.exe ' +
            '(la cartella non e'' scrivibile?): %s'), [sFileName]));
    end;

    // documenti dello zip (best effort: un errore qui non annulla l'aggiornamento)
    for sFileName in TDirectory.GetFiles(sSrcDir) do
        if not SameText(ExtractFileName(sFileName), 'HoloInput.exe') and
            not SameText(ExtractFileExt(sFileName), '.ini') then
        try
            TFile.Copy(sFileName, TPath.Combine(sAppDir, ExtractFileName(sFileName)), True);
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
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento: svuota la cartella temporanea; scarica il file .sha256
//** (obbligatorio) e ne legge l'impronta; scarica lo zip con l'avanzamento
//** (salvato come UPD_TEMP_FILE, al massimo UPD_MAX_ZIP byte);
//** confronta lo SHA-256 dello zip con l'impronta; estrae lo zip e installa.
//** Ogni errore (o l'annullamento) interrompe l'aggiornamento senza toccare
//** l'exe in uso, salvo nella fase di installazione, che lo ripristina da sola.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TUpdateWorker.Execute;
var
    sDir, sZipFile, sExtractDir, sExpected, sActual: string;
    aParts: TArray<string>;
begin
    if bFCancel then
        Exit;   // thread mai avviato (finestra distrutta prima di comparire)
    rFClock := TStopwatch.StartNew;
    try
        sDir := sUpdateTempDir;
        if TDirectory.Exists(sDir) then
            TDirectory.Delete(sDir, True);
        TDirectory.CreateDirectory(sDir);

        // 1. codice di verifica (obbligatorio)
        SetStage(usHash);
        if rFInfo.sHashUrl = '' then
            raise Exception.Create(sTr('update.err.nohash', 'Nella release manca il file di verifica ' +
                '(.sha256): aggiornamento annullato.'));
        aParts := Trim(sDownloadText(rFInfo.sHashUrl)).Split([' ', #9, #13, #10],
            TStringSplitOptions.ExcludeEmpty);
        if (Length(aParts) = 0) or (Length(aParts[0]) <> 64) then
            raise Exception.Create(sTr('update.err.nohash', 'Nella release manca il file di verifica ' +
                '(.sha256): aggiornamento annullato.'));
        sExpected := LowerCase(aParts[0]);
        if bFCancel then
            Abort;

        // 2. download dello zip (la dimensione dichiarata da GitHub e' controllata subito)
        if rFInfo.iZipSize > UPD_MAX_ZIP then
            RaiseTooBig;
        SetStage(usDownload);
        sZipFile := TPath.Combine(sDir, UPD_TEMP_FILE);
        DownloadFile(rFInfo.sZipUrl, sZipFile);

        // 3. verifica dello SHA-256
        SetStage(usVerify);
        sActual := LowerCase(THashSHA2.GetHashStringFromFile(sZipFile));
        if sActual <> sExpected then
            raise Exception.Create(sTr('update.err.hash', 'Il file scaricato non corrisponde al codice ' +
                'di verifica (SHA-256): aggiornamento annullato.'));
        if bFCancel then
            Abort;

        // 4. estrazione
        SetStage(usExtract);
        sExtractDir := TPath.Combine(sDir, 'files');
        TZipFile.ExtractZipFile(sZipFile, sExtractDir);
        if bFCancel then
            Abort;

        // 5. installazione (da qui in poi non si annulla piu')
        SetStage(usInstall);
        Install(sExtractDir);
        bFSuccess := True;
    except
        on oError: EAbort do
            sFError := '';
        on oError: Exception do
            if bFTooBig then
                sFError := sTooBigMessage   // il client HTTP puo' segnalare l'interruzione come errore
            else if bFCancel then
                sFError := ''
            else
                sFError := oError.Message;
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
    if (oFWorker <> nil) and not bFStarted then
    begin
        bFStarted := True;
        oFWorker.Start;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloUpdateForm.ShowStage
//** Parametri di ingresso: eAStage: TUpdateStage; iADone, iATotal: Int64
//** Parametri di uscita: nessuno
//** Scopo: Mostrare la fase in corso, la barra di progresso e i MB scaricati.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: la barra indica il download; nelle fasi successive resta
//** piena. Durante l'installazione il pulsante Annulla viene disattivato.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloUpdateForm.ShowStage(eAStage: TUpdateStage; iADone, iATotal: Int64);
begin
    case eAStage of
        usHash:
            oFStatus.Text := sTr('update.stage.hash', 'Lettura del codice di verifica...');
        usDownload:
            oFStatus.Text := Format(sTr('update.stage.download', 'Download di HoloInput %s...'),
                [sFVersion]);
        usVerify:
            oFStatus.Text := sTr('update.stage.verify', 'Verifica del file scaricato (SHA-256)...');
        usExtract:
            oFStatus.Text := sTr('update.stage.extract', 'Estrazione dei file...');
        usInstall:
            oFStatus.Text := sTr('update.stage.install', 'Installazione...');
    end;
    if eAStage = usDownload then
    begin
        if iATotal > 0 then
        begin
            oFBar.dPosition := iADone / iATotal;
            oFDetail.Text := Format(sTr('update.size', '%.1f / %.1f MB'),
                [iADone / 1048576, iATotal / 1048576]);
        end
        else
            oFDetail.Text := Format(sTr('update.size.unknown', '%.1f MB'), [iADone / 1048576]);
    end
    else if eAStage > usDownload then
    begin
        oFBar.dPosition := 1;
        oFDetail.Text := '';
    end;
    if eAStage = usInstall then
    begin
        oFCancelBtn.Enabled := False;
        oFCancelBtn.Opacity := 0.35;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloUpdateForm.CancelClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiedere l'annullamento: la finestra si chiude quando il thread si e' fermato.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloUpdateForm.CancelClick(oSender: TObject);
begin
    if (oFWorker = nil) or not oFCancelBtn.Enabled then
        Exit;
    oFWorker.bFCancel := True;
    oFCancelBtn.Enabled := False;
    oFCancelBtn.Opacity := 0.35;
    oFStatus.Text := sTr('update.stage.cancel', 'Annullamento in corso...');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloUpdateForm.WorkerDone
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiudere la finestra al termine del thread (OnTerminate, nel thread principale).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloUpdateForm.WorkerDone(oSender: TObject);
begin
    if oFWorker.bFSuccess then
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
    if oFWorker <> nil then
    begin
        oFWorker.bFCancel := True;
        oFWorker.OnTerminate := nil;
        if bFStarted and not oFWorker.Finished then
            oFWorker.WaitFor;
        FreeAndNil(oFWorker);
    end;
    inherited;
end;

//** bAskUpdate
//** **********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: oMakeText
//** Parametri di ingresso: oAParent: TFmxObject; dAPosX, dAPosY, dAWidth, dAHeight, dASize: Single; bABold:
//**                        Boolean; iAColor:
//**                        TAlphaColor; sAText: string
//** Parametri di uscita: Result: TLabel
//** Scopo: Creare un testo della finestra con il font dell'app.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
function oMakeText(oAParent: TFmxObject; dAPosX, dAPosY, dAWidth, dAHeight, dASize: Single; bABold: Boolean;
    iAColor: TAlphaColor;
    const sAText: string): TLabel;
begin
    Result := TLabel.Create(oAParent);
    Result.Parent := oAParent;
    Result.SetBounds(dAPosX, dAPosY, dAWidth, dAHeight);
    Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Family,
        TStyledSetting.Size, TStyledSetting.Style, TStyledSetting.FontColor];
    Result.TextSettings.Font.Family := HOLO_FONT;
    Result.TextSettings.Font.Size := dASize;
    if bABold then
        Result.TextSettings.Font.Style := [TFontStyle.fsBold];
    Result.TextSettings.FontColor := iAColor;
    Result.TextSettings.VertAlign := TTextAlign.Leading;
    Result.WordWrap := True;
    Result.Text := sAText;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloAskUpdateForm.OkClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Scegliere Aggiorna.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloAskUpdateForm.OkClick(oSender: TObject);
begin
    ModalResult := mrOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloAskUpdateForm.LaterClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Scegliere Piu' tardi.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloAskUpdateForm.LaterClick(oSender: TObject);
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
//** Nome funzione: bAskUpdate
//** Parametri di ingresso: rAInfo: TUpdateInfo; sACurrentVersion: string; rAColors: TSkinColors
//** Parametri di uscita: Result: Boolean
//** Scopo: Chiedere se aggiornare, mostrando le novita' della nuova versione.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: finestra senza bordi nello stile degli avvisi, piu' grande:
//** titolo, versione nuova e in uso, riquadro scorrevole con le novita'
//** (rAInfo.Notes; se mancano un rimando alla pagina della release) e i pulsanti
//** Aggiorna e Piu' tardi. Invio = Aggiorna, Esc = Piu' tardi.
//***********************************************************************************************************
//***********************************************************************************************************
function bAskUpdate(const rAInfo: TUpdateInfo; const sACurrentVersion: string;
    const rAColors: TSkinColors): Boolean;
const
    ASK_W = 680;
    ASK_H = 520;
var
    oForm: THoloAskUpdateForm;
    oPanel: THoloUpdatePanel;
    oBox: TVertScrollBox;
    oNotes: TLabel;
    oBOk, oBLater: THoloButton;
    sTxt: string;
begin
    oForm := THoloAskUpdateForm.CreateNew(nil);
    try
        oForm.BorderStyle := TFmxFormBorderStyle.None;
        oForm.Transparency := True;
        oForm.FormStyle := TFormStyle.StayOnTop;
        oForm.Position := TFormPosition.ScreenCenter;
        oForm.Caption := sTr('update.found.title', 'Aggiornamento disponibile');
        oForm.Width := ASK_W;
        oForm.Height := ASK_H;

        oPanel := THoloUpdatePanel.Create(oForm);
        oPanel.rFColors := rAColors;
        oPanel.Parent := oForm;
        oPanel.Align := TAlignLayout.Client;
        oPanel.HitTest := False;

        oMakeText(oPanel, UPD_PAD, 16, ASK_W - 2 * UPD_PAD, 32, 16, True, rAColors.iAccent,
            UpperCase(sTr('update.found.title', 'Aggiornamento disponibile')));
        oMakeText(oPanel, UPD_PAD, UPD_TITLE_LINE_Y + 12, ASK_W - 2 * UPD_PAD, 44, 12, False, rAColors.iText,
            Format(sTr('update.found.text', 'E'' disponibile HoloInput %s (versione in uso: %s).' +
            sLineBreak + sLineBreak + 'Scaricarla e installarla ora? Al termine HoloInput si riavvia ' +
            'da solo.'), [rAInfo.sVersion, sACurrentVersion]));
        oMakeText(oPanel, UPD_PAD, UPD_TITLE_LINE_Y + 70, ASK_W - 2 * UPD_PAD, 20, 11, True,
            iWithAlpha(rAColors.iPrimary, $D0), UpperCase(sTr('update.notes.title', 'Novita''')));

        // riquadro scorrevole con le novita'
        oBox := TVertScrollBox.Create(oForm);
        oBox.Parent := oPanel;
        oBox.SetBounds(UPD_PAD, UPD_TITLE_LINE_Y + 94, ASK_W - 2 * UPD_PAD,
            ASK_H - (UPD_TITLE_LINE_Y + 94) - UPD_BTN_H - 2 * UPD_PAD);
        sTxt := rAInfo.sNotes;
        if sTxt = '' then
            sTxt := Format(sTr('update.notes.none', 'Le novita'' sono descritte nella pagina della ' +
                'release: %s'), [rAInfo.sPageUrl]);
        oNotes := oMakeText(oBox, 4, 4, oBox.Width - 28, 20, 11, False, iWithAlpha(rAColors.iText, $E0),
            sTxt);
        oNotes.TextSettings.Font.Family := 'Segoe UI';
        oNotes.AutoSize := True;

        oBLater := THoloButton.Create(oForm);
        oBLater.Parent := oPanel;
        oBLater.SetBounds(ASK_W - UPD_PAD - UPD_BTN_W, ASK_H - UPD_PAD - UPD_BTN_H, UPD_BTN_W, UPD_BTN_H);
        oBLater.sText := sTr('update.found.later', 'Piu'' tardi');
        oBLater.SetColors(rAColors);
        oBLater.OnClick := oForm.LaterClick;

        oBOk := THoloButton.Create(oForm);
        oBOk.Parent := oPanel;
        oBOk.SetBounds(ASK_W - UPD_PAD - 2 * UPD_BTN_W - 12, ASK_H - UPD_PAD - UPD_BTN_H, UPD_BTN_W,
            UPD_BTN_H);
        oBOk.sText := sTr('update.found.ok', 'Aggiorna');
        oBOk.SetColors(rAColors);
        oBOk.OnClick := oForm.OkClick;

        Result := oForm.ShowModal = mrOk;
    finally
        oForm.Free;
    end;
end;

//** bRunUpdate
//** **********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: bRunUpdate
//** Parametri di ingresso: rAInfo: TUpdateInfo; rAColors: TSkinColors
//** Parametri di uscita: sAError: string; Result: Boolean
//** Scopo: Mostrare la finestra con la barra di progresso ed eseguire l'aggiornamento.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: finestra senza bordi nello stile degli avvisi, sempre in
//** primo piano e centrata sullo schermo: titolo, fase in corso, barra di
//** progresso, MB scaricati e pulsante Annulla. Il thread parte quando la
//** finestra compare e la chiude al termine. True se l'aggiornamento e' stato
//** installato; False con sAError = '' se l'utente ha annullato.
//***********************************************************************************************************
//***********************************************************************************************************
function bRunUpdate(const rAInfo: TUpdateInfo; const rAColors: TSkinColors; out sAError: string): Boolean;
var
    oForm: THoloUpdateForm;
    oPanel: THoloUpdatePanel;
begin
    sAError := '';
    oForm := THoloUpdateForm.CreateNew(nil);
    try
        oForm.BorderStyle := TFmxFormBorderStyle.None;
        oForm.Transparency := True;
        oForm.FormStyle := TFormStyle.StayOnTop;
        oForm.Position := TFormPosition.ScreenCenter;
        oForm.Caption := sTr('update.title', 'Aggiornamento di HoloInput');
        oForm.Width := UPD_W;
        oForm.Height := UPD_H;
        oForm.sFVersion := rAInfo.sVersion;

        oPanel := THoloUpdatePanel.Create(oForm);
        oPanel.rFColors := rAColors;
        oPanel.Parent := oForm;
        oPanel.Align := TAlignLayout.Client;
        oPanel.HitTest := False;

        oMakeText(oPanel, UPD_PAD, 16, UPD_W - 2 * UPD_PAD, 32, 16, True, rAColors.iAccent,
            UpperCase(sTr('update.title', 'Aggiornamento di HoloInput')));
        oForm.oFStatus := oMakeText(oPanel, UPD_PAD, UPD_TITLE_LINE_Y + 16, UPD_W - 2 * UPD_PAD, 22, 12,
            False,
            rAColors.iText, '');
        oForm.oFBar := THoloProgressBar.Create(oForm);
        oForm.oFBar.Parent := oPanel;
        oForm.oFBar.rFColors := rAColors;
        oForm.oFBar.SetBounds(UPD_PAD, UPD_TITLE_LINE_Y + 46, UPD_W - 2 * UPD_PAD, 20);
        oForm.oFDetail := oMakeText(oPanel, UPD_PAD, UPD_TITLE_LINE_Y + 72, UPD_W - 2 * UPD_PAD, 20, 11,
            False,
            iWithAlpha(rAColors.iText, $B0), '');

        oForm.oFCancelBtn := THoloButton.Create(oForm);
        oForm.oFCancelBtn.Parent := oPanel;
        oForm.oFCancelBtn.SetBounds(UPD_W - UPD_PAD - UPD_BTN_W, UPD_H - UPD_PAD - UPD_BTN_H,
            UPD_BTN_W, UPD_BTN_H);
        oForm.oFCancelBtn.sText := sTr('dialog.cancel', 'Annulla');
        oForm.oFCancelBtn.SetColors(rAColors);
        oForm.oFCancelBtn.OnClick := oForm.CancelClick;

        oForm.oFWorker := TUpdateWorker.Create(True);
        oForm.oFWorker.FreeOnTerminate := False;
        oForm.oFWorker.oFForm := oForm;
        oForm.oFWorker.rFInfo := rAInfo;
        oForm.oFWorker.OnTerminate := oForm.WorkerDone;

        Result := oForm.ShowModal = mrOk;
        if not Result and (oForm.oFWorker <> nil) then
        begin
            // finestra chiusa in altro modo (es. Alt+F4): si ferma il thread, a meno che
            // non stia gia' installando (in quel caso l'installazione si completa)
            oForm.oFWorker.bFCancel := True;
            if oForm.bFStarted and not oForm.oFWorker.Finished then
                oForm.oFWorker.WaitFor;
            Result := oForm.oFWorker.bFSuccess;
            if not Result then
                sAError := oForm.oFWorker.sFError;
        end;
    finally
        oForm.Free;
    end;
end;

//** riavvio ************************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: bRestartAfterUpdate
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Avviare il nuovo exe passando il pid di questo processo.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: il nuovo processo aspetta la chiusura di questo prima di
//** partire davvero (FinishPendingUpdate); il chiamante deve poi chiudere l'app.
//***********************************************************************************************************
//***********************************************************************************************************
function bRestartAfterUpdate: Boolean;
var
    sExe, sParams: string;
begin
    sExe := ParamStr(0);
    sParams := OPT_AFTER_UPDATE + ' ' + IntToStr(GetCurrentProcessId);
    Result := ShellExecute(0, 'open', PChar(sExe), PChar(sParams), PChar(ExtractFilePath(sExe)),
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
//** e la cartella temporanea, e segna l'aggiornamento (bJustUpdated). Senza il
//** parametro cancella comunque eventuali .old rimasti da un aggiornamento
//** precedente.
//***********************************************************************************************************
//***********************************************************************************************************
procedure FinishPendingUpdate;
var
    iParam, iPid, iTry_: Integer;
    hProcess: THandle;
    sExe, sOldFile: string;
    bLeft: Boolean;
begin
    iPid := 0;
    for iParam := 1 to ParamCount - 1 do
        if SameText(ParamStr(iParam), OPT_AFTER_UPDATE) then
            iPid := StrToIntDef(ParamStr(iParam + 1), 0);
    if iPid > 0 then
    begin
        bGJustUpdated := True;
        hProcess := OpenProcess(SYNCHRONIZE, False, DWORD(iPid));
        if hProcess <> 0 then
        try
            WaitForSingleObject(hProcess, 20000);
        finally
            CloseHandle(hProcess);
        end;
    end;
    sExe := ParamStr(0);
    try
        for iTry_ := 1 to 10 do
        begin
            bLeft := False;
            for sOldFile in TDirectory.GetFiles(ExtractFilePath(sExe), ExtractFileName(sExe) + '*.old') do
                if not System.SysUtils.DeleteFile(sOldFile) then
                    bLeft := True;
            if not bLeft or (iPid = 0) then
                Break;
            Sleep(200);
        end;
        if (iPid > 0) and TDirectory.Exists(sUpdateTempDir) then
            TDirectory.Delete(sUpdateTempDir, True);
    except
        // pulizia best effort: i file rimasti verranno cancellati al prossimo avvio
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: bJustUpdated
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: True se questo avvio segue un aggiornamento appena installato.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
function bJustUpdated: Boolean;
begin
    Result := bGJustUpdated;
end;

end.
