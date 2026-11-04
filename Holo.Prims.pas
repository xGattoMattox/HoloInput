//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Prims
//** Scopo: Primitive 3D con aspetto "ologramma" usate da tutti gli sketch dei dispositivi.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: una THoloShape e' composta da:
//**   - un riempimento traslucido (TCube / TCylinder / TSphere) che non scrive
//**     nello Z-buffer, quindi lascia vedere le parti retrostanti (effetto raggi X);
//**   - gli spigoli luminosi disegnati come linee (vertex/index buffer in cache,
//**     un'unica chiamata DrawLines per forma).
//**
//** THoloKit possiede i materiali condivisi e i colori della skin: cambiando
//** skin si aggiornano 4 material source e tutte le forme cambiano colore.
//** Convenzione assi FMX: X verso destra, Y verso il BASSO, Z verso l'interno
//** dello schermo (lontano dalla camera).
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.Prims;

interface

uses
    System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
    System.Math.Vectors,
    FMX.Types, FMX.Types3D, FMX.Controls3D, FMX.Objects3D, FMX.MaterialSources,
    FMX.Materials,
    Holo.Skins;

type
    /// Stile visivo di una forma.
    THoloStyle = (
        hsNormal,   // riempimento leggero + spigoli colore primario
        hsDim,      // parti secondarie (basi, piastre): colori attenuati
        hsGhost,    // solo spigoli, nessun riempimento
        hsSolid,    // riempimento piu' denso (impugnature, corpi)
        hsScan);    // solo riempimento, nessuno spigolo (scanline)

    TShapeKind = (skBox, skCylinder, skSphere);
    TAxis3 = (axX, axY, axZ);

    THoloKit = class;

    /// Sezione orizzontale (piano XZ) di una superficie "loft": superellisse
    /// centrata in (CX, Y, CZ) con semiassi A (X) e B (Z) ed esponente N
    /// (2 = ellisse, 4..6 = quadrato arrotondato).
    TLoftSection = record
        Y, CX, CZ, A, B, N: Single;
    end;

    /// Base: oggetto 3D che disegna una lista di segmenti in cache.
    THoloLines = class(TDummy)
    private
        FKit: THoloKit;
        FVB: TVertexBuffer;
        FIB: TIndexBuffer;
    protected
        procedure Render; override;
        function LineColor: TAlphaColor; virtual; abstract;
        procedure SetLines(const APoints: TArray<TPoint3D>);
        /// Collega il kit (serve alle classi derivate dichiarate in altre unit,
        /// es. Holo.Obj, che non vedono il campo privato FKit).
        procedure AttachKit(AKit: THoloKit);
        /// Stato "acceso" (input premuto). Le classi derivate lo ridefiniscono.
        function GetActive: Boolean; virtual;
        procedure SetActive(const Value: Boolean); virtual;
    public
        destructor Destroy; override;
        property Kit: THoloKit read FKit;
        property Active: Boolean read GetActive write SetActive;
    end;

    /// Forma olografica (riempimento + spigoli).
    THoloShape = class(THoloLines)
    private
        FKind: TShapeKind;
        FStyle: THoloStyle;
        FFill: TControl3D;
        FActive: Boolean;
        FSize: TPoint3D;
        procedure RebuildEdges;
        procedure UpdateFill;
        procedure SetStyle(const Value: THoloStyle);
    protected
        function LineColor: TAlphaColor; override;
        function GetActive: Boolean; override;
        procedure SetActive(const Value: Boolean); override;
    public
        constructor CreateShape(AKit: THoloKit; AParent: TFmxObject; AKind: TShapeKind;
            const ASize: TPoint3D; AStyle: THoloStyle);
        /// (non "Resize3D": nasconderebbe il metodo virtuale omonimo di TControl3D, warning W1010)
        procedure SetShapeSize(const ASize: TPoint3D);
        procedure RefreshLook;
        property Style: THoloStyle read FStyle write SetStyle;
        property Fill: TControl3D read FFill;
        property Size: TPoint3D read FSize;
    end;

    /// Anello (eventualmente tratteggiato) nel piano XZ: base del "proiettore".
    THoloRing = class(THoloLines)
    private
        FRadius: Single;
        FDashed: Boolean;
        FStyle: THoloStyle;
        procedure Rebuild;
    protected
        function LineColor: TAlphaColor; override;
    public
        constructor CreateRing(AKit: THoloKit; AParent: TFmxObject; ARadius: Single;
            ADashed: Boolean; AStyle: THoloStyle);
        procedure SetRadius(ARadius: Single);
    end;

    /// Superficie curva ad alta densita' di poligoni ottenuta "estrudendo" una
    /// serie di sezioni lungo un asse (impugnature, corpi, tasti arrotondati...).
    /// Con asse Y le sezioni sono nel piano XZ (campi CX/CZ, semiassi A su X e
    /// B su Z); con asse Z sono nel piano XY (CX -> X, CZ -> Y, A su X, B su Y);
    /// con asse X sono nel piano YZ (CX -> Y, CZ -> Z, A su Y, B su Z).
    /// Il campo Y della sezione e' sempre la quota lungo l'asse scelto.
    /// Disegna un riempimento traslucido a triangoli e una rete di linee
    /// (anelli + meridiani) come un ologramma wireframe.
    THoloLoft = class(THoloLines)
    private
        FStyle: THoloStyle;
        FActive: Boolean;
        FTriVB: TVertexBuffer;
        FTriIB: TIndexBuffer;
    protected
        procedure Render; override;
        function LineColor: TAlphaColor; override;
        function GetActive: Boolean; override;
        procedure SetActive(const Value: Boolean); override;
    public
        constructor CreateLoft(AKit: THoloKit; AParent: TFmxObject;
            const ASections: array of TLoftSection; ASegments, ALineEvery: Integer;
            AStyle: THoloStyle; AAxis: TAxis3 = axY);
        destructor Destroy; override;
    end;

    /// Fabbrica di forme + materiali condivisi della skin corrente.
    THoloKit = class
    private
        FColors: TSkinColors;
        FMatNormal, FMatDim, FMatActive, FMatText: TColorMaterialSource;
        FLineMat: TColorMaterial;
        FShowLegends: Boolean;
    public
        constructor Create(const AColors: TSkinColors);
        destructor Destroy; override;
        procedure ApplyColors(const AColors: TSkinColors);
        function FillMaterial(AStyle: THoloStyle; AActive: Boolean): TMaterialSource;
        function FillOpacity(AStyle: THoloStyle; AActive: Boolean): Single;
        function EdgeColor(AStyle: THoloStyle; AActive: Boolean): TAlphaColor;

        function Pivot(AParent: TFmxObject; X, Y, Z: Single): TDummy;
        function Box(AParent: TFmxObject; X, Y, Z, W, H, D: Single;
            AStyle: THoloStyle = hsNormal): THoloShape;
        function Cyl(AParent: TFmxObject; X, Y, Z, ADiam, ALen: Single;
            AAxis: TAxis3 = axY; AStyle: THoloStyle = hsNormal): THoloShape;
        function Ball(AParent: TFmxObject; X, Y, Z, W, H, D: Single;
            AStyle: THoloStyle = hsNormal): THoloShape;
        function Loft(AParent: TFmxObject; X, Y, Z: Single; const ASections: array of TLoftSection;
            AStyle: THoloStyle = hsSolid; ASegments: Integer = 32; ALineEvery: Integer = 2;
            AAxis: TAxis3 = axY): THoloLoft;
        function RBox(AParent: TFmxObject; X, Y, Z, W, H, D: Single;
            AStyle: THoloStyle = hsNormal; AAxis: TAxis3 = axZ; ATaper: Single = 0;
            ASegments: Integer = 24; ARound: Single = 5): THoloLoft;
        function Ring(AParent: TFmxObject; X, Y, Z, ARadius: Single; ADashed: Boolean;
            AStyle: THoloStyle = hsDim): THoloRing;
        function Text(AParent: TFmxObject; X, Y, Z, ASize: Single; const S: string;
            AForce: Boolean = False; const AFamily: string = ''): TText3D;

        property Colors: TSkinColors read FColors;
        property LineMaterial: TColorMaterial read FLineMat;
        property ShowLegends: Boolean read FShowLegends write FShowLegends;
    end;

