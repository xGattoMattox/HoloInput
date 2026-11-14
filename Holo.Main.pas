//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Main
//** Scopo: Form principale = overlay trasparente, senza bordi, sempre in primo piano.
//** Data Ultima Modifica: 06/11/2026
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
    Holo.Config, Holo.Skins, Holo.Input, Holo.Models, Holo.Widget, Holo.UI, Holo.WebOverlay,
    Holo.Updater;

type
    TfrmMain = class(TForm)
    private
        oFConfig: TAppConfig;
        oFInput: TInputManager;
        rFColors: TSkinColors;
        oFContainer: TLayout;
        aFWidgets: array[TDeviceKind] of TDeviceWidget;
        oFToolbar: TLayout;
        oFBtnSetup, oFBtnLock, oFBtnExit, oFStatus, oFCredits: THoloButton;
        oFTimer: TTimer;
        rFClock: TStopwatch;
        dFLastTime: Double;
        bFLocked: Boolean;
        bFDirty: Boolean;
        bFSetupOpen: Boolean;
        bFToolbarHot: Boolean;     // mouse sulla barra comandi (solo da bloccato)
        rFFormOrigin: TPointF;
        oFWeb: TWebOverlayServer;  // servizio Browser Source per OBS
        bFObsActive: Boolean;      // servizio OBS avviato (overlay occultato)
        iFObsFrames: Integer;      // fotogrammi preparati dall'avvio del servizio
        iFObsMs: Int64;            // tempo di cattura e composizione dell'ultimo fotogramma (thread principale)
        dFObsLastCapture: Double;  // istante dell'ultimo fotogramma (secondi di rFClock)
        dFObsFpsT0: Double;        // inizio della misura dei fotogrammi al secondo
        iFObsFpsCount: Integer;    // fotogrammi preparati dall'inizio della misura
        iFObsFpsValue: Integer;    // fotogrammi al secondo effettivi (ultima misura)
        sFObsError: string;        // ultimo errore della preparazione dei fotogrammi
        procedure BuildUI;
        procedure ApplyConfig;
        procedure LayoutWidgets;
        procedure ApplyWindowStyles;
        procedure SetLocked(bAValue: Boolean);
        procedure UpdateToolbar;
        function bStreamerActive: Boolean;
        function dBarHeight: Single;
        function bIsShown(eAKind: TDeviceKind): Boolean;
        procedure ToggleStreamer;
        procedure UpdateHotZone;
        procedure SaveConfig;
        procedure OpenSetup;
        procedure ShowDisclaimer;
        procedure AutoStartObs;
        procedure ToggleOverlay;
        function bStartObs: Boolean;
        procedure StopObs;
        procedure ApplyObsHiding;
        procedure MoveToMonitor(const rAMonitor: TMonitorDesc);
        procedure CaptureObsFrame;
        function sObsStatusText: string;
        procedure TimerTick(oSender: TObject);
        procedure HotkeyPressed(oSender: TObject; iAHotkeyId: Integer);
        procedure WidgetMoved(oSender: TObject);
        procedure WidgetResized(oSender: TObject);
        procedure WidgetViewChanged(oSender: TObject);
        procedure SetupObsFpsChange(oSender: TObject; iAFps: Integer);
        procedure StartupUpdateCheck;
        procedure StartUpdateCheck;
        procedure CheckUpdatesNow;
        procedure UpdateFound(const rAInfo: TUpdateInfo; bAManual: Boolean);
        procedure InstallUpdate(const rAInfo: TUpdateInfo);
        procedure BtnSetupClick(oSender: TObject);
        procedure BtnLockClick(oSender: TObject);
        procedure BtnExitClick(oSender: TObject);
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
    Holo.Setup, Holo.Lang, Holo.Disclaimer, Holo.About, Holo.Dialog;

var
    /// True dalla distruzione della finestra principale: i risultati del controllo
    /// degli aggiornamenti in arrivo dal thread vengono ignorati.
    bGMainClosing: Boolean = False;

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
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: legge il .ini (se esiste), carica la lingua scelta, avvia
//** l'acquisizione input e le hotkey, costruisce l'interfaccia, applica la
//** configurazione e avvia il timer di rendering (~60 fps) e prepara il
//** servizio OBS (fermo); se l'avviso del
//** primo avvio non e' ancora stato accettato lo mette in coda
//** (ShowDisclaimer); se e' gia' accettato e nel Setup e' scelto "Avvia il
//** servizio all'avvio di HoloInput" mette in coda l'avvio del servizio OBS
//** (AutoStartObs). Al primo avvio (senza .ini) parte sbloccata per mostrare
//** subito i comandi. Infine mette in coda StartupUpdateCheck (messaggio dopo
//** un aggiornamento o controllo di una nuova versione su GitHub).
//***********************************************************************************************************
//***********************************************************************************************************
constructor TfrmMain.Create(AOwner: TComponent);
var
    bHasIni: Boolean;
