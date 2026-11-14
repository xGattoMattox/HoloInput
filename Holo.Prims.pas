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
        dY, dCX, dCZ, dA, dB, dN: Single;
    end;

    /// Base: oggetto 3D che disegna una lista di segmenti in cache.
    THoloLines = class(TDummy)
    private
        oFKit: THoloKit;
        oFVB: TVertexBuffer;
        oFIB: TIndexBuffer;
    protected
        procedure Render; override;
        function iLineColor: TAlphaColor; virtual; abstract;
        procedure SetLines(const aAPoints: TArray<TPoint3D>);
        /// Collega il kit (serve alle classi derivate dichiarate in altre unit,
        /// es. Holo.Obj, che non vedono il campo privato oFKit).
        procedure AttachKit(oAKit: THoloKit);
        /// Stato "acceso" (input premuto). Le classi derivate lo ridefiniscono.
        function bGetActive: Boolean; virtual;
        procedure SetActive(const bValue: Boolean); virtual;
    public
        destructor Destroy; override;
        property oKit: THoloKit read oFKit;
        property bActive: Boolean read bGetActive write SetActive;
    end;

    /// Forma olografica (riempimento + spigoli).
    THoloShape = class(THoloLines)
    private
        eFKind: TShapeKind;
        eFStyle: THoloStyle;
        oFFill: TControl3D;
        bFActive: Boolean;
        rFSize: TPoint3D;
        procedure RebuildEdges;
        procedure UpdateFill;
        procedure SetStyle(const eValue: THoloStyle);
    protected
        function iLineColor: TAlphaColor; override;
        function bGetActive: Boolean; override;
        procedure SetActive(const bValue: Boolean); override;
    public
        constructor CreateShape(oAKit: THoloKit; oAParent: TFmxObject; eAKind: TShapeKind;
            const rASize: TPoint3D; eAStyle: THoloStyle);
        /// (non "Resize3D": nasconderebbe il metodo virtuale omonimo di TControl3D, warning W1010)
        procedure SetShapeSize(const rASize: TPoint3D);
        procedure RefreshLook;
        property eStyle: THoloStyle read eFStyle write SetStyle;
        property oFill: TControl3D read oFFill;
        property rSize: TPoint3D read rFSize;
    end;

    /// Anello (eventualmente tratteggiato) nel piano XZ: base del "proiettore".
    THoloRing = class(THoloLines)
    private
        dFRadius: Single;
        bFDashed: Boolean;
        eFStyle: THoloStyle;
        procedure Rebuild;
    protected
        function iLineColor: TAlphaColor; override;
    public
        constructor CreateRing(oAKit: THoloKit; oAParent: TFmxObject; dARadius: Single;
            bADashed: Boolean; eAStyle: THoloStyle);
        procedure SetRadius(dARadius: Single);
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
        eFStyle: THoloStyle;
        bFActive: Boolean;
        oFTriVB: TVertexBuffer;
        oFTriIB: TIndexBuffer;
    protected
        procedure Render; override;
        function iLineColor: TAlphaColor; override;
        function bGetActive: Boolean; override;
        procedure SetActive(const bValue: Boolean); override;
    public
        constructor CreateLoft(oAKit: THoloKit; oAParent: TFmxObject;
            const aASections: array of TLoftSection; iASegments, iALineEvery: Integer;
            eAStyle: THoloStyle; eAAxis: TAxis3 = axY);
        destructor Destroy; override;
    end;

    /// Fabbrica di forme + materiali condivisi della skin corrente.
    THoloKit = class
    private
        rFColors: TSkinColors;
        oFMatNormal, oFMatDim, oFMatActive, oFMatText: TColorMaterialSource;
        oFLineMat: TColorMaterial;
        bFShowLegends: Boolean;
    public
        constructor Create(const rAColors: TSkinColors);
        destructor Destroy; override;
        procedure ApplyColors(const rAColors: TSkinColors);
        function oFillMaterial(eAStyle: THoloStyle; bAActive: Boolean): TMaterialSource;
        function dFillOpacity(eAStyle: THoloStyle; bAActive: Boolean): Single;
        function iEdgeColor(eAStyle: THoloStyle; bAActive: Boolean): TAlphaColor;

        function oPivot(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ: Single): TDummy;
        function oBox(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dAWidth, dAHeight, dADepth: Single;
            eAStyle: THoloStyle = hsNormal): THoloShape;
        function oCyl(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dADiam, dALen: Single;
            eAAxis: TAxis3 = axY; eAStyle: THoloStyle = hsNormal): THoloShape;
        function oBall(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dAWidth, dAHeight, dADepth: Single;
            eAStyle: THoloStyle = hsNormal): THoloShape;
        function oLoft(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ: Single;
            const aASections: array of TLoftSection;
            eAStyle: THoloStyle = hsSolid; iASegments: Integer = 32; iALineEvery: Integer = 2;
            eAAxis: TAxis3 = axY): THoloLoft;
        function oRBox(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dAWidth, dAHeight, dADepth: Single;
            eAStyle: THoloStyle = hsNormal; eAAxis: TAxis3 = axZ; dATaper: Single = 0;
            iASegments: Integer = 24; dARound: Single = 5): THoloLoft;
        function oRing(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dARadius: Single; bADashed: Boolean;
            eAStyle: THoloStyle = hsDim): THoloRing;
        function oText(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dASize: Single; const sAText: string;
            bAForce: Boolean = False; const sAFamily: string = ''): TText3D;

        property rColors: TSkinColors read rFColors;
        property oLineMaterial: TColorMaterial read oFLineMat;
        property bShowLegends: Boolean read bFShowLegends write bFShowLegends;
    end;

