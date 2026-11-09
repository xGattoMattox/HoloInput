//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Config
//** Scopo: Configurazione dell'applicazione e persistenza nel file .ini.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: il file si chiama come l'eseguibile (HoloInput.ini) e si trova nella stessa
//** cartella; viene letto all'avvio se esiste e scritto dal Setup.
//** Contiene anche i nomi tradotti di tipologie e layout (KindText, LayoutText): i vettori
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
    /// manette (throttle): RangeX = leva, RangeY / RangeZ = mini-stick (gradi totali)
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
    OBS_HIDE_MONITOR = 2;    // occultamento: finestra spostata su un altro monitor (ObsMonitor)

type
    /// Impostazioni di un singolo widget/dispositivo.
    TWidgetConfig = record
        Visible: Boolean;
        ModelId: string;          // id del modello 3D (vedi Holo.Models)
        Absolute: Boolean;        // True = usa X/Y (layout Personalizzato), False = calcolata
        X, Y, W, H: Integer;      // posizione sullo schermo (anche quella calcolata) e dimensioni
        DeviceIndex: Integer;     // id joystick WinMM (0..15) o slot XInput (0..3)
        AxisX, AxisY, AxisZ: Integer;        // indici assi joystick (0=X 1=Y 2=Z 3=R 4=U 5=V)
        InvertX, InvertY, InvertZ: Boolean;  // inversione assi
        RangeX, RangeY, RangeZ: Integer;     // joystick: ampiezza totale del movimento (gradi)
        ButtonOffset: Integer;    // pulsantiere: indice del primo pulsante usato
        Tilt, Yaw: Single;        // correzione della vista (gradi aggiunti al default del modello)
        Zoom: Single;             // moltiplicatore di zoom (1 = auto-fit)
        PanY: Single;             // spostamento verticale della vista (frazione dell'altezza visibile)
    end;

    TAppConfig = class
    public
        Layout: TLayoutMode;
        SkinId: string;
        Margin: Integer;            // distanza dei widget dal bordo dello schermo
        Spacing: Integer;           // spazio tra i widget
        Opacity: Single;            // opacita' globale dell'overlay (0.2..1)
        Animations: Boolean;        // anelli rotanti, scanline, sfarfallio olografico
        WidgetStyle: TWidgetStyle;  // pannello completo / solo dispositivo (sfondo trasparente)
        BaseEffects: Boolean;       // effetti di base dei widget: anelli del proiettore e scanline
        AutoHide: Boolean;          // nasconde i widget dei dispositivi inattivi (da bloccato)
        AutoHideSecs: Integer;      // secondi senza input prima di nascondere un widget
        CheckUpdates: Boolean;      // all'avvio controlla su GitHub se c'e' una nuova versione
        ShowLegends: Boolean;       // scritte 3D sui tasti
        StayOnTop: Boolean;
        StartLocked: Boolean;       // avvio in modalita' "bloccata" (click-through)
        StreamerMode: Boolean;      // nasconde i pulsanti della barra (resta l'etichetta)
        PrivacyMode: Boolean;       // nasconde sempre il widget della tastiera
        DisclaimerAccepted: Boolean; // avviso del primo avvio gia' accettato
        MouseRange: Integer;        // count del mouse per percorrere tutto il tappetino
        Language: string;           // lingua dell'interfaccia: file LANG\<Language>.ini (vedi Holo.Lang)
        ObsPort: Integer;           // OBS: porta del servizio Browser Source (http://127.0.0.1:porta/)
        ObsWidth, ObsHeight: Integer; // OBS: risoluzione della pagina (default: nativa del monitor)
        ObsHideMode: Integer;       // OBS: OBS_HIDE_WINDOW / OBS_HIDE_OFFSCREEN / OBS_HIDE_MONITOR
        ObsFps: Integer;            // OBS: fotogrammi al secondo inviati (15 / 30 / 60)
        ObsAutoStart: Boolean;      // OBS: avvia il servizio all'avvio di HoloInput
        ObsMonitor: string;         // OBS: monitor di destinazione (es. \\.\DISPLAY2) per OBS_HIDE_MONITOR
        Widgets: array[TDeviceKind] of TWidgetConfig;
        constructor Create;
        procedure SetDefaults;
        procedure Assign(ASource: TAppConfig);
        procedure LoadFromFile(const AFileName: string);
        procedure SaveToFile(const AFileName: string);
        class function DefaultFileName: string;
        /// Imposta il layout; con lmCustom tutti i widget usano le loro X/Y.
        procedure SetLayout(AMode: TLayoutMode);
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

