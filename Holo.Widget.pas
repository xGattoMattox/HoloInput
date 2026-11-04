//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Widget
//** Scopo: Widget che mostra UN dispositivo: pannello 2D (cornice, titolo, stato) con una scena 3D.
//** Data Ultima Modifica: 31/10/2026
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
        FCorner: TPointF;
        FSnapX, FSnapY: Boolean;
    protected
        procedure Paint; override;
    public
        constructor Create(AOwner: TComponent); override;
        procedure ShowAt(const ACorner: TPointF; ASnapX, ASnapY: Boolean);
    end;

    TDeviceWidget = class(TControl)
    private
        FKind: TDeviceKind;
        FCfg: TWidgetConfig;
        FColors: TSkinColors;
        FKit: THoloKit;
        FViewport: TViewport3D;
        FCamera: TCamera;
        FStage: TDummy;
        FWorld: TDummy;
        FModelRoot: TDummy;
        FModel: TDeviceModel;
        FModelClass: TDeviceModelClass;
        FRingOuter, FRingInner: THoloRing;
        FScan: THoloShape;
        FShowLegends: Boolean;
        FDeviceOnly: Boolean;              // stile "solo dispositivo" (nessun pannello)
        FBaseEffects: Boolean;             // anelli del proiettore e scanline visibili
        FLangVersion: Integer;                 // lingua con cui e' stato costruito il modello
        FEffW, FEffH, FEffD: Single;
        FTime: Single;
        FLastW, FLastH: Single;
        FConnected: Boolean;
        FEditMode, FDragging, FResizing: Boolean;
        FDragMouse: TPointF;               // punto di presa (coordinate assolute) all'inizio dello spostamento
        FSnapX, FSnapY: Boolean;           // spostamento agganciato in X (linea verticale) / Y (orizzontale)
        FEdges: TResizeEdges;
        FStartRect: TRectF;
        FResizeMouse: TPointF;
        FAnimating: Boolean;
        FOnMoved: TNotifyEvent;
        FOnResized: TNotifyEvent;
        FRotating: Boolean;                // rotazione della vista con il tasto destro
        FRotMouse: TPointF;
        FRotTilt0, FRotYaw0: Single;
        FOnViewChanged: TNotifyEvent;
        function EdgesAt(X, Y: Single): TResizeEdges;
        procedure UpdateCursor(X, Y: Single);
        procedure SetOutlineOnly(AValue: Boolean);
        procedure PaintOutline;
        procedure PaintStatus(const R: TRectF; Op: Single);
        procedure PaintEditFrame(const R: TRectF; Op: Single);
        procedure PaintDeviceOnly;
        procedure CreateModel;
        procedure FitCamera;
        procedure ApplyView;
        procedure ApplyEffects;
        procedure SetEditMode(const Value: Boolean);
        function Title: string;
        function Guides: TWidgetGuides;
        procedure SnapPosition(var ALeft, ATop: Single);
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
        constructor CreateWidget(AOwner: TComponent; AKind: TDeviceKind);
        destructor Destroy; override;
        procedure Configure(const ACfg: TWidgetConfig; const AColors: TSkinColors; AShowLegends: Boolean);
        procedure BindDevices(AInput: TInputManager);
        /// Stile del widget: solo dispositivo (sfondo trasparente) ed effetti di base.
        procedure SetStyle(ADeviceOnly, ABaseEffects: Boolean);
        procedure Tick(const S: TInputSnapshot; ADeltaT: Single; AAnimate: Boolean);
        property Kind: TDeviceKind read FKind;
        property EditMode: Boolean read FEditMode write SetEditMode;
        property OnMoved: TNotifyEvent read FOnMoved write FOnMoved;
        /// Chiamato al termine di un ridimensionamento fatto con il mouse.
        property OnResized: TNotifyEvent read FOnResized write FOnResized;
        /// Chiamato al termine di una rotazione della vista (tasto destro) e a ogni
        /// scatto della rotella (zoom).
        property OnViewChanged: TNotifyEvent read FOnViewChanged write FOnViewChanged;
        /// Correzioni della vista impostate con il mouse (gradi).
        property ViewTilt: Single read FCfg.Tilt;
        property ViewYaw: Single read FCfg.Yaw;
        property ViewZoom: Single read FCfg.Zoom;
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
//** Parametri di ingresso: ACorner: TPointF; ASnapX, ASnapY: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Mostrare le linee guida passanti per ACorner (coordinate del contenitore).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: occupa tutto il contenitore dei widget (il genitore), resta
//** in primo piano sopra i widget e si ridisegna con la nuova posizione;
//** ASnapX / ASnapY indicano le linee agganciate a un altro widget.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TWidgetGuides.ShowAt(const ACorner: TPointF; ASnapX, ASnapY: Boolean);
begin
    if ParentControl <> nil then
        SetBounds(0, 0, ParentControl.Width, ParentControl.Height);
    FCorner := ACorner;
    FSnapX := ASnapX;
    FSnapY := ASnapY;
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
    //** Parametri di ingresso: ASnapped: Boolean
    //** Parametri di uscita: nessuno
    //** Scopo: Impostare il tratto della linea: pieno se agganciata, tratteggiato se libera.
    //** Data Ultima Modifica: 30/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure SetPen(ASnapped: Boolean);
    begin
        Canvas.Stroke.Kind := TBrushKind.Solid;
        if ASnapped then
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
    X, Y: Single;