/// Imposta l'opacita' di un oggetto 3D (anche dove la proprieta' e' protected).
procedure SetObjOpacity(oAObj: TControl3D; dAValue: Single);
/// Costruisce una sezione per THoloKit.Loft.
function rSec(dAPosY, dACenterX, dACenterZ, dAHalfX, dAHalfZ: Single; dAExponent: Single = 2): TLoftSection;

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
//** Parametri di ingresso: oAObj: TControl3D; oAMat: TMaterialSource
//** Parametri di uscita: nessuno
//** Scopo: Assegnare un materiale a un mesh primitivo indipendentemente dalla classe.
//** Data Ultima Modifica: 19/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure SetMeshMaterial(oAObj: TControl3D; oAMat: TMaterialSource);
begin
    if oAObj is TCube then
        TCube(oAObj).MaterialSource := oAMat
    else if oAObj is TCylinder then
        TCylinder(oAObj).MaterialSource := oAMat
    else if oAObj is TSphere then
        TSphere(oAObj).MaterialSource := oAMat;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: SetObjOpacity
//** Parametri di ingresso: oAObj: TControl3D; dAValue: Single
//** Parametri di uscita: nessuno
//** Scopo: Impostare l'opacita' di un oggetto 3D tramite il cracker.
//** Data Ultima Modifica: 20/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure SetObjOpacity(oAObj: TControl3D; dAValue: Single);
begin
    if oAObj <> nil then
        TControl3DAccess(oAObj).Opacity := EnsureRange(dAValue, 0, 1);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: NoHit
//** Parametri di ingresso: oAObj: TControl3D
//** Parametri di uscita: nessuno
//** Scopo: Rendere un oggetto 3D "trasparente" al mouse.
//** Data Ultima Modifica: 20/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure NoHit(oAObj: TControl3D);
begin
    TControl3DAccess(oAObj).HitTest := False;
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
    FreeAndNil(oFVB);
    FreeAndNil(oFIB);
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloLines.SetLines
//** Parametri di ingresso: aAPoints: TArray<TPoint3D>
//** Parametri di uscita: nessuno
//** Scopo: (ri)costruire i buffer delle linee.
//** Data Ultima Modifica: 20/09/2026
//***********************************************************************************************************
//** Funzionamento: aAPoints contiene coppie di punti (inizio, fine) di ogni
//** segmento; vertici e indici sono generati una volta sola e riutilizzati
//** ad ogni frame.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloLines.SetLines(const aAPoints: TArray<TPoint3D>);
var
    iPoint, iCount: Integer;
begin
    FreeAndNil(oFVB);
    FreeAndNil(oFIB);
    iCount := Length(aAPoints) and not 1;
    if iCount = 0 then
        Exit;
    oFVB := TVertexBuffer.Create([TVertexFormat.Vertex], iCount);
    oFIB := TIndexBuffer.Create(iCount);
    for iPoint := 0 to iCount - 1 do
    begin
        oFVB.Vertices[iPoint] := aAPoints[iPoint];
        oFIB.Indices[iPoint] := iPoint;
    end;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloLines.AttachKit
//** Parametri di ingresso: oAKit: THoloKit
//** Parametri di uscita: nessuno
//** Scopo: Collegare il kit della skin (materiali e colori condivisi).
//** Data Ultima Modifica: 16/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloLines.AttachKit(oAKit: THoloKit);
begin
    oFKit := oAKit;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloLines.bGetActive
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Default per oggetti senza stato acceso (es. anelli).
//** Data Ultima Modifica: 20/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloLines.bGetActive: Boolean;
begin
    Result := False;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloLines.SetActive
//** Parametri di ingresso: bValue: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Ignorare l'accensione: gli oggetti di sole linee non hanno stato acceso.
//** Data Ultima Modifica: 20/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloLines.SetActive(const bValue: Boolean);
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
    if (oFVB = nil) or (oFIB = nil) or (oFKit = nil) then
        Exit;
    oFKit.oLineMaterial.Color := iLineColor;
    Context.DrawLines(oFVB, oFIB, oFKit.oLineMaterial, AbsoluteOpacity);
end;

//** THoloShape *********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloShape.CreateShape
//** Parametri di ingresso: oAKit: THoloKit; oAParent: TFmxObject; eAKind: TShapeKind; rASize: TPoint3D;
//**                        eAStyle: THoloStyle
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare una forma olografica e agganciarla al genitore.
//** Data Ultima Modifica: 20/09/2026
//***********************************************************************************************************
//** Funzionamento: crea il mesh di riempimento del tipo richiesto (figlio della
//** forma), lo rende non scrivente nello Z-buffer e genera gli spigoli.
//***********************************************************************************************************
//***********************************************************************************************************
constructor THoloShape.CreateShape(oAKit: THoloKit; oAParent: TFmxObject;
    eAKind: TShapeKind; const rASize: TPoint3D; eAStyle: THoloStyle);
