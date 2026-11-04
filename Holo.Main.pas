//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Main
//** Scopo: Form principale = overlay trasparente, senza bordi, sempre in primo piano.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: modalita':
//**   BLOCCATO  : la finestra e' "click-through" (WS_EX_TRANSPARENT) e copre
//**               solo l'area dei widget; i click passano al gioco. Solo la
//**               barra comandi resta cliccabile: quando il mouse ci passa
//**               sopra la finestra smette di essere trasparente ai click, cosi'
//**               "Sblocca layout", "Setup" ed "Esci" funzionano anche da bloccato.
//**   SBLOCCATO : la finestra copre l'intero desktop (le zone vuote restano
//**               trasparenti ai click); i widget si trascinano con il mouse e
//**               la barra comandi (Setup / Blocca layout / Esci) e' cliccabile.
//** Hotkey globali: Ctrl+Alt+F12 blocca/sblocca, Ctrl+Alt+F11 setup,
//**                 Ctrl+Alt+F10 mostra/nasconde, Ctrl+Alt+F9 modalita' streamer.
//**
//** Modalita' (pagina "Modalita'" del Setup):
//**   STREAMER : i pulsanti della barra spariscono, resta solo l'etichetta con
//**              il tasto rapido per farli ricomparire (Ctrl+Alt+F9).
//**   PRIVACY  : il widget della tastiera non viene mai mostrato, anche se e'
//**              attivo tra i dispositivi (per non mostrare password in diretta).
//**
//** Servizio OBS (pagina "OBS" del Setup):
//**   con "Avvia il servizio" (o all'avvio, se scelto nel Setup) parte un server HTTP/WebSocket locale
//**   (Holo.WebOverlay) e l'overlay viene occultato (finestra nascosta,
//**   spostata fuori dallo schermo o spostata su un altro monitor, a scelta).
//**   Al ritmo scelto (15/30/60 fps) i widget visibili vengono fotografati e
//**   composti nell'area che occupano, nella stessa posizione che hanno sullo
//**   schermo, riportata alla risoluzione del servizio (default: nativa del
//**   monitor); la compressione PNG e l'invio a OBS (WebSocket, pagina per il
//**   Browser Source) avvengono in altri thread. Ctrl+Alt+F11 riapre il Setup per fermare
//**   il servizio; finche' e' attivo le hotkey di blocco, visibilita' e
//**   modalita' streamer sono ignorate.
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.Main;

interface

uses
    Winapi.Windows,
    System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
    System.Diagnostics,
    FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Layouts, FMX.Dialogs,
    FMX.Platform.Win,
    Holo.Config, Holo.Skins, Holo.Input, Holo.Models, Holo.Widget, Holo.UI, Holo.WebOverlay;

type
    TfrmMain = class(TForm)
    private
        FConfig: TAppConfig;
        FInput: TInputManager;
        FColors: TSkinColors;
        FContainer: TLayout;
        FWidgets: array[TDeviceKind] of TDeviceWidget;
        FToolbar: TLayout;
        FBtnSetup, FBtnLock, FBtnExit, FStatus, FCredits: THoloButton;
        FTimer: TTimer;
        FClock: TStopwatch;
        FLastTime: Double;
        FLocked: Boolean;
        FDirty: Boolean;
        FSetupOpen: Boolean;
        FToolbarHot: Boolean;     // mouse sulla barra comandi (solo da bloccato)
        FFormOrigin: TPointF;
        FWeb: TWebOverlayServer;  // servizio Browser Source per OBS
        FObsActive: Boolean;      // servizio OBS avviato (overlay occultato)
        FObsFrames: Integer;      // fotogrammi preparati dall'avvio del servizio
        FObsMs: Int64;            // tempo di cattura e composizione dell'ultimo fotogramma (thread principale)
        FObsLastCapture: Double;  // istante dell'ultimo fotogramma (secondi di FClock)
        FObsFpsT0: Double;        // inizio della misura dei fotogrammi al secondo
        FObsFpsCount: Integer;    // fotogrammi preparati dall'inizio della misura
        FObsFpsValue: Integer;    // fotogrammi al secondo effettivi (ultima misura)
        FObsError: string;        // ultimo errore della preparazione dei fotogrammi
        procedure BuildUI;
        procedure ApplyConfig;
        procedure LayoutWidgets;
        procedure ApplyWindowStyles;
        procedure SetLocked(AValue: Boolean);
        procedure UpdateToolbar;
        function StreamerActive: Boolean;
        function BarHeight: Single;
        function IsShown(AKind: TDeviceKind): Boolean;
        procedure ToggleStreamer;
        procedure UpdateHotZone;
        procedure SaveConfig;
        procedure OpenSetup;
        procedure ShowDisclaimer;
        procedure AutoStartObs;
        procedure ToggleOverlay;
        function StartObs: Boolean;
        procedure StopObs;
        procedure ApplyObsHiding;
        procedure MoveToMonitor(const AMonitor: TMonitorDesc);
        procedure CaptureObsFrame;
        function ObsStatusText: string;
        procedure TimerTick(Sender: TObject);
        procedure HotkeyPressed(Sender: TObject; AHotkeyId: Integer);
        procedure WidgetMoved(Sender: TObject);
        procedure WidgetResized(Sender: TObject);
        procedure WidgetViewChanged(Sender: TObject);
        procedure BtnSetupClick(Sender: TObject);
        procedure BtnLockClick(Sender: TObject);
        procedure BtnExitClick(Sender: TObject);
    protected
        procedure DoShow; override;
    public
        constructor Create(AOwner: TComponent); override;
        destructor Destroy; override;
    end;

var
    frmMain: TfrmMain;

implementation

{$R *.fmx}

uses
    Holo.Setup, Holo.Lang, Holo.Disclaimer;

type
    /// Una fila (riga o colonna) di widget nei layout predefiniti.
    TKindLine = TArray<TDeviceKind>;

const
    TOOLBAR_H = 30;
    TOOLBAR_W = 620;
    CREDITS_GAP = 4;          // spazio tra i pulsanti e l'etichetta dei crediti
    CREDITS_H = TOOLBAR_H;    // stessa altezza dei pulsanti
    BAR_H = TOOLBAR_H + CREDITS_GAP + CREDITS_H;   // altezza totale della barra
    /// testi predefiniti (italiano) della barra: quelli mostrati passano da Tr (Holo.Lang)
    STREAMER_HINT = '   ' + #$00B7 + '   CTRL+ALT+F9 MOSTRA I COMANDI';
    CREDITS_TEXT = 'HOLOINPUT OVERLAY by CITIZEN GATTOMATTO';

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.Create
//** Parametri di ingresso: AOwner: TComponent
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Inizializzare l'applicazione.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: legge il .ini (se esiste), carica la lingua scelta, avvia
//** l'acquisizione input e le hotkey, costruisce l'interfaccia, applica la
//** configurazione e avvia il timer di rendering (~60 fps) e prepara il
//** servizio OBS (fermo); se l'avviso del
//** primo avvio non e' ancora stato accettato lo mette in coda
//** (ShowDisclaimer); se e' gia' accettato e nel Setup e' scelto "Avvia il
//** servizio all'avvio di HoloInput" mette in coda l'avvio del servizio OBS
//** (AutoStartObs). Al primo avvio (senza .ini) parte sbloccata per mostrare
//** subito i comandi.
//***********************************************************************************************************
//***********************************************************************************************************
constructor TfrmMain.Create(AOwner: TComponent);
var
    HasIni: Boolean;