function FloatToIni(AValue: Single): string;
function IniToFloat(const AText: string; ADefault: Single): Single;
function KindText(AKind: TDeviceKind): string;
function LayoutText(AMode: TLayoutMode): string;

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
    GIniFormat: TFormatSettings;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: FloatToIni
//** Parametri di ingresso: AValue: Single
//** Parametri di uscita: Result: string
//** Scopo: Scrivere un numero nel .ini indipendentemente dalle impostazioni internazionali (sempre
//**        con il punto decimale).
//** Data Ultima Modifica: 16/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function FloatToIni(AValue: Single): string;
begin
    Result := FormatFloat('0.###', AValue, GIniFormat);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: IniToFloat
//** Parametri di ingresso: AText: string; ADefault: Single
//** Parametri di uscita: Result: Single
//** Scopo: Leggere un numero scritto con FloatToIni; se non valido usa il default.
//** Data Ultima Modifica: 16/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function IniToFloat(const AText: string; ADefault: Single): Single;
begin
    Result := StrToFloatDef(Trim(AText), ADefault, GIniFormat);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: KindText
//** Parametri di ingresso: AKind: TDeviceKind
//** Parametri di uscita: Result: string
//** Scopo: Nome della tipologia di widget nella lingua corrente (chiave kind.<chiave .ini>).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function KindText(AKind: TDeviceKind): string;
begin
    Result := Tr('kind.' + LowerCase(KindIniKey[AKind]), KindCaption[AKind]);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: LayoutText
//** Parametri di ingresso: AMode: TLayoutMode
//** Parametri di uscita: Result: string
//** Scopo: Nome del layout nella lingua corrente (chiave layout.<valore .ini>).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function LayoutText(AMode: TLayoutMode): string;
begin
    Result := Tr('layout.' + LowerCase(LayoutIniText[AMode]), LayoutCaption[AMode]);
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
//** Nome funzione: TAppConfig.DefaultFileName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Percorso del file .ini (stessa cartella e nome dell'eseguibile).
//** Data Ultima Modifica: 16/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TAppConfig.DefaultFileName: string;
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
    K: TDeviceKind;
begin
    Layout := DefLayout;
    SkinId := DefSkin;
    Margin := DefMargin;
    Spacing := DefSpacing;
    Opacity := 0.95;
    Animations := True;
    WidgetStyle := DefWidgetStyle;
    BaseEffects := True;
    AutoHide := False;
    AutoHideSecs := DEF_AUTOHIDE_SECS;
    CheckUpdates := True;
    ShowLegends := True;
    StayOnTop := True;
    StartLocked := True;
    StreamerMode := False;
    PrivacyMode := False;
    DisclaimerAccepted := False;
    MouseRange := 3000;
    Language := DEF_LANGUAGE;
    ObsPort := OBS_DEF_PORT;
    ObsWidth := NativeScreenSize.cx;
    ObsHeight := NativeScreenSize.cy;
    ObsHideMode := OBS_HIDE_WINDOW;
    ObsMonitor := '';
    ObsFps := OBS_DEF_FPS;
    ObsAutoStart := False;
    for K := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        Widgets[K] := Default(TWidgetConfig);
        Widgets[K].Visible := DefVisible[K];
        Widgets[K].ModelId := DefModel[K];
        Widgets[K].Absolute := False;
        Widgets[K].X := 0;
        Widgets[K].Y := 0;
        Widgets[K].W := DefWidgetW[K];
        Widgets[K].H := DefWidgetH[K];
        Widgets[K].DeviceIndex := DefDevice[K];
        Widgets[K].AxisX := 0;
        Widgets[K].AxisY := 1;
        Widgets[K].AxisZ := 3;   // R = twist su quasi tutti gli stick
        // i modelli predefiniti dei joystick sono Virpil: twist sull'asse Z (vedi DefaultAxes)
        if K in [dkJoyLeft, dkJoyRight] then
            Widgets[K].AxisZ := 2;
        Widgets[K].RangeX := DEF_RANGE_X;
        Widgets[K].RangeY := DEF_RANGE_Y;
        Widgets[K].RangeZ := DEF_RANGE_Z;
        Widgets[K].ButtonOffset := 0;
        Widgets[K].Zoom := 1;
        Widgets[K].PanY := 0;
        // manette: leva sull'asse Z, mini-stick su X e Y (vedi Thr.Base)
        if K in [dkThrLeft, dkThrRight] then
        begin
            Widgets[K].AxisX := 2;
            Widgets[K].AxisY := 0;
            Widgets[K].AxisZ := 1;
            Widgets[K].RangeX := DEF_THR_LEVER;
            Widgets[K].RangeY := DEF_THR_MINI;
            Widgets[K].RangeZ := DEF_THR_MINI;
        end;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TAppConfig.Assign