begin
    inherited Create(nil);
    oFKit := oAKit;
    eFKind := eAKind;
    eFStyle := eAStyle;
    rFSize := rASize;
    NoHit(Self);
    Parent := oAParent;

    case eAKind of
        skBox:      oFFill := TCube.Create(nil);
        skCylinder: oFFill := TCylinder.Create(nil);
    else
        oFFill := TSphere.Create(nil);
    end;
    oFFill.Parent := Self;
    if oFFill is TCylinder then
        TCylinder(oFFill).SubdivisionsAxes := 32
    else if oFFill is TSphere then
    begin
        TSphere(oFFill).SubdivisionsAxes := 32;
        TSphere(oFFill).SubdivisionsHeight := 16;
    end;
    NoHit(oFFill);
    TControl3DAccess(oFFill).ZWrite := False;
    TControl3DAccess(oFFill).Width := rASize.X;
    TControl3DAccess(oFFill).Height := rASize.Y;
    TControl3DAccess(oFFill).Depth := rASize.Z;
    UpdateFill;
    RebuildEdges;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloShape.SetShapeSize
//** Parametri di ingresso: rASize: TPoint3D
//** Parametri di uscita: nessuno
//** Scopo: Cambiare le dimensioni della forma (riempimento + spigoli).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloShape.SetShapeSize(const rASize: TPoint3D);
begin
    rFSize := rASize;
    TControl3DAccess(oFFill).Width := rASize.X;
    TControl3DAccess(oFFill).Height := rASize.Y;
    TControl3DAccess(oFFill).Depth := rASize.Z;
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
    aPoints: TArray<TPoint3D>;
    dHalfX, dHalfY, dHalfZ, dAngle0, dAngle1: Single;
    iSegment: Integer;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: Add
    //** Parametri di ingresso: rAPointA, rAPointB: TPoint3D
    //** Parametri di uscita: nessuno
    //** Scopo: Aggiungere un segmento (coppia di punti) all'elenco degli spigoli.
    //** Data Ultima Modifica: 20/09/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Add(const rAPointA, rAPointB: TPoint3D);
    begin
        aPoints := aPoints + [rAPointA, rAPointB];
    end;

begin
    aPoints := nil;
    dHalfX := rFSize.X / 2;
    dHalfY := rFSize.Y / 2;
    dHalfZ := rFSize.Z / 2;
    if eFStyle <> hsScan then
        case eFKind of
            skBox:
                begin
                    // faccia anteriore (z = -HZ) e posteriore (z = +HZ)
                    Add(Point3D(-dHalfX, -dHalfY, -dHalfZ), Point3D(dHalfX, -dHalfY, -dHalfZ));
                    Add(Point3D(dHalfX, -dHalfY, -dHalfZ), Point3D(dHalfX, dHalfY, -dHalfZ));
                    Add(Point3D(dHalfX, dHalfY, -dHalfZ), Point3D(-dHalfX, dHalfY, -dHalfZ));
                    Add(Point3D(-dHalfX, dHalfY, -dHalfZ), Point3D(-dHalfX, -dHalfY, -dHalfZ));
                    Add(Point3D(-dHalfX, -dHalfY, dHalfZ), Point3D(dHalfX, -dHalfY, dHalfZ));
                    Add(Point3D(dHalfX, -dHalfY, dHalfZ), Point3D(dHalfX, dHalfY, dHalfZ));
                    Add(Point3D(dHalfX, dHalfY, dHalfZ), Point3D(-dHalfX, dHalfY, dHalfZ));
                    Add(Point3D(-dHalfX, dHalfY, dHalfZ), Point3D(-dHalfX, -dHalfY, dHalfZ));
                    // spigoli di profondita'
                    Add(Point3D(-dHalfX, -dHalfY, -dHalfZ), Point3D(-dHalfX, -dHalfY, dHalfZ));
                    Add(Point3D(dHalfX, -dHalfY, -dHalfZ), Point3D(dHalfX, -dHalfY, dHalfZ));
                    Add(Point3D(dHalfX, dHalfY, -dHalfZ), Point3D(dHalfX, dHalfY, dHalfZ));
                    Add(Point3D(-dHalfX, dHalfY, -dHalfZ), Point3D(-dHalfX, dHalfY, dHalfZ));
                end;
            skCylinder:
                begin
                    for iSegment := 0 to SEG_CYL - 1 do
                    begin
                        dAngle0 := 2 * Pi * iSegment / SEG_CYL;
                        dAngle1 := 2 * Pi * (iSegment + 1) / SEG_CYL;
                        Add(Point3D(dHalfX * Cos(dAngle0), -dHalfY, dHalfZ * Sin(dAngle0)), Point3D(dHalfX * Cos(dAngle1), -dHalfY, dHalfZ * Sin(dAngle1)));
                        Add(Point3D(dHalfX * Cos(dAngle0), dHalfY, dHalfZ * Sin(dAngle0)), Point3D(dHalfX * Cos(dAngle1), dHalfY, dHalfZ * Sin(dAngle1)));
                    end;
                    for iSegment := 0 to 3 do
                    begin
                        dAngle0 := Pi / 2 * iSegment + Pi / 4;
                        Add(Point3D(dHalfX * Cos(dAngle0), -dHalfY, dHalfZ * Sin(dAngle0)), Point3D(dHalfX * Cos(dAngle0), dHalfY, dHalfZ * Sin(dAngle0)));
                    end;
                end;
            skSphere:
                for iSegment := 0 to SEG_SPH - 1 do
                begin
                    dAngle0 := 2 * Pi * iSegment / SEG_SPH;
                    dAngle1 := 2 * Pi * (iSegment + 1) / SEG_SPH;
                    Add(Point3D(dHalfX * Cos(dAngle0), dHalfY * Sin(dAngle0), 0),
                        Point3D(dHalfX * Cos(dAngle1), dHalfY * Sin(dAngle1), 0));
                    Add(Point3D(dHalfX * Cos(dAngle0), 0, dHalfZ * Sin(dAngle0)),
                        Point3D(dHalfX * Cos(dAngle1), 0, dHalfZ * Sin(dAngle1)));
                    Add(Point3D(0, dHalfY * Cos(dAngle0), dHalfZ * Sin(dAngle0)), Point3D(0,
                        dHalfY * Cos(dAngle1), dHalfZ * Sin(dAngle1)));
                end;
        end;
    SetLines(aPoints);
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
    dOpacity: Single;
