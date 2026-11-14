//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Widget
//** Scopo: Widget che mostra UN dispositivo: pannello 2D (cornice, titolo, stato) con una scena 3D.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: pannello 2D (cornice, titolo, stato) con
//** dentro una scena 3D (TViewport3D) composta da:
//**   Camera  -> guarda il centro della scena da leggermente in alto
//**   Stage   -> contenitore fisso (proiettore olografico, scanline)
//**   World   -> ruota con l'inclinazione/rotazione della vista
//**   ModelRoot -> radice del modello 3D scelto (unit nelle sottocartelle)
//**
//** In modalita' "sbloccata" il widget si trascina con il mouse (nuova
//** posizione) oppure si ridimensiona afferrandone un bordo o un angolo
//** (fascia di RESIZE_BORDER pixel lungo la cornice). Durante l'operazione la
//** scena 3D viene nascosta e il widget e' disegnato come solo CONTORNO
//** (cornice tratteggiata + misure); la scena ricompare al rilascio del mouse,
//** gia' adattata alla nuova dimensione.
//** Durante lo spostamento dall'angolo inferiore sinistro del widget partono
//** due linee guida verdi (verticale e orizzontale) lunghe quanto l'overlay
//** (TWidgetGuides): se arrivano a meno di SNAP_DIST pixel da un lato di un
//** altro widget visibile vi si agganciano (linea piena), cosi' i widget si
//** allineano a sinistra/destra e in alto/in basso.
//** Tenendo premuto il tasto DESTRO e muovendo il mouse si ruota il modello
//** dentro il widget: destra/sinistra = rotazione attorno all'asse verticale
//** (asse Z, come il twist di un joystick), avanti/indietro = inclinazione
//** avanti/indietro (asse Y, come il pitch). La rotella del mouse ingrandisce
//** (in avanti) o rimpicciolisce (indietro) il modello. La vista si salva nel
//** .ini e torna quella predefinita con il pulsante Default del Setup.
//**
//** Stile (SetStyle, opzione "Stile dei widget" del Setup):
//**   pannello         sfondo, cornice, staffe, titolo e stato del dispositivo;
//**                    la scena 3D sta sotto la fascia del titolo;
//**   solo dispositivo nessun pannello: la scena 3D (sfondo gia' trasparente)
//**                    occupa tutto il widget e resta visibile solo il modello.
//**                    Con il layout sbloccato titolo, cornice tratteggiata e
//**                    maniglie compaiono solo quando il mouse e' sopra il
//**                    widget; il resto del tempo c'e' solo una velatura
//**                    invisibile (alfa minimo: con i pixel del tutto
//**                    trasparenti i click attraverserebbero la finestra e il
//**                    widget non si potrebbe afferrare). In ogni caso, se il
//**                    dispositivo non e' collegato compare l'avviso.
//** Gli "effetti di base" (anelli del proiettore e scanline) si possono
//** nascondere in entrambi gli stili.
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.Widget;

interface

uses
    System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
    System.Math.Vectors,
    FMX.Types, FMX.Types3D, FMX.Controls, FMX.Graphics, FMX.Viewport3D,
    FMX.Controls3D, FMX.Objects3D,
    Holo.Config, Holo.Skins, Holo.Input, Holo.Prims, Holo.Models, Holo.UI;

const
    CAMERA_ELEVATION = 18;   // gradi: la camera guarda leggermente dall'alto
    HEADER_H = 22;
    EDIT_VEIL_ALPHA = $03;   // velatura invisibile dei widget "solo dispositivo" da sbloccati (afferrabili)
    RESIZE_BORDER = 8;       // pixel lungo la cornice che afferrano il ridimensionamento
    WIDGET_MIN_W = 120;      // dimensioni minime durante il ridimensionamento
    WIDGET_MIN_H = 100;
    VIEW_DRAG_DEG = 0.4;     // gradi di rotazione della vista per pixel di trascinamento
    VIEW_TILT_LIMIT = 90;    // inclinazione massima aggiunta a quella del modello (gradi)
    VIEW_ZOOM_STEP = 1.1;    // fattore di zoom per ogni scatto della rotella
    AUTOHIDE_FADE_OUT = 0.6; // secondi della dissolvenza quando il widget si nasconde
    AUTOHIDE_FADE_IN = 0.15; // secondi della dissolvenza quando il widget ricompare
    AUTOHIDE_AXIS_EPS = 0.01;   // variazione minima di un asse joystick considerata input
    AUTOHIDE_STICK_DEAD = 0.25; // levetta del gamepad considerata in uso oltre questa deflessione
    VIEW_ZOOM_MIN = 0.3;     // limiti dello zoom (1 = modello inquadrato per intero)
    VIEW_ZOOM_MAX = 3;
    SNAP_DIST = 10;          // distanza (pixel) entro cui le linee guida si agganciano a un widget
    GUIDE_COLOR = $FF39FF6A; // verde delle linee guida durante lo spostamento

type
    TResizeEdge = (reLeft, reTop, reRight, reBottom);
    TResizeEdges = set of TResizeEdge;

    /// Linee guida dello spostamento: una verticale e una orizzontale che
    /// passano per l'angolo inferiore sinistro del widget trascinato e
    /// attraversano tutto il contenitore dei widget. Piena = agganciata.
    TWidgetGuides = class(TControl)
    private
        rFCorner: TPointF;
        bFSnapX, bFSnapY: Boolean;
    protected
        procedure Paint; override;
    public
        constructor Create(AOwner: TComponent); override;
        procedure ShowAt(const rACorner: TPointF; bASnapX, bASnapY: Boolean);
    end;

    TDeviceWidget = class(TControl)
    private
        eFKind: TDeviceKind;
        rFCfg: TWidgetConfig;
        rFColors: TSkinColors;
        oFKit: THoloKit;
        oFViewport: TViewport3D;
        oFCamera: TCamera;
        oFStage: TDummy;
        oFPan: TDummy;                      // spostamento verticale della vista (figlio di oFStage)
        oFWorld: TDummy;
        oFModelRoot: TDummy;
        oFModel: TDeviceModel;
        oFModelClass: TDeviceModelClass;
        oFRingOuter, oFRingInner: THoloRing;
        oFScan: THoloShape;
        bFShowLegends: Boolean;
        bFDeviceOnly: Boolean;              // stile "solo dispositivo" (nessun pannello)
        bFBaseEffects: Boolean;             // anelli del proiettore e scanline visibili
        iFLangVersion: Integer;                 // lingua con cui e' stato costruito il modello
        dFEffW, dFEffH, dFEffD: Single;
        dFTime: Single;
        dFLastW, dFLastH: Single;
        bFConnected: Boolean;
        bFEditMode, bFDragging, bFResizing: Boolean;
        rFDragMouse: TPointF;               // punto di presa (coordinate assolute) all'inizio dello spostamento
        bFSnapX, bFSnapY: Boolean;           // spostamento agganciato in X (linea verticale) / Y (orizzontale)
        eFEdges: TResizeEdges;
        rFStartRect: TRectF;
        rFResizeMouse: TPointF;
        bFAnimating: Boolean;
        mFOnMoved: TNotifyEvent;
        mFOnResized: TNotifyEvent;
        bFRotating: Boolean;                // rotazione della vista con il tasto destro
        rFRotMouse: TPointF;
        dFRotTilt0, dFRotYaw0: Single;
        bFPanning: Boolean;                 // spostamento verticale della vista (Shift + tasto destro)
        dFPanY0: Single;
        bFAutoHide: Boolean;                // nascondi il widget quando il dispositivo e' inattivo
        dFAutoHideSecs: Single;
        dFIdle: Single;                     // secondi trascorsi dall'ultimo input del dispositivo
        dFShow: Single;                     // visibilita' del widget: 1 = visibile, 0 = nascosto
        rFPrevJoy: TJoyState;               // stato precedente (per riconoscere un nuovo input)
        rFPrevPad: TPadState;
        mFOnViewChanged: TNotifyEvent;
        function bDeviceActive(const rASnapshot: TInputSnapshot): Boolean;
        procedure UpdateAutoHide(const rASnapshot: TInputSnapshot; dADeltaT: Single);
        function eEdgesAt(dAPosX, dAPosY: Single): TResizeEdges;
        procedure UpdateCursor(dAPosX, dAPosY: Single);
        procedure SetOutlineOnly(bAValue: Boolean);
        procedure PaintOutline;
        procedure PaintStatus(const rARect: TRectF; dAOpacity: Single);
        procedure PaintEditFrame(const rARect: TRectF; dAOpacity: Single);
        procedure PaintDeviceOnly;
        procedure CreateModel;
        procedure FitCamera;
        procedure ApplyView;
        procedure ApplyEffects;
        procedure SetEditMode(const bValue: Boolean);
        function sTitle: string;
        function oGuides: TWidgetGuides;
        procedure SnapPosition(var dALeft, dATop: Single);
        procedure HideGuides;
    protected
        procedure Paint; override;
        procedure AfterPaint; override;
        procedure DoMouseEnter; override;
        procedure DoMouseLeave; override;
        procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
        procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
        procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
        procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    public
        constructor CreateWidget(oAOwner: TComponent; eAKind: TDeviceKind);
        destructor Destroy; override;
        procedure Configure(const rACfg: TWidgetConfig; const rAColors: TSkinColors; bAShowLegends: Boolean);
        procedure BindDevices(oAInput: TInputManager);
        /// Stile del widget: solo dispositivo (sfondo trasparente) ed effetti di base.
        procedure SetStyle(bADeviceOnly, bABaseEffects: Boolean);
        /// Nascondi automaticamente il widget dopo iASeconds senza input del suo dispositivo.
        procedure SetAutoHide(bAEnabled: Boolean; iASeconds: Integer);
        procedure Tick(const rASnapshot: TInputSnapshot; dADeltaT: Single; bAAnimate: Boolean);
        property eKind: TDeviceKind read eFKind;
        property bEditMode: Boolean read bFEditMode write SetEditMode;
        property mOnMoved: TNotifyEvent read mFOnMoved write mFOnMoved;
        /// Chiamato al termine di un ridimensionamento fatto con il mouse.
        property mOnResized: TNotifyEvent read mFOnResized write mFOnResized;
        /// Chiamato al termine di una rotazione (tasto destro) o di uno spostamento
        /// verticale (Shift + tasto destro) della vista e a ogni scatto della rotella (zoom).
        property mOnViewChanged: TNotifyEvent read mFOnViewChanged write mFOnViewChanged;
        /// Correzioni della vista impostate con il mouse (gradi).
        property dViewTilt: Single read rFCfg.dTilt;
        property dViewYaw: Single read rFCfg.dYaw;
        property dViewZoom: Single read rFCfg.dZoom;
        /// Spostamento verticale della vista (frazione dell'altezza visibile, + = in basso).
        property dViewPanY: Single read rFCfg.dPanY;
        /// Visibilita' attuale dovuta a "nascondi i widget inattivi" (1 = visibile, 0 = nascosto).
        property dShowAlpha: Single read dFShow;
    published
        property Visible;
        property Position;
    end;