/// Imposta l'opacita' di un oggetto 3D (anche dove la proprieta' e' protected).
procedure SetObjOpacity(AObj: TControl3D; AValue: Single);
/// Costruisce una sezione per THoloKit.Loft.
function Sec(Y, CX, CZ, A, B: Single; N: Single = 2): TLoftSection;

implementation

uses
    // serve per espandere inline TVertexBuffer.SetVertices (hint H2443)
    System.RTLConsts;

type
    /// "Cracker" per accedere a proprieta' di TControl3D che in alcune versioni
    /// di FMX sono protected (ZWrite, Opacity, HitTest, dimensioni).
    TControl3DAccess = class(TControl3D);

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: SetMeshMaterial
//** Parametri di ingresso: AObj: TControl3D; AMat: TMaterialSource
//** Parametri di uscita: nessuno
//** Scopo: Assegnare un materiale a un mesh primitivo indipendentemente dalla classe.
//** Data Ultima Modifica: 19/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure SetMeshMaterial(AObj: TControl3D; AMat: TMaterialSource);
begin
    if AObj is TCube then
        TCube(AObj).MaterialSource := AMat
    else if AObj is TCylinder then
        TCylinder(AObj).MaterialSource := AMat
    else if AObj is TSphere then
        TSphere(AObj).MaterialSource := AMat;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: SetObjOpacity
//** Parametri di ingresso: AObj: TControl3D; AValue: Single
//** Parametri di uscita: nessuno
//** Scopo: Impostare l'opacita' di un oggetto 3D tramite il cracker.
//** Data Ultima Modifica: 20/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure SetObjOpacity(AObj: TControl3D; AValue: Single);
begin
    if AObj <> nil then
        TControl3DAccess(AObj).Opacity := EnsureRange(AValue, 0, 1);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: NoHit
//** Parametri di ingresso: AObj: TControl3D
//** Parametri di uscita: nessuno
//** Scopo: Rendere un oggetto 3D "trasparente" al mouse.
//** Data Ultima Modifica: 20/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure NoHit(AObj: TControl3D);
begin
    TControl3DAccess(AObj).HitTest := False;
end;