begin
    dOpacity := oFKit.dFillOpacity(eFStyle, bFActive);
    SetMeshMaterial(oFFill, oFKit.oFillMaterial(eFStyle, bFActive));
    TControl3DAccess(oFFill).Opacity := dOpacity;
    oFFill.Visible := dOpacity > 0;
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
//** Parametri di ingresso: bValue: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Accendere/spegnere l'evidenziazione (input premuto).
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//** Funzionamento: cambia materiale/opacita' solo se lo stato cambia, cosi'
//** la scena viene ridisegnata solo quando serve.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloShape.SetActive(const bValue: Boolean);
begin
    if bFActive = bValue then
        Exit;
    bFActive := bValue;
    UpdateFill;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloShape.SetStyle
//** Parametri di ingresso: eValue: THoloStyle
//** Parametri di uscita: nessuno
//** Scopo: Cambiare lo stile della forma.
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloShape.SetStyle(const eValue: THoloStyle);
begin
    if eFStyle = eValue then
        Exit;
    eFStyle := eValue;
    UpdateFill;
    RebuildEdges;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloShape.bGetActive
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Restituire lo stato acceso (evidenziato) della forma.
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloShape.bGetActive: Boolean;
begin
    Result := bFActive;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloShape.iLineColor
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TAlphaColor
//** Scopo: Colore degli spigoli in base a stile e stato.
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloShape.iLineColor: TAlphaColor;
begin
    Result := oFKit.iEdgeColor(eFStyle, bFActive);
end;

//** THoloRing **********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloRing.CreateRing
//** Parametri di ingresso: oAKit: THoloKit; oAParent: TFmxObject; dARadius: Single; bADashed: Boolean;
//**                        eAStyle: THoloStyle
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare un anello nel piano XZ (orizzontale).
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
constructor THoloRing.CreateRing(oAKit: THoloKit; oAParent: TFmxObject;
    dARadius: Single; bADashed: Boolean; eAStyle: THoloStyle);
begin
    inherited Create(nil);
    oFKit := oAKit;
    dFRadius := dARadius;
    bFDashed := bADashed;
    eFStyle := eAStyle;
    NoHit(Self);
    Parent := oAParent;
    Rebuild;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloRing.SetRadius
//** Parametri di ingresso: dARadius: Single
//** Parametri di uscita: nessuno
//** Scopo: Cambiare il raggio dell'anello.
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloRing.SetRadius(dARadius: Single);
begin
    if SameValue(dFRadius, dARadius, 0.0001) then
        Exit;
    dFRadius := dARadius;
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
    aPoints: TArray<TPoint3D>;
    iSegment: Integer;
    dAngle0, dAngle1: Single;
begin
    aPoints := nil;
    for iSegment := 0 to SEG - 1 do
    begin
        if bFDashed and Odd(iSegment) then
            Continue;
        dAngle0 := 2 * Pi * iSegment / SEG;
        dAngle1 := 2 * Pi * (iSegment + 1) / SEG;
        aPoints := aPoints + [Point3D(dFRadius * Cos(dAngle0), 0, dFRadius * Sin(dAngle0)),
                  Point3D(dFRadius * Cos(dAngle1), 0, dFRadius * Sin(dAngle1))];
    end;
    SetLines(aPoints);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloRing.iLineColor
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TAlphaColor
//** Scopo: Colore dell'anello in base allo stile.
//** Data Ultima Modifica: 21/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloRing.iLineColor: TAlphaColor;
begin
    Result := oFKit.iEdgeColor(eFStyle, False);
end;

//** THoloLoft **********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: rSec
//** Parametri di ingresso: dAPosY, dACenterX, dACenterZ, dAHalfX, dAHalfZ: Single; dAExponent: Single
//** Parametri di uscita: Result: TLoftSection
//** Scopo: Costruire una sezione di loft.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function rSec(dAPosY, dACenterX, dACenterZ, dAHalfX, dAHalfZ: Single; dAExponent: Single): TLoftSection;
begin
    Result.dY := dAPosY;
    Result.dCX := dACenterX;
    Result.dCZ := dACenterZ;
    Result.dA := dAHalfX;
    Result.dB := dAHalfZ;
    Result.dN := dAExponent;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: rSuperPoint