implementation

uses
    Holo.Lang;

//** TWidgetGuides ******************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWidgetGuides.Create
//** Parametri di ingresso: AOwner: TComponent
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare le linee guida, nascoste e trasparenti ai click.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
constructor TWidgetGuides.Create(AOwner: TComponent);
begin
    inherited;
    HitTest := False;
    Visible := False;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWidgetGuides.ShowAt
//** Parametri di ingresso: rACorner: TPointF; bASnapX, bASnapY: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Mostrare le linee guida passanti per rACorner (coordinate del contenitore).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: occupa tutto il contenitore dei widget (il genitore), resta
//** in primo piano sopra i widget e si ridisegna con la nuova posizione;
//** bASnapX / bASnapY indicano le linee agganciate a un altro widget.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TWidgetGuides.ShowAt(const rACorner: TPointF; bASnapX, bASnapY: Boolean);
begin
    if ParentControl <> nil then
        SetBounds(0, 0, ParentControl.Width, ParentControl.Height);
    rFCorner := rACorner;
    bFSnapX := bASnapX;
    bFSnapY := bASnapY;
    if not Visible then
    begin
        Visible := True;
        BringToFront;
    end;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWidgetGuides.Paint
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare le due linee guida verdi e il punto dell'angolo inferiore sinistro.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: linea verticale per X dell'angolo, orizzontale per Y, da
//** bordo a bordo; tratteggiata e sottile se libera, piena e piu' spessa se
//** agganciata a un widget. Un pallino verde segna l'angolo.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TWidgetGuides.Paint;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: SetPen
    //** Parametri di ingresso: bASnapped: Boolean
    //** Parametri di uscita: nessuno
    //** Scopo: Impostare il tratto della linea: pieno se agganciata, tratteggiato se libera.
    //** Data Ultima Modifica: 30/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure SetPen(bASnapped: Boolean);
    begin
        Canvas.Stroke.Kind := TBrushKind.Solid;
        if bASnapped then
        begin
            Canvas.Stroke.Thickness := 2;
            Canvas.Stroke.Dash := TStrokeDash.Solid;
            Canvas.Stroke.Color := GUIDE_COLOR;
        end
        else
        begin
            Canvas.Stroke.Thickness := 1;
            Canvas.Stroke.Dash := TStrokeDash.Dash;
            Canvas.Stroke.Color := (GUIDE_COLOR and $00FFFFFF) or $B0000000;
        end;
    end;

var
    dPosX, dPosY: Single;
begin
    dPosX := Round(rFCorner.X) + 0.5;
    dPosY := Round(rFCorner.Y) - 0.5;
    SetPen(bFSnapX);
    Canvas.DrawLine(PointF(dPosX, 0), PointF(dPosX, Height), 1);
    SetPen(bFSnapY);
    Canvas.DrawLine(PointF(0, dPosY), PointF(Width, dPosY), 1);
    Canvas.Stroke.Dash := TStrokeDash.Solid;
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := GUIDE_COLOR;
    Canvas.FillEllipse(RectF(dPosX - 4, dPosY - 4, dPosX + 4, dPosY + 4), 1);
end;

//** TDeviceWidget: linee guida e aggancio ******************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceWidget.oGuides
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TWidgetGuides
//** Scopo: Linee guida condivise dai widget dello stesso contenitore (create alla prima richiesta).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceWidget.oGuides: TWidgetGuides;
var
    iChild: Integer;
begin
    Result := nil;
    if Parent = nil then
        Exit;
    for iChild := 0 to Parent.ChildrenCount - 1 do
        if Parent.Children[iChild] is TWidgetGuides then
            Exit(TWidgetGuides(Parent.Children[iChild]));
    Result := TWidgetGuides.Create(Parent);
    Result.Parent := Parent;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.HideGuides
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Nascondere le linee guida alla fine dello spostamento.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.HideGuides;
var
    oGuideLayer: TWidgetGuides;
begin
    oGuideLayer := oGuides;
    if oGuideLayer <> nil then
        oGuideLayer.Visible := False;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.SnapPosition
//** Parametri di ingresso: dALeft, dATop: Single (var)
//** Parametri di uscita: dALeft, dATop: Single (var)
//** Scopo: Agganciare le linee guida del widget trascinato ai lati degli altri widget visibili.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: la linea verticale (lato sinistro, dALeft) si aggancia al
//** lato sinistro o destro piu' vicino di un altro widget, quella orizzontale
//** (lato inferiore, dATop + Height) al lato superiore o inferiore piu' vicino,
//** se distano al massimo SNAP_DIST pixel; le due linee sono indipendenti.
//** Aggiorna bFSnapX / bFSnapY.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.SnapPosition(var dALeft, dATop: Single);
var
    iChild: Integer;
    oOther: TDeviceWidget;
    dBestX, dBestY, dBottom: Single;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: Try1
    //** Parametri di ingresso: dAValue, dATarget: Single; dABest: Single (var)
    //** Parametri di uscita: dABest: Single (var)
    //** Scopo: Tenere in dABest la distanza (con segno) dal bersaglio piu' vicino entro SNAP_DIST.
    //** Data Ultima Modifica: 30/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Try1(dAValue, dATarget: Single; var dABest: Single);
    begin
        if (Abs(dATarget - dAValue) <= SNAP_DIST) and (Abs(dATarget - dAValue) < Abs(dABest)) then
            dABest := dATarget - dAValue;
    end;