begin
    inherited;
    oFConfig := TAppConfig.Create;
    bHasIni := FileExists(TAppConfig.sDefaultFileName);
    if bHasIni then
    try
        oFConfig.LoadFromFile(TAppConfig.sDefaultFileName);
    except
        oFConfig.SetDefaults;
    end;

    oFInput := TInputManager.Create;
    oFInput.mOnHotkey := HotkeyPressed;
    oFInput.bRegisterHotkeys;

    LoadLanguage(oFConfig.sLanguage);
    bFLocked := bHasIni and oFConfig.bStartLocked;
    BuildUI;
    ApplyConfig;

    rFClock := TStopwatch.StartNew;
    dFLastTime := 0;
    oFTimer := TTimer.Create(Self);
    oFTimer.Interval := 15;
    oFTimer.OnTimer := TimerTick;
    oFTimer.Enabled := True;

    // servizio Browser Source per OBS: fermo finche' non lo si avvia dal Setup
    oFWeb := TWebOverlayServer.Create;

    // primo avvio: avviso legale (Holo.Disclaimer), finche' non viene accettato;
    // altrimenti, se richiesto, avvio automatico del servizio OBS
    if not oFConfig.bDisclaimerAccepted then
        TThread.ForceQueue(nil,
            procedure
            begin
                ShowDisclaimer;
            end)
    else if oFConfig.bObsAutoStart then
        TThread.ForceQueue(nil,
            procedure
            begin
                AutoStartObs;
            end);

    // aggiornamenti: messaggio dopo un aggiornamento appena installato oppure
    // controllo (in background) di una nuova versione su GitHub
    if oFConfig.bDisclaimerAccepted then
        TThread.ForceQueue(nil,
            procedure
            begin
                StartupUpdateCheck;
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
    bGMainClosing := True;
    if oFTimer <> nil then
        oFTimer.Enabled := False;
    bFObsActive := False;
    FreeAndNil(oFWeb);
    if bFDirty then
        SaveConfig;
    FreeAndNil(oFInput);
    inherited;
    FreeAndNil(oFConfig);
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
    eDevice: TDeviceKind;
    dPosX: Single;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: oMakeButton
    //** Parametri di ingresso: sAText: string; dAWidth: Single; mAClick: TNotifyEvent
    //** Parametri di uscita: Result: THoloButton
    //** Scopo: Creare un pulsante della barra comandi con testo, larghezza e gestore del click,
    //**        accodandolo ai precedenti.
    //** Data Ultima Modifica: 29/09/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function oMakeButton(const sAText: string; dAWidth: Single; mAClick: TNotifyEvent): THoloButton;
    begin
        Result := THoloButton.Create(Self);
        Result.Parent := oFToolbar;
        Result.sText := sAText;
        Result.SetBounds(dPosX, 0, dAWidth, TOOLBAR_H);
        Result.OnClick := mAClick;
        dPosX := dPosX + dAWidth + 6;
    end;

begin
    oFContainer := TLayout.Create(Self);
    oFContainer.Parent := Self;
    oFContainer.Align := TAlignLayout.Client;
    oFContainer.HitTest := False;

    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        aFWidgets[eDevice] := TDeviceWidget.CreateWidget(Self, eDevice);
        aFWidgets[eDevice].Parent := oFContainer;
        aFWidgets[eDevice].Visible := False;
        aFWidgets[eDevice].mOnMoved := WidgetMoved;
        aFWidgets[eDevice].mOnResized := WidgetResized;
        aFWidgets[eDevice].mOnViewChanged := WidgetViewChanged;
    end;

    oFToolbar := TLayout.Create(Self);
    oFToolbar.Parent := oFContainer;
    oFToolbar.HitTest := False;
    oFToolbar.Width := TOOLBAR_W;
    oFToolbar.Height := BAR_H;

    dPosX := 0;
    // i testi dei pulsanti vengono scritti (nella lingua corrente) da UpdateToolbar
    oFBtnSetup := oMakeButton('', 90, BtnSetupClick);
    oFBtnLock := oMakeButton('', 160, BtnLockClick);
    oFBtnExit := oMakeButton('', 80, BtnExitClick);
    oFStatus := oMakeButton('', TOOLBAR_W - dPosX, nil);
    oFStatus.bPassive := True;
    oFStatus.dFontSize := 10;

    // etichetta dei crediti sotto i pulsanti, larga quanto tutta la barra
    oFCredits := THoloButton.Create(Self);
    oFCredits.Parent := oFToolbar;
    oFCredits.SetBounds(0, TOOLBAR_H + CREDITS_GAP, TOOLBAR_W, CREDITS_H);
    oFCredits.bPassive := True;
    oFCredits.bKeepCase := True;
    oFCredits.dFontSize := 11;
    oFCredits.sText := sTr('main.credits', CREDITS_TEXT);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.ApplyConfig
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Applicare la configurazione corrente a tutta l'interfaccia.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: risolve la skin, aggiorna stile finestra e gestore degli input,
//** configura i widget visibili (stile pannello / solo dispositivo, effetti
//** di base, creando/aggiornando i modelli 3D), registra
//** i dispositivi da leggere, ricalcola la disposizione e gli stili Win32.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.ApplyConfig;
var
    eDevice: TDeviceKind;
    oSkinCls: TSkinClass;
    oWidget: TDeviceWidget;
begin
    oSkinCls := oFindSkin(oFConfig.sSkinId);
    if oSkinCls <> nil then
        rFColors := oSkinCls.rColors
    else
        rFColors := rDefaultSkinColors;

    if oFConfig.bStayOnTop then
    begin
        if FormStyle <> TFormStyle.StayOnTop then
            FormStyle := TFormStyle.StayOnTop;
    end
    else if FormStyle <> TFormStyle.Normal then
        FormStyle := TFormStyle.Normal;

    oFInput.dMouseRange := oFConfig.iMouseRange;
    oFInput.ClearUsage;
    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        oWidget := aFWidgets[eDevice];
        oWidget.Visible := bIsShown(eDevice);
        if oWidget.Visible then
        begin
            oWidget.SetStyle(oFConfig.eWidgetStyle = wsDeviceOnly, oFConfig.bBaseEffects);
            oWidget.SetAutoHide(oFConfig.bAutoHide, oFConfig.iAutoHideSecs);
            oWidget.Configure(oFConfig.aWidgets[eDevice], rFColors, oFConfig.bShowLegends);
            oWidget.BindDevices(oFInput);
        end;
        oWidget.bEditMode := not bFLocked;
    end;

    oFBtnSetup.SetColors(rFColors);
    oFBtnLock.SetColors(rFColors);
    oFBtnExit.SetColors(rFColors);
    oFStatus.SetColors(rFColors);
    oFCredits.SetColors(rFColors);
    oFContainer.Opacity := oFConfig.dOpacity;

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
    eDevice: TDeviceKind;
    aRects: array[TDeviceKind] of TRectF;
    aVis: TKindLine;
    aLines: TArray<TKindLine>;
    rWorkArea, rUnion, rBarRect, rFormRect: TRectF;
    dMargin, dGap, dPosX, dPosY, dLineL, dLineT, dLTop, dLLeft, dBlockH, dTBx, dToolbarHeight: Single;
    iLineIndex: Integer;
    bFirst, bHoriz: Boolean;
    rWidget: TWidgetConfig;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: dAlong
    //** Parametri di ingresso: eAKind: TDeviceKind; bAHoriz: Boolean
    //** Parametri di uscita: Result: Single
    //** Scopo: Dimensione di un widget lungo la direzione della fila (larghezza in orizzontale,
    //**        altezza in verticale).
    //** Data Ultima Modifica: 21/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function dAlong(eAKind: TDeviceKind; bAHoriz: Boolean): Single;
    begin
        if bAHoriz then
            Result := oFConfig.aWidgets[eAKind].iW
        else
            Result := oFConfig.aWidgets[eAKind].iH;
    end;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: dAcross
    //** Parametri di ingresso: eAKind: TDeviceKind; bAHoriz: Boolean
    //** Parametri di uscita: Result: Single
    //** Scopo: Dimensione di un widget nella direzione trasversale alla fila (altezza in
    //**        orizzontale, larghezza in verticale).
    //** Data Ultima Modifica: 21/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function dAcross(eAKind: TDeviceKind; bAHoriz: Boolean): Single;
    begin
        Result := dAlong(eAKind, not bAHoriz);
    end;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: dLineLen
    //** Parametri di ingresso: aALine: TKindLine; bAHoriz: Boolean
    //** Parametri di uscita: Result: Single
    //** Scopo: Lunghezza di una fila di widget, spazi tra i widget compresi.
    //** Data Ultima Modifica: 21/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function dLineLen(const aALine: TKindLine; bAHoriz: Boolean): Single;
    var
        iItem: Integer;
    begin
        Result := 0;
        for iItem := 0 to High(aALine) do
        begin
            if iItem > 0 then
                Result := Result + dGap;
            Result := Result + dAlong(aALine[iItem], bAHoriz);
        end;
    end;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: dLineThick
    //** Parametri di ingresso: aALine: TKindLine; bAHoriz: Boolean
    //** Parametri di uscita: Result: Single
    //** Scopo: Spessore di una fila di widget, cioe' la dimensione trasversale del widget piu'
    //**        grande.
    //** Data Ultima Modifica: 21/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function dLineThick(const aALine: TKindLine; bAHoriz: Boolean): Single;
    var
        iItem: Integer;
    begin
        Result := 0;
        for iItem := 0 to High(aALine) do
            Result := Max(Result, dAcross(aALine[iItem], bAHoriz));
    end;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: aSplitLines
    //** Parametri di ingresso: bAHoriz: Boolean; dALimit: Single
    //** Parametri di uscita: Result: TArray<TKindLine>
    //** Scopo: Divide i widget visibili in file che non superano dALimit.
    //** Data Ultima Modifica: 21/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function aSplitLines(bAHoriz: Boolean; dALimit: Single): TArray<TKindLine>;
    var
        aAcc: TArray<TKindLine>;
        aLine: TKindLine;
        dLen, dSize: Single;
        iItem: Integer;

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
            if Length(aLine) = 0 then
                Exit;
            SetLength(aAcc, Length(aAcc) + 1);
            aAcc[High(aAcc)] := aLine;
            aLine := nil;
            dLen := 0;
        end;

    begin
        aAcc := nil;
        aLine := nil;
        dLen := 0;
        for iItem := 0 to High(aVis) do
        begin
            dSize := dAlong(aVis[iItem], bAHoriz);
            if (Length(aLine) > 0) and (dLen + dGap + dSize > dALimit) then
                Flush;
            if Length(aLine) > 0 then
                dLen := dLen + dGap;
            dLen := dLen + dSize;
            SetLength(aLine, Length(aLine) + 1);
            aLine[High(aLine)] := aVis[iItem];
        end;
        Flush;
        Result := aAcc;
    end;

begin
    rWorkArea := RectF(Screen.WorkAreaLeft, Screen.WorkAreaTop,
        Screen.WorkAreaLeft + Screen.WorkAreaWidth, Screen.WorkAreaTop + Screen.WorkAreaHeight);
    dMargin := oFConfig.iMargin;
    dToolbarHeight := dBarHeight;
    dGap := oFConfig.iSpacing;

    aVis := nil;
    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        aRects[eDevice] := RectF(0, 0, 0, 0);
        if bIsShown(eDevice) then
        begin
            SetLength(aVis, Length(aVis) + 1);
            aVis[High(aVis)] := eDevice;
        end;
    end;

    // barra comandi: SEMPRE in basso al centro del monitor, qualunque sia il layout
    dTBx := rWorkArea.Left + (rWorkArea.Width - TOOLBAR_W) / 2;
    rBarRect := RectF(dTBx, rWorkArea.Bottom - dMargin - dToolbarHeight, dTBx + TOOLBAR_W, rWorkArea.Bottom
        - dMargin);

    case oFConfig.eLayout of
        lmBottom, lmTop:
            begin
                bHoriz := True;
                aLines := aSplitLines(bHoriz, rWorkArea.Width - 2 * dMargin);
                if oFConfig.eLayout = lmBottom then
                    dPosY := rBarRect.Top - dGap          // la fila in basso si appoggia sopra la barra
                else
                    dPosY := rWorkArea.Top + dMargin;
                for iLineIndex := 0 to High(aLines) do
                begin
                    dLineL := dLineLen(aLines[iLineIndex], bHoriz);
                    dLineT := dLineThick(aLines[iLineIndex], bHoriz);
                    dPosX := rWorkArea.Left + (rWorkArea.Width - dLineL) / 2;
                    if oFConfig.eLayout = lmBottom then
                        dLTop := dPosY - dLineT
                    else
                        dLTop := dPosY;
                    for eDevice in aLines[iLineIndex] do
                    begin
                        rWidget := oFConfig.aWidgets[eDevice];
                        if oFConfig.eLayout = lmBottom then
                            aRects[eDevice] := RectF(dPosX, dLTop + dLineT - rWidget.iH, dPosX + rWidget.iW,
                                dLTop + dLineT)
                        else
                            aRects[eDevice] := RectF(dPosX, dLTop, dPosX + rWidget.iW, dLTop + rWidget.iH);
                        dPosX := dPosX + rWidget.iW + dGap;
                    end;
                    if oFConfig.eLayout = lmBottom then
                        dPosY := dLTop - dGap
                    else
                        dPosY := dLTop + dLineT + dGap;
                end;
            end;

        lmRight, lmLeft:
            begin
                bHoriz := False;
                aLines := aSplitLines(bHoriz, rWorkArea.Height - 2 * dMargin);
                dBlockH := 0;
                for iLineIndex := 0 to High(aLines) do
                    dBlockH := Max(dBlockH, dLineLen(aLines[iLineIndex], bHoriz));
                dLTop := Max(rWorkArea.Top + dMargin, rWorkArea.Top + (rWorkArea.Height - dBlockH) / 2);
                if oFConfig.eLayout = lmRight then
                    dPosX := rWorkArea.Right - dMargin
                else
                    dPosX := rWorkArea.Left + dMargin;
                for iLineIndex := 0 to High(aLines) do
                begin
                    dLineL := dLineLen(aLines[iLineIndex], bHoriz);
                    dLineT := dLineThick(aLines[iLineIndex], bHoriz);
                    if oFConfig.eLayout = lmRight then
                        dLLeft := dPosX - dLineT
                    else
                        dLLeft := dPosX;
                    dPosY := dLTop + (dBlockH - dLineL) / 2;
                    for eDevice in aLines[iLineIndex] do
                    begin
                        rWidget := oFConfig.aWidgets[eDevice];
                        if oFConfig.eLayout = lmRight then
                            aRects[eDevice] := RectF(dLLeft + dLineT - rWidget.iW, dPosY, dLLeft + dLineT,
                                dPosY + rWidget.iH)
                        else
                            aRects[eDevice] := RectF(dLLeft, dPosY, dLLeft + rWidget.iW, dPosY + rWidget.iH);
                        dPosY := dPosY + rWidget.iH + dGap;
                    end;
                    if oFConfig.eLayout = lmRight then
                        dPosX := dLLeft - dGap
                    else
                        dPosX := dLLeft + dLineT + dGap;
                end;
            end;

    else  // lmCustom
        for eDevice in aVis do
        begin
            rWidget := oFConfig.aWidgets[eDevice];
            aRects[eDevice] := RectF(rWidget.iX, rWidget.iY, rWidget.iX + rWidget.iW, rWidget.iY
                + rWidget.iH);
        end;
    end;

    // layout predefiniti: se qualche widget finirebbe sopra la barra comandi,
    // tutto il gruppo sale quanto basta (senza superare il bordo superiore)
    if oFConfig.eLayout in [lmTop, lmRight, lmLeft] then
    begin
        dPosY := 0;
        for eDevice in aVis do
            if (aRects[eDevice].Right > rBarRect.Left - dGap) and (aRects[eDevice].Left < rBarRect.Right
                + dGap) then
                dPosY := Max(dPosY, aRects[eDevice].Bottom - (rBarRect.Top - dGap));
        if dPosY > 0 then
        begin
            dLTop := rWorkArea.Bottom;
            for eDevice in aVis do
                dLTop := Min(dLTop, aRects[eDevice].Top);
            dPosY := Min(dPosY, Max(0, dLTop - (rWorkArea.Top + dMargin)));
            for eDevice in aVis do
                aRects[eDevice].Offset(0, -dPosY);
        end;
    end;

    // posizioni calcolate -> X/Y (mostrate nel setup)
    if oFConfig.eLayout <> lmCustom then
        for eDevice in aVis do
        begin
            oFConfig.aWidgets[eDevice].iX := Round(aRects[eDevice].Left);
            oFConfig.aWidgets[eDevice].iY := Round(aRects[eDevice].Top);
        end;

    bFirst := True;
    rUnion := RectF(0, 0, 0, 0);
    for eDevice in aVis do
    begin
        if bFirst then
            rUnion := aRects[eDevice]
        else
            rUnion := TRectF.Union(rUnion, aRects[eDevice]);
        bFirst := False;
    end;

    if bFirst then
        rUnion := rBarRect
    else
        rUnion := TRectF.Union(rUnion, rBarRect);

    if bFLocked then
    begin
        rFormRect := rUnion;
        rFormRect.Inflate(2, 2);
    end
    else
        rFormRect := RectF(Screen.DesktopLeft, Screen.DesktopTop,
            Screen.DesktopLeft + Screen.DesktopWidth, Screen.DesktopTop + Screen.DesktopHeight);

    rFFormOrigin := rFormRect.TopLeft;
    SetBounds(Round(rFormRect.Left), Round(rFormRect.Top), Round(rFormRect.Width), Round(rFormRect.Height));

    for eDevice in aVis do
        aFWidgets[eDevice].SetBounds(aRects[eDevice].Left - rFFormOrigin.X, aRects[eDevice].Top
            - rFFormOrigin.Y,
            aRects[eDevice].Width, aRects[eDevice].Height);
    oFToolbar.Position.Point := PointF(rBarRect.Left - rFFormOrigin.X, rBarRect.Top - rFFormOrigin.Y);
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
//** finestra), tranne quando il mouse e' sulla barra comandi (bFToolbarHot):
//** in quel caso la finestra riceve i click e i pulsanti funzionano.
//** In modalita' sbloccata li rimuove entrambi. La trasparenza per-pixel e'
//** gestita da FMX (Transparency = True nel .fmx).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.ApplyWindowStyles;
var
    hWindow: HWND;
    iExStyle, iNewEx: NativeInt;
begin
    if Handle = nil then
        Exit;
    hWindow := FmxHandleToHWND(Handle);
    if hWindow = 0 then
        Exit;
    iExStyle := GetWindowLongPtr(hWindow, GWL_EXSTYLE);
    iNewEx := iExStyle and not NativeInt(WS_EX_TRANSPARENT or WS_EX_NOACTIVATE);
    if bFLocked then
    begin
        iNewEx := iNewEx or WS_EX_NOACTIVATE;
        if not bFToolbarHot then
            iNewEx := iNewEx or WS_EX_TRANSPARENT;
    end;
    if iNewEx <> iExStyle then
        SetWindowLongPtr(hWindow, GWL_EXSTYLE, iNewEx);
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
    rMousePos: TPointF;
    rBarRect: TRectF;
    bOver: Boolean;
begin
    bOver := False;
    if bFLocked and Visible and not bFSetupOpen then
    begin
        rMousePos := ScreenToClient(Screen.MousePos);
        rBarRect := oFToolbar.AbsoluteRect;
        rBarRect.Inflate(4, 4);
        bOver := rBarRect.Contains(rMousePos);
    end;
    if bOver = bFToolbarHot then
        Exit;
    bFToolbarHot := bOver;
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
//** Parametri di ingresso: bAValue: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Passare tra modalita' bloccata e sbloccata.
//** Data Ultima Modifica: 29/09/2026
//***********************************************************************************************************
//** Funzionamento: aggiorna i widget (trascinabili o no), la barra, la
//** geometria della finestra e gli stili; quando si blocca salva su .ini le
//** posizioni eventualmente modificate a mano.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.SetLocked(bAValue: Boolean);
var
    eDevice: TDeviceKind;
begin
    bFLocked := bAValue;
    bFToolbarHot := False;
    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
        aFWidgets[eDevice].bEditMode := not bFLocked;
    if bFLocked and bFDirty then
        SaveConfig;
    LayoutWidgets;
    UpdateToolbar;
    ApplyWindowStyles;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmMain.bStreamerActive
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: True se la modalita' streamer e' attiva E il suo tasto rapido funziona (altrimenti non
//**        ci sarebbe modo di far ricomparire i pulsanti).
//** Data Ultima Modifica: 24/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmMain.bStreamerActive: Boolean;
begin
    Result := oFConfig.bStreamerMode and oFInput.bStreamerHotkeyOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmMain.dBarHeight
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Single
//** Scopo: Altezza della barra comandi (solo etichetta in modalita' streamer).
//** Data Ultima Modifica: 24/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmMain.dBarHeight: Single;
begin
    if bStreamerActive then
        Result := CREDITS_H
    else
        Result := BAR_H;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmMain.bIsShown
//** Parametri di ingresso: eAKind: TDeviceKind
//** Parametri di uscita: Result: Boolean
//** Scopo: True se il widget va mostrato: deve essere attivo nel setup e, per la tastiera, la
//**        modalita' privacy deve essere spenta.
//** Data Ultima Modifica: 24/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmMain.bIsShown(eAKind: TDeviceKind): Boolean;
begin
    Result := oFConfig.aWidgets[eAKind].bVisible and
        not ((eAKind = dkKeyboard) and oFConfig.bPrivacyMode);
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
    oFConfig.bStreamerMode := not oFConfig.bStreamerMode;
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
    bStreamer: Boolean;
begin
    bStreamer := bStreamerActive;
    oFBtnSetup.Visible := not bStreamer;
    oFBtnLock.Visible := not bStreamer;
    oFBtnExit.Visible := not bStreamer;
    oFStatus.Visible := not bStreamer;
    if bStreamer then
    begin
        oFCredits.Position.Y := 0;
        oFCredits.sText := sTr('main.credits', CREDITS_TEXT) + sTr('main.streamerhint', STREAMER_HINT);
    end
    else
    begin
        oFCredits.Position.Y := TOOLBAR_H + CREDITS_GAP;
        oFCredits.sText := sTr('main.credits', CREDITS_TEXT);
    end;
    oFToolbar.Height := dBarHeight;

    oFBtnSetup.sText := sTr('main.btn.setup', 'Setup');
    oFBtnExit.sText := sTr('main.btn.exit', 'Esci');
    if bFLocked then
    begin
        oFBtnLock.sText := sTr('main.btn.unlock', 'Sblocca layout');
        oFBtnLock.bHighlight := True;
        oFStatus.sText := sTr('main.status.locked', 'BLOCCATO  ' + #$00B7 + '  CTRL+ALT+F12 PER SBLOCCARE');
        if bFToolbarHot then
            oFToolbar.Opacity := 1
        else
            oFToolbar.Opacity := 0.55;
    end
    else
    begin
        oFBtnLock.sText := sTr('main.btn.lock', 'Blocca layout');
        oFBtnLock.bHighlight := False;
        oFStatus.sText := sTr('main.status.edit', 'MODIFICA  ' + #$00B7 + '  TRASCINA I WIDGET');
        oFToolbar.Opacity := 1;
    end;
    if not oFInput.bHotkeysOk then
        oFStatus.sText := oFStatus.sText + sTr('main.status.nohotkeys', '  (HOTKEY NON DISPONIBILI)');
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
        oFConfig.SaveToFile(TAppConfig.sDefaultFileName);
        bFDirty := False;
    except
        on oError: Exception do
            ShowMessage(sTr('main.err.save', 'Impossibile salvare la configurazione:') + sLineBreak +
                oError.Message);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.TimerTick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Ciclo principale (~60 fps).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: misura il tempo trascorso, aggiorna lo snapshot degli input
//** e lo passa a tutti i widget visibili; con il servizio OBS attivo prepara
//** un fotogramma per OBS al ritmo scelto (iObsFps) e misura i fotogrammi al
//** secondo effettivi.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.TimerTick(oSender: TObject);
var
    dTime, dDeltaTime: Double;
    eDevice: TDeviceKind;
    pSnapshot: PInputSnapshot;
begin
    dTime := rFClock.Elapsed.TotalSeconds;
    dDeltaTime := EnsureRange(dTime - dFLastTime, 0, 0.1);
    dFLastTime := dTime;
    UpdateHotZone;
    oFInput.Poll(dDeltaTime);
    pSnapshot := oFInput.pStatePtr;
    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
        if aFWidgets[eDevice].Visible then
            aFWidgets[eDevice].Tick(pSnapshot^, dDeltaTime, oFConfig.bAnimations);

    // servizio OBS: un fotogramma ogni 1/fps secondi (il timer gira a ~64 Hz,
    // la tolleranza del 10% evita di saltare un tick per pochi decimi di ms)
    if bFObsActive then
    begin
        if dTime - dFObsLastCapture >= 0.9 / Max(1, oFConfig.iObsFps) then
        begin
            dFObsLastCapture := dTime;
            CaptureObsFrame;
        end;
        if dTime - dFObsFpsT0 >= 1 then
        begin
            iFObsFpsValue := Round(iFObsFpsCount / (dTime - dFObsFpsT0));
            iFObsFpsCount := 0;
            dFObsFpsT0 := dTime;
        end;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.HotkeyPressed
//** Parametri di ingresso: oSender: TObject; iAHotkeyId: Integer
//** Parametri di uscita: nessuno
//** Scopo: Gestire le hotkey globali.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: l'azione viene accodata (ForceQueue) per eseguirla fuori
//** dalla procedura di finestra, cosi' si possono aprire finestre modali.
//** Con il servizio OBS attivo funziona solo Ctrl+Alt+F11 (Setup): le altre
//** cambierebbero posizione o visibilita' della finestra occultata.
//** Ctrl+Alt+F11 spegne anche la modalita' streamer, se attiva: alla chiusura
//** del Setup la barra comandi e l'etichetta sottostante sono di nuovo visibili.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.HotkeyPressed(oSender: TObject; iAHotkeyId: Integer);
begin
    TThread.ForceQueue(nil,
        procedure
        begin
            case iAHotkeyId of
                HK_LOCK:    if not bFSetupOpen and not bFObsActive then SetLocked(not bFLocked);
                HK_SETUP:
                    begin
                        if oFConfig.bStreamerMode and not bFSetupOpen then
                            ToggleStreamer;   // la barra comandi torna visibile
                        OpenSetup;
                    end;
                HK_VISIBLE: ToggleOverlay;
                HK_STREAMER: if not bFSetupOpen and not bFObsActive then ToggleStreamer;
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
    if bFSetupOpen or bFObsActive then
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
//** Parametri di ingresso: oSender: TObject
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
procedure TfrmMain.WidgetMoved(oSender: TObject);
var
    oWidget: TDeviceWidget;
begin
    oWidget := oSender as TDeviceWidget;
    if oFConfig.eLayout <> lmCustom then
        oFConfig.SetLayout(lmCustom);
    oFConfig.aWidgets[oWidget.eKind].iX := Round(rFFormOrigin.X + oWidget.Position.X);
    oFConfig.aWidgets[oWidget.eKind].iY := Round(rFFormOrigin.Y + oWidget.Position.Y);
    bFDirty := True;
    LayoutWidgets;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.WidgetResized
//** Parametri di ingresso: oSender: TObject
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
procedure TfrmMain.WidgetResized(oSender: TObject);
var
    oWidget: TDeviceWidget;
begin
    oWidget := oSender as TDeviceWidget;
    oFConfig.aWidgets[oWidget.eKind].iW := Round(oWidget.Width);
    oFConfig.aWidgets[oWidget.eKind].iH := Round(oWidget.Height);
    if oFConfig.eLayout = lmCustom then
    begin
        oFConfig.aWidgets[oWidget.eKind].iX := Round(rFFormOrigin.X + oWidget.Position.X);
        oFConfig.aWidgets[oWidget.eKind].iY := Round(rFFormOrigin.Y + oWidget.Position.Y);
    end;
    bFDirty := True;
    LayoutWidgets;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.WidgetViewChanged
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Memorizzare la vista di un widget ruotata con il tasto destro o zoomata con la rotella
//**        del mouse.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: copia inclinazione, rotazione, zoom e spostamento verticale
//** del widget nella configurazione (VistaInclinazione / VistaRotazione /
//** VistaZoom / VistaSpostamento nel .ini);
//** il file viene salvato con le altre modifiche quando si blocca il layout.
//** Il pulsante Default del Setup riporta la vista a quella predefinita.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.WidgetViewChanged(oSender: TObject);
var
    oWidget: TDeviceWidget;
begin
    oWidget := oSender as TDeviceWidget;
    oFConfig.aWidgets[oWidget.eKind].dTilt := oWidget.dViewTilt;
    oFConfig.aWidgets[oWidget.eKind].dYaw := oWidget.dViewYaw;
    oFConfig.aWidgets[oWidget.eKind].dZoom := oWidget.dViewZoom;
    oFConfig.aWidgets[oWidget.eKind].dPanY := oWidget.dViewPanY;
    bFDirty := True;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.OpenSetup
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Aprire la schermata di setup.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: nasconde l'overlay ("pulisce la vista"), lavora su una
//** copia della configurazione; con Salva la copia diventa la configurazione
//** attiva, viene scritta nel .ini e applicata; con Chiudi non cambia nulla.
//** Il Setup riceve lo stato del servizio OBS e restituisce l'azione chiesta
//** (avvia/ferma); con il servizio attivo l'overlay resta occultato. Il cambio
//** degli FPS con il servizio attivo e' eseguito subito (SetupObsFpsChange).
//** Con il pulsante "Controlla aggiornamenti" (pagina Info) dopo la chiusura
//** parte il controllo degli aggiornamenti (CheckUpdatesNow).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.OpenSetup;
var
    oTmp: TAppConfig;
    oDlg: TfrmSetup;
    eRes: TModalResult;
    eAct: TObsAction;
    bUpd: Boolean;
begin
    if bFSetupOpen then
        Exit;
    bFSetupOpen := True;
    bFToolbarHot := False;
    oFTimer.Enabled := False;
    Hide;
    eAct := oaNone;
    bUpd := False;
    oTmp := TAppConfig.Create;
    try
        oTmp.Assign(oFConfig);
        // cambiando lingua il setup si chiude con mrRetry e si riapre nella nuova
        // lingua, mantenendo le modifiche non ancora salvate (sono in Tmp)
        repeat
            oDlg := TfrmSetup.CreateSetup(nil, oTmp, oFInput);
            try
                oDlg.mOnObsFpsChange := SetupObsFpsChange;
                oDlg.SetObsState(bFObsActive, sObsStatusText);
                eRes := oDlg.ShowModal;
                eAct := oDlg.eObsAction;
                bUpd := oDlg.bUpdateRequested;
            finally
                oDlg.Free;
            end;
            if eRes = mrRetry then
                LoadLanguage(oTmp.sLanguage);
        until eRes <> mrRetry;
        if eRes = mrOk then
        begin
            oFConfig.Assign(oTmp);
            SaveConfig;
        end;
        // lingua definitiva: quella salvata (chiudendo senza salvare torna la precedente)
        if not SameText(sCurrentLanguage, oFConfig.sLanguage) then
            LoadLanguage(oFConfig.sLanguage);
    finally
        oTmp.Free;
        bFSetupOpen := False;
    end;
    ApplyConfig;
    // servizio OBS: avvio/arresto chiesto dalla pagina OBS; con Salva e il servizio
    // gia' attivo lo si riavvia, cosi' valgono subito porta e risoluzione nuove
    if eRes = mrOk then
        case eAct of
            oaStart: bStartObs;
            oaStop:  StopObs;
        else
            if bFObsActive then
                bStartObs;
        end;
    if bFObsActive then
        ApplyObsHiding
    else
    begin
        Show;
        ApplyWindowStyles;
    end;
    oFTimer.Enabled := True;
    // pulsante "Controlla aggiornamenti" della pagina Info
    if (eRes = mrOk) and bUpd then
        CheckUpdatesNow;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.ShowDisclaimer
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Mostrare l'avviso legale del primo avvio e ricordarne l'accettazione.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: nasconde l'overlay e ferma il rendering mentre l'avviso e'
//** aperto (bFSetupOpen blocca anche setup e blocco del layout dalle hotkey).
//** Con "Accetto" salva nel .ini l'accettazione e la lingua e la skin scelte
//** nell'avviso, applica la configurazione e rimostra l'overlay; con
//** "Rifiuto" chiude l'applicazione senza salvare (l'avviso ricomparira' al
//** prossimo avvio). Dopo l'accettazione puo' partire il servizio OBS
//** (AutoStartObs) e il controllo degli aggiornamenti.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.ShowDisclaimer;
var
    bAccepted: Boolean;
begin
    bFSetupOpen := True;
    oFTimer.Enabled := False;
    Hide;
    try
        bAccepted := bRunDisclaimer(oFConfig);
    finally
        bFSetupOpen := False;
    end;
    if not bAccepted then
    begin
        Application.Terminate;
        Close;
        Exit;
    end;
    oFConfig.bDisclaimerAccepted := True;
    SaveConfig;
    ApplyConfig;
    Show;
    ApplyWindowStyles;
    oFTimer.Enabled := True;
    AutoStartObs;
    if oFConfig.bCheckUpdates then
        StartUpdateCheck;
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
//** occulta l'overlay come scelto nel Setup. Se la porta e' occupata bStartObs
//** mostra l'errore e l'overlay resta visibile.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.AutoStartObs;
begin
    if bFObsActive or bFSetupOpen or not oFConfig.bObsAutoStart then
        Exit;
    if bStartObs then
        ApplyObsHiding;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmMain.bStartObs
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
function TfrmMain.bStartObs: Boolean;
begin
    Result := False;
    if not bFLocked then
        SetLocked(True);
    try
        oFWeb.Start(oFConfig.iObsPort, oFConfig.iObsWidth, oFConfig.iObsHeight);
    except
        on oError: Exception do
        begin
            bFObsActive := False;
            ShowMessage(Format(sTr('obs.err.start', 'Impossibile avviare il servizio OBS sulla porta %d:'),
                [oFConfig.iObsPort]) + sLineBreak + oError.Message);
            Exit;
        end;
    end;
    bFObsActive := True;
    iFObsFrames := 0;
    iFObsMs := 0;
    sFObsError := '';
    dFObsLastCapture := 0;
    dFObsFpsT0 := rFClock.Elapsed.TotalSeconds;
    iFObsFpsCount := 0;
    iFObsFpsValue := 0;
    Result := True;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.StartupUpdateCheck
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: All'avvio, segnalare un aggiornamento appena installato oppure controllare se su GitHub
//**        c'e' una nuova versione.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: dopo un aggiornamento (avvio con "--after-update") mostra
//** la versione installata; altrimenti, se nel Setup e' attivo "Controlla
//** all'avvio", avvia il controllo in background (StartUpdateCheck).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.StartupUpdateCheck;
begin
    if bJustUpdated then
        HoloMessage(sTr('update.done.title', 'HoloInput aggiornato'),
            Format(sTr('update.done.text', 'HoloInput e'' stato aggiornato alla versione %s.' + sLineBreak +
            sLineBreak + 'Le novita'' sono nel file CHANGELOG.md accanto all''eseguibile.'), [sAppVersion]),
            rFColors)
    else if oFConfig.bCheckUpdates then
        StartUpdateCheck;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.StartUpdateCheck
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Controllare in background se su GitHub c'e' una nuova versione.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: la richiesta a GitHub (con le novita' della nuova versione)
//** gira in un thread, cosi' l'overlay non si blocca; il risultato torna nel
//** thread principale (UpdateFound) solo se la richiesta e' riuscita. Gli
//** errori di rete vengono ignorati in silenzio.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.StartUpdateCheck;
var
    sCur: string;
begin
    sCur := sAppVersion;   // letta qui, nel thread principale
    TThread.CreateAnonymousThread(
        procedure
        var
            rInfo: TUpdateInfo;
            sErr: string;
        begin
            if bCheckForUpdate(sCur, rInfo, sErr) then
                TThread.Queue(nil,
                    procedure
                    begin
                        if not bGMainClosing then
                            UpdateFound(rInfo, False);
                    end);
        end).Start;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.CheckUpdatesNow
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Controllare subito gli aggiornamenti (pulsante "Controlla aggiornamenti" del Setup).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: la richiesta e' breve e viene fatta direttamente; se non
//** riesce mostra l'errore, altrimenti passa il risultato a UpdateFound, che
//** risponde anche quando non ci sono novita'.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.CheckUpdatesNow;
var
    rInfo: TUpdateInfo;
    sErr: string;
begin
    if bCheckForUpdate(sAppVersion, rInfo, sErr) then
        UpdateFound(rInfo, True)
    else
        HoloMessage(sTr('update.checkfail.title', 'Controllo aggiornamenti'),
            Format(sTr('update.checkfail.text', 'Impossibile controllare gli aggiornamenti:' + sLineBreak +
            '%s'), [sErr]), rFColors);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.UpdateFound
//** Parametri di ingresso: rAInfo: TUpdateInfo; bAManual: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Proporre l'aggiornamento se la release trovata e' piu' recente della versione in uso.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: senza novita' risponde solo al controllo manuale. Il
//** controllo automatico non disturba mentre il Setup e' aperto o il servizio
//** OBS e' attivo (si ripropone al prossimo avvio). Chiede conferma con la
//** finestra delle novita' (bAskUpdate: Aggiorna / Piu' tardi) e con Aggiorna
//** passa a InstallUpdate.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.UpdateFound(const rAInfo: TUpdateInfo; bAManual: Boolean);
var
    sCur: string;
begin
    sCur := sAppVersion;
    if not bUpdateAvailable(rAInfo, sCur) then
    begin
        if bAManual then
            HoloMessage(sTr('update.none.title', 'Nessun aggiornamento'),
                Format(sTr('update.none.text', 'Stai gia'' usando la versione piu'' recente di HoloInput ' +
                '(%s).'), [sCur]), rFColors);
        Exit;
    end;
    if not bAManual and (bFSetupOpen or bFObsActive) then
        Exit;
    if bAskUpdate(rAInfo, sCur, rFColors) then
        InstallUpdate(rAInfo);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.InstallUpdate
//** Parametri di ingresso: rAInfo: TUpdateInfo
//** Parametri di uscita: nessuno
//** Scopo: Scaricare e installare l'aggiornamento (finestra con la barra di progresso), poi
//**        riavviare HoloInput.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: durante l'aggiornamento le hotkey e il Setup sono bloccati
//** (bFSetupOpen). Se l'installazione riesce ferma il servizio OBS, avvia il
//** nuovo exe (che aspetta la chiusura di questo) e chiude l'applicazione. Se
//** non riesce mostra l'errore e propone di aprire la pagina della release per
//** scaricare la nuova versione a mano; se l'utente annulla non mostra nulla.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.InstallUpdate(const rAInfo: TUpdateInfo);
var
    bInstalled: Boolean;
    sErr: string;
begin
    bFSetupOpen := True;
    try
        bInstalled := bRunUpdate(rAInfo, rFColors, sErr);
    finally
        bFSetupOpen := False;
    end;
    if bInstalled then
    begin
        if bFObsActive then
            StopObs;
        if bRestartAfterUpdate then
        begin
            bGMainClosing := True;
            Close;
        end
        else
            HoloMessage(sTr('update.fail.title', 'Aggiornamento non riuscito'),
                sTr('update.restart.text', 'L''aggiornamento e'' stato installato: chiudi e riapri ' +
                'HoloInput per usare la nuova versione.'), rFColors);
        Exit;
    end;
    if (sErr <> '') and bHoloConfirm(sTr('update.fail.title', 'Aggiornamento non riuscito'),
        Format(sTr('update.fail.text', '%s' + sLineBreak + sLineBreak + 'Puoi scaricare la nuova versione ' +
        'a mano dalla pagina della release.'), [sErr]), rFColors, sTr('update.fail.open', 'Apri la pagina'),
        sTr('update.fail.close', 'Chiudi')) then
        OpenUrl(rAInfo.sPageUrl);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.SetupObsFpsChange
//** Parametri di ingresso: oSender: TObject; iAFps: Integer
//** Parametri di uscita: nessuno
//** Scopo: Fermare e riavviare subito il servizio OBS con i nuovi fotogrammi al secondo scelti nel Setup.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: chiamata dal Setup (ancora aperto) quando si cambiano gli FPS
//** con il servizio attivo: salva il nuovo valore nel .ini, ferma e riavvia il
//** servizio (OBS si ricollega da solo) e aggiorna lo stato mostrato nella pagina
//** OBS del Setup. I fotogrammi ripartono alla chiusura del Setup, come sempre.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.SetupObsFpsChange(oSender: TObject; iAFps: Integer);
begin
    if not bFObsActive or (oFConfig.iObsFps = iAFps) then
        Exit;
    oFConfig.iObsFps := iAFps;
    SaveConfig;
    StopObs;
    bStartObs;
    if oSender is TfrmSetup then
        TfrmSetup(oSender).SetObsState(bFObsActive, sObsStatusText);
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
    bFObsActive := False;
    oFWeb.Stop;
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
//** schermo. rFFormOrigin non cambia, quindi i fotogrammi usano sempre le
//** posizioni dei widget sullo schermo principale. I diversi modi servono a
//** verificare quale continua a disegnare i widget (vedi CaptureObsFrame).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.ApplyObsHiding;
var
    rMon: TMonitorDesc;
begin
    if (oFConfig.iObsHideMode = OBS_HIDE_MONITOR) and bFindMonitor(oFConfig.sObsMonitor, rMon) and
        not rMon.bPrimary then
    begin
        MoveToMonitor(rMon);
        Show;
        MoveToMonitor(rMon);
        ApplyWindowStyles;
    end
    else if oFConfig.iObsHideMode <> OBS_HIDE_WINDOW then
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
//** Parametri di ingresso: rAMonitor: TMonitorDesc
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
procedure TfrmMain.MoveToMonitor(const rAMonitor: TMonitorDesc);
var
    hWindow: HWND;
    rWindowRect, rPrimaryRect, rMonitorRect: TRect;
    iPosX, iPosY: Integer;
begin
    if Handle = nil then
        Exit;
    hWindow := FmxHandleToHWND(Handle);
    if (hWindow = 0) or not GetWindowRect(hWindow, rWindowRect) then
        Exit;
    rPrimaryRect := rPrimaryMonitorRect;
    rMonitorRect := rAMonitor.rBounds;
    if rMonitorRect.CenterPoint.X < rPrimaryRect.CenterPoint.X then
        iPosX := rMonitorRect.Right - rWindowRect.Width
    else
        iPosX := rMonitorRect.Left;
    if rMonitorRect.CenterPoint.Y < rPrimaryRect.CenterPoint.Y then
        iPosY := rMonitorRect.Bottom - rWindowRect.Height
    else
        iPosY := rMonitorRect.Top;
    SetWindowPos(hWindow, 0, iPosX, iPosY, 0, 0, SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.CaptureObsFrame
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Preparare un fotogramma dell'overlay per OBS (dal ciclo principale, OBS_FPS volte al
//**        secondo).
//** Data Ultima Modifica: 06/11/2026
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
//**    cattura e composizione (tempo in iFObsMs).
//** Le fotografie vengono fatte prima di aprire la scena della bitmap finale
//** (una scena alla volta). Gli errori finiscono nello stato del servizio.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.CaptureObsFrame;
var
    eDevice: TDeviceKind;
    aShots: array[TDeviceKind] of TBitmap;
    aRects: array[TDeviceKind] of TRectF;
    oFrame: TBitmap;
    oWidget: TDeviceWidget;
    dScaleX, dScaleY, dScreenWidth, dScreenHeight: Single;
    rUnion, rRect: TRectF;
    rCrop: TRect;
    oData: TBitmapData;
    aPix: TBytes;
    iRow, iRowLen: Integer;
    bBgr, bAny: Boolean;
    rWatch: TStopwatch;
begin
    if not bFObsActive or bFSetupOpen then
        Exit;
    rWatch := TStopwatch.StartNew;
    // scala: dalla dimensione del monitor principale in coordinate FMX alla risoluzione del servizio
    dScreenWidth := Screen.Size.Width;
    dScreenHeight := Screen.Size.Height;
    if (dScreenWidth < 1) or (dScreenHeight < 1) then
        Exit;
    dScaleX := oFConfig.iObsWidth / dScreenWidth;
    dScaleY := oFConfig.iObsHeight / dScreenHeight;

    // rettangolo di ogni widget visibile nella pagina e area che li contiene tutti
    bAny := False;
    rUnion := RectF(0, 0, 0, 0);
    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        aShots[eDevice] := nil;
        aRects[eDevice] := RectF(0, 0, 0, 0);
        // i widget nascosti da "nascondi i widget inattivi" non entrano nel fotogramma
        if aFWidgets[eDevice].Visible and (aFWidgets[eDevice].dShowAlpha > 0.01) then
        begin
            oWidget := aFWidgets[eDevice];
            aRects[eDevice] := RectF((rFFormOrigin.X + oWidget.Position.X) * dScaleX, (rFFormOrigin.Y
                + oWidget.Position.Y) * dScaleY,
                (rFFormOrigin.X + oWidget.Position.X + oWidget.Width) * dScaleX, (rFFormOrigin.Y + oWidget.Position.Y + oWidget.Height) * dScaleY);
            if bAny then
                rUnion := TRectF.Union(rUnion, aRects[eDevice])
            else
                rUnion := aRects[eDevice];
            bAny := True;
        end;
    end;
    rCrop := Rect(0, 0, 0, 0);
    if bAny then
        rCrop := TRect.Intersect(Rect(Floor(rUnion.Left), Floor(rUnion.Top), Ceil(rUnion.Right),
            Ceil(rUnion.Bottom)),
            Rect(0, 0, oFConfig.iObsWidth, oFConfig.iObsHeight));
    if rCrop.IsEmpty then
    begin
        // nessun widget nella pagina: OBS mostra la pagina vuota
        oFWeb.SubmitFrame(nil, Rect(0, 0, 0, 0), True);
        Inc(iFObsFrames);
        Inc(iFObsFpsCount);
        Exit;
    end;

    oFrame := nil;
    try
        try
            for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
                if aFWidgets[eDevice].Visible and (aFWidgets[eDevice].dShowAlpha > 0.01) then
                    aShots[eDevice] := aFWidgets[eDevice].MakeScreenshot;

            oFrame := TBitmap.Create(rCrop.Width, rCrop.Height);
            if oFrame.Canvas.BeginScene then
            try
                oFrame.Canvas.Clear(TAlphaColors.Null);
                for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
                    if aShots[eDevice] <> nil then
                    begin
                        rRect := aRects[eDevice];
                        rRect.Offset(-rCrop.Left, -rCrop.Top);
                        oFrame.Canvas.DrawBitmap(aShots[eDevice], RectF(0, 0, aShots[eDevice].Width,
                            aShots[eDevice].Height), rRect,
                            oFConfig.dOpacity * aFWidgets[eDevice].dShowAlpha, False);
                    end;
            finally
                oFrame.Canvas.EndScene;
            end;

            // copia dei pixel (righe consecutive) per il thread di codifica
            aPix := nil;
            bBgr := True;
            if oFrame.Map(TMapAccess.Read, oData) then
            try
                bBgr := oData.PixelFormat <> TPixelFormat.RGBA;
                iRowLen := oData.Width * 4;
                SetLength(aPix, iRowLen * oData.Height);
                for iRow := 0 to oData.Height - 1 do
                    Move(PByte(oData.GetScanline(iRow))^, aPix[iRow * iRowLen], iRowLen);
            finally
                oFrame.Unmap(oData);
            end;
            if aPix <> nil then
            begin
                oFWeb.SubmitFrame(aPix, rCrop, bBgr);
                Inc(iFObsFrames);
                Inc(iFObsFpsCount);
            end;
            iFObsMs := rWatch.ElapsedMilliseconds;
            sFObsError := '';
        except
            on oError: Exception do
                sFObsError := oError.Message;
        end;
    finally
        oFrame.Free;
        for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
            aShots[eDevice].Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmMain.sObsStatusText
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
function TfrmMain.sObsStatusText: string;
var
    sMode: string;
    rMon: TMonitorDesc;
begin
    if not bFObsActive then
        Exit(sTr('obs.status.stopped', 'Servizio fermo.'));
    case oFConfig.iObsHideMode of
        OBS_HIDE_OFFSCREEN:
            sMode := sTr('setup.obs.hide.offscreen', 'Sposta la finestra fuori dallo schermo');
        OBS_HIDE_MONITOR:
            if bFindMonitor(oFConfig.sObsMonitor, rMon) and not rMon.bPrimary then
                sMode := Format(sTr('obs.status.monitor', 'finestra su %s'), [sMonitorText(rMon)])
            else
                sMode := sTr('obs.status.nomonitor', 'monitor scelto non collegato: finestra fuori dallo schermo');
    else
        sMode := sTr('setup.obs.hide.window', 'Nascondi la finestra');
    end;
    Result := Format(sTr('obs.status.running',
        'ATTIVO su %s  ' + #$00B7 + '  %d x %d  ' + #$00B7 + '  %d fps  ' + #$00B7 + '  %s'),
        [oFWeb.sUrl, oFConfig.iObsWidth, oFConfig.iObsHeight, oFConfig.iObsFps, sMode]) + sLineBreak +
        Format(sTr('obs.status.stream',
        'Fotogrammi preparati: %d (%d al secondo)  ' + #$00B7 + '  inviati a OBS: %d  ' + #$00B7 +
        '  connessioni: %d  ' + #$00B7 + '  cattura %d ms, codifica %d ms'),
        [iFObsFrames, iFObsFpsValue, oFWeb.iFramesSent, oFWeb.iClients, iFObsMs, oFWeb.iEncodeMs])
            + sLineBreak;
    if sFObsError <> '' then
        Result := Result + Format(sTr('obs.status.error', 'ERRORE: %s'), [sFObsError])
    else if oFWeb.iFramesEncoded > 0 then
    begin
        Result := Result + Format(sTr('obs.status.visible', 'Ultimo fotogramma: %d pixel visibili'),
            [oFWeb.iVisiblePixels]);
        if oFWeb.iVisiblePixels > 0 then
            Result := Result + sTr('obs.status.ok', '  ' + #$2192 + '  widget catturati con la finestra occultata.')
        else
            Result := Result + sTr('obs.status.empty',
                '  ' + #$2192 + '  ATTENZIONE: fotogramma vuoto, provare un altro modo di occultamento.');
    end;
    if oFWeb.iClients = 0 then
        Result := Result + sTr('obs.status.noclient', '  ' + #$00B7 + '  OBS non collegato');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.BtnSetupClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Aprire la finestra di Setup dal pulsante della barra comandi (in coda, fuori dal click).
//** Data Ultima Modifica: 30/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.BtnSetupClick(oSender: TObject);
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
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Bloccare/sbloccare dalla barra comandi.
//** Data Ultima Modifica: 30/09/2026
//***********************************************************************************************************
//** Funzionamento: l'azione e' accodata, cosi' il cambio di dimensioni e di
//** stile della finestra avviene dopo che il click e' stato completato.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.BtnLockClick(oSender: TObject);
begin
    TThread.ForceQueue(nil,
        procedure
        begin
            if not bFSetupOpen then
                SetLocked(not bFLocked);
        end);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmMain.BtnExitClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Uscire dall'applicazione.
//** Data Ultima Modifica: 30/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmMain.BtnExitClick(oSender: TObject);
begin
    Close;
end;

end.