begin
    inherited;
    FConfig := TAppConfig.Create;
    HasIni := FileExists(TAppConfig.DefaultFileName);
    if HasIni then
    try
        FConfig.LoadFromFile(TAppConfig.DefaultFileName);
    except
        FConfig.SetDefaults;
    end;

    FInput := TInputManager.Create;
    FInput.OnHotkey := HotkeyPressed;
    FInput.RegisterHotkeys;

    LoadLanguage(FConfig.Language);
    FLocked := HasIni and FConfig.StartLocked;
    BuildUI;
    ApplyConfig;

    FClock := TStopwatch.StartNew;
    FLastTime := 0;
    FTimer := TTimer.Create(Self);
    FTimer.Interval := 15;
    FTimer.OnTimer := TimerTick;
    FTimer.Enabled := True;

    // servizio Browser Source per OBS: fermo finche' non lo si avvia dal Setup
    FWeb := TWebOverlayServer.Create;

    // primo avvio: avviso legale (Holo.Disclaimer), finche' non viene accettato;
    // altrimenti, se richiesto, avvio automatico del servizio OBS
    if not FConfig.DisclaimerAccepted then
        TThread.ForceQueue(nil,
            procedure
            begin
                ShowDisclaimer;
            end)
    else if FConfig.ObsAutoStart then
        TThread.ForceQueue(nil,
            procedure
            begin
                AutoStartObs;
            end);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.Destroy
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Chiudere l'applicazione (ferma il servizio OBS) salvando le posizioni modificate a mano.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
destructor TfrmMain.Destroy;
begin
    if FTimer <> nil then
        FTimer.Enabled := False;
    FObsActive := False;
    FreeAndNil(FWeb);
    if FDirty then
        SaveConfig;
    FreeAndNil(FInput);
    inherited;
    FreeAndNil(FConfig);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.BuildUI
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Creare contenitore, widget (uno per tipologia) e barra comandi.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: i widget vengono creati tutti ma il modello 3D viene
//** costruito solo per quelli visibili (in ApplyConfig).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.BuildUI;
var
    K: TDeviceKind;
    X: Single;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: MakeButton
    //** Parametri di ingresso: AText: string; AWidth: Single; AClick: TNotifyEvent
    //** Parametri di uscita: Result: THoloButton
    //** Scopo: Creare un pulsante della barra comandi con testo, larghezza e gestore del click,
    //**        accodandolo ai precedenti.
    //** Data Ultima Modifica: 29/09/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function MakeButton(const AText: string; AWidth: Single; AClick: TNotifyEvent): THoloButton;
    begin
        Result := THoloButton.Create(Self);
        Result.Parent := FToolbar;
        Result.Text := AText;
        Result.SetBounds(X, 0, AWidth, TOOLBAR_H);
        Result.OnClick := AClick;
        X := X + AWidth + 6;
    end;

begin
    FContainer := TLayout.Create(Self);
    FContainer.Parent := Self;
    FContainer.Align := TAlignLayout.Client;
    FContainer.HitTest := False;

    for K := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        FWidgets[K] := TDeviceWidget.CreateWidget(Self, K);
        FWidgets[K].Parent := FContainer;
        FWidgets[K].Visible := False;
        FWidgets[K].OnMoved := WidgetMoved;
        FWidgets[K].OnResized := WidgetResized;
        FWidgets[K].OnViewChanged := WidgetViewChanged;
    end;

    FToolbar := TLayout.Create(Self);
    FToolbar.Parent := FContainer;
    FToolbar.HitTest := False;
    FToolbar.Width := TOOLBAR_W;
    FToolbar.Height := BAR_H;

    X := 0;
    // i testi dei pulsanti vengono scritti (nella lingua corrente) da UpdateToolbar
    FBtnSetup := MakeButton('', 90, BtnSetupClick);
    FBtnLock := MakeButton('', 160, BtnLockClick);
    FBtnExit := MakeButton('', 80, BtnExitClick);
    FStatus := MakeButton('', TOOLBAR_W - X, nil);
    FStatus.Passive := True;
    FStatus.FontSize := 10;

    // etichetta dei crediti sotto i pulsanti, larga quanto tutta la barra
    FCredits := THoloButton.Create(Self);
    FCredits.Parent := FToolbar;
    FCredits.SetBounds(0, TOOLBAR_H + CREDITS_GAP, TOOLBAR_W, CREDITS_H);
    FCredits.Passive := True;
    FCredits.KeepCase := True;
    FCredits.FontSize := 11;
    FCredits.Text := Tr('main.credits', CREDITS_TEXT);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.ApplyConfig
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Applicare la configurazione corrente a tutta l'interfaccia.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: risolve la skin, aggiorna stile finestra e gestore degli input,
//** configura i widget visibili (stile pannello / solo dispositivo, effetti
//** di base, creando/aggiornando i modelli 3D), registra
//** i dispositivi da leggere, ricalcola la disposizione e gli stili Win32.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.ApplyConfig;
var
    K: TDeviceKind;
    SkinCls: TSkinClass;
    W: TDeviceWidget;