//** Parametri di ingresso: rASection: TLoftSection; dAAngle: Single; eAAxis: TAxis3
//** Parametri di uscita: Result: TPoint3D
//** Scopo: Punto di una superellisse (|u/a|^n + |v/b|^n = 1) all'angolo T, orientata secondo l'asse
//**        del loft.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//** Funzionamento: calcola le coordinate (u, v) nel piano della sezione e
//** la quota s lungo l'asse, poi le colloca negli assi del mondo.
//***********************************************************************************************************
//***********************************************************************************************************
function rSuperPoint(const rASection: TLoftSection; dAAngle: Single; eAAxis: TAxis3): TPoint3D;
var
    dCosine, dSine, dExponent, dCoordU, dCoordV: Single;
begin
    dCosine := Cos(dAAngle);
    dSine := Sin(dAAngle);
    dExponent := 2 / Max(0.5, rASection.dN);
    dCoordU := rASection.dCX + rASection.dA * Sign(dCosine) * Power(Abs(dCosine), dExponent);
    dCoordV := rASection.dCZ + rASection.dB * Sign(dSine) * Power(Abs(dSine), dExponent);
    case eAAxis of
        axZ: Result := Point3D(dCoordU, dCoordV, rASection.dY);
        axX: Result := Point3D(rASection.dY, dCoordU, dCoordV);
    else
        Result := Point3D(dCoordU, rASection.dY, dCoordV);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: rSectionCenter
//** Parametri di ingresso: rASection: TLoftSection; eAAxis: TAxis3
//** Parametri di uscita: Result: TPoint3D
//** Scopo: Centro di una sezione nelle coordinate del mondo.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function rSectionCenter(const rASection: TLoftSection; eAAxis: TAxis3): TPoint3D;
begin
    case eAAxis of
        axZ: Result := Point3D(rASection.dCX, rASection.dCZ, rASection.dY);
        axX: Result := Point3D(rASection.dY, rASection.dCX, rASection.dCZ);
    else
        Result := Point3D(rASection.dCX, rASection.dY, rASection.dCZ);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloLoft.CreateLoft
//** Parametri di ingresso: oAKit: THoloKit; oAParent: TFmxObject; aASections: array of TLoftSection;
//**                        iASegments, iALineEvery: Integer; eAStyle: THoloStyle; eAAxis: TAxis3
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare la superficie a partire dalle sezioni.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//** Funzionamento:
//**  - ogni sezione diventa un anello di iASegments vertici;
//**  - anelli consecutivi sono uniti da coppie di triangoli; le due estremita'
//**    sono chiuse da un "ventaglio" attorno al centro della sezione;
//**  - ogni triangolo e' inserito con entrambi gli ordini dei vertici, cosi'
//**    la superficie e' visibile da qualunque lato senza cambiare lo stato
//**    di culling del contesto;
//**  - linee: tutti gli anelli + un meridiano ogni iALineEvery vertici;
//**  - tutti gli array sono pre-dimensionati (nessuna riallocazione), cosi'
//**    anche centinaia di loft (es. i copritasti) si creano rapidamente.
//***********************************************************************************************************
//***********************************************************************************************************
constructor THoloLoft.CreateLoft(oAKit: THoloKit; oAParent: TFmxObject;
    const aASections: array of TLoftSection; iASegments, iALineEvery: Integer;
    eAStyle: THoloStyle; eAAxis: TAxis3);
var
    iRingCount, iSegCount, iRing, iSegment, iVert, iBase, iStartCap, iEndCap, iIndexCount, iLineCount,
        iNMer: Integer;
    aPts: TArray<TPoint3D>;
    aLines: TArray<TPoint3D>;
    aIdx: TArray<Integer>;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: Tri
    //** Parametri di ingresso: iAVertA, iAVertB, iAVertC: Integer
    //** Parametri di uscita: nessuno
    //** Scopo: Aggiungere un triangolo a due facce (entrambi i versi) agli indici del loft.
    //** Data Ultima Modifica: 22/09/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Tri(iAVertA, iAVertB, iAVertC: Integer);
    begin
        aIdx[iIndexCount] := iAVertA;     aIdx[iIndexCount + 1] := iAVertB; aIdx[iIndexCount + 2] := iAVertC;
        aIdx[iIndexCount + 3] := iAVertA; aIdx[iIndexCount + 4] := iAVertC; aIdx[iIndexCount + 5] := iAVertB;
        Inc(iIndexCount, 6);
    end;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: Seg
    //** Parametri di ingresso: rAPointA, rAPointB: TPoint3D
    //** Parametri di uscita: nessuno
    //** Scopo: Aggiungere un segmento all'elenco delle linee del loft.
    //** Data Ultima Modifica: 22/09/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Seg(const rAPointA, rAPointB: TPoint3D);
    begin
        aLines[iLineCount] := rAPointA;
        aLines[iLineCount + 1] := rAPointB;
        Inc(iLineCount, 2);
    end;