//** THoloLines *********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloLines.Destroy
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Liberare i buffer delle linee.
//** Data Ultima Modifica: 20/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
destructor THoloLines.Destroy;
begin
    FreeAndNil(FVB);
    FreeAndNil(FIB);
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloLines.SetLines
//** Parametri di ingresso: APoints: TArray<TPoint3D>
//** Parametri di uscita: nessuno
//** Scopo: (ri)costruire i buffer delle linee.
//** Data Ultima Modifica: 20/09/2026
//***********************************************************************************************************
//** Funzionamento: APoints contiene coppie di punti (inizio, fine) di ogni
//** segmento; vertici e indici sono generati una volta sola e riutilizzati
//** ad ogni frame.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloLines.SetLines(const APoints: TArray<TPoint3D>);
var
    I, N: Integer;
begin
    FreeAndNil(FVB);
    FreeAndNil(FIB);
    N := Length(APoints) and not 1;
    if N = 0 then
        Exit;
    FVB := TVertexBuffer.Create([TVertexFormat.Vertex], N);
    FIB := TIndexBuffer.Create(N);
    for I := 0 to N - 1 do
    begin
        FVB.Vertices[I] := APoints[I];
        FIB.Indices[I] := I;
    end;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloLines.AttachKit
//** Parametri di ingresso: AKit: THoloKit
//** Parametri di uscita: nessuno
//** Scopo: Collegare il kit della skin (materiali e colori condivisi).
//** Data Ultima Modifica: 16/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloLines.AttachKit(AKit: THoloKit);
begin
    FKit := AKit;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloLines.GetActive
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Default per oggetti senza stato acceso (es. anelli).
//** Data Ultima Modifica: 20/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloLines.GetActive: Boolean;
begin
    Result := False;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloLines.SetActive
//** Parametri di ingresso: Value: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Ignorare l'accensione: gli oggetti di sole linee non hanno stato acceso.
//** Data Ultima Modifica: 20/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloLines.SetActive(const Value: Boolean);
begin
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloLines.Render
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare gli spigoli olografici.
//** Data Ultima Modifica: 20/09/2026
//***********************************************************************************************************
//** Funzionamento: FMX ha gia' impostato la matrice dell'oggetto; si assegna il
//** colore al materiale linee condiviso e si disegna tutto in una chiamata.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloLines.Render;
begin
    if (FVB = nil) or (FIB = nil) or (FKit = nil) then
        Exit;
    FKit.LineMaterial.Color := LineColor;
    Context.DrawLines(FVB, FIB, FKit.LineMaterial, AbsoluteOpacity);
end;

//** THoloShape *********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloShape.CreateShape
//** Parametri di ingresso: AKit: THoloKit; AParent: TFmxObject; AKind: TShapeKind; ASize: TPoint3D;
//**                        AStyle: THoloStyle
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare una forma olografica e agganciarla al genitore.
//** Data Ultima Modifica: 20/09/2026
//***********************************************************************************************************
//** Funzionamento: crea il mesh di riempimento del tipo richiesto (figlio della
//** forma), lo rende non scrivente nello Z-buffer e genera gli spigoli.
//***********************************************************************************************************
//***********************************************************************************************************
constructor THoloShape.CreateShape(AKit: THoloKit; AParent: TFmxObject;
    AKind: TShapeKind; const ASize: TPoint3D; AStyle: THoloStyle);
begin
    inherited Create(nil);
    FKit := AKit;
    FKind := AKind;
    FStyle := AStyle;
    FSize := ASize;
    NoHit(Self);
    Parent := AParent;

    case AKind of
        skBox:      FFill := TCube.Create(nil);
        skCylinder: FFill := TCylinder.Create(nil);
    else
        FFill := TSphere.Create(nil);
    end;
    FFill.Parent := Self;
    if FFill is TCylinder then
        TCylinder(FFill).SubdivisionsAxes := 32
    else if FFill is TSphere then
    begin
        TSphere(FFill).SubdivisionsAxes := 32;
        TSphere(FFill).SubdivisionsHeight := 16;
    end;
    NoHit(FFill);
    TControl3DAccess(FFill).ZWrite := False;
    TControl3DAccess(FFill).Width := ASize.X;
    TControl3DAccess(FFill).Height := ASize.Y;
    TControl3DAccess(FFill).Depth := ASize.Z;
    UpdateFill;
    RebuildEdges;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloShape.SetShapeSize
//** Parametri di ingresso: ASize: TPoint3D
//** Parametri di uscita: nessuno
//** Scopo: Cambiare le dimensioni della forma (riempimento + spigoli).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloShape.SetShapeSize(const ASize: TPoint3D);
begin
    FSize := ASize;
    TControl3DAccess(FFill).Width := ASize.X;
    TControl3DAccess(FFill).Height := ASize.Y;
    TControl3DAccess(FFill).Depth := ASize.Z;
    RebuildEdges;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloShape.RebuildEdges
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Generare la lista dei segmenti degli spigoli.
//** Data Ultima Modifica: 20/09/2026
//***********************************************************************************************************
//** Funzionamento:
//**  - box: i 12 spigoli del parallelepipedo;
//**  - cilindro (asse Y): due ellissi a 16 lati + 4 generatrici;
//**  - sfera/ellissoide: tre ellissi principali (piani XY, XZ, YZ).
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloShape.RebuildEdges;
const
    SEG_CYL = 32;
    SEG_SPH = 32;