begin
    bFSnapX := False;
    bFSnapY := False;
    if Parent = nil then
        Exit;
    dBestX := SNAP_DIST + 1;
    dBestY := SNAP_DIST + 1;
    dBottom := dATop + Height;
    for iChild := 0 to Parent.ChildrenCount - 1 do
    begin
        if not (Parent.Children[iChild] is TDeviceWidget) then
            Continue;
        oOther := TDeviceWidget(Parent.Children[iChild]);
        if (oOther = Self) or not oOther.Visible then
            Continue;
        Try1(dALeft, oOther.Position.X, dBestX);
        Try1(dALeft, oOther.Position.X + oOther.Width, dBestX);
        Try1(dBottom, oOther.Position.Y, dBestY);
        Try1(dBottom, oOther.Position.Y + oOther.Height, dBestY);
    end;
    if Abs(dBestX) <= SNAP_DIST then
    begin
        dALeft := dALeft + dBestX;
        bFSnapX := True;
    end;
    if Abs(dBestY) <= SNAP_DIST then
    begin
        dATop := dATop + dBestY;
        bFSnapY := True;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.CreateWidget
//** Parametri di ingresso: oAOwner: TComponent; eAKind: TDeviceKind
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare il widget e la sua scena 3D vuota.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: il viewport ha sfondo trasparente e non intercetta il mouse
//** (cosi' il trascinamento arriva al widget); la camera e' puntata sullo Stage.
//***********************************************************************************************************
//***********************************************************************************************************
constructor TDeviceWidget.CreateWidget(oAOwner: TComponent; eAKind: TDeviceKind);
begin
    inherited Create(oAOwner);
    eFKind := eAKind;
    rFColors := rDefaultSkinColors;
    bFBaseEffects := True;
    HitTest := True;
    // il widget resta fermo mentre si trascina la sagoma: senza la cattura del
    // mouse, appena il puntatore esce dal widget (per ingrandirlo o spostarlo)
    // i movimenti andrebbero ad altri controlli e l'operazione si bloccherebbe
    AutoCapture := True;

    oFViewport := TViewport3D.Create(Self);
    oFViewport.Parent := Self;
    oFViewport.Align := TAlignLayout.Client;
    oFViewport.Margins.Rect := RectF(4, HEADER_H, 4, 4);
    oFViewport.Color := TAlphaColors.Null;
    oFViewport.HitTest := False;
    oFViewport.Multisample := TMultisample.FourSamples;

    dFShow := 1;

    oFStage := TDummy.Create(Self);
    oFStage.Parent := oFViewport;

    // la camera punta oFStage; modello, anelli e scanline stanno sotto oFPan, che si
    // sposta in verticale (Shift + tasto destro) senza muovere il punto mirato
    oFPan := TDummy.Create(Self);
    oFPan.Parent := oFStage;

    oFWorld := TDummy.Create(Self);
    oFWorld.Parent := oFPan;

    oFCamera := TCamera.Create(Self);
    oFCamera.Parent := oFViewport;
    oFCamera.AngleOfView := 30;
    oFCamera.Target := oFStage;
    oFCamera.Position.Point := Point3D(0, -6, -20);
    oFViewport.UsingDesignCamera := False;
    oFViewport.Camera := oFCamera;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.Destroy
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Distruggere modello e kit nell'ordine corretto.
//** Data Ultima Modifica: 27/09/2026
//***********************************************************************************************************
//** Funzionamento: prima la logica del modello, poi le forme 3D (che usano i
//** materiali del kit), infine il kit stesso.
//***********************************************************************************************************
//***********************************************************************************************************
destructor TDeviceWidget.Destroy;
begin
    FreeAndNil(oFModel);
    FreeAndNil(oFModelRoot);
    FreeAndNil(oFRingOuter);
    FreeAndNil(oFRingInner);
    FreeAndNil(oFScan);
    inherited;
    FreeAndNil(oFKit);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.CreateModel
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: (ri)creare il modello 3D scelto nella configurazione.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: elimina il modello precedente e le decorazioni, crea la
//** nuova radice sotto World, istanzia la classe del modello e aggiunge il
//** "proiettore" (due anelli) e la scanline nello Stage (visibili secondo
//** l'opzione degli effetti di base).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.CreateModel;
begin
    FreeAndNil(oFModel);
    FreeAndNil(oFModelRoot);
    FreeAndNil(oFRingOuter);
    FreeAndNil(oFRingInner);
    FreeAndNil(oFScan);

    oFModelClass := oFindModel(eFKind, rFCfg.sModelId);
    oFModelRoot := oFKit.oPivot(oFWorld, 0, 0, 0);
    if oFModelClass <> nil then
        oFModel := oFModelClass.Create(oFKit, oFModelRoot);

    oFRingOuter := oFKit.oRing(oFPan, 0, 0, 0, 1, True, hsNormal);
    oFRingInner := oFKit.oRing(oFPan, 0, 0, 0, 1, False, hsDim);
    oFScan := oFKit.oBox(oFPan, 0, 0, 0, 1, 0.02, 1, hsScan);
    oFScan.Visible := False;
    ApplyEffects;
    dFLastW := -1;   // forza FitCamera al prossimo Tick
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.Configure
//** Parametri di ingresso: rACfg: TWidgetConfig; rAColors: TSkinColors; bAShowLegends: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Applicare configurazione, skin e legende al widget.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: crea il kit alla prima chiamata; ricrea il modello solo se
//** il modello scelto o l'opzione legende sono cambiati, altrimenti aggiorna
//** solo colori e vista.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.Configure(const rACfg: TWidgetConfig; const rAColors: TSkinColors;
    bAShowLegends: Boolean);
var
    oNewClass: TDeviceModelClass;
begin
    rFCfg := rACfg;
    rFColors := rAColors;
    if oFKit = nil then
        oFKit := THoloKit.Create(rAColors)
    else
        oFKit.ApplyColors(rAColors);

    oNewClass := oFindModel(eFKind, rACfg.sModelId);
    // il modello si ricostruisce anche se e' cambiata la lingua (legende 3D)
    if (oFModel = nil) or (oNewClass <> oFModelClass) or (bAShowLegends <> bFShowLegends) or
        (iFLangVersion <> iLanguageVersion) then
    begin
        iFLangVersion := iLanguageVersion;
        bFShowLegends := bAShowLegends;
        oFKit.bShowLegends := bAShowLegends;
        CreateModel;
    end
    else if oFModel <> nil then
        oFModel.SkinChanged;
    ApplyView;
    dFLastW := -1;
    oFWorld.Repaint;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.BindDevices
//** Parametri di ingresso: oAInput: TInputManager
//** Parametri di uscita: nessuno
//** Scopo: Registrare i dispositivi del modello presso il gestore degli input.
//** Data Ultima Modifica: 27/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.BindDevices(oAInput: TInputManager);
begin
    if oFModel <> nil then
        oFModel.BindDevices(oAInput, rFCfg);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.SetStyle
//** Parametri di ingresso: bADeviceOnly, bABaseEffects: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Applicare lo stile del widget (pannello / solo dispositivo) e gli effetti di base.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: con "solo dispositivo" la scena 3D occupa tutto il widget
//** (nessuno spazio per il titolo), con il pannello resta sotto la fascia del
//** titolo; la camera viene riadattata al prossimo Tick. Gli anelli e la
//** scanline vengono mostrati o nascosti subito.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.SetStyle(bADeviceOnly, bABaseEffects: Boolean);
begin
    bFBaseEffects := bABaseEffects;
    if bADeviceOnly <> bFDeviceOnly then
    begin
        bFDeviceOnly := bADeviceOnly;
        if bFDeviceOnly then
            oFViewport.Margins.Rect := RectF(0, 0, 0, 0)
        else
            oFViewport.Margins.Rect := RectF(4, HEADER_H, 4, 4);
        dFLastW := -1;   // forza FitCamera con la nuova area del viewport
    end;
    ApplyEffects;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.SetAutoHide