begin
    inherited Create(nil);
    oFKit := oAKit;
    eFStyle := eAStyle;
    NoHit(Self);
    ZWrite := False;
    Parent := oAParent;

    iRingCount := Length(aASections);
    iSegCount := Max(6, iASegments);
    if iALineEvery < 1 then
        iALineEvery := 1;
    if iRingCount < 2 then
        Exit;

    // vertici degli anelli + 2 centri per i tappi
    SetLength(aPts, iRingCount * iSegCount + 2);
    for iRing := 0 to iRingCount - 1 do
        for iSegment := 0 to iSegCount - 1 do
            aPts[iRing * iSegCount + iSegment] := rSuperPoint(aASections[iRing],
                2 * Pi * iSegment / iSegCount, eAAxis);
    iStartCap := iRingCount * iSegCount;
    iEndCap := iRingCount * iSegCount + 1;
    aPts[iStartCap] := rSectionCenter(aASections[0], eAAxis);
    aPts[iEndCap] := rSectionCenter(aASections[iRingCount - 1], eAAxis);

    // triangoli: (R-1)*S*2 tra gli anelli + 2*S per i tappi, 6 indici ciascuno
    SetLength(aIdx, ((iRingCount - 1) * iSegCount * 2 + 2 * iSegCount) * 6);
    iIndexCount := 0;
    for iRing := 0 to iRingCount - 2 do
        for iSegment := 0 to iSegCount - 1 do
        begin
            iBase := iRing * iSegCount;
            Tri(iBase + iSegment, iBase + iSegCount + iSegment, iBase + (iSegment + 1) mod iSegCount);
            Tri(iBase + (iSegment + 1) mod iSegCount, iBase + iSegCount + iSegment, iBase + iSegCount
                + (iSegment + 1) mod iSegCount);
        end;
    for iSegment := 0 to iSegCount - 1 do
    begin
        Tri(iStartCap, iSegment, (iSegment + 1) mod iSegCount);
        Tri(iEndCap, (iRingCount - 1) * iSegCount + (iSegment + 1) mod iSegCount, (iRingCount
            - 1) * iSegCount + iSegment);
    end;

    oFTriVB := TVertexBuffer.Create([TVertexFormat.Vertex], Length(aPts));
    for iVert := 0 to High(aPts) do
        oFTriVB.Vertices[iVert] := aPts[iVert];
    oFTriIB := TIndexBuffer.Create(iIndexCount);
    for iVert := 0 to iIndexCount - 1 do
        oFTriIB.Indices[iVert] := aIdx[iVert];

    // rete di linee: anelli + meridiani
    iNMer := (iSegCount + iALineEvery - 1) div iALineEvery;
    SetLength(aLines, (iRingCount * iSegCount + (iRingCount - 1) * iNMer) * 2);
    iLineCount := 0;
    for iRing := 0 to iRingCount - 1 do
        for iSegment := 0 to iSegCount - 1 do
            Seg(aPts[iRing * iSegCount + iSegment], aPts[iRing * iSegCount + (iSegment + 1) mod iSegCount]);
    for iRing := 0 to iRingCount - 2 do
    begin
        iSegment := 0;
        while iSegment < iSegCount do
        begin
            Seg(aPts[iRing * iSegCount + iSegment], aPts[(iRing + 1) * iSegCount + iSegment]);
            Inc(iSegment, iALineEvery);
        end;
    end;
    SetLength(aLines, iLineCount);
    SetLines(aLines);
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
    FreeAndNil(oFTriVB);
    FreeAndNil(oFTriIB);
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
    dOpacity: Single;
begin
    dOpacity := oFKit.dFillOpacity(eFStyle, bFActive);
    if (dOpacity > 0) and (oFTriVB <> nil) and (oFTriIB <> nil) then
        Context.DrawTriangles(oFTriVB, oFTriIB, oFKit.oFillMaterial(eFStyle, bFActive).Material,
            AbsoluteOpacity * dOpacity);
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloLoft.iLineColor
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TAlphaColor
//** Scopo: Colore della rete di linee per stile/stato.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloLoft.iLineColor: TAlphaColor;
begin
    Result := oFKit.iEdgeColor(eFStyle, bFActive);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloLoft.bGetActive
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Restituire lo stato acceso (evidenziato) della superficie.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloLoft.bGetActive: Boolean;
begin
    Result := bFActive;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloLoft.SetActive
//** Parametri di ingresso: bValue: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Evidenziare la superficie (es. tasto o grilletto premuto).
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloLoft.SetActive(const bValue: Boolean);
begin
    if bFActive = bValue then
        Exit;
    bFActive := bValue;
    Repaint;
end;

//** THoloKit ***********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloKit.Create
//** Parametri di ingresso: rAColors: TSkinColors
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare i materiali condivisi con i colori della skin.
//** Data Ultima Modifica: 22/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
constructor THoloKit.Create(const rAColors: TSkinColors);
begin
    inherited Create;
    bFShowLegends := True;
    oFMatNormal := TColorMaterialSource.Create(nil);
    oFMatDim := TColorMaterialSource.Create(nil);
    oFMatActive := TColorMaterialSource.Create(nil);
    oFMatText := TColorMaterialSource.Create(nil);
    oFLineMat := TColorMaterial.Create;
    ApplyColors(rAColors);
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
    oFMatNormal.Free;
    oFMatDim.Free;
    oFMatActive.Free;
    oFMatText.Free;
    oFLineMat.Free;
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloKit.ApplyColors
//** Parametri di ingresso: rAColors: TSkinColors
//** Parametri di uscita: nessuno
//** Scopo: Applicare una nuova skin.
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//** Funzionamento: aggiorna i colori dei material source condivisi; FMX
//** notifica automaticamente tutti gli oggetti che li usano. Gli spigoli
//** leggono il colore dal kit ad ogni rendering.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloKit.ApplyColors(const rAColors: TSkinColors);
begin
    rFColors := rAColors;
    oFMatNormal.Color := rAColors.iPrimary;
    oFMatDim.Color := rAColors.iDim;
    oFMatActive.Color := rAColors.iAccent;
    oFMatText.Color := rAColors.iText;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.oFillMaterial