begin
    X := Round(FCorner.X) + 0.5;
    Y := Round(FCorner.Y) - 0.5;
    SetPen(FSnapX);
    Canvas.DrawLine(PointF(X, 0), PointF(X, Height), 1);
    SetPen(FSnapY);
    Canvas.DrawLine(PointF(0, Y), PointF(Width, Y), 1);
    Canvas.Stroke.Dash := TStrokeDash.Solid;
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := GUIDE_COLOR;
    Canvas.FillEllipse(RectF(X - 4, Y - 4, X + 4, Y + 4), 1);
end;

//** TDeviceWidget: linee guida e aggancio ******************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceWidget.Guides
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TWidgetGuides
//** Scopo: Linee guida condivise dai widget dello stesso contenitore (create alla prima richiesta).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceWidget.Guides: TWidgetGuides;
var
    I: Integer;
begin
    Result := nil;
    if Parent = nil then
        Exit;
    for I := 0 to Parent.ChildrenCount - 1 do
        if Parent.Children[I] is TWidgetGuides then
            Exit(TWidgetGuides(Parent.Children[I]));
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
    G: TWidgetGuides;
begin
    G := Guides;
    if G <> nil then
        G.Visible := False;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.SnapPosition
//** Parametri di ingresso: ALeft, ATop: Single (var)
//** Parametri di uscita: ALeft, ATop: Single (var)
//** Scopo: Agganciare le linee guida del widget trascinato ai lati degli altri widget visibili.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: la linea verticale (lato sinistro, ALeft) si aggancia al
//** lato sinistro o destro piu' vicino di un altro widget, quella orizzontale
//** (lato inferiore, ATop + Height) al lato superiore o inferiore piu' vicino,
//** se distano al massimo SNAP_DIST pixel; le due linee sono indipendenti.
//** Aggiorna FSnapX / FSnapY.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.SnapPosition(var ALeft, ATop: Single);
var
    I: Integer;
    W: TDeviceWidget;
    BestX, BestY, Bottom: Single;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: Try1
    //** Parametri di ingresso: AValue, ATarget: Single; ABest: Single (var)
    //** Parametri di uscita: ABest: Single (var)
    //** Scopo: Tenere in ABest la distanza (con segno) dal bersaglio piu' vicino entro SNAP_DIST.
    //** Data Ultima Modifica: 30/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Try1(AValue, ATarget: Single; var ABest: Single);
    begin
        if (Abs(ATarget - AValue) <= SNAP_DIST) and (Abs(ATarget - AValue) < Abs(ABest)) then
            ABest := ATarget - AValue;
    end;

begin
    FSnapX := False;
    FSnapY := False;
    if Parent = nil then
        Exit;
    BestX := SNAP_DIST + 1;
    BestY := SNAP_DIST + 1;
    Bottom := ATop + Height;
    for I := 0 to Parent.ChildrenCount - 1 do
    begin
        if not (Parent.Children[I] is TDeviceWidget) then
            Continue;
        W := TDeviceWidget(Parent.Children[I]);
        if (W = Self) or not W.Visible then
            Continue;
        Try1(ALeft, W.Position.X, BestX);
        Try1(ALeft, W.Position.X + W.Width, BestX);
        Try1(Bottom, W.Position.Y, BestY);
        Try1(Bottom, W.Position.Y + W.Height, BestY);
    end;
    if Abs(BestX) <= SNAP_DIST then
    begin
        ALeft := ALeft + BestX;
        FSnapX := True;
    end;
    if Abs(BestY) <= SNAP_DIST then
    begin
        ATop := ATop + BestY;
        FSnapY := True;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.CreateWidget