begin
    SkinCls := FindSkin(FConfig.SkinId);
    if SkinCls <> nil then
        FColors := SkinCls.Colors
    else
        FColors := DefaultSkinColors;

    if FConfig.StayOnTop then
    begin
        if FormStyle <> TFormStyle.StayOnTop then
            FormStyle := TFormStyle.StayOnTop;
    end
    else if FormStyle <> TFormStyle.Normal then
        FormStyle := TFormStyle.Normal;

    FInput.MouseRange := FConfig.MouseRange;
    FInput.ClearUsage;
    for K := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        W := FWidgets[K];
        W.Visible := IsShown(K);
        if W.Visible then
        begin
            W.SetStyle(FConfig.WidgetStyle = wsDeviceOnly, FConfig.BaseEffects);
            W.Configure(FConfig.Widgets[K], FColors, FConfig.ShowLegends);
            W.BindDevices(FInput);
        end;
        W.EditMode := not FLocked;
    end;

    FBtnSetup.SetColors(FColors);
    FBtnLock.SetColors(FColors);
    FBtnExit.SetColors(FColors);
    FStatus.SetColors(FColors);
    FCredits.SetColors(FColors);
    FContainer.Opacity := FConfig.Opacity;

    LayoutWidgets;
    UpdateToolbar;
    ApplyWindowStyles;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.LayoutWidgets
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Calcolare posizione e dimensioni di widget, barra e finestra.
//** Data Ultima Modifica: 29/09/2026
//***********************************************************************************************************
//** Funzionamento:
//**  1. layout predefiniti (area di lavoro del monitor principale, senza la
//**     barra di Windows):
//**       Orizzontale (Basso/Alto): i widget in fila, allineati al bordo
//**         inferiore/superiore e centrati in orizzontale; se non stanno in una
//**         riga si va a capo (righe successive verso il centro dello schermo);
//**         in Basso le righe si appoggiano sopra la barra comandi;
//**       Verticale (Destra/Sinistra): i widget in colonna, allineati al bordo
//**         destro/sinistro e centrati in verticale; se non stanno in una
//**         colonna se ne crea un'altra verso il centro;
//**       se un widget finirebbe sopra la barra comandi, il gruppo sale;
//**     le posizioni calcolate vengono memorizzate in X/Y (il setup le mostra
//**     e diventano il punto di partenza del layout Personalizzato);
//**  2. Personalizzato: ogni widget usa le sue X/Y;
//**  la barra comandi (pulsanti + etichetta) e' SEMPRE in basso al centro del
//**  monitor principale, a distanza Margine dal bordo, qualunque sia il layout;
//**  3. bloccato: la finestra copre solo l'unione dei rettangoli;
//**     sbloccato: la finestra copre tutto il desktop virtuale;
//**  4. i controlli vengono posizionati relativamente all'origine della finestra.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.LayoutWidgets;
var
    K: TDeviceKind;
    Rects: array[TDeviceKind] of TRectF;
    Vis: TKindLine;
    Lines: TArray<TKindLine>;
    WA, U, TB, F: TRectF;
    M, G, X, Y, LineL, LineT, LTop, LLeft, BlockH, TBx, BH: Single;
    I: Integer;
    First, Horiz: Boolean;
    C: TWidgetConfig;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: Along
    //** Parametri di ingresso: AKind: TDeviceKind; AHoriz: Boolean
    //** Parametri di uscita: Result: Single
    //** Scopo: Dimensione di un widget lungo la direzione della fila (larghezza in orizzontale,
    //**        altezza in verticale).
    //** Data Ultima Modifica: 21/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function Along(AKind: TDeviceKind; AHoriz: Boolean): Single;
    begin
        if AHoriz then
            Result := FConfig.Widgets[AKind].W
        else
            Result := FConfig.Widgets[AKind].H;
    end;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: Across
    //** Parametri di ingresso: AKind: TDeviceKind; AHoriz: Boolean
    //** Parametri di uscita: Result: Single
    //** Scopo: Dimensione di un widget nella direzione trasversale alla fila (altezza in
    //**        orizzontale, larghezza in verticale).
    //** Data Ultima Modifica: 21/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function Across(AKind: TDeviceKind; AHoriz: Boolean): Single;
    begin
        Result := Along(AKind, not AHoriz);
    end;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: LineLen
    //** Parametri di ingresso: ALine: TKindLine; AHoriz: Boolean
    //** Parametri di uscita: Result: Single
    //** Scopo: Lunghezza di una fila di widget, spazi tra i widget compresi.
    //** Data Ultima Modifica: 21/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function LineLen(const ALine: TKindLine; AHoriz: Boolean): Single;
    var
        J: Integer;
    begin
        Result := 0;
        for J := 0 to High(ALine) do
        begin
            if J > 0 then
                Result := Result + G;
            Result := Result + Along(ALine[J], AHoriz);
        end;
    end;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: LineThick
    //** Parametri di ingresso: ALine: TKindLine; AHoriz: Boolean
    //** Parametri di uscita: Result: Single
    //** Scopo: Spessore di una fila di widget, cioe' la dimensione trasversale del widget piu'
    //**        grande.
    //** Data Ultima Modifica: 21/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function LineThick(const ALine: TKindLine; AHoriz: Boolean): Single;
    var
        J: Integer;
    begin
        Result := 0;
        for J := 0 to High(ALine) do
            Result := Max(Result, Across(ALine[J], AHoriz));
    end;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: SplitLines
    //** Parametri di ingresso: AHoriz: Boolean; ALimit: Single
    //** Parametri di uscita: Result: TArray<TKindLine>
    //** Scopo: Divide i widget visibili in file che non superano ALimit.
    //** Data Ultima Modifica: 21/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function SplitLines(AHoriz: Boolean; ALimit: Single): TArray<TKindLine>;
    var
        Acc: TArray<TKindLine>;
        Line: TKindLine;
        Len, Sz: Single;
        J: Integer;

        //***********************************************************************************************************
        //***********************************************************************************************************
        //** Autore: Citizen GattoMatto
        //** Nome procedura: Flush
        //** Parametri di ingresso: nessuno
        //** Parametri di uscita: nessuno
        //** Scopo: Chiudere la fila corrente aggiungendola all'elenco delle file (se non vuota).
        //** Data Ultima Modifica: 21/10/2026
        //***********************************************************************************************************
        //***********************************************************************************************************
        procedure Flush;
        begin
            if Length(Line) = 0 then
                Exit;
            SetLength(Acc, Length(Acc) + 1);
            Acc[High(Acc)] := Line;
            Line := nil;
            Len := 0;
        end;

    begin
        Acc := nil;
        Line := nil;
        Len := 0;
        for J := 0 to High(Vis) do
        begin
            Sz := Along(Vis[J], AHoriz);
            if (Length(Line) > 0) and (Len + G + Sz > ALimit) then
                Flush;
            if Length(Line) > 0 then
                Len := Len + G;
            Len := Len + Sz;
            SetLength(Line, Length(Line) + 1);
            Line[High(Line)] := Vis[J];
        end;
        Flush;
        Result := Acc;
    end;