//** Parametri di ingresso: eAStyle: THoloStyle; bAActive: Boolean
//** Parametri di uscita: Result: TMaterialSource
//** Scopo: Materiale del riempimento per stile/stato.
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.oFillMaterial(eAStyle: THoloStyle; bAActive: Boolean): TMaterialSource;
begin
    if bAActive then
        Result := oFMatActive
    else if eAStyle = hsDim then
        Result := oFMatDim
    else
        Result := oFMatNormal;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.dFillOpacity
//** Parametri di ingresso: eAStyle: THoloStyle; bAActive: Boolean
//** Parametri di uscita: Result: Single
//** Scopo: Opacita' del riempimento per stile/stato (0 = nascosto).
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.dFillOpacity(eAStyle: THoloStyle; bAActive: Boolean): Single;
begin
    if bAActive then
        Exit(0.62);
    case eAStyle of
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
//** Nome funzione: THoloKit.iEdgeColor
//** Parametri di ingresso: eAStyle: THoloStyle; bAActive: Boolean
//** Parametri di uscita: Result: TAlphaColor
//** Scopo: Colore degli spigoli per stile/stato.
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.iEdgeColor(eAStyle: THoloStyle; bAActive: Boolean): TAlphaColor;
begin
    if bAActive then
        Result := rFColors.iAccent
    else if eAStyle = hsDim then
        Result := rFColors.iDim
    else
        Result := rFColors.iPrimary;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.oPivot
//** Parametri di ingresso: oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ: Single
//** Parametri di uscita: Result: TDummy
//** Scopo: Creare un punto di articolazione (gimbal, gruppo) senza grafica.
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.oPivot(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ: Single): TDummy;
begin
    Result := TDummy.Create(nil);
    NoHit(Result);
    Result.Parent := oAParent;
    Result.Position.Point := Point3D(dAPosX, dAPosY, dAPosZ);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.oBox
//** Parametri di ingresso: oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dAWidth, dAHeight, dADepth: Single;
//**                        eAStyle: THoloStyle
//** Parametri di uscita: Result: THoloShape
//** Scopo: Creare un parallelepipedo olografico centrato in (X,Y,Z).
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.oBox(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dAWidth, dAHeight, dADepth: Single;
    eAStyle: THoloStyle): THoloShape;
begin
    Result := THoloShape.CreateShape(Self, oAParent, skBox, Point3D(dAWidth, dAHeight, dADepth), eAStyle);
    Result.Position.Point := Point3D(dAPosX, dAPosY, dAPosZ);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.oCyl
//** Parametri di ingresso: oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dADiam, dALen: Single; eAAxis:
//**                        TAxis3;
//**                        eAStyle: THoloStyle
//** Parametri di uscita: Result: THoloShape
//** Scopo: Creare un cilindro olografico orientato lungo l'asse richiesto.
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//** Funzionamento: il cilindro FMX ha l'asse lungo Y; per X e Z viene ruotato
//** di 90 gradi (la rotazione e' simmetrica, il segno non conta).
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.oCyl(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dADiam, dALen: Single;
    eAAxis: TAxis3; eAStyle: THoloStyle): THoloShape;
begin
    Result := THoloShape.CreateShape(Self, oAParent, skCylinder, Point3D(dADiam, dALen, dADiam), eAStyle);
    Result.Position.Point := Point3D(dAPosX, dAPosY, dAPosZ);
    case eAAxis of
        axX: Result.RotationAngle.Z := 90;
        axZ: Result.RotationAngle.X := 90;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.oBall
//** Parametri di ingresso: oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dAWidth, dAHeight, dADepth: Single;
//**                        eAStyle: THoloStyle
//** Parametri di uscita: Result: THoloShape
//** Scopo: Creare una sfera/ellissoide olografica.
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.oBall(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dAWidth, dAHeight, dADepth: Single;
    eAStyle: THoloStyle): THoloShape;
begin
    Result := THoloShape.CreateShape(Self, oAParent, skSphere, Point3D(dAWidth, dAHeight, dADepth), eAStyle);
    Result.Position.Point := Point3D(dAPosX, dAPosY, dAPosZ);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.oLoft
//** Parametri di ingresso: oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ: Single; aASections: array of
//**                        TLoftSection;
//**                        eAStyle: THoloStyle; iASegments, iALineEvery: Integer; eAAxis: TAxis3
//** Parametri di uscita: Result: THoloLoft
//** Scopo: Creare una superficie loft (alta densita' di poligoni) in (X,Y,Z).
//** Data Ultima Modifica: 23/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.oLoft(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ: Single;
    const aASections: array of TLoftSection; eAStyle: THoloStyle; iASegments,
    iALineEvery: Integer; eAAxis: TAxis3): THoloLoft;