//** Parametri di ingresso: bAEnabled: Boolean; iASeconds: Integer
//** Parametri di uscita: nessuno
//** Scopo: Attivare o disattivare "nascondi i widget inattivi" e il tempo di attesa.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: azzera il tempo di inattivita' e rende subito visibile il
//** widget, cosi' dopo un cambio delle impostazioni il conteggio riparte da zero.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.SetAutoHide(bAEnabled: Boolean; iASeconds: Integer);
begin
    bFAutoHide := bAEnabled;
    dFAutoHideSecs := EnsureRange(iASeconds, AUTOHIDE_MIN, AUTOHIDE_MAX);
    dFIdle := 0;
    dFShow := 1;
    Opacity := 1;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceWidget.bDeviceActive
//** Parametri di ingresso: rASnapshot: TInputSnapshot
//** Parametri di uscita: Result: Boolean
//** Scopo: Indicare se nel frame corrente c'e' input dal dispositivo del widget.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: dipende dalla tipologia:
//**  - tastiera: un tasto premuto;
//**  - mouse: un pulsante premuto, un movimento o uno scatto della rotella;
//**  - gamepad: un pulsante premuto, un grilletto o una levetta oltre
//**    AUTOHIDE_STICK_DEAD, oppure una levetta che si muove;
//**  - joystick e manette: un pulsante premuto, il POV fuori dal centro o un
//**    asse che si muove di almeno AUTOHIDE_AXIS_EPS (un asse fermo non conta,
//**    cosi' slider e leve in posizione non tengono il widget sempre visibile);
//**  - pulsantiere: un pulsante premuto a partire dal primo pulsante usato.
//** Lo stato precedente di joystick e gamepad e' in rFPrevJoy / rFPrevPad.
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceWidget.bDeviceActive(const rASnapshot: TInputSnapshot): Boolean;
var
    iKey, iIdx: Integer;
    rJoy: TJoyState;
    rPad: TPadState;
begin
    Result := False;
    iIdx := rFCfg.iDeviceIndex;
    case eFKind of
        dkKeyboard:
            for iKey := 0 to High(rASnapshot.aKeys) do
                if rASnapshot.aKeys[iKey] then
                    Exit(True);
        dkMouse:
            Result := (rASnapshot.rMouse.iButtons <> 0) or (rASnapshot.rMouse.dDX <> 0)
                or (rASnapshot.rMouse.dDY <> 0) or
                (rASnapshot.rMouse.dWheelDelta <> 0);
        dkGamepad:
            if (iIdx >= 0) and (iIdx < MAX_PADS) then
            begin
                rPad := rASnapshot.aPads[iIdx];
                Result := (rPad.iButtons <> 0) or (rPad.dLT > 0.05) or (rPad.dRT > 0.05) or
                    (Abs(rPad.dLX) > AUTOHIDE_STICK_DEAD) or (Abs(rPad.dLY) > AUTOHIDE_STICK_DEAD) or
                    (Abs(rPad.dRX) > AUTOHIDE_STICK_DEAD) or (Abs(rPad.dRY) > AUTOHIDE_STICK_DEAD) or
                    (Abs(rPad.dLX - rFPrevPad.dLX) > AUTOHIDE_AXIS_EPS) or
                    (Abs(rPad.dLY - rFPrevPad.dLY) > AUTOHIDE_AXIS_EPS) or
                    (Abs(rPad.dRX - rFPrevPad.dRX) > AUTOHIDE_AXIS_EPS) or
                    (Abs(rPad.dRY - rFPrevPad.dRY) > AUTOHIDE_AXIS_EPS);
                rFPrevPad := rPad;
            end;
        dkJoyLeft, dkJoyRight, dkThrLeft, dkThrRight:
            if (iIdx >= 0) and (iIdx < MAX_JOY) then
            begin
                rJoy := rASnapshot.aJoys[iIdx];
                Result := (rJoy.iButtons <> 0) or (rJoy.iPOV >= 0);
                if rJoy.bConnected and rFPrevJoy.bConnected then
                    for iKey := 0 to JOY_AXES - 1 do
                        if Abs(rJoy.aAxes[iKey] - rFPrevJoy.aAxes[iKey]) > AUTOHIDE_AXIS_EPS then
                            Result := True;
                rFPrevJoy := rJoy;
            end;
        dkBoxLeft, dkBoxRight:
            if (iIdx >= 0) and (iIdx < MAX_JOY) then
                Result := (rASnapshot.aJoys[iIdx].iButtons shr EnsureRange(rFCfg.iButtonOffset, 0, 31)) <> 0;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.UpdateAutoHide
//** Parametri di ingresso: rASnapshot: TInputSnapshot; dADeltaT: Single
//** Parametri di uscita: nessuno
//** Scopo: Nascondere il widget dopo dFAutoHideSecs secondi senza input del suo dispositivo e farlo
//**        ricomparire al primo input.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: con l'opzione spenta o con il layout sbloccato (modalita'
//** modifica) il widget resta sempre visibile. Altrimenti conta i secondi di
//** inattivita' (azzerati da bDeviceActive) e, superato il tempo, porta dFShow a 0
//** con una dissolvenza di AUTOHIDE_FADE_OUT secondi; al primo input torna a 1
//** in AUTOHIDE_FADE_IN secondi. dFShow e' applicato all'opacita' del widget e
//** usato anche per i fotogrammi di OBS (dShowAlpha).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.UpdateAutoHide(const rASnapshot: TInputSnapshot; dADeltaT: Single);
var
    dTarget: Single;
begin
    dTarget := 1;
    if bFAutoHide and not bFEditMode then
    begin
        if bDeviceActive(rASnapshot) then
            dFIdle := 0
        else
            dFIdle := dFIdle + dADeltaT;
        if dFIdle >= dFAutoHideSecs then
            dTarget := 0;
    end
    else
        dFIdle := 0;
    if dFShow < dTarget then
        dFShow := Min(dTarget, dFShow + dADeltaT / AUTOHIDE_FADE_IN)
    else if dFShow > dTarget then
        dFShow := Max(dTarget, dFShow - dADeltaT / AUTOHIDE_FADE_OUT);
    if not SameValue(Opacity, dFShow, 0.001) then
        Opacity := dFShow;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.ApplyEffects
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Mostrare o nascondere gli effetti di base (anelli del proiettore e scanline).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: gli anelli seguono direttamente l'opzione; la scanline,
//** se l'opzione e' attiva, viene accesa da Tick solo con le animazioni.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.ApplyEffects;
begin
    if oFRingOuter <> nil then
        oFRingOuter.Visible := bFBaseEffects;
    if oFRingInner <> nil then
        oFRingInner.Visible := bFBaseEffects;
    if (oFScan <> nil) and not bFBaseEffects then
        oFScan.Visible := False;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.ApplyView
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Applicare inclinazione e rotazione della vista al nodo World.
//** Data Ultima Modifica: 27/09/2026
//***********************************************************************************************************
//** Funzionamento: somma la vista di default del modello e le correzioni
//** dell'utente (VistaInclinazione / VistaRotazione nel .ini).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.ApplyView;
var
    rView: TModelView;
begin
    if oFModelClass <> nil then
        rView := oFModelClass.rDefaultView
    else
        rView := rMakeView(0, 0);
    oFWorld.RotationAngle.X := (rView.dTilt + rFCfg.dTilt) * ROT_SIGN;
    oFWorld.RotationAngle.Y := (rView.dYaw + rFCfg.dYaw) * ROT_SIGN;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.FitCamera
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Posizionare la camera in modo che il modello riempia il riquadro.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: stima l'ingombro apparente del modello dopo le rotazioni
//** della vista, calcola la distanza necessaria in verticale e in orizzontale
//** (in base al campo visivo e alle proporzioni del viewport), prende la
//** maggiore e applica lo zoom dell'utente. Dimensiona anche anelli e scanline.
//** Lo spostamento verticale dell'utente (dPanY, frazione dell'altezza visibile
//** alla distanza del modello) sposta oFPan lungo la direzione "giu'" dello
//** schermo (perpendicolare alla linea di vista inclinata di CAMERA_ELEVATION),
//** cosi' il contenuto scorre in verticale senza cambiare prospettiva.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.FitCamera;
var
    rExtent: TPoint3D;
    rView: TModelView;
    dTilt, dYaw, dElevation, dProjWidth, dProjDepth, dTiltHeight, dTiltDepth, dVisHeight, dAspect, dTanH,
        dDistH, dDistW, dDist, dViewWidth, dViewHeight, dPanH: Single;