begin
    WA := RectF(Screen.WorkAreaLeft, Screen.WorkAreaTop,
        Screen.WorkAreaLeft + Screen.WorkAreaWidth, Screen.WorkAreaTop + Screen.WorkAreaHeight);
    M := FConfig.Margin;
    BH := BarHeight;
    G := FConfig.Spacing;

    Vis := nil;
    for K := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        Rects[K] := RectF(0, 0, 0, 0);
        if IsShown(K) then
        begin
            SetLength(Vis, Length(Vis) + 1);
            Vis[High(Vis)] := K;
        end;
    end;

    // barra comandi: SEMPRE in basso al centro del monitor, qualunque sia il layout
    TBx := WA.Left + (WA.Width - TOOLBAR_W) / 2;
    TB := RectF(TBx, WA.Bottom - M - BH, TBx + TOOLBAR_W, WA.Bottom - M);

    case FConfig.Layout of
        lmBottom, lmTop:
            begin
                Horiz := True;
                Lines := SplitLines(Horiz, WA.Width - 2 * M);
                if FConfig.Layout = lmBottom then
                    Y := TB.Top - G          // la fila in basso si appoggia sopra la barra
                else
                    Y := WA.Top + M;
                for I := 0 to High(Lines) do
                begin
                    LineL := LineLen(Lines[I], Horiz);
                    LineT := LineThick(Lines[I], Horiz);
                    X := WA.Left + (WA.Width - LineL) / 2;
                    if FConfig.Layout = lmBottom then
                        LTop := Y - LineT
                    else
                        LTop := Y;
                    for K in Lines[I] do
                    begin
                        C := FConfig.Widgets[K];
                        if FConfig.Layout = lmBottom then
                            Rects[K] := RectF(X, LTop + LineT - C.H, X + C.W, LTop + LineT)
                        else
                            Rects[K] := RectF(X, LTop, X + C.W, LTop + C.H);
                        X := X + C.W + G;
                    end;
                    if FConfig.Layout = lmBottom then
                        Y := LTop - G
                    else
                        Y := LTop + LineT + G;
                end;
            end;

        lmRight, lmLeft:
            begin
                Horiz := False;
                Lines := SplitLines(Horiz, WA.Height - 2 * M);
                BlockH := 0;
                for I := 0 to High(Lines) do
                    BlockH := Max(BlockH, LineLen(Lines[I], Horiz));
                LTop := Max(WA.Top + M, WA.Top + (WA.Height - BlockH) / 2);
                if FConfig.Layout = lmRight then
                    X := WA.Right - M
                else
                    X := WA.Left + M;
                for I := 0 to High(Lines) do
                begin
                    LineL := LineLen(Lines[I], Horiz);
                    LineT := LineThick(Lines[I], Horiz);
                    if FConfig.Layout = lmRight then
                        LLeft := X - LineT
                    else
                        LLeft := X;
                    Y := LTop + (BlockH - LineL) / 2;
                    for K in Lines[I] do
                    begin
                        C := FConfig.Widgets[K];
                        if FConfig.Layout = lmRight then
                            Rects[K] := RectF(LLeft + LineT - C.W, Y, LLeft + LineT, Y + C.H)
                        else
                            Rects[K] := RectF(LLeft, Y, LLeft + C.W, Y + C.H);
                        Y := Y + C.H + G;
                    end;
                    if FConfig.Layout = lmRight then
                        X := LLeft - G
                    else
                        X := LLeft + LineT + G;
                end;
            end;

    else  // lmCustom
        for K in Vis do
        begin
            C := FConfig.Widgets[K];
            Rects[K] := RectF(C.X, C.Y, C.X + C.W, C.Y + C.H);
        end;
    end;

    // layout predefiniti: se qualche widget finirebbe sopra la barra comandi,
    // tutto il gruppo sale quanto basta (senza superare il bordo superiore)
    if FConfig.Layout in [lmTop, lmRight, lmLeft] then
    begin
        Y := 0;
        for K in Vis do
            if (Rects[K].Right > TB.Left - G) and (Rects[K].Left < TB.Right + G) then
                Y := Max(Y, Rects[K].Bottom - (TB.Top - G));
        if Y > 0 then
        begin
            LTop := WA.Bottom;
            for K in Vis do
                LTop := Min(LTop, Rects[K].Top);
            Y := Min(Y, Max(0, LTop - (WA.Top + M)));
            for K in Vis do
                Rects[K].Offset(0, -Y);
        end;
    end;

    // posizioni calcolate -> X/Y (mostrate nel setup)
    if FConfig.Layout <> lmCustom then
        for K in Vis do
        begin
            FConfig.Widgets[K].X := Round(Rects[K].Left);
            FConfig.Widgets[K].Y := Round(Rects[K].Top);
        end;

    First := True;
    U := RectF(0, 0, 0, 0);
    for K in Vis do
    begin
        if First then
            U := Rects[K]
        else
            U := TRectF.Union(U, Rects[K]);
        First := False;
    end;

    if First then
        U := TB
    else
        U := TRectF.Union(U, TB);

    if FLocked then
    begin
        F := U;
        F.Inflate(2, 2);
    end
    else
        F := RectF(Screen.DesktopLeft, Screen.DesktopTop,
            Screen.DesktopLeft + Screen.DesktopWidth, Screen.DesktopTop + Screen.DesktopHeight);

    FFormOrigin := F.TopLeft;
    SetBounds(Round(F.Left), Round(F.Top), Round(F.Width), Round(F.Height));

    for K in Vis do
        FWidgets[K].SetBounds(Rects[K].Left - FFormOrigin.X, Rects[K].Top - FFormOrigin.Y,
            Rects[K].Width, Rects[K].Height);
    FToolbar.Position.Point := PointF(TB.Left - FFormOrigin.X, TB.Top - FFormOrigin.Y);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.ApplyWindowStyles
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Applicare gli stili Win32 dell'overlay.
//** Data Ultima Modifica: 29/09/2026
//***********************************************************************************************************
//** Funzionamento: in modalita' bloccata aggiunge WS_EX_NOACTIVATE (il gioco
//** non perde il fuoco) e WS_EX_TRANSPARENT (i click attraversano la
//** finestra), tranne quando il mouse e' sulla barra comandi (FToolbarHot):
//** in quel caso la finestra riceve i click e i pulsanti funzionano.
//** In modalita' sbloccata li rimuove entrambi. La trasparenza per-pixel e'
//** gestita da FMX (Transparency = True nel .fmx).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.ApplyWindowStyles;
var
    H: HWND;
    Ex, NewEx: NativeInt;
begin
    if Handle = nil then
        Exit;
    H := FmxHandleToHWND(Handle);
    if H = 0 then
        Exit;
    Ex := GetWindowLongPtr(H, GWL_EXSTYLE);
    NewEx := Ex and not NativeInt(WS_EX_TRANSPARENT or WS_EX_NOACTIVATE);
    if FLocked then
    begin
        NewEx := NewEx or WS_EX_NOACTIVATE;
        if not FToolbarHot then
            NewEx := NewEx or WS_EX_TRANSPARENT;
    end;
    if NewEx <> Ex then
        SetWindowLongPtr(H, GWL_EXSTYLE, NewEx);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.UpdateHotZone
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Rendere cliccabile la barra comandi anche da bloccato.
//** Data Ultima Modifica: 21/10/2026
//***********************************************************************************************************
//** Funzionamento: ad ogni tick controlla se il mouse e' sopra la barra
//** (coordinate FMX, quindi corrette anche con lo zoom di Windows); quando
//** entra o esce cambia lo stile della finestra e l'evidenziazione della barra.
//** Se si e' gia' sulla barra, il click raggiunge il pulsante al primo colpo
//** perche' lo stile cambia appena il mouse arriva sopra.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.UpdateHotZone;
var
    P: TPointF;
    R: TRectF;
    Over: Boolean;
begin
    Over := False;
    if FLocked and Visible and not FSetupOpen then
    begin
        P := ScreenToClient(Screen.MousePos);
        R := FToolbar.AbsoluteRect;
        R.Inflate(4, 4);
        Over := R.Contains(P);
    end;
    if Over = FToolbarHot then
        Exit;
    FToolbarHot := Over;
    ApplyWindowStyles;
    UpdateToolbar;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.DoShow
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Riapplicare gli stili Win32 dopo che la finestra e' stata mostrata (FMX puo' ricreare
//**        l'handle quando cambiano alcune proprieta').
//** Data Ultima Modifica: 29/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.DoShow;
begin
    inherited;
    TThread.ForceQueue(nil,
        procedure
        begin
            ApplyWindowStyles;
        end);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.SetLocked
//** Parametri di ingresso: AValue: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Passare tra modalita' bloccata e sbloccata.
//** Data Ultima Modifica: 29/09/2026
//***********************************************************************************************************
//** Funzionamento: aggiorna i widget (trascinabili o no), la barra, la
//** geometria della finestra e gli stili; quando si blocca salva su .ini le
//** posizioni eventualmente modificate a mano.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.SetLocked(AValue: Boolean);
var
    K: TDeviceKind;