var
    P: TArray<TPoint3D>;
    HX, HY, HZ, A0, A1: Single;
    I: Integer;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: Add
    //** Parametri di ingresso: A, B: TPoint3D
    //** Parametri di uscita: nessuno
    //** Scopo: Aggiungere un segmento (coppia di punti) all'elenco degli spigoli.
    //** Data Ultima Modifica: 20/09/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Add(const A, B: TPoint3D);
    begin
        P := P + [A, B];
    end;

begin
    P := nil;
    HX := FSize.X / 2;
    HY := FSize.Y / 2;
    HZ := FSize.Z / 2;
    if FStyle <> hsScan then
        case FKind of
            skBox:
                begin
                    // faccia anteriore (z = -HZ) e posteriore (z = +HZ)
                    Add(Point3D(-HX, -HY, -HZ), Point3D(HX, -HY, -HZ));
                    Add(Point3D(HX, -HY, -HZ), Point3D(HX, HY, -HZ));
                    Add(Point3D(HX, HY, -HZ), Point3D(-HX, HY, -HZ));
                    Add(Point3D(-HX, HY, -HZ), Point3D(-HX, -HY, -HZ));
                    Add(Point3D(-HX, -HY, HZ), Point3D(HX, -HY, HZ));
                    Add(Point3D(HX, -HY, HZ), Point3D(HX, HY, HZ));
                    Add(Point3D(HX, HY, HZ), Point3D(-HX, HY, HZ));
                    Add(Point3D(-HX, HY, HZ), Point3D(-HX, -HY, HZ));
                    // spigoli di profondita'
                    Add(Point3D(-HX, -HY, -HZ), Point3D(-HX, -HY, HZ));
                    Add(Point3D(HX, -HY, -HZ), Point3D(HX, -HY, HZ));
                    Add(Point3D(HX, HY, -HZ), Point3D(HX, HY, HZ));
                    Add(Point3D(-HX, HY, -HZ), Point3D(-HX, HY, HZ));
                end;
            skCylinder:
                begin
                    for I := 0 to SEG_CYL - 1 do
                    begin
                        A0 := 2 * Pi * I / SEG_CYL;
                        A1 := 2 * Pi * (I + 1) / SEG_CYL;
                        Add(Point3D(HX * Cos(A0), -HY, HZ * Sin(A0)), Point3D(HX * Cos(A1), -HY, HZ * Sin(A1)));
                        Add(Point3D(HX * Cos(A0), HY, HZ * Sin(A0)), Point3D(HX * Cos(A1), HY, HZ * Sin(A1)));
                    end;
                    for I := 0 to 3 do
                    begin
                        A0 := Pi / 2 * I + Pi / 4;
                        Add(Point3D(HX * Cos(A0), -HY, HZ * Sin(A0)), Point3D(HX * Cos(A0), HY, HZ * Sin(A0)));
                    end;
                end;
            skSphere:
                for I := 0 to SEG_SPH - 1 do
                begin
                    A0 := 2 * Pi * I / SEG_SPH;
                    A1 := 2 * Pi * (I + 1) / SEG_SPH;
                    Add(Point3D(HX * Cos(A0), HY * Sin(A0), 0), Point3D(HX * Cos(A1), HY * Sin(A1), 0));
                    Add(Point3D(HX * Cos(A0), 0, HZ * Sin(A0)), Point3D(HX * Cos(A1), 0, HZ * Sin(A1)));
                    Add(Point3D(0, HY * Cos(A0), HZ * Sin(A0)), Point3D(0, HY * Cos(A1), HZ * Sin(A1)));
                end;
        end;
    SetLines(P);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloShape.UpdateFill
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Applicare materiale e opacita' del riempimento in base a stile/stato.
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloShape.UpdateFill;
var
    Op: Single;
begin
    Op := FKit.FillOpacity(FStyle, FActive);
    SetMeshMaterial(FFill, FKit.FillMaterial(FStyle, FActive));
    TControl3DAccess(FFill).Opacity := Op;
    FFill.Visible := Op > 0;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloShape.RefreshLook
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Riapplicare l'aspetto (dopo un cambio skin).
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloShape.RefreshLook;
begin
    UpdateFill;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloShape.SetActive
//** Parametri di ingresso: Value: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Accendere/spegnere l'evidenziazione (input premuto).
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//** Funzionamento: cambia materiale/opacita' solo se lo stato cambia, cosi'
//** la scena viene ridisegnata solo quando serve.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloShape.SetActive(const Value: Boolean);
begin
    if FActive = Value then
        Exit;
    FActive := Value;
    UpdateFill;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloShape.SetStyle
//** Parametri di ingresso: Value: THoloStyle
//** Parametri di uscita: nessuno
//** Scopo: Cambiare lo stile della forma.
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloShape.SetStyle(const Value: THoloStyle);
begin
    if FStyle = Value then
        Exit;
    FStyle := Value;
    UpdateFill;
    RebuildEdges;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloShape.GetActive
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Restituire lo stato acceso (evidenziato) della forma.
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloShape.GetActive: Boolean;
begin
    Result := FActive;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloShape.LineColor
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TAlphaColor
//** Scopo: Colore degli spigoli in base a stile e stato.
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloShape.LineColor: TAlphaColor;
begin
    Result := FKit.EdgeColor(FStyle, FActive);
end;