begin
    dFLastW := Width;
    dFLastH := Height;
    if oFModel = nil then
        Exit;
    dViewWidth := Max(10, oFViewport.Width);
    dViewHeight := Max(10, oFViewport.Height);
    rExtent := oFModel.rExtent;
    rView := oFModelClass.rDefaultView;
    dTilt := DegToRad(rView.dTilt + rFCfg.dTilt);
    dYaw := DegToRad(rView.dYaw + rFCfg.dYaw);
    dElevation := DegToRad(CAMERA_ELEVATION);

    dProjWidth := Abs(rExtent.X * Cos(dYaw)) + Abs(rExtent.Z * Sin(dYaw));
    dProjDepth := Abs(rExtent.X * Sin(dYaw)) + Abs(rExtent.Z * Cos(dYaw));
    dTiltHeight := Abs(rExtent.Y * Cos(dTilt)) + Abs(dProjDepth * Sin(dTilt));
    dTiltDepth := Abs(rExtent.Y * Sin(dTilt)) + Abs(dProjDepth * Cos(dTilt));
    dVisHeight := dTiltHeight * Cos(dElevation) + dTiltDepth * Sin(dElevation);

    dFEffW := dProjWidth;
    dFEffH := dTiltHeight;
    dFEffD := dTiltDepth;

    dAspect := dViewWidth / dViewHeight;
    dTanH := Tan(DegToRad(oFCamera.AngleOfView) / 2);
    dDistH := (dVisHeight / 2) / dTanH;
    dDistW := (dProjWidth / 2) / (dTanH * dAspect);
    dDist := (Max(dDistH, dDistW) * 1.10 + dTiltDepth / 2) / Max(0.3, rFCfg.dZoom);

    oFCamera.Position.Point := Point3D(0, -dDist * Sin(dElevation), -dDist * Cos(dElevation));
    dPanH := rFCfg.dPanY * 2 * dDist * dTanH;
    oFPan.Position.Point := Point3D(0, dPanH * Cos(dElevation), -dPanH * Sin(dElevation));

    if oFRingOuter <> nil then
    begin
        oFRingOuter.SetRadius(Max(dProjWidth, dTiltDepth) * 0.52);
        oFRingOuter.Position.Y := dTiltHeight / 2 + 0.15;
        oFRingInner.SetRadius(Max(dProjWidth, dTiltDepth) * 0.40);
        oFRingInner.Position.Y := dTiltHeight / 2 + 0.15;
        oFScan.SetShapeSize(Point3D(dProjWidth * 1.04, 0.02, dTiltDepth * 1.04));
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.Tick
//** Parametri di ingresso: rASnapshot: TInputSnapshot; dADeltaT: Single; bAAnimate: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Aggiornare il widget ad ogni frame.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: riadatta la camera se il riquadro e' cambiato, passa gli
//** input al modello, gestisce "nascondi i widget inattivi" (UpdateAutoHide),
//** aggiorna l'indicatore di collegamento e, se abilitate,
//** le animazioni olografiche (anello rotante, scanline, sfarfallio); la
//** scanline compare solo con gli effetti di base attivi.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.Tick(const rASnapshot: TInputSnapshot; dADeltaT: Single; bAAnimate: Boolean);
var
    bConn: Boolean;
    dPhase: Single;
begin
    if (oFModel = nil) or not Visible or bFDragging or bFResizing then
        Exit;
    if not (SameValue(Width, dFLastW) and SameValue(Height, dFLastH)) then
        FitCamera;

    oFModel.Update(rASnapshot, rFCfg, dADeltaT);
    UpdateAutoHide(rASnapshot, dADeltaT);

    bConn := oFModel.bIsConnected(rASnapshot, rFCfg);
    if bConn <> bFConnected then
    begin
        bFConnected := bConn;
        Repaint;
    end;

    if bAAnimate then
    begin
        bFAnimating := True;
        dFTime := dFTime + dADeltaT;
        oFRingOuter.RotationAngle.Y := Frac(dFTime / 12) * 360;
        oFRingInner.RotationAngle.Y := -Frac(dFTime / 20) * 360;
        dPhase := Frac(dFTime / 3.2);
        oFScan.Visible := bFBaseEffects;
        oFScan.Position.Y := -dFEffH / 2 + dPhase * dFEffH;
        SetObjOpacity(oFScan, Sin(dPhase * Pi));
        // leggero sfarfallio olografico
        SetObjOpacity(oFWorld, 0.93 + 0.05 * Sin(dFTime * 9.1) + 0.02 * Sin(dFTime * 23.7));
    end
    else if bFAnimating then
    begin
        bFAnimating := False;
        oFScan.Visible := False;
        SetObjOpacity(oFWorld, 1);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceWidget.sTitle
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Testo dell'intestazione (tipologia + modello).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceWidget.sTitle: string;
begin
    Result := sKindText(eFKind);
    if oFModelClass <> nil then
        Result := Result + '  ' + #$00B7 + '  ' + UpperCase(oFModelClass.sDisplayName);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.Paint
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare il pannello 2D del widget.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: sfondo semitrasparente, sottile cornice, staffe luminose
//** agli angoli, titolo a sinistra e stato del dispositivo a destra
//** (PaintStatus). In modalita' modifica aggiunge un contorno tratteggiato
//** color accento e le maniglie (PaintEditFrame). Con lo stile "solo
//** dispositivo" qui si disegna solo, da sbloccato, una velatura invisibile
//** (EDIT_VEIL_ALPHA, a opacita' piena per non scendere a zero con
//** l'opacita' dell'overlay: con i pixel del tutto trasparenti i click
//** attraverserebbero la finestra e il widget non si potrebbe afferrare); il
//** resto e' in AfterPaint, sopra la scena 3D.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.Paint;
const
    L = 16;
var
    rRect, rTextRect: TRectF;
    dOpacity: Single;
