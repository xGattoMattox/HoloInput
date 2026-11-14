//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Config
//** Scopo: Configurazione dell'applicazione e persistenza nel file .ini.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: il file si chiama come l'eseguibile (HoloInput.ini) e si trova nella stessa
//** cartella; viene letto all'avvio se esiste e scritto dal Setup.
//** Contiene anche i nomi tradotti di tipologie e layout (sKindText, sLayoutText): i vettori
//** KindCaption e LayoutCaption sono i testi predefiniti (italiano).
//** La sezione [OBS] contiene i parametri del servizio Browser Source per OBS
//** (porta, risoluzione della pagina, fotogrammi al secondo, avvio automatico, modo di
//** occultamento della finestra e,
//** per lo spostamento su un altro monitor, il nome del dispositivo scelto);
//** la risoluzione predefinita e' quella nativa del monitor principale, cosi'
//** i widget compaiono in OBS esattamente dove sono stati posizionati.
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.Config;

interface

uses
    System.SysUtils, System.Classes, System.IniFiles, System.Math;

type
    /// Disposizione dei widget sullo schermo (monitor principale, area di lavoro):
    ///   lmBottom / lmTop  : in fila orizzontale, in basso / in alto, centrati in orizzontale
    ///   lmRight / lmLeft  : in colonna, a destra / a sinistra, centrati in verticale
    ///   lmCustom          : posizioni libere (X/Y di ogni widget); si attiva da
    ///                       solo quando si trascina un widget.
    TLayoutMode = (lmBottom, lmTop, lmRight, lmLeft, lmCustom);

    /// Tipologie di widget. L'ordine e' anche l'ordine di disposizione automatica
    /// (da sinistra a destra in orizzontale, dall'alto in basso in verticale).
    TDeviceKind = (dkBoxLeft, dkThrLeft, dkJoyLeft, dkKeyboard, dkMouse, dkGamepad, dkJoyRight, dkThrRight,
        dkBoxRight);

    /// Aspetto dei widget:
    ///   wsPanel      : pannello con sfondo, cornice, titolo e stato del dispositivo;
    ///   wsDeviceOnly : solo il dispositivo 3D su sfondo completamente trasparente
    ///                  (cornice e titolo compaiono solo con il layout sbloccato,
    ///                  lo stato solo se il dispositivo non e' collegato).
    TWidgetStyle = (wsPanel, wsDeviceOnly);

const
    LayoutCaption: array[TLayoutMode] of string = (
        'Orizzontale (Basso)', 'Orizzontale (Alto)', 'Verticale (Destra)',
        'Verticale (Sinistra)', 'Personalizzato');
    LayoutIniText: array[TLayoutMode] of string = (
        'OrizzontaleBasso', 'OrizzontaleAlto', 'VerticaleDestra', 'VerticaleSinistra',
        'Personalizzato');

    WidgetStyleIniText: array[TWidgetStyle] of string = ('Pannello', 'SoloDispositivo');

    KindIniKey: array[TDeviceKind] of string = (
        'PulsantieraSX', 'ManettaSX', 'JoystickSX', 'Tastiera', 'Mouse', 'Gamepad', 'JoystickDX',
        'ManettaDX', 'PulsantieraDX');

    KindCaption: array[TDeviceKind] of string = (
        'PULSANTIERA SX', 'MANETTA SX', 'JOYSTICK SX', 'TASTIERA', 'MOUSE', 'GAMEPAD', 'JOYSTICK DX',
        'MANETTA DX', 'PULSANTIERA DX');

    /// ampiezza totale del movimento dei joystick (gradi): 60 = da -30 a +30
    JOY_RANGE_MIN = 0;
    JOY_RANGE_MAX = 180;
    DEF_RANGE_X = 36;    // inclinazione sinistra/destra (rollio): +/-18
    DEF_RANGE_Y = 36;    // inclinazione avanti/indietro (beccheggio): +/-18
    DEF_RANGE_Z = 50;    // rotazione dell'impugnatura (twist): +/-25
    /// manette (throttle): iRangeX = leva, iRangeY / iRangeZ = mini-stick (gradi totali)
    DEF_THR_LEVER = 60;  // leva avanti / indietro: +/-30
    DEF_THR_MINI = 40;   // mini-stick: +/-20 per asse

    /// nascondi automaticamente i widget inattivi: secondi senza input prima di nasconderli
    AUTOHIDE_MIN = 1;
    AUTOHIDE_MAX = 600;
    DEF_AUTOHIDE_SECS = 5;

    /// servizio Browser Source per OBS
    OBS_PORT_MIN = 1024;
    OBS_PORT_MAX = 65535;
    OBS_SIZE_MIN = 320;
    OBS_SIZE_MAX = 7680;
    OBS_HIDE_WINDOW = 0;     // occultamento: finestra nascosta
    OBS_HIDE_OFFSCREEN = 1;  // occultamento: finestra spostata fuori dallo schermo
    OBS_FPS_MIN = 5;
    OBS_FPS_MAX = 60;
    OBS_HIDE_MONITOR = 2;    // occultamento: finestra spostata su un altro monitor (sObsMonitor)