//** THoloRing **********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloRing.CreateRing
//** Parametri di ingresso: AKit: THoloKit; AParent: TFmxObject; ARadius: Single; ADashed: Boolean;
//**                        AStyle: THoloStyle
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare un anello nel piano XZ (orizzontale).
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
constructor THoloRing.CreateRing(AKit: THoloKit; AParent: TFmxObject;
    ARadius: Single; ADashed: Boolean; AStyle: THoloStyle);
begin
    inherited Create(nil);
    FKit := AKit;
    FRadius := ARadius;
    FDashed := ADashed;
    FStyle := AStyle;
    NoHit(Self);
    Parent := AParent;
    Rebuild;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloRing.SetRadius
//** Parametri di ingresso: ARadius: Single
//** Parametri di uscita: nessuno
//** Scopo: Cambiare il raggio dell'anello.
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloRing.SetRadius(ARadius: Single);
begin
    if SameValue(FRadius, ARadius, 0.0001) then
        Exit;
    FRadius := ARadius;
    Rebuild;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloRing.Rebuild
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Generare i segmenti dell'anello (48 lati; se tratteggiato uno su due).
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloRing.Rebuild;
const
    SEG = 48;
var
    P: TArray<TPoint3D>;
    I: Integer;
    A0, A1: Single;
begin
    P := nil;
    for I := 0 to SEG - 1 do
    begin
        if FDashed and Odd(I) then
            Continue;
        A0 := 2 * Pi * I / SEG;
        A1 := 2 * Pi * (I + 1) / SEG;
        P := P + [Point3D(FRadius * Cos(A0), 0, FRadius * Sin(A0)),
                  Point3D(FRadius * Cos(A1), 0, FRadius * Sin(A1))];
    end;
    SetLines(P);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloRing.LineColor
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TAlphaColor
//** Scopo: Colore dell'anello in base allo stile.
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloRing.LineColor: TAlphaColor;
begin
    Result := FKit.EdgeColor(FStyle, False);
end;

//** THoloLoft **********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: Sec
//** Parametri di ingresso: Y, CX, CZ, A, B: Single; N: Single
//** Parametri di uscita: Result: TLoftSection
//** Scopo: Costruire una sezione di loft.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function Sec(Y, CX, CZ, A, B: Single; N: Single): TLoftSection;
begin
    Result.Y := Y;
    Result.CX := CX;
    Result.CZ := CZ;
    Result.A := A;
    Result.B := B;
    Result.N := N;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: SuperPoint
//** Parametri di ingresso: S: TLoftSection; T: Single; AAxis: TAxis3
//** Parametri di uscita: Result: TPoint3D
//** Scopo: Punto di una superellisse (|u/a|^n + |v/b|^n = 1) all'angolo T, orientata secondo l'asse
//**        del loft.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//** Funzionamento: calcola le coordinate (u, v) nel piano della sezione e
//** la quota s lungo l'asse, poi le colloca negli assi del mondo.
//***********************************************************************************************************
//***********************************************************************************************************
function SuperPoint(const S: TLoftSection; T: Single; AAxis: TAxis3): TPoint3D;
var
    C, Sn, E, U, V: Single;
begin
    C := Cos(T);
    Sn := Sin(T);
    E := 2 / Max(0.5, S.N);
    U := S.CX + S.A * Sign(C) * Power(Abs(C), E);
    V := S.CZ + S.B * Sign(Sn) * Power(Abs(Sn), E);
    case AAxis of
        axZ: Result := Point3D(U, V, S.Y);
        axX: Result := Point3D(S.Y, U, V);
    else
        Result := Point3D(U, S.Y, V);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: SectionCenter
//** Parametri di ingresso: S: TLoftSection; AAxis: TAxis3
//** Parametri di uscita: Result: TPoint3D
//** Scopo: Centro di una sezione nelle coordinate del mondo.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function SectionCenter(const S: TLoftSection; AAxis: TAxis3): TPoint3D;
begin
    case AAxis of
        axZ: Result := Point3D(S.CX, S.CZ, S.Y);
        axX: Result := Point3D(S.Y, S.CX, S.CZ);
    else
        Result := Point3D(S.CX, S.Y, S.CZ);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloLoft.CreateLoft
//** Parametri di ingresso: AKit: THoloKit; AParent: TFmxObject; ASections: array of TLoftSection;
//**                        ASegments, ALineEvery: Integer; AStyle: THoloStyle; AAxis: TAxis3
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare la superficie a partire dalle sezioni.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//** Funzionamento:
//**  - ogni sezione diventa un anello di ASegments vertici;
//**  - anelli consecutivi sono uniti da coppie di triangoli; le due estremita'
//**    sono chiuse da un "ventaglio" attorno al centro della sezione;
//**  - ogni triangolo e' inserito con entrambi gli ordini dei vertici, cosi'
//**    la superficie e' visibile da qualunque lato senza cambiare lo stato
//**    di culling del contesto;
//**  - linee: tutti gli anelli + un meridiano ogni ALineEvery vertici;
//**  - tutti gli array sono pre-dimensionati (nessuna riallocazione), cosi'
//**    anche centinaia di loft (es. i copritasti) si creano rapidamente.
//***********************************************************************************************************
//***********************************************************************************************************
constructor THoloLoft.CreateLoft(AKit: THoloKit; AParent: TFmxObject;
    const ASections: array of TLoftSection; ASegments, ALineEvery: Integer;
    AStyle: THoloStyle; AAxis: TAxis3);