begin
    if bFDragging or bFResizing then
    begin
        PaintOutline;
        Exit;
    end;
    rRect := LocalRect;
    dOpacity := AbsoluteOpacity;

    // solo dispositivo: qui solo la velatura (sotto la scena 3D); titolo, stato e
    // cornice di modifica vanno sopra la scena, in AfterPaint
    if bFDeviceOnly then
    begin
        if bFEditMode then
        begin
            Canvas.Fill.Kind := TBrushKind.Solid;
            Canvas.Fill.Color := iWithAlpha(rFColors.iPrimary, EDIT_VEIL_ALPHA);
            Canvas.FillRect(rRect, 0, 0, [], 1);
        end;
        Exit;
    end;

    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := rFColors.iPanelBack;
    Canvas.FillRect(rRect, 6, 6, AllCorners, dOpacity);

    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Stroke.Dash := TStrokeDash.Solid;
    Canvas.Stroke.Color := iWithAlpha(rFColors.iPrimary, $40);
    Canvas.Stroke.Thickness := 1;
    rTextRect := rRect;
    rTextRect.Inflate(-0.5, -0.5);
    Canvas.DrawRect(rTextRect, 6, 6, AllCorners, dOpacity);

    // staffe agli angoli
    Canvas.Stroke.Color := rFColors.iPanelBorder;
    Canvas.Stroke.Thickness := 2;
    Canvas.DrawLine(PointF(rRect.Left + 1, rRect.Top + 1), PointF(rRect.Left + 1 + L, rRect.Top + 1),
        dOpacity);
    Canvas.DrawLine(PointF(rRect.Left + 1, rRect.Top + 1), PointF(rRect.Left + 1, rRect.Top + 1 + L),
        dOpacity);
    Canvas.DrawLine(PointF(rRect.Right - 1, rRect.Top + 1), PointF(rRect.Right - 1 - L, rRect.Top + 1),
        dOpacity);
    Canvas.DrawLine(PointF(rRect.Right - 1, rRect.Top + 1), PointF(rRect.Right - 1, rRect.Top + 1 + L),
        dOpacity);
    Canvas.DrawLine(PointF(rRect.Left + 1, rRect.Bottom - 1), PointF(rRect.Left + 1 + L, rRect.Bottom - 1),
        dOpacity);
    Canvas.DrawLine(PointF(rRect.Left + 1, rRect.Bottom - 1), PointF(rRect.Left + 1, rRect.Bottom - 1 - L),
        dOpacity);
    Canvas.DrawLine(PointF(rRect.Right - 1, rRect.Bottom - 1), PointF(rRect.Right - 1 - L, rRect.Bottom - 1),
        dOpacity);
    Canvas.DrawLine(PointF(rRect.Right - 1, rRect.Bottom - 1), PointF(rRect.Right - 1, rRect.Bottom - 1 - L),
        dOpacity);

    // linea sotto il titolo
    Canvas.Stroke.Color := iWithAlpha(rFColors.iPrimary, $60);
    Canvas.Stroke.Thickness := 1;
    Canvas.DrawLine(PointF(rRect.Left + 10, rRect.Top + HEADER_H - 2), PointF(rRect.Right - 10, rRect.Top + HEADER_H - 2), dOpacity);

    // titolo
    Canvas.Font.Family := HOLO_FONT;
    Canvas.Font.Size := 11;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.Fill.Color := rFColors.iText;
    Canvas.FillText(RectF(rRect.Left + 10, rRect.Top + 2, rRect.Right - 90, rRect.Top + HEADER_H - 2),
        sTitle,
        False, dOpacity, [], TTextAlign.Leading, TTextAlign.Center);

    PaintStatus(rRect, dOpacity);

    if bFEditMode then
        PaintEditFrame(rRect, dOpacity);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.AfterPaint
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare sopra la scena 3D le scritte dello stile "solo dispositivo".
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: FMX la chiama dopo aver disegnato i controlli figli (il
//** viewport 3D, che in questo stile occupa tutto il widget); durante
//** spostamento e ridimensionamento il disegno e' quello di PaintOutline.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.AfterPaint;
begin
    inherited;
    if bFDeviceOnly and not (bFDragging or bFResizing) then
        PaintDeviceOnly;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.DoMouseEnter
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Mostrare titolo e cornice di un widget "solo dispositivo" quando il mouse ci entra.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.DoMouseEnter;
begin
    inherited;
    if bFDeviceOnly and bFEditMode then
        Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.DoMouseLeave
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Nascondere titolo e cornice di un widget "solo dispositivo" quando il mouse esce.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.DoMouseLeave;
begin
    inherited;
    if bFDeviceOnly and bFEditMode then
        Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.PaintStatus
//** Parametri di ingresso: rARect: TRectF; dAOpacity: Single
//** Parametri di uscita: nessuno
//** Scopo: Disegnare lo stato del dispositivo (etichetta e pallino) in alto a destra.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: etichetta del dispositivo (es. JOY ID 1) nel colore
//** primario se collegato, nel colore accento con "OFFLINE" se scollegato;
//** "NESSUN MODELLO" se il modello scelto non esiste.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.PaintStatus(const rARect: TRectF; dAOpacity: Single);
var
    sStatus: string;
begin
    if oFModel <> nil then
    begin
        sStatus := oFModel.sDeviceLabel(rFCfg);
        if not bFConnected then
            sStatus := sStatus + sTr('widget.offline', '  OFFLINE');
    end
    else
        sStatus := sTr('widget.nomodel', 'NESSUN MODELLO');
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Font.Family := HOLO_FONT;
    Canvas.Font.Size := 9;
    Canvas.Font.Style := [];
    if bFConnected then
        Canvas.Fill.Color := rFColors.iPrimary
    else
        Canvas.Fill.Color := rFColors.iAccent;
    Canvas.FillText(RectF(rARect.Right - 160, rARect.Top + 2, rARect.Right - 22, rARect.Top + HEADER_H - 2),
        sStatus,
        False, dAOpacity, [], TTextAlign.Trailing, TTextAlign.Center);
    Canvas.FillEllipse(RectF(rARect.Right - 17, rARect.Top + 8, rARect.Right - 10, rARect.Top + 15),
        dAOpacity);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.PaintEditFrame
//** Parametri di ingresso: rARect: TRectF; dAOpacity: Single
//** Parametri di uscita: nessuno
//** Scopo: Disegnare il contorno tratteggiato e le maniglie di ridimensionamento (layout sbloccato).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.PaintEditFrame(const rARect: TRectF; dAOpacity: Single);
var
    rTextRect: TRectF;
begin
    Canvas.Stroke.Color := rFColors.iAccent;
    Canvas.Stroke.Dash := TStrokeDash.Dash;
    Canvas.Stroke.Thickness := 1;
    rTextRect := rARect;
    rTextRect.Inflate(-3, -3);
    Canvas.DrawRect(rTextRect, 4, 4, AllCorners, dAOpacity);
    Canvas.Stroke.Dash := TStrokeDash.Solid;
    // maniglie di ridimensionamento: angoli e meta' dei lati
    Canvas.Fill.Color := rFColors.iAccent;
    Canvas.FillRect(RectF(rARect.Left, rARect.Top, rARect.Left + 7, rARect.Top + 7), 0, 0, [], dAOpacity);
    Canvas.FillRect(RectF(rARect.Right - 7, rARect.Top, rARect.Right, rARect.Top + 7), 0, 0, [], dAOpacity);
    Canvas.FillRect(RectF(rARect.Left, rARect.Bottom - 7, rARect.Left + 7, rARect.Bottom), 0, 0, [],
        dAOpacity);
    Canvas.FillRect(RectF(rARect.Right - 7, rARect.Bottom - 7, rARect.Right, rARect.Bottom), 0, 0, [],
        dAOpacity);
    Canvas.FillRect(RectF(rARect.CenterPoint.X - 8, rARect.Top, rARect.CenterPoint.X + 8, rARect.Top + 4), 0,
        0, [], dAOpacity);
    Canvas.FillRect(RectF(rARect.CenterPoint.X - 8, rARect.Bottom - 4, rARect.CenterPoint.X + 8,
        rARect.Bottom), 0, 0, [], dAOpacity);
    Canvas.FillRect(RectF(rARect.Left, rARect.CenterPoint.Y - 8, rARect.Left + 4, rARect.CenterPoint.Y + 8),
        0, 0, [], dAOpacity);
    Canvas.FillRect(RectF(rARect.Right - 4, rARect.CenterPoint.Y - 8, rARect.Right, rARect.CenterPoint.Y
        + 8), 0, 0, [], dAOpacity);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.PaintDeviceOnly
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare il widget nello stile "solo dispositivo" (nessun pannello).
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: chiamata da AfterPaint, quindi sopra la scena 3D. Di norma
//** non disegna nulla (resta visibile solo il modello 3D) tranne lo stato, se
//** il dispositivo non e' collegato o il modello non esiste. Solo da
//** sbloccato e con il mouse sopra il widget (o durante la rotazione o lo
//** spostamento della vista) disegna titolo, stato, contorno tratteggiato e maniglie (la
//** velatura invisibile che rende afferrabile il widget e' in Paint).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.PaintDeviceOnly;
var
    rRect: TRectF;
    dOpacity: Single;
begin
    rRect := LocalRect;
    dOpacity := AbsoluteOpacity;
    if not bFEditMode or not (IsMouseOver or bFRotating or bFPanning) then
    begin
        if (oFModel = nil) or not bFConnected then
            PaintStatus(rRect, dOpacity);
        Exit;
    end;
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Font.Family := HOLO_FONT;
    Canvas.Font.Size := 11;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.Fill.Color := rFColors.iText;
    Canvas.FillText(RectF(rRect.Left + 10, rRect.Top + 2, rRect.Right - 90, rRect.Top + HEADER_H - 2),
        sTitle,
        False, dOpacity, [], TTextAlign.Leading, TTextAlign.Center);
    PaintStatus(rRect, dOpacity);
    PaintEditFrame(rRect, dOpacity);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.SetEditMode
//** Parametri di ingresso: bValue: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Attivare/disattivare il trascinamento con il mouse.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.SetEditMode(const bValue: Boolean);
begin
    if bFEditMode = bValue then
        Exit;
    bFEditMode := bValue;
    if bFResizing or bFDragging then
        SetOutlineOnly(False);
    if bFDragging then
        HideGuides;
    bFResizing := False;
    bFDragging := False;
    bFRotating := False;
    bFPanning := False;
    if bValue then
        Cursor := crSizeAll
    else
        Cursor := crDefault;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceWidget.eEdgesAt
//** Parametri di ingresso: dAPosX, dAPosY: Single
//** Parametri di uscita: Result: TResizeEdges
//** Scopo: Lati della cornice sotto il punto (X, Y) in coordinate locali.
//** Data Ultima Modifica: 23/10/2026
//***********************************************************************************************************
//** Funzionamento: un lato e' "afferrato" se il punto e' entro RESIZE_BORDER
//** pixel da esso; vicino a un angolo si afferrano due lati insieme.
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceWidget.eEdgesAt(dAPosX, dAPosY: Single): TResizeEdges;
begin
    Result := [];
    if dAPosX < RESIZE_BORDER then
        Include(Result, reLeft)
    else if dAPosX > Width - RESIZE_BORDER then
        Include(Result, reRight);
    if dAPosY < RESIZE_BORDER then
        Include(Result, reTop)
    else if dAPosY > Height - RESIZE_BORDER then
        Include(Result, reBottom);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.UpdateCursor
//** Parametri di ingresso: dAPosX, dAPosY: Single
//** Parametri di uscita: nessuno
//** Scopo: Mostrare il cursore adatto (frecce di ridimensionamento sui bordi, croce di spostamento
//**        all'interno).
//** Data Ultima Modifica: 23/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.UpdateCursor(dAPosX, dAPosY: Single);
var
    eEdges: TResizeEdges;
    eCursor: TCursor;
begin
    eEdges := eEdgesAt(dAPosX, dAPosY);
    if (eEdges = [reLeft, reTop]) or (eEdges = [reRight, reBottom]) then
        eCursor := crSizeNWSE
    else if (eEdges = [reRight, reTop]) or (eEdges = [reLeft, reBottom]) then
        eCursor := crSizeNESW
    else if (eEdges = [reLeft]) or (eEdges = [reRight]) then
        eCursor := crSizeWE
    else if (eEdges = [reTop]) or (eEdges = [reBottom]) then
        eCursor := crSizeNS
    else
        eCursor := crSizeAll;
    if Cursor <> eCursor then
        Cursor := eCursor;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.SetOutlineOnly
//** Parametri di ingresso: bAValue: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Entrare/uscire dalla modalita' "solo contorno" usata durante spostamento e
//**        ridimensionamento.
//** Data Ultima Modifica: 25/10/2026
//***********************************************************************************************************
//** Funzionamento: all'inizio nasconde la scena 3D (il viewport) e ridisegna
//** il widget come semplice contorno; alla fine rimostra la scena, che si
//** adatta alla nuova dimensione al primo Tick (FitCamera).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.SetOutlineOnly(bAValue: Boolean);
begin
    oFViewport.Visible := not bAValue;
    if not bAValue then
        dFLastW := -1;   // forza FitCamera con la nuova dimensione
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.PaintOutline
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare il widget come solo contorno (durante spostamento o ridimensionamento):
//**        cornice tratteggiata nel colore accento, staffe agli angoli, nome del widget e misure
//**        correnti al centro. Nessuno sfondo.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.PaintOutline;
const
    L = 18;
var
    rRect: TRectF;
begin
    rRect := LocalRect;
    rRect.Inflate(-1, -1);
    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Stroke.Color := rFColors.iAccent;
    Canvas.Stroke.Thickness := 2;
    Canvas.Stroke.Dash := TStrokeDash.Dash;
    Canvas.DrawRect(rRect, 6, 6, AllCorners, 1);
    Canvas.Stroke.Dash := TStrokeDash.Solid;
    Canvas.DrawLine(PointF(rRect.Left, rRect.Top), PointF(rRect.Left + L, rRect.Top), 1);
    Canvas.DrawLine(PointF(rRect.Left, rRect.Top), PointF(rRect.Left, rRect.Top + L), 1);
    Canvas.DrawLine(PointF(rRect.Right, rRect.Top), PointF(rRect.Right - L, rRect.Top), 1);
    Canvas.DrawLine(PointF(rRect.Right, rRect.Top), PointF(rRect.Right, rRect.Top + L), 1);
    Canvas.DrawLine(PointF(rRect.Left, rRect.Bottom), PointF(rRect.Left + L, rRect.Bottom), 1);
    Canvas.DrawLine(PointF(rRect.Left, rRect.Bottom), PointF(rRect.Left, rRect.Bottom - L), 1);
    Canvas.DrawLine(PointF(rRect.Right, rRect.Bottom), PointF(rRect.Right - L, rRect.Bottom), 1);
    Canvas.DrawLine(PointF(rRect.Right, rRect.Bottom), PointF(rRect.Right, rRect.Bottom - L), 1);

    Canvas.Font.Family := HOLO_FONT;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := rFColors.iAccent;
    Canvas.Font.Size := 11;
    Canvas.FillText(RectF(rRect.Left, rRect.CenterPoint.Y - 26, rRect.Right, rRect.CenterPoint.Y - 4),
        sKindText(eFKind), False, 1, [], TTextAlign.Center, TTextAlign.Center);
    Canvas.Font.Size := 13;
    Canvas.FillText(RectF(rRect.Left, rRect.CenterPoint.Y, rRect.Right, rRect.CenterPoint.Y + 24),
        Format('%d ' + #$00D7 + ' %d', [Round(Width), Round(Height)]),
        False, 1, [], TTextAlign.Center, TTextAlign.Center);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.MouseDown
//** Parametri di ingresso: Button: TMouseButton; Shift: TShiftState; X, Y: Single
//** Parametri di uscita: nessuno
//** Scopo: Iniziare spostamento o ridimensionamento (solo in modalita' modifica, tasto sinistro)
//**        oppure la rotazione (tasto destro) o lo spostamento verticale (Shift + tasto destro)
//**        della vista.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: se il click e' sulla cornice inizia il ridimensionamento
//** dai lati afferrati, altrimenti lo spostamento (con le linee guida verdi
//** dall'angolo inferiore sinistro); in entrambi i casi la
//** scena 3D sparisce e resta solo il contorno. Per il ridimensionamento si
//** memorizzano il rettangolo iniziale e il punto del mouse in coordinate
//** assolute (il widget si sposta mentre lo si allarga a sinistra o in alto).
//** Con il tasto destro si memorizzano il punto del mouse (coordinate
//** assolute) e la vista di partenza: la rotazione si calcola in MouseMove.
//** Con Shift premuto il tasto destro sposta invece il contenuto in verticale.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
    inherited;
    if bFEditMode and (Button = TMouseButton.mbLeft) then
    begin
        BringToFront;
        eFEdges := eEdgesAt(X, Y);
        rFStartRect := RectF(Position.X, Position.Y, Position.X + Width, Position.Y + Height);
        if eFEdges <> [] then
        begin
            bFResizing := True;
            rFResizeMouse := LocalToAbsolute(PointF(X, Y));
        end
        else
        begin
            bFDragging := True;
            rFDragMouse := LocalToAbsolute(PointF(X, Y));
            bFSnapX := False;
            bFSnapY := False;
            oGuides.ShowAt(PointF(Position.X, Position.Y + Height), False, False);
        end;
        SetOutlineOnly(True);
    end
    else if (Button = TMouseButton.mbRight) and not (bFDragging or bFResizing) and (oFModel <> nil) then
    begin
        rFRotMouse := LocalToAbsolute(PointF(X, Y));
        if ssShift in Shift then
        begin
            bFPanning := True;
            dFPanY0 := rFCfg.dPanY;
            Cursor := crSizeNS;
        end
        else
        begin
            bFRotating := True;
            dFRotTilt0 := rFCfg.dTilt;
            dFRotYaw0 := rFCfg.dYaw;
            Cursor := crHandPoint;
        end;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.MouseMove
//** Parametri di ingresso: Shift: TShiftState; X, Y: Single
//** Parametri di uscita: nessuno
//** Scopo: Spostare o ridimensionare il contorno seguendo il mouse, oppure ruotare o spostare in
//**        verticale la vista.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento:
//**  - rotazione (tasto destro premuto): lo spostamento orizzontale ruota il
//**    modello attorno all'asse verticale (mouse a destra = il davanti del
//**    modello gira verso destra), quello verticale lo inclina (mouse in avanti
//**    = la parte alta si allontana); VIEW_DRAG_DEG gradi per pixel, rotazione
//**    riportata in -180..180, inclinazione limitata a +-VIEW_TILT_LIMIT. La
//**    camera si riadatta subito, cosi' il modello resta inquadrato;
//**  - spostamento verticale (Shift + tasto destro): il contenuto segue il
//**    mouse in verticale (mouse in avanti = su, indietro = giu'), entro
//**    +-VIEW_PAN_LIMIT dell'altezza visibile;
//**  - spostamento: la nuova posizione e' quella iniziale piu' lo spostamento
//**    del mouse in coordinate assolute (cosi' l'aggancio non fa slittare il
//**    punto di presa); SnapPosition la aggancia agli altri widget e le linee
//**    guida seguono l'angolo inferiore sinistro;
//**  - ridimensionamento: lo spostamento del mouse (in coordinate assolute)
//**    viene applicato ai soli lati afferrati, rispettando le dimensioni minime;
//**  - senza operazioni in corso aggiorna il cursore.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.MouseMove(Shift: TShiftState; X, Y: Single);
var
    rDelta: TPointF;
    rRect: TRectF;
    dNewX, dNewY: Single;
begin
    inherited;
    if bFRotating then
    begin
        rDelta := LocalToAbsolute(PointF(X, Y)) - rFRotMouse;
        rFCfg.dYaw := dFRotYaw0 - rDelta.X * VIEW_DRAG_DEG;
        rFCfg.dYaw := rFCfg.dYaw - 360 * Round(rFCfg.dYaw / 360);
        rFCfg.dTilt := EnsureRange(dFRotTilt0 + rDelta.Y * VIEW_DRAG_DEG, -VIEW_TILT_LIMIT, VIEW_TILT_LIMIT);
        ApplyView;
        FitCamera;
    end
    else if bFPanning then
    begin
        rDelta := LocalToAbsolute(PointF(X, Y)) - rFRotMouse;
        rFCfg.dPanY := EnsureRange(dFPanY0 + rDelta.Y / Max(10, oFViewport.Height), -VIEW_PAN_LIMIT,
            VIEW_PAN_LIMIT);
        FitCamera;
    end
    else if bFResizing then
    begin
        rDelta := LocalToAbsolute(PointF(X, Y)) - rFResizeMouse;
        rRect := rFStartRect;
        if reLeft in eFEdges then
            rRect.Left := Min(rRect.Left + rDelta.X, rRect.Right - WIDGET_MIN_W);
        if reRight in eFEdges then
            rRect.Right := Max(rRect.Right + rDelta.X, rRect.Left + WIDGET_MIN_W);
        if reTop in eFEdges then
            rRect.Top := Min(rRect.Top + rDelta.Y, rRect.Bottom - WIDGET_MIN_H);
        if reBottom in eFEdges then
            rRect.Bottom := Max(rRect.Bottom + rDelta.Y, rRect.Top + WIDGET_MIN_H);
        SetBounds(rRect.Left, rRect.Top, rRect.Width, rRect.Height);
        Repaint;
    end
    else if bFDragging then
    begin
        rDelta := LocalToAbsolute(PointF(X, Y)) - rFDragMouse;
        dNewX := rFStartRect.Left + rDelta.X;
        dNewY := rFStartRect.Top + rDelta.Y;
        SnapPosition(dNewX, dNewY);
        Position.Point := PointF(dNewX, dNewY);
        oGuides.ShowAt(PointF(dNewX, dNewY + Height), bFSnapX, bFSnapY);
    end
    else if bFEditMode then
        UpdateCursor(X, Y);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.MouseUp
//** Parametri di ingresso: Button: TMouseButton; Shift: TShiftState; X, Y: Single
//** Parametri di uscita: nessuno
//** Scopo: Terminare spostamento, ridimensionamento, rotazione o spostamento verticale della vista.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: al rilascio del tasto destro termina la rotazione (o lo
//** spostamento verticale) e, se la vista e' cambiata, avvisa la form
//** principale (mOnViewChanged) che la salva.
//** Per spostamento e ridimensionamento nasconde le linee guida e allinea
//** posizione (e dimensioni) a una griglia di 4 px (tranne le coordinate
//** agganciate a un altro widget, che restano esatte), rimostra la scena 3D e avvisa la form principale,
//** che aggiorna la configurazione (e quindi i valori del Setup) e ricalcola
//** la disposizione. Un semplice click senza movimento non cambia nulla.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
    bWasResize: Boolean;
    bChanged: Boolean;
    dNewX, dNewY: Single;
begin
    inherited;
    if bFPanning and (Button = TMouseButton.mbRight) then
    begin
        bFPanning := False;
        if bFEditMode then
            Cursor := crSizeAll
        else
            Cursor := crDefault;
        if not SameValue(rFCfg.dPanY, dFPanY0) and Assigned(mFOnViewChanged) then
            mFOnViewChanged(Self);
        if bFDeviceOnly then
            Repaint;
        Exit;
    end;
    if bFRotating and (Button = TMouseButton.mbRight) then
    begin
        bFRotating := False;
        if bFEditMode then
            Cursor := crSizeAll
        else
            Cursor := crDefault;
        if not (SameValue(rFCfg.dTilt, dFRotTilt0) and SameValue(rFCfg.dYaw, dFRotYaw0)) and
            Assigned(mFOnViewChanged) then
            mFOnViewChanged(Self);
        if bFDeviceOnly then
            Repaint;   // "solo dispositivo": la cornice resta solo se il mouse e' ancora sopra
        Exit;
    end;
    if not (bFResizing or bFDragging) then
        Exit;
    bWasResize := bFResizing;
    bFResizing := False;
    bFDragging := False;
    HideGuides;
    if bWasResize then
        SetBounds(Round(Position.X / 4) * 4, Round(Position.Y / 4) * 4,
            Max(WIDGET_MIN_W, Round(Width / 4) * 4), Max(WIDGET_MIN_H, Round(Height / 4) * 4))
    else
    begin
        // la griglia di 4 px vale solo per le coordinate non agganciate a un altro widget
        if bFSnapX then
            dNewX := Round(Position.X)
        else
            dNewX := Round(Position.X / 4) * 4;
        if bFSnapY then
            dNewY := Round(Position.Y)
        else
            dNewY := Round(Position.Y / 4) * 4;
        Position.Point := PointF(dNewX, dNewY);
    end;
    bChanged := RectF(Position.X, Position.Y, Position.X + Width, Position.Y + Height) <> rFStartRect;
    SetOutlineOnly(False);
    if not bChanged then
        Exit;
    if bWasResize then
    begin
        if Assigned(mFOnResized) then
            mFOnResized(Self);
    end
    else if Assigned(mFOnMoved) then
        mFOnMoved(Self);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.MouseWheel
//** Parametri di ingresso: Shift: TShiftState; WheelDelta: Integer; Handled: Boolean (var)
//** Parametri di uscita: Handled: Boolean (var)
//** Scopo: Ingrandire o rimpicciolire il modello con la rotella del mouse.
//** Data Ultima Modifica: 26/10/2026
//***********************************************************************************************************
//** Funzionamento: rotella in avanti (dWheelDelta positivo) = zoom in,
//** indietro = zoom out; ogni scatto (120 unita') moltiplica o divide lo zoom
//** per VIEW_ZOOM_STEP, entro VIEW_ZOOM_MIN..VIEW_ZOOM_MAX. Lo zoom agisce
//** sulla distanza della camera (FitCamera), quindi il modello resta centrato.
//** La form principale viene avvisata (mOnViewChanged) per salvarlo nel .ini.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
var
    dZoom: Single;
begin
    inherited;
    if (oFModel = nil) or bFDragging or bFResizing or (WheelDelta = 0) then
        Exit;
    dZoom := rFCfg.dZoom * Power(VIEW_ZOOM_STEP, WheelDelta / 120);
    dZoom := EnsureRange(dZoom, VIEW_ZOOM_MIN, VIEW_ZOOM_MAX);
    Handled := True;
    if SameValue(dZoom, rFCfg.dZoom) then
        Exit;
    rFCfg.dZoom := dZoom;
    FitCamera;
    if Assigned(mFOnViewChanged) then
        mFOnViewChanged(Self);
end;

end.