type
    /// Impostazioni di un singolo widget/dispositivo.
    TWidgetConfig = record
        bVisible: Boolean;
        sModelId: string;          // id del modello 3D (vedi Holo.Models)
        bAbsolute: Boolean;        // True = usa X/Y (layout Personalizzato), False = calcolata
        iX, iY, iW, iH: Integer;      // posizione sullo schermo (anche quella calcolata) e dimensioni
        iDeviceIndex: Integer;     // id joystick WinMM (0..15) o slot XInput (0..3)
        iAxisX, iAxisY, iAxisZ: Integer;        // indici assi joystick (0=X 1=Y 2=Z 3=R 4=U 5=V)
        bInvertX, bInvertY, bInvertZ: Boolean;  // inversione assi
        iRangeX, iRangeY, iRangeZ: Integer;     // joystick: ampiezza totale del movimento (gradi)
        iButtonOffset: Integer;    // pulsantiere: indice del primo pulsante usato
        dTilt, dYaw: Single;        // correzione della vista (gradi aggiunti al default del modello)
        dZoom: Single;             // moltiplicatore di zoom (1 = auto-fit)
        dPanY: Single;             // spostamento verticale della vista (frazione dell'altezza visibile)
    end;

    TAppConfig = class
    public
        eLayout: TLayoutMode;
        sSkinId: string;
        iMargin: Integer;            // distanza dei widget dal bordo dello schermo
        iSpacing: Integer;           // spazio tra i widget
        dOpacity: Single;            // opacita' globale dell'overlay (0.2..1)
        bAnimations: Boolean;        // anelli rotanti, scanline, sfarfallio olografico
        eWidgetStyle: TWidgetStyle;  // pannello completo / solo dispositivo (sfondo trasparente)
        bBaseEffects: Boolean;       // effetti di base dei widget: anelli del proiettore e scanline
        bAutoHide: Boolean;          // nasconde i widget dei dispositivi inattivi (da bloccato)
        iAutoHideSecs: Integer;      // secondi senza input prima di nascondere un widget
        bCheckUpdates: Boolean;      // all'avvio controlla su GitHub se c'e' una nuova versione
        bShowLegends: Boolean;       // scritte 3D sui tasti
        bStayOnTop: Boolean;
        bStartLocked: Boolean;       // avvio in modalita' "bloccata" (click-through)
        bStreamerMode: Boolean;      // nasconde i pulsanti della barra (resta l'etichetta)
        bPrivacyMode: Boolean;       // nasconde sempre il widget della tastiera
        bDisclaimerAccepted: Boolean; // avviso del primo avvio gia' accettato
        iMouseRange: Integer;        // count del mouse per percorrere tutto il tappetino
        sLanguage: string;           // lingua dell'interfaccia: file LANG\<Language>.ini (vedi Holo.Lang)
        iObsPort: Integer;           // OBS: porta del servizio Browser Source (http://127.0.0.1:porta/)
        iObsWidth, iObsHeight: Integer; // OBS: risoluzione della pagina (default: nativa del monitor)
        iObsHideMode: Integer;       // OBS: OBS_HIDE_WINDOW / OBS_HIDE_OFFSCREEN / OBS_HIDE_MONITOR
        iObsFps: Integer;            // OBS: fotogrammi al secondo inviati (15 / 30 / 60)
        bObsAutoStart: Boolean;      // OBS: avvia il servizio all'avvio di HoloInput
        sObsMonitor: string;         // OBS: monitor di destinazione (es. \\.\DISPLAY2) per OBS_HIDE_MONITOR
        aWidgets: array[TDeviceKind] of TWidgetConfig;
        constructor Create;
        procedure SetDefaults;
        procedure Assign(oASource: TAppConfig);
        procedure LoadFromFile(const sAFileName: string);
        procedure SaveToFile(const sAFileName: string);
        class function sDefaultFileName: string;
        /// Imposta il layout; con lmCustom tutti i widget usano le loro X/Y.
        procedure SetLayout(eAMode: TLayoutMode);
        /// Ripristina skin (RSI), stile dei widget (pannello con effetti di base),
        /// disposizione e misure: layout Orizzontale (Basso),
        /// margine, spaziatura e dimensioni predefinite di tutti i widget, e
        /// la vista predefinita dei modelli (annulla rotazioni e zoom fatti con il mouse).
        procedure ResetLayoutDefaults;
    end;