var
    R, S, I, J, V, Base, C0, C1, NI, NL, NMer: Integer;
    Pts: TArray<TPoint3D>;
    Lines: TArray<TPoint3D>;
    Idx: TArray<Integer>;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: Tri
    //** Parametri di ingresso: A, B, C: Integer
    //** Parametri di uscita: nessuno
    //** Scopo: Aggiungere un triangolo a due facce (entrambi i versi) agli indici del loft.
    //** Data Ultima Modifica: 22/09/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Tri(A, B, C: Integer);
    begin
        Idx[NI] := A;     Idx[NI + 1] := B; Idx[NI + 2] := C;
        Idx[NI + 3] := A; Idx[NI + 4] := C; Idx[NI + 5] := B;
        Inc(NI, 6);
    end;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: Seg
    //** Parametri di ingresso: A, B: TPoint3D
    //** Parametri di uscita: nessuno
    //** Scopo: Aggiungere un segmento all'elenco delle linee del loft.
    //** Data Ultima Modifica: 22/09/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Seg(const A, B: TPoint3D);
    begin
        Lines[NL] := A;
        Lines[NL + 1] := B;
        Inc(NL, 2);
    end;

begin
    inherited Create(nil);
    FKit := AKit;
    FStyle := AStyle;
    NoHit(Self);
    ZWrite := False;
    Parent := AParent;

    R := Length(ASections);
    S := Max(6, ASegments);
    if ALineEvery < 1 then
        ALineEvery := 1;
    if R < 2 then
        Exit;

    // vertici degli anelli + 2 centri per i tappi
    SetLength(Pts, R * S + 2);
    for I := 0 to R - 1 do
        for J := 0 to S - 1 do
            Pts[I * S + J] := SuperPoint(ASections[I], 2 * Pi * J / S, AAxis);
    C0 := R * S;
    C1 := R * S + 1;
    Pts[C0] := SectionCenter(ASections[0], AAxis);
    Pts[C1] := SectionCenter(ASections[R - 1], AAxis);

    // triangoli: (R-1)*S*2 tra gli anelli + 2*S per i tappi, 6 indici ciascuno
    SetLength(Idx, ((R - 1) * S * 2 + 2 * S) * 6);
    NI := 0;
    for I := 0 to R - 2 do
        for J := 0 to S - 1 do
        begin
            Base := I * S;
            Tri(Base + J, Base + S + J, Base + (J + 1) mod S);
            Tri(Base + (J + 1) mod S, Base + S + J, Base + S + (J + 1) mod S);
        end;
    for J := 0 to S - 1 do
    begin
        Tri(C0, J, (J + 1) mod S);
        Tri(C1, (R - 1) * S + (J + 1) mod S, (R - 1) * S + J);
    end;

    FTriVB := TVertexBuffer.Create([TVertexFormat.Vertex], Length(Pts));
    for V := 0 to High(Pts) do
        FTriVB.Vertices[V] := Pts[V];
    FTriIB := TIndexBuffer.Create(NI);
    for V := 0 to NI - 1 do
        FTriIB.Indices[V] := Idx[V];

    // rete di linee: anelli + meridiani
    NMer := (S + ALineEvery - 1) div ALineEvery;
    SetLength(Lines, (R * S + (R - 1) * NMer) * 2);
    NL := 0;
    for I := 0 to R - 1 do
        for J := 0 to S - 1 do
            Seg(Pts[I * S + J], Pts[I * S + (J + 1) mod S]);
    for I := 0 to R - 2 do
    begin
        J := 0;
        while J < S do
        begin
            Seg(Pts[I * S + J], Pts[(I + 1) * S + J]);
            Inc(J, ALineEvery);
        end;
    end;
    SetLength(Lines, NL);
    SetLines(Lines);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloLoft.Destroy
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Liberare i buffer dei triangoli.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
destructor THoloLoft.Destroy;
begin
    FreeAndNil(FTriVB);
    FreeAndNil(FTriIB);
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloLoft.Render
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare riempimento traslucido e poi la rete di linee.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloLoft.Render;
var
    Op: Single;
begin
    Op := FKit.FillOpacity(FStyle, FActive);
    if (Op > 0) and (FTriVB <> nil) and (FTriIB <> nil) then
        Context.DrawTriangles(FTriVB, FTriIB, FKit.FillMaterial(FStyle, FActive).Material,
            AbsoluteOpacity * Op);
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloLoft.LineColor
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TAlphaColor
//** Scopo: Colore della rete di linee per stile/stato.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloLoft.LineColor: TAlphaColor;
begin
    Result := FKit.EdgeColor(FStyle, FActive);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloLoft.GetActive
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Restituire lo stato acceso (evidenziato) della superficie.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloLoft.GetActive: Boolean;
begin
    Result := FActive;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloLoft.SetActive
//** Parametri di ingresso: Value: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Evidenziare la superficie (es. tasto o grilletto premuto).
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloLoft.SetActive(const Value: Boolean);
begin
    if FActive = Value then
        Exit;
    FActive := Value;
    Repaint;
end;