begin
    Result := THoloLoft.CreateLoft(Self, oAParent, aASections, iASegments, iALineEvery, eAStyle, eAAxis);
    Result.Position.Point := Point3D(dAPosX, dAPosY, dAPosZ);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.oRBox
//** Parametri di ingresso: oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dAWidth, dAHeight, dADepth: Single;
//**                        eAStyle: THoloStyle;
//**                        eAAxis: TAxis3; dATaper: Single; iASegments: Integer; dARound: Single
//** Parametri di uscita: Result: THoloLoft
//** Scopo: Creare un parallelepipedo ARROTONDATO ad alta definizione (corpi, piastre, copritasti)
//**        centrato in (X,Y,Z) con ingombro W x H x D.
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//** Funzionamento: loft lungo l'asse eAAxis con sezioni a quadrato
//** arrotondato (superellisse di esponente dARound) e smussi alle due
//** estremita'. dATaper (0..0.5) restringe l'estremita' "negativa" dell'asse
//** (per i copritasti con asse Z e' la faccia rivolta alla camera), come la
//** sagoma tronco-piramidale di un tasto.
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.oRBox(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dAWidth, dAHeight, dADepth: Single;
    eAStyle: THoloStyle; eAAxis: TAxis3; dATaper: Single; iASegments: Integer;
    dARound: Single): THoloLoft;
var
    dBoxLen, dHalfHeight, dHalfDepth, dBevel, dTaper: Single;
begin
    case eAAxis of
        axX:
            begin
                dBoxLen := dAWidth;
                dHalfHeight := dAHeight / 2;
                dHalfDepth := dADepth / 2;
            end;
        axY:
            begin
                dBoxLen := dAHeight;
                dHalfHeight := dAWidth / 2;
                dHalfDepth := dADepth / 2;
            end;
    else
        begin
            dBoxLen := dADepth;
            dHalfHeight := dAWidth / 2;
            dHalfDepth := dAHeight / 2;
        end;
    end;
    dBevel := Min(dBoxLen * 0.25, Min(dHalfHeight, dHalfDepth) * 0.35);
    dTaper := EnsureRange(dATaper, 0, 0.5);
    Result := oLoft(oAParent, dAPosX, dAPosY, dAPosZ, [
        rSec(-dBoxLen / 2,            0, 0, dHalfHeight * (1 - dTaper) - dBevel * 0.6, dHalfDepth * (1
            - dTaper) - dBevel * 0.6, dARound),
        rSec(-dBoxLen / 2 + dBevel * 0.4, 0, 0, dHalfHeight * (1 - dTaper) - dBevel * 0.15, dHalfDepth * (1
            - dTaper) - dBevel * 0.15, dARound),
        rSec(-dBoxLen / 2 + dBevel,       0, 0, dHalfHeight * (1 - dTaper * 0.85), dHalfDepth * (1
            - dTaper * 0.85), dARound),
        rSec(dBoxLen / 2 - dBevel,        0, 0, dHalfHeight, dHalfDepth, dARound),
        rSec(dBoxLen / 2,             0, 0, dHalfHeight - dBevel * 0.4, dHalfDepth - dBevel * 0.4, dARound)],
        eAStyle, iASegments, 3, eAAxis);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.oRing
//** Parametri di ingresso: oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dARadius: Single; bADashed:
//**                        Boolean; eAStyle:
//**                        THoloStyle
//** Parametri di uscita: Result: THoloRing
//** Scopo: Creare un anello orizzontale (piano XZ).
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.oRing(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dARadius: Single;
    bADashed: Boolean; eAStyle: THoloStyle): THoloRing;
begin
    Result := THoloRing.CreateRing(Self, oAParent, dARadius, bADashed, eAStyle);
    Result.Position.Point := Point3D(dAPosX, dAPosY, dAPosZ);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloKit.oText
//** Parametri di ingresso: oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dASize: Single; sAText: string;
//**                        bAForce: Boolean;
//**                        sAFamily: string
//** Parametri di uscita: Result: TText3D
//** Scopo: Creare una scritta 3D (legenda di tasti/pulsanti) rivolta alla camera.
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//** Funzionamento: la scritta giace nel piano XY ed e' adattata (Stretch) a un
//** riquadro alto dASize; restituisce nil se le legende sono disattivate,
//** salvo bAForce = True (scritte indispensabili, es. ABXY del gamepad).
//***********************************************************************************************************
//***********************************************************************************************************
function THoloKit.oText(oAParent: TFmxObject; dAPosX, dAPosY, dAPosZ, dASize: Single;
    const sAText: string; bAForce: Boolean; const sAFamily: string): TText3D;
begin
    Result := nil;
    if (sAText = '') or not (bFShowLegends or bAForce) then
        Exit;
    Result := TText3D.Create(nil);
    NoHit(Result);
    Result.Parent := oAParent;
    Result.Position.Point := Point3D(dAPosX, dAPosY, dAPosZ);
    Result.Width := Max(dASize * 0.7, dASize * Length(sAText) * 0.6);
    Result.Height := dASize;
    Result.Depth := 0.01;
    Result.Stretch := True;
    if sAFamily <> '' then
        Result.Font.Family := sAFamily
    else
        Result.Font.Family := 'Segoe UI';
    Result.Text := sAText;
    Result.MaterialSource := oFMatText;
    Result.MaterialShaftSource := oFMatText;
    Result.MaterialBackSource := oFMatText;
end;

end.