//** Parametri di ingresso: ASource: TAppConfig
//** Parametri di uscita: nessuno
//** Scopo: Copiare tutte le impostazioni da un'altra istanza (usato dal Setup per lavorare su una
//**        copia annullabile).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TAppConfig.Assign(ASource: TAppConfig);
var
    K: TDeviceKind;
begin
    Layout := ASource.Layout;
    SkinId := ASource.SkinId;
    Margin := ASource.Margin;
    Spacing := ASource.Spacing;
    Opacity := ASource.Opacity;
    Animations := ASource.Animations;
    WidgetStyle := ASource.WidgetStyle;
    BaseEffects := ASource.BaseEffects;
    AutoHide := ASource.AutoHide;
    AutoHideSecs := ASource.AutoHideSecs;
    CheckUpdates := ASource.CheckUpdates;
    ShowLegends := ASource.ShowLegends;
    StayOnTop := ASource.StayOnTop;
    StartLocked := ASource.StartLocked;
    StreamerMode := ASource.StreamerMode;
    PrivacyMode := ASource.PrivacyMode;
    DisclaimerAccepted := ASource.DisclaimerAccepted;
    MouseRange := ASource.MouseRange;
    Language := ASource.Language;
    ObsPort := ASource.ObsPort;
    ObsWidth := ASource.ObsWidth;
    ObsHeight := ASource.ObsHeight;
    ObsHideMode := ASource.ObsHideMode;
    ObsMonitor := ASource.ObsMonitor;
    ObsFps := ASource.ObsFps;
    ObsAutoStart := ASource.ObsAutoStart;
    for K := Low(TDeviceKind) to High(TDeviceKind) do
        Widgets[K] := ASource.Widgets[K];
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TAppConfig.SetLayout
//** Parametri di ingresso: AMode: TLayoutMode
//** Parametri di uscita: nessuno
//** Scopo: Cambiare layout mantenendo coerente il flag Absolute dei widget.
//** Data Ultima Modifica: 21/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TAppConfig.SetLayout(AMode: TLayoutMode);
var
    K: TDeviceKind;
begin
    Layout := AMode;
    for K := Low(TDeviceKind) to High(TDeviceKind) do
        Widgets[K].Absolute := AMode = lmCustom;
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
    K: TDeviceKind;
begin
    SkinId := DefSkin;
    WidgetStyle := DefWidgetStyle;
    BaseEffects := True;
    Margin := DefMargin;
    Spacing := DefSpacing;
    for K := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        Widgets[K].W := DefWidgetW[K];
        Widgets[K].H := DefWidgetH[K];
        Widgets[K].X := 0;
        Widgets[K].Y := 0;
        Widgets[K].Tilt := 0;
        Widgets[K].Yaw := 0;
        Widgets[K].Zoom := 1;
        Widgets[K].PanY := 0;
    end;
    SetLayout(DefLayout);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TAppConfig.LoadFromFile
//** Parametri di ingresso: AFileName: string
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
procedure TAppConfig.LoadFromFile(const AFileName: string);
var
    Ini: TMemIniFile;
    K: TDeviceKind;
    S, LayoutText: string;
    W: TWidgetConfig;
    M: TLayoutMode;
    WS: TWidgetStyle;
    Found, Legacy, AnyAbsolute: Boolean;