//** Parametri di ingresso: AOwner: TComponent; AKind: TDeviceKind
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare il widget e la sua scena 3D vuota.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: il viewport ha sfondo trasparente e non intercetta il mouse
//** (cosi' il trascinamento arriva al widget); la camera e' puntata sullo Stage.
//***********************************************************************************************************
//***********************************************************************************************************
constructor TDeviceWidget.CreateWidget(AOwner: TComponent; AKind: TDeviceKind);
begin
    inherited Create(AOwner);
    FKind := AKind;
    FColors := DefaultSkinColors;
    FBaseEffects := True;
    HitTest := True;
    // il widget resta fermo mentre si trascina la sagoma: senza la cattura del
    // mouse, appena il puntatore esce dal widget (per ingrandirlo o spostarlo)
    // i movimenti andrebbero ad altri controlli e l'operazione si bloccherebbe
    AutoCapture := True;

    FViewport := TViewport3D.Create(Self);
    FViewport.Parent := Self;
    FViewport.Align := TAlignLayout.Client;
    FViewport.Margins.Rect := RectF(4, HEADER_H, 4, 4);
    FViewport.Color := TAlphaColors.Null;
    FViewport.HitTest := False;
    FViewport.Multisample := TMultisample.FourSamples;

    FStage := TDummy.Create(Self);
    FStage.Parent := FViewport;

    FWorld := TDummy.Create(Self);
    FWorld.Parent := FStage;

    FCamera := TCamera.Create(Self);
    FCamera.Parent := FViewport;
    FCamera.AngleOfView := 30;
    FCamera.Target := FStage;
    FCamera.Position.Point := Point3D(0, -6, -20);
    FViewport.UsingDesignCamera := False;
    FViewport.Camera := FCamera;
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
    FreeAndNil(FModel);
    FreeAndNil(FModelRoot);
    FreeAndNil(FRingOuter);
    FreeAndNil(FRingInner);
    FreeAndNil(FScan);
    inherited;
    FreeAndNil(FKit);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.CreateModel
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: (ri)creare il modello 3D scelto nella configurazione.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: elimina il modello precedente e le decorazioni, crea la
//** nuova radice sotto World, istanzia la classe del modello e aggiunge il
//** "proiettore" (due anelli) e la scanline nello Stage (visibili secondo
//** l'opzione degli effetti di base).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.CreateModel;
begin
    FreeAndNil(FModel);
    FreeAndNil(FModelRoot);
    FreeAndNil(FRingOuter);
    FreeAndNil(FRingInner);
    FreeAndNil(FScan);

    FModelClass := FindModel(FKind, FCfg.ModelId);
    FModelRoot := FKit.Pivot(FWorld, 0, 0, 0);
    if FModelClass <> nil then
        FModel := FModelClass.Create(FKit, FModelRoot);

    FRingOuter := FKit.Ring(FStage, 0, 0, 0, 1, True, hsNormal);
    FRingInner := FKit.Ring(FStage, 0, 0, 0, 1, False, hsDim);
    FScan := FKit.Box(FStage, 0, 0, 0, 1, 0.02, 1, hsScan);
    FScan.Visible := False;
    ApplyEffects;
    FLastW := -1;   // forza FitCamera al prossimo Tick
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.Configure
//** Parametri di ingresso: ACfg: TWidgetConfig; AColors: TSkinColors; AShowLegends: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Applicare configurazione, skin e legende al widget.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: crea il kit alla prima chiamata; ricrea il modello solo se
//** il modello scelto o l'opzione legende sono cambiati, altrimenti aggiorna
//** solo colori e vista.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.Configure(const ACfg: TWidgetConfig; const AColors: TSkinColors;
    AShowLegends: Boolean);
var
    NewClass: TDeviceModelClass;
begin
    FCfg := ACfg;
    FColors := AColors;
    if FKit = nil then
        FKit := THoloKit.Create(AColors)
    else
        FKit.ApplyColors(AColors);

    NewClass := FindModel(FKind, ACfg.ModelId);
    // il modello si ricostruisce anche se e' cambiata la lingua (legende 3D)
    if (FModel = nil) or (NewClass <> FModelClass) or (AShowLegends <> FShowLegends) or
        (FLangVersion <> LanguageVersion) then
    begin
        FLangVersion := LanguageVersion;
        FShowLegends := AShowLegends;
        FKit.ShowLegends := AShowLegends;
        CreateModel;
    end
    else if FModel <> nil then
        FModel.SkinChanged;
    ApplyView;
    FLastW := -1;
    FWorld.Repaint;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.BindDevices
//** Parametri di ingresso: AInput: TInputManager
//** Parametri di uscita: nessuno
//** Scopo: Registrare i dispositivi del modello presso il gestore degli input.
//** Data Ultima Modifica: 27/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.BindDevices(AInput: TInputManager);
begin
    if FModel <> nil then
        FModel.BindDevices(AInput, FCfg);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.SetStyle
//** Parametri di ingresso: ADeviceOnly, ABaseEffects: Boolean
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
procedure TDeviceWidget.SetStyle(ADeviceOnly, ABaseEffects: Boolean);
begin
    FBaseEffects := ABaseEffects;
    if ADeviceOnly <> FDeviceOnly then
    begin
        FDeviceOnly := ADeviceOnly;
        if FDeviceOnly then
            FViewport.Margins.Rect := RectF(0, 0, 0, 0)
        else
            FViewport.Margins.Rect := RectF(4, HEADER_H, 4, 4);
        FLastW := -1;   // forza FitCamera con la nuova area del viewport
    end;
    ApplyEffects;
    Repaint;
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
    if FRingOuter <> nil then
        FRingOuter.Visible := FBaseEffects;
    if FRingInner <> nil then
        FRingInner.Visible := FBaseEffects;
    if (FScan <> nil) and not FBaseEffects then
        FScan.Visible := False;
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
    V: TModelView;