//** THoloKit ***********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloKit.Create
//** Parametri di ingresso: AColors: TSkinColors
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare i materiali condivisi con i colori della skin.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
constructor THoloKit.Create(const AColors: TSkinColors);
begin
    inherited Create;
    FShowLegends := True;
    FMatNormal := TColorMaterialSource.Create(nil);
    FMatDim := TColorMaterialSource.Create(nil);
    FMatActive := TColorMaterialSource.Create(nil);
    FMatText := TColorMaterialSource.Create(nil);
    FLineMat := TColorMaterial.Create;
    ApplyColors(AColors);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloKit.Destroy
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Liberare i materiali (le forme devono essere gia' state distrutte).
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
destructor THoloKit.Destroy;
begin
    FMatNormal.Free;
    FMatDim.Free;
    FMatActive.Free;
    FMatText.Free;
    FLineMat.Free;
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloKit.ApplyColors
//** Parametri di ingresso: AColors: TSkinColors
//** Parametri di uscita: nessuno
//** Scopo: Applicare una nuova skin.
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//** Funzionamento: aggiorna i colori dei material source condivisi; FMX
//** notifica automaticamente tutti gli oggetti che li usano. Gli spigoli
//** leggono il colore dal kit ad ogni rendering.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloKit.ApplyColors(const AColors: TSkinColors);
begin
    FColors := AColors;
    FMatNormal.Color := AColors.Primary;
    FMatDim.Color := AColors.Dim;
    FMatActive.Color := AColors.Accent;
    FMatText.Color := AColors.Text;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.FillMaterial
//** Parametri di ingresso: AStyle: THoloStyle; AActive: Boolean
//** Parametri di uscita: Result: TMaterialSource
//** Scopo: Materiale del riempimento per stile/stato.
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.FillMaterial(AStyle: THoloStyle; AActive: Boolean): TMaterialSource;
begin
    if AActive then
        Result := FMatActive
    else if AStyle = hsDim then
        Result := FMatDim
    else
        Result := FMatNormal;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.FillOpacity
//** Parametri di ingresso: AStyle: THoloStyle; AActive: Boolean
//** Parametri di uscita: Result: Single
//** Scopo: Opacita' del riempimento per stile/stato (0 = nascosto).
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.FillOpacity(AStyle: THoloStyle; AActive: Boolean): Single;
begin
    if AActive then
        Exit(0.62);
    case AStyle of
        hsNormal: Result := 0.16;
        hsDim:    Result := 0.12;
        hsGhost:  Result := 0;
        hsSolid:  Result := 0.30;
    else
        Result := 0.10;   // hsScan
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.EdgeColor
//** Parametri di ingresso: AStyle: THoloStyle; AActive: Boolean
//** Parametri di uscita: Result: TAlphaColor
//** Scopo: Colore degli spigoli per stile/stato.
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.EdgeColor(AStyle: THoloStyle; AActive: Boolean): TAlphaColor;
begin
    if AActive then
        Result := FColors.Accent
    else if AStyle = hsDim then
        Result := FColors.Dim
    else
        Result := FColors.Primary;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.Pivot
//** Parametri di ingresso: AParent: TFmxObject; X, Y, Z: Single
//** Parametri di uscita: Result: TDummy
//** Scopo: Creare un punto di articolazione (gimbal, gruppo) senza grafica.
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.Pivot(AParent: TFmxObject; X, Y, Z: Single): TDummy;
begin
    Result := TDummy.Create(nil);
    NoHit(Result);
    Result.Parent := AParent;
    Result.Position.Point := Point3D(X, Y, Z);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.Box
//** Parametri di ingresso: AParent: TFmxObject; X, Y, Z, W, H, D: Single; AStyle: THoloStyle
//** Parametri di uscita: Result: THoloShape
//** Scopo: Creare un parallelepipedo olografico centrato in (X,Y,Z).
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.Box(AParent: TFmxObject; X, Y, Z, W, H, D: Single;
    AStyle: THoloStyle): THoloShape;
begin
    Result := THoloShape.CreateShape(Self, AParent, skBox, Point3D(W, H, D), AStyle);
    Result.Position.Point := Point3D(X, Y, Z);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.Cyl
//** Parametri di ingresso: AParent: TFmxObject; X, Y, Z, ADiam, ALen: Single; AAxis: TAxis3;
//**                        AStyle: THoloStyle
//** Parametri di uscita: Result: THoloShape
//** Scopo: Creare un cilindro olografico orientato lungo l'asse richiesto.
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//** Funzionamento: il cilindro FMX ha l'asse lungo Y; per X e Z viene ruotato
//** di 90 gradi (la rotazione e' simmetrica, il segno non conta).
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.Cyl(AParent: TFmxObject; X, Y, Z, ADiam, ALen: Single;
    AAxis: TAxis3; AStyle: THoloStyle): THoloShape;
begin
    Result := THoloShape.CreateShape(Self, AParent, skCylinder, Point3D(ADiam, ALen, ADiam), AStyle);
    Result.Position.Point := Point3D(X, Y, Z);
    case AAxis of
        axX: Result.RotationAngle.Z := 90;
        axZ: Result.RotationAngle.X := 90;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.Ball
//** Parametri di ingresso: AParent: TFmxObject; X, Y, Z, W, H, D: Single; AStyle: THoloStyle
//** Parametri di uscita: Result: THoloShape
//** Scopo: Creare una sfera/ellissoide olografica.
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.Ball(AParent: TFmxObject; X, Y, Z, W, H, D: Single;
    AStyle: THoloStyle): THoloShape;
begin
    Result := THoloShape.CreateShape(Self, AParent, skSphere, Point3D(W, H, D), AStyle);
    Result.Position.Point := Point3D(X, Y, Z);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.Loft
//** Parametri di ingresso: AParent: TFmxObject; X, Y, Z: Single; ASections: array of TLoftSection;
//**                        AStyle: THoloStyle; ASegments, ALineEvery: Integer; AAxis: TAxis3
//** Parametri di uscita: Result: THoloLoft
//** Scopo: Creare una superficie loft (alta densita' di poligoni) in (X,Y,Z).
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.Loft(AParent: TFmxObject; X, Y, Z: Single;
    const ASections: array of TLoftSection; AStyle: THoloStyle; ASegments,
    ALineEvery: Integer; AAxis: TAxis3): THoloLoft;
begin
    Result := THoloLoft.CreateLoft(Self, AParent, ASections, ASegments, ALineEvery, AStyle, AAxis);
    Result.Position.Point := Point3D(X, Y, Z);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.RBox
//** Parametri di ingresso: AParent: TFmxObject; X, Y, Z, W, H, D: Single; AStyle: THoloStyle;
//**                        AAxis: TAxis3; ATaper: Single; ASegments: Integer; ARound: Single
//** Parametri di uscita: Result: THoloLoft
//** Scopo: Creare un parallelepipedo ARROTONDATO ad alta definizione (corpi, piastre, copritasti)
//**        centrato in (X,Y,Z) con ingombro W x H x D.
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//** Funzionamento: loft lungo l'asse AAxis con sezioni a quadrato
//** arrotondato (superellisse di esponente ARound) e smussi alle due
//** estremita'. ATaper (0..0.5) restringe l'estremita' "negativa" dell'asse
//** (per i copritasti con asse Z e' la faccia rivolta alla camera), come la
//** sagoma tronco-piramidale di un tasto.
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.RBox(AParent: TFmxObject; X, Y, Z, W, H, D: Single;
    AStyle: THoloStyle; AAxis: TAxis3; ATaper: Single; ASegments: Integer;
    ARound: Single): THoloLoft;
var
    L, SA, SB, Bv, T: Single;
begin
    case AAxis of
        axX:
            begin
                L := W;
                SA := H / 2;
                SB := D / 2;
            end;
        axY:
            begin
                L := H;
                SA := W / 2;
                SB := D / 2;
            end;
    else
        begin
            L := D;
            SA := W / 2;
            SB := H / 2;
        end;
    end;
    Bv := Min(L * 0.25, Min(SA, SB) * 0.35);
    T := EnsureRange(ATaper, 0, 0.5);
    Result := Loft(AParent, X, Y, Z, [
        Sec(-L / 2,            0, 0, SA * (1 - T) - Bv * 0.6, SB * (1 - T) - Bv * 0.6, ARound),
        Sec(-L / 2 + Bv * 0.4, 0, 0, SA * (1 - T) - Bv * 0.15, SB * (1 - T) - Bv * 0.15, ARound),
        Sec(-L / 2 + Bv,       0, 0, SA * (1 - T * 0.85), SB * (1 - T * 0.85), ARound),
        Sec(L / 2 - Bv,        0, 0, SA, SB, ARound),
        Sec(L / 2,             0, 0, SA - Bv * 0.4, SB - Bv * 0.4, ARound)],
        AStyle, ASegments, 3, AAxis);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.Ring
//** Parametri di ingresso: AParent: TFmxObject; X, Y, Z, ARadius: Single; ADashed: Boolean; AStyle:
//**                        THoloStyle
//** Parametri di uscita: Result: THoloRing
//** Scopo: Creare un anello orizzontale (piano XZ).
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.Ring(AParent: TFmxObject; X, Y, Z, ARadius: Single;
    ADashed: Boolean; AStyle: THoloStyle): THoloRing;
begin
    Result := THoloRing.CreateRing(Self, AParent, ARadius, ADashed, AStyle);
    Result.Position.Point := Point3D(X, Y, Z);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.Text
//** Parametri di ingresso: AParent: TFmxObject; X, Y, Z, ASize: Single; S: string; AForce: Boolean;
//**                        AFamily: string
//** Parametri di uscita: Result: TText3D
//** Scopo: Creare una scritta 3D (legenda di tasti/pulsanti) rivolta alla camera.
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//** Funzionamento: la scritta giace nel piano XY ed e' adattata (Stretch) a un
//** riquadro alto ASize; restituisce nil se le legende sono disattivate,
//** salvo AForce = True (scritte indispensabili, es. ABXY del gamepad).
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.Text(AParent: TFmxObject; X, Y, Z, ASize: Single;
    const S: string; AForce: Boolean; const AFamily: string): TText3D;
begin
    Result := nil;
    if (S = '') or not (FShowLegends or AForce) then
        Exit;
    Result := TText3D.Create(nil);
    NoHit(Result);
    Result.Parent := AParent;
    Result.Position.Point := Point3D(X, Y, Z);
    Result.Width := Max(ASize * 0.7, ASize * Length(S) * 0.6);
    Result.Height := ASize;
    Result.Depth := 0.01;
    Result.Stretch := True;
    if AFamily <> '' then
        Result.Font.Family := AFamily
    else
        Result.Font.Family := 'Segoe UI';
    Result.Text := S;
    Result.MaterialSource := FMatText;
    Result.MaterialShaftSource := FMatText;
    Result.MaterialBackSource := FMatText;
end;

end.