const
    /// Spostamento verticale massimo della vista di un widget (Shift + tasto destro),
    /// in frazioni dell'altezza visibile.
    VIEW_PAN_LIMIT = 0.45;

function sFloatToIni(dAValue: Single): string;
function dIniToFloat(const sAText: string; dADefault: Single): Single;
function sKindText(eAKind: TDeviceKind): string;
function sLayoutText(eAMode: TLayoutMode): string;

implementation

uses
    Holo.Lang, Holo.WebOverlay;

const
    /// Dimensioni predefinite dei widget (pixel).
    DefWidgetW: array[TDeviceKind] of Integer = (240, 230, 230, 560, 240, 300, 230, 230, 240);
    DefWidgetH: array[TDeviceKind] of Integer = (230, 300, 300, 230, 230, 230, 300, 300, 230);
    DefLayout = lmBottom;
    DefSkin = 'rsi';     // skin predefinita (RSI)
    DefWidgetStyle = wsPanel;
    DefMargin = 20;
    DefSpacing = 10;

var
    rGIniFormat: TFormatSettings;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sFloatToIni
//** Parametri di ingresso: dAValue: Single
//** Parametri di uscita: Result: string
//** Scopo: Scrivere un numero nel .ini indipendentemente dalle impostazioni internazionali (sempre
//**        con il punto decimale).
//** Data Ultima Modifica: 16/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function sFloatToIni(dAValue: Single): string;
begin
    Result := FormatFloat('0.###', dAValue, rGIniFormat);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: dIniToFloat
//** Parametri di ingresso: sAText: string; dADefault: Single
//** Parametri di uscita: Result: Single
//** Scopo: Leggere un numero scritto con sFloatToIni; se non valido usa il default.
//** Data Ultima Modifica: 16/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function dIniToFloat(const sAText: string; dADefault: Single): Single;
begin
    Result := StrToFloatDef(Trim(sAText), dADefault, rGIniFormat);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sKindText
//** Parametri di ingresso: eAKind: TDeviceKind
//** Parametri di uscita: Result: string
//** Scopo: Nome della tipologia di widget nella lingua corrente (chiave kind.<chiave .ini>).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function sKindText(eAKind: TDeviceKind): string;
begin
    Result := sTr('kind.' + LowerCase(KindIniKey[eAKind]), KindCaption[eAKind]);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sLayoutText
//** Parametri di ingresso: eAMode: TLayoutMode
//** Parametri di uscita: Result: string
//** Scopo: Nome del layout nella lingua corrente (chiave layout.<valore .ini>).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function sLayoutText(eAMode: TLayoutMode): string;
begin
    Result := sTr('layout.' + LowerCase(LayoutIniText[eAMode]), LayoutCaption[eAMode]);
end;