begin
    if FModelClass <> nil then
        V := FModelClass.DefaultView
    else
        V := MakeView(0, 0);
    FWorld.RotationAngle.X := (V.Tilt + FCfg.Tilt) * ROT_SIGN;
    FWorld.RotationAngle.Y := (V.Yaw + FCfg.Yaw) * ROT_SIGN;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.FitCamera
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Posizionare la camera in modo che il modello riempia il riquadro.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: stima l'ingombro apparente del modello dopo le rotazioni
//** della vista, calcola la distanza necessaria in verticale e in orizzontale
//** (in base al campo visivo e alle proporzioni del viewport), prende la
//** maggiore e applica lo zoom dell'utente. Dimensiona anche anelli e scanline.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.FitCamera;
var
    E: TPoint3D;
    V: TModelView;
    T, Yw, El, W1, D1, H2, D2, HV, Aspect, TanH, DistH, DistW, Dist, VW, VH: Single;
begin
    FLastW := Width;
    FLastH := Height;
    if FModel = nil then
        Exit;
    VW := Max(10, FViewport.Width);
    VH := Max(10, FViewport.Height);
    E := FModel.Extent;
    V := FModelClass.DefaultView;
    T := DegToRad(V.Tilt + FCfg.Tilt);
    Yw := DegToRad(V.Yaw + FCfg.Yaw);
    El := DegToRad(CAMERA_ELEVATION);

    W1 := Abs(E.X * Cos(Yw)) + Abs(E.Z * Sin(Yw));
    D1 := Abs(E.X * Sin(Yw)) + Abs(E.Z * Cos(Yw));
    H2 := Abs(E.Y * Cos(T)) + Abs(D1 * Sin(T));
    D2 := Abs(E.Y * Sin(T)) + Abs(D1 * Cos(T));
    HV := H2 * Cos(El) + D2 * Sin(El);

    FEffW := W1;
    FEffH := H2;
    FEffD := D2;

    Aspect := VW / VH;
    TanH := Tan(DegToRad(FCamera.AngleOfView) / 2);
    DistH := (HV / 2) / TanH;
    DistW := (W1 / 2) / (TanH * Aspect);
    Dist := (Max(DistH, DistW) * 1.10 + D2 / 2) / Max(0.3, FCfg.Zoom);

    FCamera.Position.Point := Point3D(0, -Dist * Sin(El), -Dist * Cos(El));

    if FRingOuter <> nil then
    begin
        FRingOuter.SetRadius(Max(W1, D2) * 0.52);
        FRingOuter.Position.Y := H2 / 2 + 0.15;
        FRingInner.SetRadius(Max(W1, D2) * 0.40);
        FRingInner.Position.Y := H2 / 2 + 0.15;
        FScan.SetShapeSize(Point3D(W1 * 1.04, 0.02, D2 * 1.04));
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.Tick
//** Parametri di ingresso: S: TInputSnapshot; ADeltaT: Single; AAnimate: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Aggiornare il widget ad ogni frame.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: riadatta la camera se il riquadro e' cambiato, passa gli
//** input al modello, aggiorna l'indicatore di collegamento e, se abilitate,
//** le animazioni olografiche (anello rotante, scanline, sfarfallio); la
//** scanline compare solo con gli effetti di base attivi.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.Tick(const S: TInputSnapshot; ADeltaT: Single; AAnimate: Boolean);
var
    Conn: Boolean;
    Ph: Single;
begin
    if (FModel = nil) or not Visible or FDragging or FResizing then
        Exit;
    if not (SameValue(Width, FLastW) and SameValue(Height, FLastH)) then
        FitCamera;

    FModel.Update(S, FCfg, ADeltaT);

    Conn := FModel.IsConnected(S, FCfg);
    if Conn <> FConnected then
    begin
        FConnected := Conn;
        Repaint;
    end;

    if AAnimate then
    begin
        FAnimating := True;
        FTime := FTime + ADeltaT;
        FRingOuter.RotationAngle.Y := Frac(FTime / 12) * 360;
        FRingInner.RotationAngle.Y := -Frac(FTime / 20) * 360;
        Ph := Frac(FTime / 3.2);
        FScan.Visible := FBaseEffects;
        FScan.Position.Y := -FEffH / 2 + Ph * FEffH;
        SetObjOpacity(FScan, Sin(Ph * Pi));
        // leggero sfarfallio olografico
        SetObjOpacity(FWorld, 0.93 + 0.05 * Sin(FTime * 9.1) + 0.02 * Sin(FTime * 23.7));
    end
    else if FAnimating then
    begin
        FAnimating := False;
        FScan.Visible := False;
        SetObjOpacity(FWorld, 1);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceWidget.Title
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Testo dell'intestazione (tipologia + modello).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceWidget.Title: string;
begin
    Result := KindText(FKind);
    if FModelClass <> nil then
        Result := Result + '  ' + #$00B7 + '  ' + UpperCase(FModelClass.DisplayName);
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
    R, RT: TRectF;
    Op: Single;