begin
    if not FileExists(AFileName) then
        Exit;
    Ini := TMemIniFile.Create(AFileName, TEncoding.UTF8);
    try
        S := 'Generale';
        LayoutText := Ini.ReadString(S, 'Layout', '');
        Found := False;
        Legacy := False;
        for M := Low(TLayoutMode) to High(TLayoutMode) do
            if SameText(LayoutText, LayoutIniText[M]) then
            begin
                Layout := M;
                Found := True;
            end;
        if not Found then
            if SameText(LayoutText, 'Verticale') then
            begin
                Layout := lmLeft;
                Legacy := True;
            end
            else if SameText(LayoutText, 'Orizzontale') then
            begin
                Layout := lmBottom;
                Legacy := True;
            end;
        SkinId := Ini.ReadString(S, 'Skin', SkinId);
        Margin := EnsureRange(Ini.ReadInteger(S, 'Margine', Margin), 0, 500);
        Spacing := EnsureRange(Ini.ReadInteger(S, 'Spaziatura', Spacing), 0, 200);
        Opacity := EnsureRange(IniToFloat(Ini.ReadString(S, 'Opacita', ''), Opacity), 0.2, 1);
        Animations := Ini.ReadBool(S, 'Animazioni', Animations);
        LayoutText := Ini.ReadString(S, 'StileWidget', WidgetStyleIniText[WidgetStyle]);
        for WS := Low(TWidgetStyle) to High(TWidgetStyle) do
            if SameText(LayoutText, WidgetStyleIniText[WS]) then
                WidgetStyle := WS;
        BaseEffects := Ini.ReadBool(S, 'EffettiBase', BaseEffects);
        AutoHide := Ini.ReadBool(S, 'NascondiInattivi', AutoHide);
        AutoHideSecs := EnsureRange(Ini.ReadInteger(S, 'NascondiDopoSecondi', AutoHideSecs),
            AUTOHIDE_MIN, AUTOHIDE_MAX);
        CheckUpdates := Ini.ReadBool(S, 'ControllaAggiornamenti', CheckUpdates);
        ShowLegends := Ini.ReadBool(S, 'LegendeTasti', ShowLegends);
        StayOnTop := Ini.ReadBool(S, 'SempreInPrimoPiano', StayOnTop);
        StartLocked := Ini.ReadBool(S, 'AvvioBloccato', StartLocked);
        StreamerMode := Ini.ReadBool(S, 'ModalitaStreamer', StreamerMode);
        PrivacyMode := Ini.ReadBool(S, 'ModalitaPrivacy', PrivacyMode);
        DisclaimerAccepted := Ini.ReadBool(S, 'AvvisoAccettato', DisclaimerAccepted);
        MouseRange := EnsureRange(Ini.ReadInteger(S, 'MouseCorsa', MouseRange), 200, 50000);
        Language := LowerCase(Trim(Ini.ReadString(S, 'Lingua', Language)));
        if Language = '' then
            Language := DEF_LANGUAGE;

        S := 'OBS';
        ObsPort := EnsureRange(Ini.ReadInteger(S, 'Porta', ObsPort), OBS_PORT_MIN, OBS_PORT_MAX);
        ObsWidth := EnsureRange(Ini.ReadInteger(S, 'Larghezza', ObsWidth), OBS_SIZE_MIN, OBS_SIZE_MAX);
        ObsHeight := EnsureRange(Ini.ReadInteger(S, 'Altezza', ObsHeight), OBS_SIZE_MIN, OBS_SIZE_MAX);
        ObsHideMode := EnsureRange(Ini.ReadInteger(S, 'Occultamento', ObsHideMode), OBS_HIDE_WINDOW,
            OBS_HIDE_MONITOR);
        ObsMonitor := Trim(Ini.ReadString(S, 'Monitor', ObsMonitor));
        ObsFps := EnsureRange(Ini.ReadInteger(S, 'FPS', ObsFps), OBS_FPS_MIN, OBS_FPS_MAX);
        ObsAutoStart := Ini.ReadBool(S, 'AvvioAutomatico', ObsAutoStart);

        for K := Low(TDeviceKind) to High(TDeviceKind) do
        begin
            S := 'Widget.' + KindIniKey[K];
            W := Widgets[K];
            W.Visible := Ini.ReadBool(S, 'Visibile', W.Visible);
            W.ModelId := Ini.ReadString(S, 'Modello', W.ModelId);
            W.Absolute := Ini.ReadBool(S, 'PosizioneAssoluta', W.Absolute);
            W.X := Ini.ReadInteger(S, 'X', W.X);
            W.Y := Ini.ReadInteger(S, 'Y', W.Y);
            W.W := EnsureRange(Ini.ReadInteger(S, 'Larghezza', W.W), 80, 4000);
            W.H := EnsureRange(Ini.ReadInteger(S, 'Altezza', W.H), 80, 4000);
            W.DeviceIndex := EnsureRange(Ini.ReadInteger(S, 'Dispositivo', W.DeviceIndex), 0, 15);
            W.AxisX := EnsureRange(Ini.ReadInteger(S, 'AsseX', W.AxisX), 0, 5);
            W.AxisY := EnsureRange(Ini.ReadInteger(S, 'AsseY', W.AxisY), 0, 5);
            W.AxisZ := EnsureRange(Ini.ReadInteger(S, 'AsseZ', W.AxisZ), 0, 5);
            W.InvertX := Ini.ReadBool(S, 'InvertiX', W.InvertX);
            W.InvertY := Ini.ReadBool(S, 'InvertiY', W.InvertY);
            W.InvertZ := Ini.ReadBool(S, 'InvertiZ', W.InvertZ);
            W.RangeX := EnsureRange(Ini.ReadInteger(S, 'AmpiezzaX', W.RangeX), JOY_RANGE_MIN, JOY_RANGE_MAX);
            W.RangeY := EnsureRange(Ini.ReadInteger(S, 'AmpiezzaY', W.RangeY), JOY_RANGE_MIN, JOY_RANGE_MAX);
            W.RangeZ := EnsureRange(Ini.ReadInteger(S, 'AmpiezzaZ', W.RangeZ), JOY_RANGE_MIN, JOY_RANGE_MAX);
            W.ButtonOffset := EnsureRange(Ini.ReadInteger(S, 'PrimoPulsante', W.ButtonOffset), 0, 31);
            W.Tilt := IniToFloat(Ini.ReadString(S, 'VistaInclinazione', ''), W.Tilt);
            W.Yaw := IniToFloat(Ini.ReadString(S, 'VistaRotazione', ''), W.Yaw);
            W.Zoom := EnsureRange(IniToFloat(Ini.ReadString(S, 'VistaZoom', ''), W.Zoom), 0.3, 3);
            W.PanY := EnsureRange(IniToFloat(Ini.ReadString(S, 'VistaSpostamento', ''), W.PanY),
                -VIEW_PAN_LIMIT, VIEW_PAN_LIMIT);
            Widgets[K] := W;
        end;
    finally
        Ini.Free;
    end;

    if Legacy then
    begin
        AnyAbsolute := False;
        for K := Low(TDeviceKind) to High(TDeviceKind) do
            if Widgets[K].Visible and Widgets[K].Absolute then
                AnyAbsolute := True;
        if AnyAbsolute then
            Layout := lmCustom;
    end;
    SetLayout(Layout);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TAppConfig.SaveToFile