//** TAppConfig *********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TAppConfig.Create
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare la configurazione gia' popolata con i valori di default.
//** Data Ultima Modifica: 16/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
constructor TAppConfig.Create;
begin
    inherited Create;
    SetDefaults;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TAppConfig.sDefaultFileName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Percorso del file .ini (stessa cartella e nome dell'eseguibile).
//** Data Ultima Modifica: 16/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TAppConfig.sDefaultFileName: string;
begin
    Result := ChangeFileExt(ParamStr(0), '.ini');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TAppConfig.SetDefaults
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Riportare tutte le impostazioni ai valori di fabbrica.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: imposta i parametri generali (compresi quelli del
//** servizio OBS, con la risoluzione nativa del monitor) e, per ogni
//** tipologia, modello, dimensioni, dispositivo e ampiezza del movimento
//** (joystick) predefiniti. I joystick predefiniti sono Virpil, con assi
//** "0,1,2" (twist sull'asse Z); le manette (nascoste) hanno la leva sull'asse
//** Z e il mini-stick su X e Y ("2,0,1"), con le ampiezze delle manette.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TAppConfig.SetDefaults;
const
    DefModel: array[TDeviceKind] of string = (
        'btnsx.panel', 'thrsx.generic', 'joysx.virpilobj', 'kbd.iso100', 'mouse.gaming', 'pad.xboxobj',
        'joydx.virpilobj', 'thrdx.generic', 'btndx.grid16');
    DefVisible: array[TDeviceKind] of Boolean = (False, False, True, True, True, False, True, False, False);
    DefDevice: array[TDeviceKind] of Integer = (3, 4, 1, 0, 0, 0, 0, 5, 2);
var
    eDevice: TDeviceKind;
begin
    eLayout := DefLayout;
    sSkinId := DefSkin;
    iMargin := DefMargin;
    iSpacing := DefSpacing;
    dOpacity := 0.95;
    bAnimations := True;
    eWidgetStyle := DefWidgetStyle;
    bBaseEffects := True;
    bAutoHide := False;
    iAutoHideSecs := DEF_AUTOHIDE_SECS;
    bCheckUpdates := True;
    bShowLegends := True;
    bStayOnTop := True;
    bStartLocked := True;
    bStreamerMode := False;
    bPrivacyMode := False;
    bDisclaimerAccepted := False;
    iMouseRange := 3000;
    sLanguage := DEF_LANGUAGE;
    iObsPort := OBS_DEF_PORT;
    iObsWidth := rNativeScreenSize.cx;
    iObsHeight := rNativeScreenSize.cy;
    iObsHideMode := OBS_HIDE_WINDOW;
    sObsMonitor := '';
    iObsFps := OBS_DEF_FPS;
    bObsAutoStart := False;
    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        aWidgets[eDevice] := Default(TWidgetConfig);
        aWidgets[eDevice].bVisible := DefVisible[eDevice];
        aWidgets[eDevice].sModelId := DefModel[eDevice];
        aWidgets[eDevice].bAbsolute := False;
        aWidgets[eDevice].iX := 0;
        aWidgets[eDevice].iY := 0;
        aWidgets[eDevice].iW := DefWidgetW[eDevice];
        aWidgets[eDevice].iH := DefWidgetH[eDevice];
        aWidgets[eDevice].iDeviceIndex := DefDevice[eDevice];
        aWidgets[eDevice].iAxisX := 0;
        aWidgets[eDevice].iAxisY := 1;
        aWidgets[eDevice].iAxisZ := 3;   // R = twist su quasi tutti gli stick
        // i modelli predefiniti dei joystick sono Virpil: twist sull'asse Z (vedi sDefaultAxes)
        if eDevice in [dkJoyLeft, dkJoyRight] then
            aWidgets[eDevice].iAxisZ := 2;
        aWidgets[eDevice].iRangeX := DEF_RANGE_X;
        aWidgets[eDevice].iRangeY := DEF_RANGE_Y;
        aWidgets[eDevice].iRangeZ := DEF_RANGE_Z;
        aWidgets[eDevice].iButtonOffset := 0;
        aWidgets[eDevice].dZoom := 1;
        aWidgets[eDevice].dPanY := 0;
        // manette: leva sull'asse Z, mini-stick su X e Y (vedi Thr.Base)
        if eDevice in [dkThrLeft, dkThrRight] then
        begin
            aWidgets[eDevice].iAxisX := 2;
            aWidgets[eDevice].iAxisY := 0;
            aWidgets[eDevice].iAxisZ := 1;
            aWidgets[eDevice].iRangeX := DEF_THR_LEVER;
            aWidgets[eDevice].iRangeY := DEF_THR_MINI;
            aWidgets[eDevice].iRangeZ := DEF_THR_MINI;
        end;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TAppConfig.Assign
//** Parametri di ingresso: oASource: TAppConfig
//** Parametri di uscita: nessuno
//** Scopo: Copiare tutte le impostazioni da un'altra istanza (usato dal Setup per lavorare su una
//**        copia annullabile).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TAppConfig.Assign(oASource: TAppConfig);
var
    eDevice: TDeviceKind;
begin
    eLayout := oASource.eLayout;
    sSkinId := oASource.sSkinId;
    iMargin := oASource.iMargin;
    iSpacing := oASource.iSpacing;
    dOpacity := oASource.dOpacity;
    bAnimations := oASource.bAnimations;
    eWidgetStyle := oASource.eWidgetStyle;
    bBaseEffects := oASource.bBaseEffects;
    bAutoHide := oASource.bAutoHide;
    iAutoHideSecs := oASource.iAutoHideSecs;
    bCheckUpdates := oASource.bCheckUpdates;
    bShowLegends := oASource.bShowLegends;
    bStayOnTop := oASource.bStayOnTop;
    bStartLocked := oASource.bStartLocked;
    bStreamerMode := oASource.bStreamerMode;
    bPrivacyMode := oASource.bPrivacyMode;
    bDisclaimerAccepted := oASource.bDisclaimerAccepted;
    iMouseRange := oASource.iMouseRange;
    sLanguage := oASource.sLanguage;
    iObsPort := oASource.iObsPort;
    iObsWidth := oASource.iObsWidth;
    iObsHeight := oASource.iObsHeight;
    iObsHideMode := oASource.iObsHideMode;
    sObsMonitor := oASource.sObsMonitor;
    iObsFps := oASource.iObsFps;
    bObsAutoStart := oASource.bObsAutoStart;
    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
        aWidgets[eDevice] := oASource.aWidgets[eDevice];
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TAppConfig.SetLayout
//** Parametri di ingresso: eAMode: TLayoutMode
//** Parametri di uscita: nessuno
//** Scopo: Cambiare layout mantenendo coerente il flag Absolute dei widget.
//** Data Ultima Modifica: 21/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TAppConfig.SetLayout(eAMode: TLayoutMode);
var
    eDevice: TDeviceKind;
begin
    eLayout := eAMode;
    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
        aWidgets[eDevice].bAbsolute := eAMode = lmCustom;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TAppConfig.ResetLayoutDefaults
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Riportare skin, stile dei widget, disposizione, misure e vista dei modelli (rotazione e
//**        zoom) ai valori predefiniti, lasciando invariato tutto il resto (modelli, dispositivi,
//**        assi, opzioni).
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TAppConfig.ResetLayoutDefaults;
var
    eDevice: TDeviceKind;
begin
    sSkinId := DefSkin;
    eWidgetStyle := DefWidgetStyle;
    bBaseEffects := True;
    iMargin := DefMargin;
    iSpacing := DefSpacing;
    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        aWidgets[eDevice].iW := DefWidgetW[eDevice];
        aWidgets[eDevice].iH := DefWidgetH[eDevice];
        aWidgets[eDevice].iX := 0;
        aWidgets[eDevice].iY := 0;
        aWidgets[eDevice].dTilt := 0;
        aWidgets[eDevice].dYaw := 0;
        aWidgets[eDevice].dZoom := 1;
        aWidgets[eDevice].dPanY := 0;
    end;
    SetLayout(DefLayout);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TAppConfig.LoadFromFile
//** Parametri di ingresso: sAFileName: string
//** Parametri di uscita: nessuno
//** Scopo: Leggere la configurazione dal file .ini.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: ogni chiave mancante mantiene il valore attuale (default),
//** cosi' un .ini parziale o di una versione precedente resta valido.
//** I .ini delle versioni precedenti ("Orizzontale"/"Verticale" + origine)
//** diventano "Personalizzato" se c'erano widget spostati a mano, cosi'
//** l'overlay resta dov'era; altrimenti Orizzontale (Basso) / Verticale (Sinistra).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TAppConfig.LoadFromFile(const sAFileName: string);
var
    oIni: TMemIniFile;
    eDevice: TDeviceKind;
    sSection, sLayoutText: string;
    rWidget: TWidgetConfig;
    eMode: TLayoutMode;
    eStyle: TWidgetStyle;
    bFound, bLegacy, bAnyAbsolute: Boolean;
begin
    if not FileExists(sAFileName) then
        Exit;
    oIni := TMemIniFile.Create(sAFileName, TEncoding.UTF8);
    try
        sSection := 'Generale';
        sLayoutText := oIni.ReadString(sSection, 'Layout', '');
        bFound := False;
        bLegacy := False;
        for eMode := Low(TLayoutMode) to High(TLayoutMode) do
            if SameText(sLayoutText, LayoutIniText[eMode]) then
            begin
                eLayout := eMode;
                bFound := True;
            end;
        if not bFound then
            if SameText(sLayoutText, 'Verticale') then
            begin
                eLayout := lmLeft;
                bLegacy := True;
            end
            else if SameText(sLayoutText, 'Orizzontale') then
            begin
                eLayout := lmBottom;
                bLegacy := True;
            end;
        sSkinId := oIni.ReadString(sSection, 'Skin', sSkinId);
        iMargin := EnsureRange(oIni.ReadInteger(sSection, 'Margine', iMargin), 0, 500);
        iSpacing := EnsureRange(oIni.ReadInteger(sSection, 'Spaziatura', iSpacing), 0, 200);
        dOpacity := EnsureRange(dIniToFloat(oIni.ReadString(sSection, 'Opacita', ''), dOpacity), 0.2, 1);
        bAnimations := oIni.ReadBool(sSection, 'Animazioni', bAnimations);
        sLayoutText := oIni.ReadString(sSection, 'StileWidget', WidgetStyleIniText[eWidgetStyle]);
        for eStyle := Low(TWidgetStyle) to High(TWidgetStyle) do
            if SameText(sLayoutText, WidgetStyleIniText[eStyle]) then
                eWidgetStyle := eStyle;
        bBaseEffects := oIni.ReadBool(sSection, 'EffettiBase', bBaseEffects);
        bAutoHide := oIni.ReadBool(sSection, 'NascondiInattivi', bAutoHide);
        iAutoHideSecs := EnsureRange(oIni.ReadInteger(sSection, 'NascondiDopoSecondi', iAutoHideSecs),
            AUTOHIDE_MIN, AUTOHIDE_MAX);
        bCheckUpdates := oIni.ReadBool(sSection, 'ControllaAggiornamenti', bCheckUpdates);
        bShowLegends := oIni.ReadBool(sSection, 'LegendeTasti', bShowLegends);
        bStayOnTop := oIni.ReadBool(sSection, 'SempreInPrimoPiano', bStayOnTop);
        bStartLocked := oIni.ReadBool(sSection, 'AvvioBloccato', bStartLocked);
        bStreamerMode := oIni.ReadBool(sSection, 'ModalitaStreamer', bStreamerMode);
        bPrivacyMode := oIni.ReadBool(sSection, 'ModalitaPrivacy', bPrivacyMode);
        bDisclaimerAccepted := oIni.ReadBool(sSection, 'AvvisoAccettato', bDisclaimerAccepted);
        iMouseRange := EnsureRange(oIni.ReadInteger(sSection, 'MouseCorsa', iMouseRange), 200, 50000);
        sLanguage := LowerCase(Trim(oIni.ReadString(sSection, 'Lingua', sLanguage)));
        if not bIsSafeFileId(sLanguage) then
            sLanguage := DEF_LANGUAGE;

        sSection := 'OBS';
        iObsPort := EnsureRange(oIni.ReadInteger(sSection, 'Porta', iObsPort), OBS_PORT_MIN, OBS_PORT_MAX);
        iObsWidth := EnsureRange(oIni.ReadInteger(sSection, 'Larghezza', iObsWidth), OBS_SIZE_MIN,
            OBS_SIZE_MAX);
        iObsHeight := EnsureRange(oIni.ReadInteger(sSection, 'Altezza', iObsHeight), OBS_SIZE_MIN,
            OBS_SIZE_MAX);
        iObsHideMode := EnsureRange(oIni.ReadInteger(sSection, 'Occultamento', iObsHideMode),
            OBS_HIDE_WINDOW,
            OBS_HIDE_MONITOR);
        sObsMonitor := Trim(oIni.ReadString(sSection, 'Monitor', sObsMonitor));
        iObsFps := EnsureRange(oIni.ReadInteger(sSection, 'FPS', iObsFps), OBS_FPS_MIN, OBS_FPS_MAX);
        bObsAutoStart := oIni.ReadBool(sSection, 'AvvioAutomatico', bObsAutoStart);

        for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
        begin
            sSection := 'Widget.' + KindIniKey[eDevice];
            rWidget := aWidgets[eDevice];
            rWidget.bVisible := oIni.ReadBool(sSection, 'Visibile', rWidget.bVisible);
            rWidget.sModelId := oIni.ReadString(sSection, 'Modello', rWidget.sModelId);
            rWidget.bAbsolute := oIni.ReadBool(sSection, 'PosizioneAssoluta', rWidget.bAbsolute);
            rWidget.iX := oIni.ReadInteger(sSection, 'X', rWidget.iX);
            rWidget.iY := oIni.ReadInteger(sSection, 'Y', rWidget.iY);
            rWidget.iW := EnsureRange(oIni.ReadInteger(sSection, 'Larghezza', rWidget.iW), 80, 4000);
            rWidget.iH := EnsureRange(oIni.ReadInteger(sSection, 'Altezza', rWidget.iH), 80, 4000);
            rWidget.iDeviceIndex := EnsureRange(oIni.ReadInteger(sSection, 'Dispositivo',
                rWidget.iDeviceIndex), 0, 15);
            rWidget.iAxisX := EnsureRange(oIni.ReadInteger(sSection, 'AsseX', rWidget.iAxisX), 0, 5);
            rWidget.iAxisY := EnsureRange(oIni.ReadInteger(sSection, 'AsseY', rWidget.iAxisY), 0, 5);
            rWidget.iAxisZ := EnsureRange(oIni.ReadInteger(sSection, 'AsseZ', rWidget.iAxisZ), 0, 5);
            rWidget.bInvertX := oIni.ReadBool(sSection, 'InvertiX', rWidget.bInvertX);
            rWidget.bInvertY := oIni.ReadBool(sSection, 'InvertiY', rWidget.bInvertY);
            rWidget.bInvertZ := oIni.ReadBool(sSection, 'InvertiZ', rWidget.bInvertZ);
            rWidget.iRangeX := EnsureRange(oIni.ReadInteger(sSection, 'AmpiezzaX', rWidget.iRangeX),
                JOY_RANGE_MIN, JOY_RANGE_MAX);
            rWidget.iRangeY := EnsureRange(oIni.ReadInteger(sSection, 'AmpiezzaY', rWidget.iRangeY),
                JOY_RANGE_MIN, JOY_RANGE_MAX);
            rWidget.iRangeZ := EnsureRange(oIni.ReadInteger(sSection, 'AmpiezzaZ', rWidget.iRangeZ),
                JOY_RANGE_MIN, JOY_RANGE_MAX);
            rWidget.iButtonOffset := EnsureRange(oIni.ReadInteger(sSection, 'PrimoPulsante',
                rWidget.iButtonOffset), 0, 31);
            rWidget.dTilt := dIniToFloat(oIni.ReadString(sSection, 'VistaInclinazione', ''), rWidget.dTilt);
            rWidget.dYaw := dIniToFloat(oIni.ReadString(sSection, 'VistaRotazione', ''), rWidget.dYaw);
            rWidget.dZoom := EnsureRange(dIniToFloat(oIni.ReadString(sSection, 'VistaZoom', ''),
                rWidget.dZoom), 0.3, 3);
            rWidget.dPanY := EnsureRange(dIniToFloat(oIni.ReadString(sSection, 'VistaSpostamento', ''),
                rWidget.dPanY),
                -VIEW_PAN_LIMIT, VIEW_PAN_LIMIT);
            aWidgets[eDevice] := rWidget;
        end;
    finally
        oIni.Free;
    end;

    if bLegacy then
    begin
        bAnyAbsolute := False;
        for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
            if aWidgets[eDevice].bVisible and aWidgets[eDevice].bAbsolute then
                bAnyAbsolute := True;
        if bAnyAbsolute then
            eLayout := lmCustom;
    end;
    SetLayout(eLayout);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TAppConfig.SaveToFile
//** Parametri di ingresso: sAFileName: string
//** Parametri di uscita: nessuno
//** Scopo: Salvare la configurazione nel file .ini (UTF-8).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: scrive tutte le chiavi in memoria e poi su disco con UpdateFile.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TAppConfig.SaveToFile(const sAFileName: string);
var
    oIni: TMemIniFile;
    eDevice: TDeviceKind;
    sSection: string;
    rWidget: TWidgetConfig;
begin
    oIni := TMemIniFile.Create(sAFileName, TEncoding.UTF8);
    try
        sSection := 'Generale';
        oIni.WriteString(sSection, 'Layout', LayoutIniText[eLayout]);
        oIni.WriteString(sSection, 'Skin', sSkinId);
        oIni.WriteInteger(sSection, 'Margine', iMargin);
        oIni.DeleteKey(sSection, 'OrigineX');
        oIni.DeleteKey(sSection, 'OrigineY');
        oIni.WriteInteger(sSection, 'Spaziatura', iSpacing);
        oIni.WriteString(sSection, 'Opacita', sFloatToIni(dOpacity));
        oIni.WriteBool(sSection, 'Animazioni', bAnimations);
        oIni.WriteString(sSection, 'StileWidget', WidgetStyleIniText[eWidgetStyle]);
        oIni.WriteBool(sSection, 'EffettiBase', bBaseEffects);
        oIni.WriteBool(sSection, 'NascondiInattivi', bAutoHide);
        oIni.WriteInteger(sSection, 'NascondiDopoSecondi', iAutoHideSecs);
        oIni.WriteBool(sSection, 'ControllaAggiornamenti', bCheckUpdates);
        oIni.WriteBool(sSection, 'LegendeTasti', bShowLegends);
        oIni.WriteBool(sSection, 'SempreInPrimoPiano', bStayOnTop);
        oIni.WriteBool(sSection, 'AvvioBloccato', bStartLocked);
        oIni.WriteBool(sSection, 'ModalitaStreamer', bStreamerMode);
        oIni.WriteBool(sSection, 'ModalitaPrivacy', bPrivacyMode);
        oIni.WriteBool(sSection, 'AvvisoAccettato', bDisclaimerAccepted);
        oIni.WriteInteger(sSection, 'MouseCorsa', iMouseRange);
        oIni.WriteString(sSection, 'Lingua', sLanguage);

        sSection := 'OBS';
        oIni.WriteInteger(sSection, 'Porta', iObsPort);
        oIni.WriteInteger(sSection, 'Larghezza', iObsWidth);
        oIni.WriteInteger(sSection, 'Altezza', iObsHeight);
        oIni.WriteInteger(sSection, 'Occultamento', iObsHideMode);
        oIni.WriteString(sSection, 'Monitor', sObsMonitor);
        oIni.WriteInteger(sSection, 'FPS', iObsFps);
        oIni.WriteBool(sSection, 'AvvioAutomatico', bObsAutoStart);

        for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
        begin
            sSection := 'Widget.' + KindIniKey[eDevice];
            rWidget := aWidgets[eDevice];
            oIni.WriteBool(sSection, 'Visibile', rWidget.bVisible);
            oIni.WriteString(sSection, 'Modello', rWidget.sModelId);
            oIni.WriteBool(sSection, 'PosizioneAssoluta', rWidget.bAbsolute);
            oIni.WriteInteger(sSection, 'X', rWidget.iX);
            oIni.WriteInteger(sSection, 'Y', rWidget.iY);
            oIni.WriteInteger(sSection, 'Larghezza', rWidget.iW);
            oIni.WriteInteger(sSection, 'Altezza', rWidget.iH);
            oIni.WriteInteger(sSection, 'Dispositivo', rWidget.iDeviceIndex);
            oIni.WriteInteger(sSection, 'AsseX', rWidget.iAxisX);
            oIni.WriteInteger(sSection, 'AsseY', rWidget.iAxisY);
            oIni.WriteInteger(sSection, 'AsseZ', rWidget.iAxisZ);
            oIni.WriteBool(sSection, 'InvertiX', rWidget.bInvertX);
            oIni.WriteBool(sSection, 'InvertiY', rWidget.bInvertY);
            oIni.WriteBool(sSection, 'InvertiZ', rWidget.bInvertZ);
            oIni.WriteInteger(sSection, 'AmpiezzaX', rWidget.iRangeX);
            oIni.WriteInteger(sSection, 'AmpiezzaY', rWidget.iRangeY);
            oIni.WriteInteger(sSection, 'AmpiezzaZ', rWidget.iRangeZ);
            oIni.WriteInteger(sSection, 'PrimoPulsante', rWidget.iButtonOffset);
            oIni.WriteString(sSection, 'VistaInclinazione', sFloatToIni(rWidget.dTilt));
            oIni.WriteString(sSection, 'VistaRotazione', sFloatToIni(rWidget.dYaw));
            oIni.WriteString(sSection, 'VistaZoom', sFloatToIni(rWidget.dZoom));
            oIni.WriteString(sSection, 'VistaSpostamento', sFloatToIni(rWidget.dPanY));
        end;
        oIni.UpdateFile;
    finally
        oIni.Free;
    end;
end;

initialization
    rGIniFormat := TFormatSettings.Create;
    rGIniFormat.DecimalSeparator := '.';
    rGIniFormat.ThousandSeparator := #0;

end.