begin
    if FDragging or FResizing then
    begin
        PaintOutline;
        Exit;
    end;
    R := LocalRect;
    Op := AbsoluteOpacity;

    // solo dispositivo: qui solo la velatura (sotto la scena 3D); titolo, stato e
    // cornice di modifica vanno sopra la scena, in AfterPaint
    if FDeviceOnly then
    begin
        if FEditMode then
        begin
            Canvas.Fill.Kind := TBrushKind.Solid;
            Canvas.Fill.Color := WithAlpha(FColors.Primary, EDIT_VEIL_ALPHA);
            Canvas.FillRect(R, 0, 0, [], 1);
        end;
        Exit;
    end;

    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := FColors.PanelBack;
    Canvas.FillRect(R, 6, 6, AllCorners, Op);

    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Stroke.Dash := TStrokeDash.Solid;
    Canvas.Stroke.Color := WithAlpha(FColors.Primary, $40);
    Canvas.Stroke.Thickness := 1;
    RT := R;
    RT.Inflate(-0.5, -0.5);
    Canvas.DrawRect(RT, 6, 6, AllCorners, Op);

    // staffe agli angoli
    Canvas.Stroke.Color := FColors.PanelBorder;
    Canvas.Stroke.Thickness := 2;
    Canvas.DrawLine(PointF(R.Left + 1, R.Top + 1), PointF(R.Left + 1 + L, R.Top + 1), Op);
    Canvas.DrawLine(PointF(R.Left + 1, R.Top + 1), PointF(R.Left + 1, R.Top + 1 + L), Op);
    Canvas.DrawLine(PointF(R.Right - 1, R.Top + 1), PointF(R.Right - 1 - L, R.Top + 1), Op);
    Canvas.DrawLine(PointF(R.Right - 1, R.Top + 1), PointF(R.Right - 1, R.Top + 1 + L), Op);
    Canvas.DrawLine(PointF(R.Left + 1, R.Bottom - 1), PointF(R.Left + 1 + L, R.Bottom - 1), Op);
    Canvas.DrawLine(PointF(R.Left + 1, R.Bottom - 1), PointF(R.Left + 1, R.Bottom - 1 - L), Op);
    Canvas.DrawLine(PointF(R.Right - 1, R.Bottom - 1), PointF(R.Right - 1 - L, R.Bottom - 1), Op);
    Canvas.DrawLine(PointF(R.Right - 1, R.Bottom - 1), PointF(R.Right - 1, R.Bottom - 1 - L), Op);

    // linea sotto il titolo
    Canvas.Stroke.Color := WithAlpha(FColors.Primary, $60);
    Canvas.Stroke.Thickness := 1;
    Canvas.DrawLine(PointF(R.Left + 10, R.Top + HEADER_H - 2), PointF(R.Right - 10, R.Top + HEADER_H - 2), Op);

    // titolo
    Canvas.Font.Family := HOLO_FONT;
    Canvas.Font.Size := 11;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.Fill.Color := FColors.Text;
    Canvas.FillText(RectF(R.Left + 10, R.Top + 2, R.Right - 90, R.Top + HEADER_H - 2), Title,
        False, Op, [], TTextAlign.Leading, TTextAlign.Center);

    PaintStatus(R, Op);

    if FEditMode then
        PaintEditFrame(R, Op);
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
    if FDeviceOnly and not (FDragging or FResizing) then
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
    if FDeviceOnly and FEditMode then
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
    if FDeviceOnly and FEditMode then
        Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.PaintStatus
//** Parametri di ingresso: R: TRectF; Op: Single
//** Parametri di uscita: nessuno
//** Scopo: Disegnare lo stato del dispositivo (etichetta e pallino) in alto a destra.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: etichetta del dispositivo (es. JOY ID 1) nel colore
//** primario se collegato, nel colore accento con "OFFLINE" se scollegato;
//** "NESSUN MODELLO" se il modello scelto non esiste.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.PaintStatus(const R: TRectF; Op: Single);
var
    St: string;
begin
    if FModel <> nil then
    begin
        St := FModel.DeviceLabel(FCfg);
        if not FConnected then
            St := St + Tr('widget.offline', '  OFFLINE');
    end
    else
        St := Tr('widget.nomodel', 'NESSUN MODELLO');
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Font.Family := HOLO_FONT;
    Canvas.Font.Size := 9;
    Canvas.Font.Style := [];
    if FConnected then
        Canvas.Fill.Color := FColors.Primary
    else
        Canvas.Fill.Color := FColors.Accent;
    Canvas.FillText(RectF(R.Right - 160, R.Top + 2, R.Right - 22, R.Top + HEADER_H - 2), St,
        False, Op, [], TTextAlign.Trailing, TTextAlign.Center);
    Canvas.FillEllipse(RectF(R.Right - 17, R.Top + 8, R.Right - 10, R.Top + 15), Op);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.PaintEditFrame
//** Parametri di ingresso: R: TRectF; Op: Single
//** Parametri di uscita: nessuno
//** Scopo: Disegnare il contorno tratteggiato e le maniglie di ridimensionamento (layout sbloccato).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.PaintEditFrame(const R: TRectF; Op: Single);
var
    RT: TRectF;