begin
    FLocked := AValue;
    FToolbarHot := False;
    for K := Low(TDeviceKind) to High(TDeviceKind) do
        FWidgets[K].EditMode := not FLocked;
    if FLocked and FDirty then
        SaveConfig;
    LayoutWidgets;
    UpdateToolbar;
    ApplyWindowStyles;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmMain.StreamerActive
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: True se la modalita' streamer e' attiva E il suo tasto rapido funziona (altrimenti non
//**        ci sarebbe modo di far ricomparire i pulsanti).
//** Data Ultima Modifica: 24/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmMain.StreamerActive: Boolean;
begin
    Result := FConfig.StreamerMode and FInput.StreamerHotkeyOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmMain.BarHeight
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Single
//** Scopo: Altezza della barra comandi (solo etichetta in modalita' streamer).
//** Data Ultima Modifica: 24/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmMain.BarHeight: Single;
begin
    if StreamerActive then
        Result := CREDITS_H
    else
        Result := BAR_H;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmMain.IsShown
//** Parametri di ingresso: AKind: TDeviceKind
//** Parametri di uscita: Result: Boolean
//** Scopo: True se il widget va mostrato: deve essere attivo nel setup e, per la tastiera, la
//**        modalita' privacy deve essere spenta.
//** Data Ultima Modifica: 24/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmMain.IsShown(AKind: TDeviceKind): Boolean;
begin
    Result := FConfig.Widgets[AKind].Visible and
        not ((AKind = dkKeyboard) and FConfig.PrivacyMode);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.ToggleStreamer
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Attivare/disattivare la modalita' streamer con Ctrl+Alt+F9.
//** Data Ultima Modifica: 24/10/2026
//***********************************************************************************************************
//** Funzionamento: cambia l'impostazione, la salva nel .ini (resta valida al
//** riavvio) e ridisegna barra e disposizione.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.ToggleStreamer;
begin
    FConfig.StreamerMode := not FConfig.StreamerMode;
    SaveConfig;
    UpdateToolbar;
    LayoutWidgets;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.UpdateToolbar
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Aggiornare testo ed evidenziazione della barra comandi.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: in modalita' streamer nasconde i pulsanti e lo stato,
//** porta l'etichetta in cima alla barra e le aggiunge il tasto rapido per
//** uscire dalla modalita'.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.UpdateToolbar;
var
    Streamer: Boolean;
begin
    Streamer := StreamerActive;
    FBtnSetup.Visible := not Streamer;
    FBtnLock.Visible := not Streamer;
    FBtnExit.Visible := not Streamer;
    FStatus.Visible := not Streamer;
    if Streamer then
    begin
        FCredits.Position.Y := 0;
        FCredits.Text := Tr('main.credits', CREDITS_TEXT) + Tr('main.streamerhint', STREAMER_HINT);
    end
    else
    begin
        FCredits.Position.Y := TOOLBAR_H + CREDITS_GAP;
        FCredits.Text := Tr('main.credits', CREDITS_TEXT);
    end;
    FToolbar.Height := BarHeight;

    FBtnSetup.Text := Tr('main.btn.setup', 'Setup');
    FBtnExit.Text := Tr('main.btn.exit', 'Esci');
    if FLocked then
    begin
        FBtnLock.Text := Tr('main.btn.unlock', 'Sblocca layout');
        FBtnLock.Highlight := True;
        FStatus.Text := Tr('main.status.locked', 'BLOCCATO  ' + #$00B7 + '  CTRL+ALT+F12 PER SBLOCCARE');
        if FToolbarHot then
            FToolbar.Opacity := 1
        else
            FToolbar.Opacity := 0.55;
    end
    else
    begin
        FBtnLock.Text := Tr('main.btn.lock', 'Blocca layout');
        FBtnLock.Highlight := False;
        FStatus.Text := Tr('main.status.edit', 'MODIFICA  ' + #$00B7 + '  TRASCINA I WIDGET');
        FToolbar.Opacity := 1;
    end;
    if not FInput.HotkeysOk then
        FStatus.Text := FStatus.Text + Tr('main.status.nohotkeys', '  (HOTKEY NON DISPONIBILI)');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.SaveConfig
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Salvare la configurazione nel .ini segnalando eventuali errori.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.SaveConfig;
begin
    try
        FConfig.SaveToFile(TAppConfig.DefaultFileName);
        FDirty := False;
    except
        on E: Exception do
            ShowMessage(Tr('main.err.save', 'Impossibile salvare la configurazione:') + sLineBreak +
                E.Message);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.TimerTick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Ciclo principale (~60 fps).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: misura il tempo trascorso, aggiorna lo snapshot degli input
//** e lo passa a tutti i widget visibili; con il servizio OBS attivo prepara
//** un fotogramma per OBS al ritmo scelto (ObsFps) e misura i fotogrammi al
//** secondo effettivi.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.TimerTick(Sender: TObject);
var
    T, DT: Double;
    K: TDeviceKind;
    S: PInputSnapshot;
begin
    T := FClock.Elapsed.TotalSeconds;
    DT := EnsureRange(T - FLastTime, 0, 0.1);
    FLastTime := T;
    UpdateHotZone;
    FInput.Poll(DT);
    S := FInput.StatePtr;
    for K := Low(TDeviceKind) to High(TDeviceKind) do
        if FWidgets[K].Visible then
            FWidgets[K].Tick(S^, DT, FConfig.Animations);

    // servizio OBS: un fotogramma ogni 1/fps secondi (il timer gira a ~64 Hz,
    // la tolleranza del 10% evita di saltare un tick per pochi decimi di ms)
    if FObsActive then
    begin
        if T - FObsLastCapture >= 0.9 / Max(1, FConfig.ObsFps) then
        begin
            FObsLastCapture := T;
            CaptureObsFrame;
        end;
        if T - FObsFpsT0 >= 1 then
        begin
            FObsFpsValue := Round(FObsFpsCount / (T - FObsFpsT0));
            FObsFpsCount := 0;
            FObsFpsT0 := T;
        end;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.HotkeyPressed
//** Parametri di ingresso: Sender: TObject; AHotkeyId: Integer
//** Parametri di uscita: nessuno
//** Scopo: Gestire le hotkey globali.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: l'azione viene accodata (ForceQueue) per eseguirla fuori
//** dalla procedura di finestra, cosi' si possono aprire finestre modali.
//** Con il servizio OBS attivo funziona solo Ctrl+Alt+F11 (Setup): le altre
//** cambierebbero posizione o visibilita' della finestra occultata.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.HotkeyPressed(Sender: TObject; AHotkeyId: Integer);
begin
    TThread.ForceQueue(nil,
        procedure
        begin
            case AHotkeyId of
                HK_LOCK:    if not FSetupOpen and not FObsActive then SetLocked(not FLocked);
                HK_SETUP:   OpenSetup;
                HK_VISIBLE: ToggleOverlay;
                HK_STREAMER: if not FSetupOpen and not FObsActive then ToggleStreamer;
            end;
        end);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.ToggleOverlay
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Mostrare/nascondere l'overlay (non con il servizio OBS attivo).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.ToggleOverlay;
begin
    if FSetupOpen or FObsActive then
        Exit;
    if Visible then
        Hide
    else
    begin
        Show;
        ApplyWindowStyles;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.WidgetMoved
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Memorizzare la nuova posizione di un widget trascinato.
//** Data Ultima Modifica: 30/09/2026
//***********************************************************************************************************
//** Funzionamento: spostare anche un solo widget porta il layout a
//** "Personalizzato": tutti i widget restano dove sono (le loro X/Y sono gia'
//** quelle calcolate dal layout precedente) e da quel momento usano le
//** proprie coordinate; poi converte la posizione nella finestra in
//** coordinate desktop e ricalcola la barra comandi.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.WidgetMoved(Sender: TObject);
var
    W: TDeviceWidget;
begin
    W := Sender as TDeviceWidget;
    if FConfig.Layout <> lmCustom then
        FConfig.SetLayout(lmCustom);
    FConfig.Widgets[W.Kind].X := Round(FFormOrigin.X + W.Position.X);
    FConfig.Widgets[W.Kind].Y := Round(FFormOrigin.Y + W.Position.Y);
    FDirty := True;
    LayoutWidgets;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.WidgetResized
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Memorizzare le nuove dimensioni di un widget ridimensionato col mouse.
//** Data Ultima Modifica: 23/10/2026
//***********************************************************************************************************
//** Funzionamento: salva larghezza e altezza nella configurazione (cosi' il
//** Setup mostra i nuovi valori). Con un layout predefinito il layout resta
//** quello scelto e la disposizione viene ricalcolata con le nuove misure;
//** con Personalizzato si salva anche la posizione (cambia se si allarga
//** dal lato sinistro o da quello superiore).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.WidgetResized(Sender: TObject);
var
    W: TDeviceWidget;
begin
    W := Sender as TDeviceWidget;
    FConfig.Widgets[W.Kind].W := Round(W.Width);
    FConfig.Widgets[W.Kind].H := Round(W.Height);
    if FConfig.Layout = lmCustom then
    begin
        FConfig.Widgets[W.Kind].X := Round(FFormOrigin.X + W.Position.X);
        FConfig.Widgets[W.Kind].Y := Round(FFormOrigin.Y + W.Position.Y);
    end;
    FDirty := True;
    LayoutWidgets;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.WidgetViewChanged
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Memorizzare la vista di un widget ruotata con il tasto destro o zoomata con la rotella
//**        del mouse.
//** Data Ultima Modifica: 26/10/2026
//***********************************************************************************************************
//** Funzionamento: copia inclinazione, rotazione e zoom del widget nella
//** configurazione (VistaInclinazione / VistaRotazione / VistaZoom nel .ini);
//** il file viene salvato con le altre modifiche quando si blocca il layout.
//** Il pulsante Default del Setup riporta la vista a quella predefinita.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.WidgetViewChanged(Sender: TObject);
var
    W: TDeviceWidget;
begin
    W := Sender as TDeviceWidget;
    FConfig.Widgets[W.Kind].Tilt := W.ViewTilt;
    FConfig.Widgets[W.Kind].Yaw := W.ViewYaw;
    FConfig.Widgets[W.Kind].Zoom := W.ViewZoom;
    FDirty := True;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.OpenSetup
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Aprire la schermata di setup.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: nasconde l'overlay ("pulisce la vista"), lavora su una
//** copia della configurazione; con Salva la copia diventa la configurazione
//** attiva, viene scritta nel .ini e applicata; con Chiudi non cambia nulla.
//** Il Setup riceve lo stato del servizio OBS e restituisce l'azione chiesta
//** (avvia/ferma); con il servizio attivo l'overlay resta occultato.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.OpenSetup;
var
    Tmp: TAppConfig;
    Dlg: TfrmSetup;
    Res: TModalResult;
    Act: TObsAction;
begin
    if FSetupOpen then
        Exit;
    FSetupOpen := True;
    FToolbarHot := False;
    FTimer.Enabled := False;
    Hide;
    Act := oaNone;
    Tmp := TAppConfig.Create;
    try
        Tmp.Assign(FConfig);
        // cambiando lingua il setup si chiude con mrRetry e si riapre nella nuova
        // lingua, mantenendo le modifiche non ancora salvate (sono in Tmp)
        repeat
            Dlg := TfrmSetup.CreateSetup(nil, Tmp, FInput);
            try
                Dlg.SetObsState(FObsActive, ObsStatusText);
                Res := Dlg.ShowModal;
                Act := Dlg.ObsAction;
            finally
                Dlg.Free;
            end;
            if Res = mrRetry then
                LoadLanguage(Tmp.Language);
        until Res <> mrRetry;
        if Res = mrOk then
        begin
            FConfig.Assign(Tmp);
            SaveConfig;
        end;
        // lingua definitiva: quella salvata (chiudendo senza salvare torna la precedente)
        if not SameText(CurrentLanguage, FConfig.Language) then
            LoadLanguage(FConfig.Language);
    finally
        Tmp.Free;
        FSetupOpen := False;
    end;
    ApplyConfig;
    // servizio OBS: avvio/arresto chiesto dalla pagina OBS; con Salva e il servizio
    // gia' attivo lo si riavvia, cosi' valgono subito porta e risoluzione nuove
    if Res = mrOk then
        case Act of
            oaStart: StartObs;
            oaStop:  StopObs;
        else
            if FObsActive then
                StartObs;
        end;
    if FObsActive then
        ApplyObsHiding
    else
    begin
        Show;
        ApplyWindowStyles;
    end;
    FTimer.Enabled := True;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.ShowDisclaimer
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Mostrare l'avviso legale del primo avvio e ricordarne l'accettazione.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: nasconde l'overlay e ferma il rendering mentre l'avviso e'
//** aperto (FSetupOpen blocca anche setup e blocco del layout dalle hotkey).
//** Con "Accetto" salva nel .ini l'accettazione e la lingua e la skin scelte
//** nell'avviso, applica la configurazione e rimostra l'overlay; con
//** "Rifiuto" chiude l'applicazione senza salvare (l'avviso ricomparira' al
//** prossimo avvio). Dopo l'accettazione puo' partire il servizio OBS
//** (AutoStartObs).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.ShowDisclaimer;
var
    Accepted: Boolean;
begin
    FSetupOpen := True;
    FTimer.Enabled := False;
    Hide;
    try
        Accepted := RunDisclaimer(FConfig);
    finally
        FSetupOpen := False;
    end;
    if not Accepted then
    begin
        Application.Terminate;
        Close;
        Exit;
    end;
    FConfig.DisclaimerAccepted := True;
    SaveConfig;
    ApplyConfig;
    Show;
    ApplyWindowStyles;
    FTimer.Enabled := True;
    AutoStartObs;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.AutoStartObs
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Avviare il servizio OBS al lancio di HoloInput, se richiesto nel Setup.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: solo con l'opzione "Avvia il servizio all'avvio di
//** HoloInput" attiva e se il servizio non e' gia' attivo; avviato il server
//** occulta l'overlay come scelto nel Setup. Se la porta e' occupata StartObs
//** mostra l'errore e l'overlay resta visibile.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.AutoStartObs;
begin
    if FObsActive or FSetupOpen or not FConfig.ObsAutoStart then
        Exit;
    if StartObs then
        ApplyObsHiding;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmMain.StartObs
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Avviare (o riavviare con i nuovi parametri) il servizio Browser Source per OBS.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: blocca il layout (in OBS non devono comparire le cornici
//** di modifica dei widget), avvia il server sulla porta configurata e
//** azzera i contatori della verifica. Se la porta e' occupata mostra
//** l'errore e lascia il servizio fermo (Result = False). L'occultamento
//** della finestra e' gestito da OpenSetup; i fotogrammi li prepara TimerTick.
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmMain.StartObs: Boolean;
begin
    Result := False;
    if not FLocked then
        SetLocked(True);
    try
        FWeb.Start(FConfig.ObsPort, FConfig.ObsWidth, FConfig.ObsHeight);
    except
        on E: Exception do
        begin
            FObsActive := False;
            ShowMessage(Format(Tr('obs.err.start', 'Impossibile avviare il servizio OBS sulla porta %d:'),
                [FConfig.ObsPort]) + sLineBreak + E.Message);
            Exit;
        end;
    end;
    FObsActive := True;
    FObsFrames := 0;
    FObsMs := 0;
    FObsError := '';
    FObsLastCapture := 0;
    FObsFpsT0 := FClock.Elapsed.TotalSeconds;
    FObsFpsCount := 0;
    FObsFpsValue := 0;
    Result := True;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.StopObs
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Fermare il servizio Browser Source per OBS.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: smette di preparare fotogrammi e ferma il server (che
//** chiude le connessioni di OBS e scarta l'ultimo fotogramma); la finestra
//** torna visibile in OpenSetup (ApplyConfig
//** ha gia' rimesso la finestra al suo posto).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.StopObs;
begin
    FObsActive := False;
    FWeb.Stop;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.ApplyObsHiding
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Occultare l'overlay mentre il servizio OBS e' attivo, nel modo scelto nel Setup.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: OBS_HIDE_WINDOW nasconde la finestra; OBS_HIDE_OFFSCREEN
//** la lascia "visibile" per Windows ma la sposta a sinistra di tutti i
//** monitor (stesse dimensioni); OBS_HIDE_MONITOR la sposta sul monitor
//** scelto (MoveToMonitor, prima di mostrarla per non farla comparire sul
//** principale e di nuovo dopo, nel caso Show ne ripristini la posizione).
//** Se il monitor scelto non e' piu' collegato la finestra va fuori dallo
//** schermo. FFormOrigin non cambia, quindi i fotogrammi usano sempre le
//** posizioni dei widget sullo schermo principale. I diversi modi servono a
//** verificare quale continua a disegnare i widget (vedi CaptureObsFrame).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.ApplyObsHiding;
var
    Mon: TMonitorDesc;
begin
    if (FConfig.ObsHideMode = OBS_HIDE_MONITOR) and FindMonitor(FConfig.ObsMonitor, Mon) and
        not Mon.Primary then
    begin
        MoveToMonitor(Mon);
        Show;
        MoveToMonitor(Mon);
        ApplyWindowStyles;
    end
    else if FConfig.ObsHideMode <> OBS_HIDE_WINDOW then
    begin
        SetBounds(Round(Screen.DesktopLeft) - Width - 200, Round(Screen.DesktopTop), Width, Height);
        Show;
        ApplyWindowStyles;
    end
    else
        Hide;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.MoveToMonitor
//** Parametri di ingresso: AMonitor: TMonitorDesc
//** Parametri di uscita: nessuno
//** Scopo: Spostare la finestra dell'overlay su un altro monitor (servizio OBS attivo).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: lavora in pixel reali (SetWindowPos), cosi' funziona anche
//** con monitor a zoom diversi. La finestra viene allineata al bordo del
//** monitor lontano dal principale: se e' piu' grande del monitor scelto la
//** parte in eccesso esce verso l'esterno del desktop e non ricade sul
//** monitor principale. Le dimensioni non cambiano.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.MoveToMonitor(const AMonitor: TMonitorDesc);
var
    H: HWND;
    WR, PR, MR: TRect;
    X, Y: Integer;
begin
    if Handle = nil then
        Exit;
    H := FmxHandleToHWND(Handle);
    if (H = 0) or not GetWindowRect(H, WR) then
        Exit;
    PR := PrimaryMonitorRect;
    MR := AMonitor.Bounds;
    if MR.CenterPoint.X < PR.CenterPoint.X then
        X := MR.Right - WR.Width
    else
        X := MR.Left;
    if MR.CenterPoint.Y < PR.CenterPoint.Y then
        Y := MR.Bottom - WR.Height
    else
        Y := MR.Top;
    SetWindowPos(H, 0, X, Y, 0, 0, SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.CaptureObsFrame
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Preparare un fotogramma dell'overlay per OBS (dal ciclo principale, OBS_FPS volte al
//**        secondo).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento:
//** 1) calcola il rettangolo di ogni widget visibile nella pagina: posizione
//**    sullo schermo (coordinate FMX del monitor principale) scalata da
//**    Screen.Size alla risoluzione del servizio, cosi' con la risoluzione
//**    nativa ogni widget resta esattamente dov'e'; l'area da inviare e' solo
//**    quella che contiene tutti i widget (il resto della pagina e' vuoto);
//** 2) fotografa ogni widget visibile (MakeScreenshot, alla risoluzione reale
//**    dello schermo, quindi gia' con lo zoom di Windows) e li compone
//**    nell'area, con l'opacita' globale dell'overlay;
//** 3) copia i pixel e li consegna al server (SubmitFrame): compressione PNG
//**    e invio a OBS avvengono in altri thread, il thread principale fa solo
//**    cattura e composizione (tempo in FObsMs).
//** Le fotografie vengono fatte prima di aprire la scena della bitmap finale
//** (una scena alla volta). Gli errori finiscono nello stato del servizio.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.CaptureObsFrame;
var
    K: TDeviceKind;
    Shots: array[TDeviceKind] of TBitmap;
    Rects: array[TDeviceKind] of TRectF;
    Frame: TBitmap;
    W: TDeviceWidget;
    SX, SY, SW, SH: Single;
    U, R: TRectF;
    Crop: TRect;
    Data: TBitmapData;
    Pix: TBytes;
    Y, RowLen: Integer;
    Bgr, Any: Boolean;
    Watch: TStopwatch;
begin
    if not FObsActive or FSetupOpen then
        Exit;
    Watch := TStopwatch.StartNew;
    // scala: dalla dimensione del monitor principale in coordinate FMX alla risoluzione del servizio
    SW := Screen.Size.Width;
    SH := Screen.Size.Height;
    if (SW < 1) or (SH < 1) then
        Exit;
    SX := FConfig.ObsWidth / SW;
    SY := FConfig.ObsHeight / SH;

    // rettangolo di ogni widget visibile nella pagina e area che li contiene tutti
    Any := False;
    U := RectF(0, 0, 0, 0);
    for K := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        Shots[K] := nil;
        Rects[K] := RectF(0, 0, 0, 0);
        if FWidgets[K].Visible then
        begin
            W := FWidgets[K];
            Rects[K] := RectF((FFormOrigin.X + W.Position.X) * SX, (FFormOrigin.Y + W.Position.Y) * SY,
                (FFormOrigin.X + W.Position.X + W.Width) * SX, (FFormOrigin.Y + W.Position.Y + W.Height) * SY);
            if Any then
                U := TRectF.Union(U, Rects[K])
            else
                U := Rects[K];
            Any := True;
        end;
    end;
    Crop := Rect(0, 0, 0, 0);
    if Any then
        Crop := TRect.Intersect(Rect(Floor(U.Left), Floor(U.Top), Ceil(U.Right), Ceil(U.Bottom)),
            Rect(0, 0, FConfig.ObsWidth, FConfig.ObsHeight));
    if Crop.IsEmpty then
    begin
        // nessun widget nella pagina: OBS mostra la pagina vuota
        FWeb.SubmitFrame(nil, Rect(0, 0, 0, 0), True);
        Inc(FObsFrames);
        Inc(FObsFpsCount);
        Exit;
    end;

    Frame := nil;
    try
        try
            for K := Low(TDeviceKind) to High(TDeviceKind) do
                if FWidgets[K].Visible then
                    Shots[K] := FWidgets[K].MakeScreenshot;

            Frame := TBitmap.Create(Crop.Width, Crop.Height);
            if Frame.Canvas.BeginScene then
            try
                Frame.Canvas.Clear(TAlphaColors.Null);
                for K := Low(TDeviceKind) to High(TDeviceKind) do
                    if Shots[K] <> nil then
                    begin
                        R := Rects[K];
                        R.Offset(-Crop.Left, -Crop.Top);
                        Frame.Canvas.DrawBitmap(Shots[K], RectF(0, 0, Shots[K].Width, Shots[K].Height), R,
                            FConfig.Opacity, False);
                    end;
            finally
                Frame.Canvas.EndScene;
            end;

            // copia dei pixel (righe consecutive) per il thread di codifica
            Pix := nil;
            Bgr := True;
            if Frame.Map(TMapAccess.Read, Data) then
            try
                Bgr := Data.PixelFormat <> TPixelFormat.RGBA;
                RowLen := Data.Width * 4;
                SetLength(Pix, RowLen * Data.Height);
                for Y := 0 to Data.Height - 1 do
                    Move(PByte(Data.GetScanline(Y))^, Pix[Y * RowLen], RowLen);
            finally
                Frame.Unmap(Data);
            end;
            if Pix <> nil then
            begin
                FWeb.SubmitFrame(Pix, Crop, Bgr);
                Inc(FObsFrames);
                Inc(FObsFpsCount);
            end;
            FObsMs := Watch.ElapsedMilliseconds;
            FObsError := '';
        except
            on E: Exception do
                FObsError := E.Message;
        end;
    finally
        Frame.Free;
        for K := Low(TDeviceKind) to High(TDeviceKind) do
            Shots[K].Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmMain.ObsStatusText
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Testo dello stato del servizio OBS mostrato nella pagina OBS del Setup.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: servizio fermo, oppure su tre righe: indirizzo,
//** risoluzione, fps e modo di occultamento; fotogrammi preparati (e al
//** secondo effettivi), inviati a OBS, connessioni aperte, tempi di cattura
//** (thread principale) e di codifica (thread separato); pixel visibili
//** dell'ultimo fotogramma con l'esito (widget catturati / fotogramma vuoto),
//** l'eventuale errore e l'avviso se OBS non e' collegato.
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmMain.ObsStatusText: string;
var
    Mode: string;
    Mon: TMonitorDesc;
begin
    if not FObsActive then
        Exit(Tr('obs.status.stopped', 'Servizio fermo.'));
    case FConfig.ObsHideMode of
        OBS_HIDE_OFFSCREEN:
            Mode := Tr('setup.obs.hide.offscreen', 'Sposta la finestra fuori dallo schermo');
        OBS_HIDE_MONITOR:
            if FindMonitor(FConfig.ObsMonitor, Mon) and not Mon.Primary then
                Mode := Format(Tr('obs.status.monitor', 'finestra su %s'), [MonitorText(Mon)])
            else
                Mode := Tr('obs.status.nomonitor', 'monitor scelto non collegato: finestra fuori dallo schermo');
    else
        Mode := Tr('setup.obs.hide.window', 'Nascondi la finestra');
    end;
    Result := Format(Tr('obs.status.running',
        'ATTIVO su %s  ' + #$00B7 + '  %d x %d  ' + #$00B7 + '  %d fps  ' + #$00B7 + '  %s'),
        [FWeb.Url, FConfig.ObsWidth, FConfig.ObsHeight, FConfig.ObsFps, Mode]) + sLineBreak +
        Format(Tr('obs.status.stream',
        'Fotogrammi preparati: %d (%d al secondo)  ' + #$00B7 + '  inviati a OBS: %d  ' + #$00B7 +
        '  connessioni: %d  ' + #$00B7 + '  cattura %d ms, codifica %d ms'),
        [FObsFrames, FObsFpsValue, FWeb.FramesSent, FWeb.Clients, FObsMs, FWeb.EncodeMs]) + sLineBreak;
    if FObsError <> '' then
        Result := Result + Format(Tr('obs.status.error', 'ERRORE: %s'), [FObsError])
    else if FWeb.FramesEncoded > 0 then
    begin
        Result := Result + Format(Tr('obs.status.visible', 'Ultimo fotogramma: %d pixel visibili'),
            [FWeb.VisiblePixels]);
        if FWeb.VisiblePixels > 0 then
            Result := Result + Tr('obs.status.ok', '  ' + #$2192 + '  widget catturati con la finestra occultata.')
        else
            Result := Result + Tr('obs.status.empty',
                '  ' + #$2192 + '  ATTENZIONE: fotogramma vuoto, provare un altro modo di occultamento.');
    end;
    if FWeb.Clients = 0 then
        Result := Result + Tr('obs.status.noclient', '  ' + #$00B7 + '  OBS non collegato');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.BtnSetupClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Aprire la finestra di Setup dal pulsante della barra comandi (in coda, fuori dal click).
//** Data Ultima Modifica: 30/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.BtnSetupClick(Sender: TObject);
begin
    TThread.ForceQueue(nil,
        procedure
        begin
            OpenSetup;
        end);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.BtnLockClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Bloccare/sbloccare dalla barra comandi.
//** Data Ultima Modifica: 30/09/2026
//***********************************************************************************************************
//** Funzionamento: l'azione e' accodata, cosi' il cambio di dimensioni e di
//** stile della finestra avviene dopo che il click e' stato completato.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.BtnLockClick(Sender: TObject);
begin
    TThread.ForceQueue(nil,
        procedure
        begin
            if not FSetupOpen then
                SetLocked(not FLocked);
        end);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.BtnExitClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Uscire dall'applicazione.
//** Data Ultima Modifica: 30/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.BtnExitClick(Sender: TObject);
begin
    Close;
end;

end.