//** Parametri di ingresso: AFileName: string
//** Parametri di uscita: nessuno
//** Scopo: Salvare la configurazione nel file .ini (UTF-8).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: scrive tutte le chiavi in memoria e poi su disco con UpdateFile.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TAppConfig.SaveToFile(const AFileName: string);
var
    Ini: TMemIniFile;
    K: TDeviceKind;
    S: string;
    W: TWidgetConfig;
begin
    Ini := TMemIniFile.Create(AFileName, TEncoding.UTF8);
    try
        S := 'Generale';
        Ini.WriteString(S, 'Layout', LayoutIniText[Layout]);
        Ini.WriteString(S, 'Skin', SkinId);
        Ini.WriteInteger(S, 'Margine', Margin);
        Ini.DeleteKey(S, 'OrigineX');
        Ini.DeleteKey(S, 'OrigineY');
        Ini.WriteInteger(S, 'Spaziatura', Spacing);
        Ini.WriteString(S, 'Opacita', FloatToIni(Opacity));
        Ini.WriteBool(S, 'Animazioni', Animations);
        Ini.WriteString(S, 'StileWidget', WidgetStyleIniText[WidgetStyle]);
        Ini.WriteBool(S, 'EffettiBase', BaseEffects);
        Ini.WriteBool(S, 'NascondiInattivi', AutoHide);
        Ini.WriteInteger(S, 'NascondiDopoSecondi', AutoHideSecs);
        Ini.WriteBool(S, 'ControllaAggiornamenti', CheckUpdates);
        Ini.WriteBool(S, 'LegendeTasti', ShowLegends);
        Ini.WriteBool(S, 'SempreInPrimoPiano', StayOnTop);
        Ini.WriteBool(S, 'AvvioBloccato', StartLocked);
        Ini.WriteBool(S, 'ModalitaStreamer', StreamerMode);
        Ini.WriteBool(S, 'ModalitaPrivacy', PrivacyMode);
        Ini.WriteBool(S, 'AvvisoAccettato', DisclaimerAccepted);
        Ini.WriteInteger(S, 'MouseCorsa', MouseRange);
        Ini.WriteString(S, 'Lingua', Language);

        S := 'OBS';
        Ini.WriteInteger(S, 'Porta', ObsPort);
        Ini.WriteInteger(S, 'Larghezza', ObsWidth);
        Ini.WriteInteger(S, 'Altezza', ObsHeight);
        Ini.WriteInteger(S, 'Occultamento', ObsHideMode);
        Ini.WriteString(S, 'Monitor', ObsMonitor);
        Ini.WriteInteger(S, 'FPS', ObsFps);
        Ini.WriteBool(S, 'AvvioAutomatico', ObsAutoStart);

        for K := Low(TDeviceKind) to High(TDeviceKind) do
        begin
            S := 'Widget.' + KindIniKey[K];
            W := Widgets[K];
            Ini.WriteBool(S, 'Visibile', W.Visible);
            Ini.WriteString(S, 'Modello', W.ModelId);
            Ini.WriteBool(S, 'PosizioneAssoluta', W.Absolute);
            Ini.WriteInteger(S, 'X', W.X);
            Ini.WriteInteger(S, 'Y', W.Y);
            Ini.WriteInteger(S, 'Larghezza', W.W);
            Ini.WriteInteger(S, 'Altezza', W.H);
            Ini.WriteInteger(S, 'Dispositivo', W.DeviceIndex);
            Ini.WriteInteger(S, 'AsseX', W.AxisX);
            Ini.WriteInteger(S, 'AsseY', W.AxisY);
            Ini.WriteInteger(S, 'AsseZ', W.AxisZ);
            Ini.WriteBool(S, 'InvertiX', W.InvertX);
            Ini.WriteBool(S, 'InvertiY', W.InvertY);
            Ini.WriteBool(S, 'InvertiZ', W.InvertZ);
            Ini.WriteInteger(S, 'AmpiezzaX', W.RangeX);
            Ini.WriteInteger(S, 'AmpiezzaY', W.RangeY);
            Ini.WriteInteger(S, 'AmpiezzaZ', W.RangeZ);
            Ini.WriteInteger(S, 'PrimoPulsante', W.ButtonOffset);
            Ini.WriteString(S, 'VistaInclinazione', FloatToIni(W.Tilt));
            Ini.WriteString(S, 'VistaRotazione', FloatToIni(W.Yaw));
            Ini.WriteString(S, 'VistaZoom', FloatToIni(W.Zoom));
            Ini.WriteString(S, 'VistaSpostamento', FloatToIni(W.PanY));
        end;
        Ini.UpdateFile;
    finally
        Ini.Free;
    end;
end;

initialization
    GIniFormat := TFormatSettings.Create;
    GIniFormat.DecimalSeparator := '.';
    GIniFormat.ThousandSeparator := #0;

end.