begin
    Canvas.Stroke.Color := FColors.Accent;
    Canvas.Stroke.Dash := TStrokeDash.Dash;
    Canvas.Stroke.Thickness := 1;
    RT := R;
    RT.Inflate(-3, -3);
    Canvas.DrawRect(RT, 4, 4, AllCorners, Op);
    Canvas.Stroke.Dash := TStrokeDash.Solid;
    // maniglie di ridimensionamento: angoli e meta' dei lati
    Canvas.Fill.Color := FColors.Accent;
    Canvas.FillRect(RectF(R.Left, R.Top, R.Left + 7, R.Top + 7), 0, 0, [], Op);
    Canvas.FillRect(RectF(R.Right - 7, R.Top, R.Right, R.Top + 7), 0, 0, [], Op);
    Canvas.FillRect(RectF(R.Left, R.Bottom - 7, R.Left + 7, R.Bottom), 0, 0, [], Op);
    Canvas.FillRect(RectF(R.Right - 7, R.Bottom - 7, R.Right, R.Bottom), 0, 0, [], Op);
    Canvas.FillRect(RectF(R.CenterPoint.X - 8, R.Top, R.CenterPoint.X + 8, R.Top + 4), 0, 0, [], Op);
    Canvas.FillRect(RectF(R.CenterPoint.X - 8, R.Bottom - 4, R.CenterPoint.X + 8, R.Bottom), 0, 0, [], Op);
    Canvas.FillRect(RectF(R.Left, R.CenterPoint.Y - 8, R.Left + 4, R.CenterPoint.Y + 8), 0, 0, [], Op);
    Canvas.FillRect(RectF(R.Right - 4, R.CenterPoint.Y - 8, R.Right, R.CenterPoint.Y + 8), 0, 0, [], Op);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.PaintDeviceOnly
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare il widget nello stile "solo dispositivo" (nessun pannello).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: chiamata da AfterPaint, quindi sopra la scena 3D. Di norma
//** non disegna nulla (resta visibile solo il modello 3D) tranne lo stato, se
//** il dispositivo non e' collegato o il modello non esiste. Solo da
//** sbloccato e con il mouse sopra il widget (o durante la rotazione della
//** vista) disegna titolo, stato, contorno tratteggiato e maniglie (la
//** velatura invisibile che rende afferrabile il widget e' in Paint).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.PaintDeviceOnly;
var
    R: TRectF;
    Op: Single;
begin
    R := LocalRect;
    Op := AbsoluteOpacity;
    if not FEditMode or not (IsMouseOver or FRotating) then
    begin
        if (FModel = nil) or not FConnected then
            PaintStatus(R, Op);
        Exit;
    end;
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Font.Family := HOLO_FONT;
    Canvas.Font.Size := 11;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.Fill.Color := FColors.Text;
    Canvas.FillText(RectF(R.Left + 10, R.Top + 2, R.Right - 90, R.Top + HEADER_H - 2), Title,
        False, Op, [], TTextAlign.Leading, TTextAlign.Center);
    PaintStatus(R, Op);
    PaintEditFrame(R, Op);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.SetEditMode
//** Parametri di ingresso: Value: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Attivare/disattivare il trascinamento con il mouse.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.SetEditMode(const Value: Boolean);
begin
    if FEditMode = Value then
        Exit;
    FEditMode := Value;
    if FResizing or FDragging then
        SetOutlineOnly(False);
    if FDragging then
        HideGuides;
    FResizing := False;
    FDragging := False;
    FRotating := False;
    if Value then
        Cursor := crSizeAll
    else
        Cursor := crDefault;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceWidget.EdgesAt
//** Parametri di ingresso: X, Y: Single
//** Parametri di uscita: Result: TResizeEdges
//** Scopo: Lati della cornice sotto il punto (X, Y) in coordinate locali.
//** Data Ultima Modifica: 23/10/2026
//***********************************************************************************************************
//** Funzionamento: un lato e' "afferrato" se il punto e' entro RESIZE_BORDER
//** pixel da esso; vicino a un angolo si afferrano due lati insieme.
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceWidget.EdgesAt(X, Y: Single): TResizeEdges;
begin
    Result := [];
    if X < RESIZE_BORDER then
        Include(Result, reLeft)
    else if X > Width - RESIZE_BORDER then
        Include(Result, reRight);
    if Y < RESIZE_BORDER then
        Include(Result, reTop)
    else if Y > Height - RESIZE_BORDER then
        Include(Result, reBottom);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.UpdateCursor
//** Parametri di ingresso: X, Y: Single
//** Parametri di uscita: nessuno
//** Scopo: Mostrare il cursore adatto (frecce di ridimensionamento sui bordi, croce di spostamento
//**        all'interno).
//** Data Ultima Modifica: 23/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.UpdateCursor(X, Y: Single);
var
    E: TResizeEdges;
    C: TCursor;
begin
    E := EdgesAt(X, Y);
    if (E = [reLeft, reTop]) or (E = [reRight, reBottom]) then
        C := crSizeNWSE
    else if (E = [reRight, reTop]) or (E = [reLeft, reBottom]) then
        C := crSizeNESW
    else if (E = [reLeft]) or (E = [reRight]) then
        C := crSizeWE
    else if (E = [reTop]) or (E = [reBottom]) then
        C := crSizeNS
    else
        C := crSizeAll;
    if Cursor <> C then
        Cursor := C;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.SetOutlineOnly
//** Parametri di ingresso: AValue: Boolean
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
procedure TDeviceWidget.SetOutlineOnly(AValue: Boolean);
begin
    FViewport.Visible := not AValue;
    if not AValue then
        FLastW := -1;   // forza FitCamera con la nuova dimensione
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
    R: TRectF;
begin
    R := LocalRect;
    R.Inflate(-1, -1);
    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Stroke.Color := FColors.Accent;
    Canvas.Stroke.Thickness := 2;
    Canvas.Stroke.Dash := TStrokeDash.Dash;
    Canvas.DrawRect(R, 6, 6, AllCorners, 1);
    Canvas.Stroke.Dash := TStrokeDash.Solid;
    Canvas.DrawLine(PointF(R.Left, R.Top), PointF(R.Left + L, R.Top), 1);
    Canvas.DrawLine(PointF(R.Left, R.Top), PointF(R.Left, R.Top + L), 1);
    Canvas.DrawLine(PointF(R.Right, R.Top), PointF(R.Right - L, R.Top), 1);
    Canvas.DrawLine(PointF(R.Right, R.Top), PointF(R.Right, R.Top + L), 1);
    Canvas.DrawLine(PointF(R.Left, R.Bottom), PointF(R.Left + L, R.Bottom), 1);
    Canvas.DrawLine(PointF(R.Left, R.Bottom), PointF(R.Left, R.Bottom - L), 1);
    Canvas.DrawLine(PointF(R.Right, R.Bottom), PointF(R.Right - L, R.Bottom), 1);
    Canvas.DrawLine(PointF(R.Right, R.Bottom), PointF(R.Right, R.Bottom - L), 1);

    Canvas.Font.Family := HOLO_FONT;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := FColors.Accent;
    Canvas.Font.Size := 11;
    Canvas.FillText(RectF(R.Left, R.CenterPoint.Y - 26, R.Right, R.CenterPoint.Y - 4),
        KindText(FKind), False, 1, [], TTextAlign.Center, TTextAlign.Center);
    Canvas.Font.Size := 13;
    Canvas.FillText(RectF(R.Left, R.CenterPoint.Y, R.Right, R.CenterPoint.Y + 24),
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
//**        oppure la rotazione della vista (tasto destro).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: se il click e' sulla cornice inizia il ridimensionamento
//** dai lati afferrati, altrimenti lo spostamento (con le linee guida verdi
//** dall'angolo inferiore sinistro); in entrambi i casi la
//** scena 3D sparisce e resta solo il contorno. Per il ridimensionamento si
//** memorizzano il rettangolo iniziale e il punto del mouse in coordinate
//** assolute (il widget si sposta mentre lo si allarga a sinistra o in alto).
//** Con il tasto destro si memorizzano il punto del mouse (coordinate
//** assolute) e la vista di partenza: la rotazione si calcola in MouseMove.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
    inherited;
    if FEditMode and (Button = TMouseButton.mbLeft) then
    begin
        BringToFront;
        FEdges := EdgesAt(X, Y);
        FStartRect := RectF(Position.X, Position.Y, Position.X + Width, Position.Y + Height);
        if FEdges <> [] then
        begin
            FResizing := True;
            FResizeMouse := LocalToAbsolute(PointF(X, Y));
        end
        else
        begin
            FDragging := True;
            FDragMouse := LocalToAbsolute(PointF(X, Y));
            FSnapX := False;
            FSnapY := False;
            Guides.ShowAt(PointF(Position.X, Position.Y + Height), False, False);
        end;
        SetOutlineOnly(True);
    end
    else if (Button = TMouseButton.mbRight) and not (FDragging or FResizing) and (FModel <> nil) then
    begin
        FRotating := True;
        FRotMouse := LocalToAbsolute(PointF(X, Y));
        FRotTilt0 := FCfg.Tilt;
        FRotYaw0 := FCfg.Yaw;
        Cursor := crHandPoint;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.MouseMove
//** Parametri di ingresso: Shift: TShiftState; X, Y: Single
//** Parametri di uscita: nessuno
//** Scopo: Spostare o ridimensionare il contorno seguendo il mouse, oppure ruotare la vista.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento:
//**  - rotazione (tasto destro premuto): lo spostamento orizzontale ruota il
//**    modello attorno all'asse verticale (mouse a destra = il davanti del
//**    modello gira verso destra), quello verticale lo inclina (mouse in avanti
//**    = la parte alta si allontana); VIEW_DRAG_DEG gradi per pixel, rotazione
//**    riportata in -180..180, inclinazione limitata a +-VIEW_TILT_LIMIT. La
//**    camera si riadatta subito, cosi' il modello resta inquadrato;
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
    D: TPointF;
    R: TRectF;
    NewX, NewY: Single;
begin
    inherited;
    if FRotating then
    begin
        D := LocalToAbsolute(PointF(X, Y)) - FRotMouse;
        FCfg.Yaw := FRotYaw0 - D.X * VIEW_DRAG_DEG;
        FCfg.Yaw := FCfg.Yaw - 360 * Round(FCfg.Yaw / 360);
        FCfg.Tilt := EnsureRange(FRotTilt0 + D.Y * VIEW_DRAG_DEG, -VIEW_TILT_LIMIT, VIEW_TILT_LIMIT);
        ApplyView;
        FitCamera;
    end
    else if FResizing then
    begin
        D := LocalToAbsolute(PointF(X, Y)) - FResizeMouse;
        R := FStartRect;
        if reLeft in FEdges then
            R.Left := Min(R.Left + D.X, R.Right - WIDGET_MIN_W);
        if reRight in FEdges then
            R.Right := Max(R.Right + D.X, R.Left + WIDGET_MIN_W);
        if reTop in FEdges then
            R.Top := Min(R.Top + D.Y, R.Bottom - WIDGET_MIN_H);
        if reBottom in FEdges then
            R.Bottom := Max(R.Bottom + D.Y, R.Top + WIDGET_MIN_H);
        SetBounds(R.Left, R.Top, R.Width, R.Height);
        Repaint;
    end
    else if FDragging then
    begin
        D := LocalToAbsolute(PointF(X, Y)) - FDragMouse;
        NewX := FStartRect.Left + D.X;
        NewY := FStartRect.Top + D.Y;
        SnapPosition(NewX, NewY);
        Position.Point := PointF(NewX, NewY);
        Guides.ShowAt(PointF(NewX, NewY + Height), FSnapX, FSnapY);
    end
    else if FEditMode then
        UpdateCursor(X, Y);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceWidget.MouseUp
//** Parametri di ingresso: Button: TMouseButton; Shift: TShiftState; X, Y: Single
//** Parametri di uscita: nessuno
//** Scopo: Terminare spostamento, ridimensionamento o rotazione della vista.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: al rilascio del tasto destro termina la rotazione e, se la
//** vista e' cambiata, avvisa la form principale (OnViewChanged) che la salva.
//** Per spostamento e ridimensionamento nasconde le linee guida e allinea
//** posizione (e dimensioni) a una griglia di 4 px (tranne le coordinate
//** agganciate a un altro widget, che restano esatte), rimostra la scena 3D e avvisa la form principale,
//** che aggiorna la configurazione (e quindi i valori del Setup) e ricalcola
//** la disposizione. Un semplice click senza movimento non cambia nulla.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
    WasResize: Boolean;
    Changed: Boolean;
    NewX, NewY: Single;
begin
    inherited;
    if FRotating and (Button = TMouseButton.mbRight) then
    begin
        FRotating := False;
        if FEditMode then
            Cursor := crSizeAll
        else
            Cursor := crDefault;
        if not (SameValue(FCfg.Tilt, FRotTilt0) and SameValue(FCfg.Yaw, FRotYaw0)) and
            Assigned(FOnViewChanged) then
            FOnViewChanged(Self);
        if FDeviceOnly then
            Repaint;   // "solo dispositivo": la cornice resta solo se il mouse e' ancora sopra
        Exit;
    end;
    if not (FResizing or FDragging) then
        Exit;
    WasResize := FResizing;
    FResizing := False;
    FDragging := False;
    HideGuides;
    if WasResize then
        SetBounds(Round(Position.X / 4) * 4, Round(Position.Y / 4) * 4,
            Max(WIDGET_MIN_W, Round(Width / 4) * 4), Max(WIDGET_MIN_H, Round(Height / 4) * 4))
    else
    begin
        // la griglia di 4 px vale solo per le coordinate non agganciate a un altro widget
        if FSnapX then
            NewX := Round(Position.X)
        else
            NewX := Round(Position.X / 4) * 4;
        if FSnapY then
            NewY := Round(Position.Y)
        else
            NewY := Round(Position.Y / 4) * 4;
        Position.Point := PointF(NewX, NewY);
    end;
    Changed := RectF(Position.X, Position.Y, Position.X + Width, Position.Y + Height) <> FStartRect;
    SetOutlineOnly(False);
    if not Changed then
        Exit;
    if WasResize then
    begin
        if Assigned(FOnResized) then
            FOnResized(Self);
    end
    else if Assigned(FOnMoved) then
        FOnMoved(Self);
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
//** Funzionamento: rotella in avanti (WheelDelta positivo) = zoom in,
//** indietro = zoom out; ogni scatto (120 unita') moltiplica o divide lo zoom
//** per VIEW_ZOOM_STEP, entro VIEW_ZOOM_MIN..VIEW_ZOOM_MAX. Lo zoom agisce
//** sulla distanza della camera (FitCamera), quindi il modello resta centrato.
//** La form principale viene avvisata (OnViewChanged) per salvarlo nel .ini.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceWidget.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
var
    Z: Single;
begin
    inherited;
    if (FModel = nil) or FDragging or FResizing or (WheelDelta = 0) then
        Exit;
    Z := FCfg.Zoom * Power(VIEW_ZOOM_STEP, WheelDelta / 120);
    Z := EnsureRange(Z, VIEW_ZOOM_MIN, VIEW_ZOOM_MAX);
    Handled := True;
    if SameValue(Z, FCfg.Zoom) then
        Exit;
    FCfg.Zoom := Z;
    FitCamera;
    if Assigned(FOnViewChanged) then
        FOnViewChanged(Self);
end;

end.
