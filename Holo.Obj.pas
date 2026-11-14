//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Obj
//** Scopo: Modelli 3D reali (file OBJ preparati con TOOLS\holo_prep.py) disegnati in stile ologramma.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento: il file OBJ contiene due oggetti:
//**    o holo_fill   -> triangoli: riempimento traslucido
//**    o holo_lines  -> polilinee 'l': spigoli vivi (le linee dell'ologramma)
//** Sistema OBJ standard: Y in alto, pivot in 0,0,0.
//**
//** Ordine di ricerca di un file NOME:
//**   1. <cartella dell'exe>\OBJ\nome.obj   (sostituibile senza ricompilare)
//**   2. risorsa RCDATA  NOME_OBJ  incorporata con HoloObj.rc
//** Lo stesso vale per il file di accompagnamento nome.ini (risorsa NOME_INI).
//**
//** THoloObjMesh disegna, in quest'ordine:
//**   - il riempimento (due facce per triangolo, nessuna scrittura nello
//**     Z-buffer: effetto "raggi X" come le altre primitive);
//**   - le linee degli spigoli vivi (fisse);
//**   - il CONTORNO visto dalla camera, ricalcolato quando la camera si sposta
//**     rispetto al modello (cioe' quando l'impugnatura ruota): sono gli spigoli
//**     tra un triangolo rivolto verso la camera e uno rivolto dall'altra parte.
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.Obj;

interface

uses
    Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.UITypes,
    System.Math, System.Math.Vectors, System.Generics.Collections, System.IniFiles,
    FMX.Types, FMX.Types3D, FMX.Controls3D, FMX.Objects3D, FMX.Viewport3D,
    Holo.Prims;

type
    /// Contenuto di un file OBJ olografico.
    THoloObjData = record
        aVerts: TArray<TPoint3D>;   // vertici usati dai triangoli (saldati)
        aTris: TArray<Integer>;     // 3 indici per triangolo
        aLines: TArray<TPoint3D>;   // coppie di punti: inizio e fine di ogni segmento
        function bIsEmpty: Boolean;
        /// Ingombro di triangoli e linee. False se il modello e' vuoto.
        function bGetBounds(out rAMin, rAMax: TPoint3D): Boolean;
        /// P := P * rAScale (componente per componente) + rAOffset.
        /// Uno o tre fattori negativi specchiano il modello.
        procedure Transform(const rAScale, rAOffset: TPoint3D);
        /// Cambio di assi: nuovo X = rAAxisX . P, nuovo Y = rAAxisY . P, nuovo Z = rAAxisZ . P
        /// (righe di una matrice di rotazione, es. per mettere in piedi un gamepad).
        procedure Reorient(const rAAxisX, rAAxisY, rAAxisZ: TPoint3D);
    end;

    /// Mesh olografica: riempimento + spigoli vivi + contorno dinamico.
    THoloObjMesh = class(THoloLines)
    private
        eFStyle: THoloStyle;
        bFActive: Boolean;
        dFFillScale: Single;
        bFShowSilhouette: Boolean;
        oFTriVB: TVertexBuffer;
        oFTriIB: TIndexBuffer;
        oFSilIB: TIndexBuffer;
        iFSilCount: Integer;
        aFFaceN, aFFaceC: TArray<TPoint3D>;
        aFEdgeA, aFEdgeB, aFEdgeF0, aFEdgeF1: TArray<Integer>;
        aFFront: TArray<Boolean>;
        oFCamera: TCamera;
        rFLastCam: TPoint3D;
        bFHasCam: Boolean;
        dFCamTol: Single;
        eFIndexFormat: TIndexFormat;
        procedure BuildFill(const rAData: THoloObjData);
        procedure BuildEdges(const rAData: THoloObjData);
        function oFindCamera: TCamera;
        procedure UpdateSilhouette;
    protected
        procedure Render; override;
        function iLineColor: TAlphaColor; override;
        function bGetActive: Boolean; override;
        procedure SetActive(const bValue: Boolean); override;
    public
        constructor CreateMesh(oAKit: THoloKit; oAParent: TFmxObject;
            const rAData: THoloObjData; eAStyle: THoloStyle);
        destructor Destroy; override;
        /// Moltiplica l'opacita' del riempimento: le superfici reali hanno molti
        /// strati sovrapposti (davanti + dietro), quindi va tenuta bassa.
        property dFillScale: Single read dFFillScale write dFFillScale;
        property bShowSilhouette: Boolean read bFShowSilhouette write bFShowSilhouette;
        property eStyle: THoloStyle read eFStyle;
    end;

/// Apre un file della cartella OBJ (o la risorsa NOME_EXT); nil se non esiste.
function oOpenHoloAsset(const sAName, sAExt: string): TStream;
/// Legge un OBJ olografico da stream.
function bParseHoloObj(oAStream: TStream; out rAData: THoloObjData): Boolean;
/// Carica OBJ\nome.obj (o la risorsa NOME_OBJ).
function bLoadHoloObj(const sAName: string; out rAData: THoloObjData): Boolean;
/// Carica OBJ\nome.ini (o la risorsa NOME_INI); nil se non esiste.
function oLoadHoloObjIni(const sAName: string): TMemIniFile;

implementation

uses
    // serve per espandere inline TVertexBuffer.SetVertices (hint H2443)
    System.RTLConsts,
    Holo.Lang;

type
    TControl3DAccess = class(TControl3D);

//** caricamento ********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: oOpenHoloAsset
//** Parametri di ingresso: sAName, sAExt: string
//** Parametri di uscita: Result: TStream
//** Scopo: Trovare un file accanto all'exe o, in alternativa, la risorsa.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento: prova <exe>\OBJ\nome.ext; se manca cerca la risorsa
//** RCDATA NOME_EXT (maiuscolo). Restituisce uno stream da liberare. Nome o
//** estensione con un percorso (bIsSafeFileId) restituiscono nil.
//***********************************************************************************************************
//***********************************************************************************************************
function oOpenHoloAsset(const sAName, sAExt: string): TStream;
var
    sFileName, sResName: string;
begin
    Result := nil;
    if not bIsSafeFileId(sAName) or not bIsSafeFileId(sAExt) then
        Exit;
    sFileName := ExtractFilePath(ParamStr(0)) + 'OBJ' + PathDelim + LowerCase(sAName) + '.'
        + LowerCase(sAExt);
    if FileExists(sFileName) then
    begin
        try
            Result := TFileStream.Create(sFileName, fmOpenRead or fmShareDenyWrite);
            Exit;
        except
            Result := nil;
        end;
    end;
    sResName := UpperCase(sAName + '_' + sAExt);
    if FindResource(HInstance, PChar(sResName), RT_RCDATA) <> 0 then
        Result := TResourceStream.Create(HInstance, sResName, RT_RCDATA);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloObjData.bIsEmpty
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Indicare se il modello OBJ letto non contiene ne' triangoli ne' linee.
//** Data Ultima Modifica: 13/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloObjData.bIsEmpty: Boolean;
begin
    Result := (Length(aTris) = 0) and (Length(aLines) = 0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloObjData.bGetBounds
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean; rAMin, rAMax: TPoint3D (out)
//** Scopo: Calcolare l'ingombro (minimo e massimo) di tutti i punti.
//** Data Ultima Modifica: 13/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloObjData.bGetBounds(out rAMin, rAMax: TPoint3D): Boolean;
var
    bFirst: Boolean;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: Grow
    //** Parametri di ingresso: rAPoint: TPoint3D
    //** Parametri di uscita: nessuno
    //** Scopo: Allargare l'ingombro minimo/massimo per includere un punto.
    //** Data Ultima Modifica: 13/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Grow(const rAPoint: TPoint3D);
    begin
        if bFirst then
        begin
            rAMin := rAPoint;
            rAMax := rAPoint;
            bFirst := False;
        end
        else
        begin
            rAMin := Point3D(Min(rAMin.X, rAPoint.X), Min(rAMin.Y, rAPoint.Y), Min(rAMin.Z, rAPoint.Z));
            rAMax := Point3D(Max(rAMax.X, rAPoint.X), Max(rAMax.Y, rAPoint.Y), Max(rAMax.Z, rAPoint.Z));
        end;
    end;

var
    rVert: TPoint3D;
begin
    bFirst := True;
    rAMin := Point3D(0, 0, 0);
    rAMax := rAMin;
    for rVert in aVerts do
        Grow(rVert);
    for rVert in aLines do
        Grow(rVert);
    Result := not bFirst;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloObjData.Transform
//** Parametri di ingresso: rAScale, rAOffset: TPoint3D
//** Parametri di uscita: nessuno
//** Scopo: Scalare/specchiare e spostare tutti i punti del modello.
//** Data Ultima Modifica: 13/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloObjData.Transform(const rAScale, rAOffset: TPoint3D);
var
    iVert: Integer;
begin
    for iVert := 0 to High(aVerts) do
        aVerts[iVert] := Point3D(aVerts[iVert].X * rAScale.X + rAOffset.X, aVerts[iVert].Y * rAScale.Y
            + rAOffset.Y,
            aVerts[iVert].Z * rAScale.Z + rAOffset.Z);
    for iVert := 0 to High(aLines) do
        aLines[iVert] := Point3D(aLines[iVert].X * rAScale.X + rAOffset.X, aLines[iVert].Y * rAScale.Y
            + rAOffset.Y,
            aLines[iVert].Z * rAScale.Z + rAOffset.Z);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloObjData.Reorient
//** Parametri di ingresso: rAAxisX, rAAxisY, rAAxisZ: TPoint3D
//** Parametri di uscita: nessuno
//** Scopo: Ruotare tutti i punti con una matrice data per righe.
//** Data Ultima Modifica: 13/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloObjData.Reorient(const rAAxisX, rAAxisY, rAAxisZ: TPoint3D);

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: rRot
    //** Parametri di ingresso: rAPoint: TPoint3D
    //** Parametri di uscita: Result: TPoint3D
    //** Scopo: Ruotare un punto con la matrice formata dai tre assi indicati.
    //** Data Ultima Modifica: 13/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function rRot(const rAPoint: TPoint3D): TPoint3D;
    begin
        Result := Point3D(rAAxisX.X * rAPoint.X + rAAxisX.Y * rAPoint.Y + rAAxisX.Z * rAPoint.Z,
                          rAAxisY.X * rAPoint.X + rAAxisY.Y * rAPoint.Y + rAAxisY.Z * rAPoint.Z,
                          rAAxisZ.X * rAPoint.X + rAAxisZ.Y * rAPoint.Y + rAAxisZ.Z * rAPoint.Z);
    end;

var
    iVert: Integer;
begin
    for iVert := 0 to High(aVerts) do
        aVerts[iVert] := rRot(aVerts[iVert]);
    for iVert := 0 to High(aLines) do
        aLines[iVert] := rRot(aLines[iVert]);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: bParseHoloObj
//** Parametri di ingresso: oAStream: TStream
//** Parametri di uscita: Result: Boolean; rAData: THoloObjData (out)
//** Scopo: Leggere un OBJ olografico.
//** Data Ultima Modifica: 13/10/2026
//***********************************************************************************************************
//** Funzionamento:
//**  - 'v x y z'      -> vertice (tutti gli oggetti condividono la numerazione);
//**  - 'f a b c ...'  -> poligono, diviso a ventaglio in triangoli (accetta
//**                      anche a/t/n e indici negativi);
//**  - 'l a b c ...'  -> polilinea, spezzata in segmenti;
//**  - alla fine tiene solo i vertici usati dai triangoli e salda quelli con
//**    la stessa posizione (serve al calcolo del contorno).
//***********************************************************************************************************
//***********************************************************************************************************
function bParseHoloObj(oAStream: TStream; out rAData: THoloObjData): Boolean;
var
    oTextLines: TStringList;
    rFormat: TFormatSettings;
    oAll: TList<TPoint3D>;
    oTris: TList<Integer>;
    oLines: TList<TPoint3D>;
    aRemap: TArray<Integer>;
    oWeld: TDictionary<TPoint3D, Integer>;
    aTok: TArray<string>;
    aIdx: TArray<Integer>;
    sLine: string;
    iIndex, iToken, iCount, iVert: Integer;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: iVertIndex
    //** Parametri di ingresso: sAToken: string
    //** Parametri di uscita: Result: Integer
    //** Scopo: Ricavare l'indice (base 0) del vertice da un elemento di faccia OBJ del tipo v, v/vt
    //**        o v/vt/vn.
    //** Data Ultima Modifica: 13/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function iVertIndex(const sAToken: string): Integer;
    var
        iSlash: Integer;
        sNum: string;
    begin
        iSlash := Pos('/', sAToken);
        if iSlash > 0 then
            sNum := Copy(sAToken, 1, iSlash - 1)
        else
            sNum := sAToken;
        Result := StrToIntDef(sNum, 0);
        if Result > 0 then
            Dec(Result)
        else if Result < 0 then
            Result := oAll.Count + Result
        else
            Result := -1;
        if Result >= oAll.Count then
            Result := -1;
    end;

begin
    rAData := Default(THoloObjData);
    Result := False;
    if oAStream = nil then
        Exit;
    rFormat := TFormatSettings.Invariant;
    oTextLines := TStringList.Create;
    oAll := TList<TPoint3D>.Create;
    oTris := TList<Integer>.Create;
    oLines := TList<TPoint3D>.Create;
    oWeld := TDictionary<TPoint3D, Integer>.Create;
    try
        oTextLines.LoadFromStream(oAStream, TEncoding.UTF8);
        for sLine in oTextLines do
        begin
            if (Length(sLine) < 2) or (sLine[1] = '#') then
                Continue;
            aTok := sLine.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
            if Length(aTok) < 2 then
                Continue;
            if aTok[0] = 'v' then
            begin
                if Length(aTok) >= 4 then
                    oAll.Add(Point3D(StrToFloatDef(aTok[1], 0, rFormat), StrToFloatDef(aTok[2], 0, rFormat),
                        StrToFloatDef(aTok[3], 0, rFormat)));
            end
            else if (aTok[0] = 'f') or (aTok[0] = 'l') then
            begin
                SetLength(aIdx, Length(aTok) - 1);
                iCount := 0;
                for iToken := 1 to High(aTok) do
                begin
                    iVert := iVertIndex(aTok[iToken]);
                    if iVert >= 0 then
                    begin
                        aIdx[iCount] := iVert;
                        Inc(iCount);
                    end;
                end;
                if aTok[0] = 'f' then
                    for iToken := 1 to iCount - 2 do
                    begin
                        oTris.Add(aIdx[0]);
                        oTris.Add(aIdx[iToken]);
                        oTris.Add(aIdx[iToken + 1]);
                    end
                else
                    for iToken := 0 to iCount - 2 do
                    begin
                        oLines.Add(oAll[aIdx[iToken]]);
                        oLines.Add(oAll[aIdx[iToken + 1]]);
                    end;
            end;
        end;

        // solo i vertici dei triangoli, saldati per posizione
        SetLength(aRemap, oAll.Count);
        for iIndex := 0 to High(aRemap) do
            aRemap[iIndex] := -1;
        SetLength(rAData.aVerts, oAll.Count);
        iCount := 0;
        SetLength(rAData.aTris, oTris.Count);
        for iIndex := 0 to oTris.Count - 1 do
        begin
            iVert := oTris[iIndex];
            if aRemap[iVert] < 0 then
            begin
                if not oWeld.TryGetValue(oAll[iVert], iToken) then
                begin
                    iToken := iCount;
                    rAData.aVerts[iCount] := oAll[iVert];
                    Inc(iCount);
                    oWeld.Add(oAll[iVert], iToken);
                end;
                aRemap[iVert] := iToken;
            end;
            rAData.aTris[iIndex] := aRemap[iVert];
        end;
        SetLength(rAData.aVerts, iCount);
        rAData.aLines := oLines.ToArray;
        Result := not rAData.bIsEmpty;
    finally
        oWeld.Free;
        oLines.Free;
        oTris.Free;
        oAll.Free;
        oTextLines.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: bLoadHoloObj
//** Parametri di ingresso: sAName: string
//** Parametri di uscita: Result: Boolean; rAData: THoloObjData (out)
//** Scopo: Caricare un OBJ olografico per nome (file o risorsa).
//** Data Ultima Modifica: 14/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function bLoadHoloObj(const sAName: string; out rAData: THoloObjData): Boolean;
var
    oStream: TStream;
begin
    rAData := Default(THoloObjData);
    oStream := oOpenHoloAsset(sAName, 'obj');
    try
        Result := (oStream <> nil) and bParseHoloObj(oStream, rAData);
    finally
        oStream.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: oLoadHoloObjIni
//** Parametri di ingresso: sAName: string
//** Parametri di uscita: Result: TMemIniFile
//** Scopo: Caricare il file .ini di accompagnamento (posizione dei comandi).
//** Data Ultima Modifica: 14/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function oLoadHoloObjIni(const sAName: string): TMemIniFile;
var
    oStream: TStream;
    oLines: TStringList;
begin
    Result := nil;
    oStream := oOpenHoloAsset(sAName, 'ini');
    if oStream = nil then
        Exit;
    oLines := TStringList.Create;
    try
        oLines.LoadFromStream(oStream, TEncoding.UTF8);
        Result := TMemIniFile.Create('');
        Result.SetStrings(oLines);
    finally
        oLines.Free;
        oStream.Free;
    end;
end;

//** THoloObjMesh *******************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloObjMesh.CreateMesh
//** Parametri di ingresso: oAKit: THoloKit; oAParent: TFmxObject; rAData: THoloObjData; eAStyle:
//**                        THoloStyle
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare la mesh olografica sotto oAParent.
//** Data Ultima Modifica: 14/10/2026
//***********************************************************************************************************
//** Funzionamento: prepara i buffer del riempimento, la tabella degli spigoli
//** per il contorno e le linee degli spigoli vivi.
//***********************************************************************************************************
//***********************************************************************************************************
constructor THoloObjMesh.CreateMesh(oAKit: THoloKit; oAParent: TFmxObject;
    const rAData: THoloObjData; eAStyle: THoloStyle);
begin
    inherited Create(nil);
    AttachKit(oAKit);
    eFStyle := eAStyle;
    dFFillScale := 0.35;
    bFShowSilhouette := True;
    TControl3DAccess(Self).HitTest := False;
    ZWrite := False;
    Parent := oAParent;
    if Length(rAData.aVerts) > 65000 then
        eFIndexFormat := TIndexFormat.UInt32
    else
        eFIndexFormat := TIndexFormat.UInt16;
    BuildFill(rAData);
    BuildEdges(rAData);
    SetLines(rAData.aLines);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloObjMesh.Destroy
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Liberare i buffer di vertici e indici del riempimento e della silhouette.
//** Data Ultima Modifica: 14/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
destructor THoloObjMesh.Destroy;
begin
    FreeAndNil(oFTriVB);
    FreeAndNil(oFTriIB);
    FreeAndNil(oFSilIB);
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloObjMesh.BuildFill
//** Parametri di ingresso: rAData: THoloObjData
//** Parametri di uscita: nessuno
//** Scopo: Buffer dei triangoli e dati per orientamento delle facce.
//** Data Ultima Modifica: 14/10/2026
//***********************************************************************************************************
//** Funzionamento: ogni triangolo e' inserito con i due ordini dei vertici
//** (visibile da entrambi i lati, come i loft); per ogni faccia si salvano
//** normale e baricentro, usati per sapere se e' rivolta verso la camera.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloObjMesh.BuildFill(const rAData: THoloObjData);
var
    iIndex, iTriCount: Integer;
    rPointA, rPointB, rPointC: TPoint3D;
begin
    iTriCount := Length(rAData.aTris) div 3;
    if (iTriCount = 0) or (Length(rAData.aVerts) = 0) then
        Exit;
    oFTriVB := TVertexBuffer.Create([TVertexFormat.Vertex], Length(rAData.aVerts));
    for iIndex := 0 to High(rAData.aVerts) do
        oFTriVB.Vertices[iIndex] := rAData.aVerts[iIndex];
    oFTriIB := TIndexBuffer.Create(iTriCount * 6, eFIndexFormat);
    SetLength(aFFaceN, iTriCount);
    SetLength(aFFaceC, iTriCount);
    SetLength(aFFront, iTriCount);
    for iIndex := 0 to iTriCount - 1 do
    begin
        oFTriIB.Indices[iIndex * 6] := rAData.aTris[iIndex * 3];
        oFTriIB.Indices[iIndex * 6 + 1] := rAData.aTris[iIndex * 3 + 1];
        oFTriIB.Indices[iIndex * 6 + 2] := rAData.aTris[iIndex * 3 + 2];
        oFTriIB.Indices[iIndex * 6 + 3] := rAData.aTris[iIndex * 3];
        oFTriIB.Indices[iIndex * 6 + 4] := rAData.aTris[iIndex * 3 + 2];
        oFTriIB.Indices[iIndex * 6 + 5] := rAData.aTris[iIndex * 3 + 1];
        rPointA := rAData.aVerts[rAData.aTris[iIndex * 3]];
        rPointB := rAData.aVerts[rAData.aTris[iIndex * 3 + 1]];
        rPointC := rAData.aVerts[rAData.aTris[iIndex * 3 + 2]];
        aFFaceN[iIndex] := (rPointB - rPointA).CrossProduct(rPointC - rPointA);
        aFFaceC[iIndex] := Point3D((rPointA.X + rPointB.X + rPointC.X) / 3, (rPointA.Y + rPointB.Y
            + rPointC.Y) / 3, (rPointA.Z + rPointB.Z + rPointC.Z) / 3);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloObjMesh.BuildEdges
//** Parametri di ingresso: rAData: THoloObjData
//** Parametri di uscita: nessuno
//** Scopo: Tabella degli spigoli interni (condivisi da due triangoli).
//** Data Ultima Modifica: 14/10/2026
//***********************************************************************************************************
//** Funzionamento: chiave = coppia di indici (minore, maggiore) in un Int64;
//** per ogni spigolo si memorizzano i due triangoli adiacenti. Gli spigoli
//** di bordo (un solo triangolo) sono gia' nelle linee degli spigoli vivi.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloObjMesh.BuildEdges(const rAData: THoloObjData);
var
    oMap: TDictionary<Int64, Integer>;
    iTriCount, iTri, iCorner, iVertA, iVertB, iEdge, iEdgeCount, iTmp, iKeptCount: Integer;
    iKey: Int64;
    rBoundsMin, rBoundsMax: TPoint3D;
begin
    iTriCount := Length(rAData.aTris) div 3;
    if iTriCount = 0 then
        Exit;
    SetLength(aFEdgeA, iTriCount * 3);
    SetLength(aFEdgeB, iTriCount * 3);
    SetLength(aFEdgeF0, iTriCount * 3);
    SetLength(aFEdgeF1, iTriCount * 3);
    iEdgeCount := 0;
    oMap := TDictionary<Int64, Integer>.Create(iTriCount * 2);
    try
        for iTri := 0 to iTriCount - 1 do
            for iCorner := 0 to 2 do
            begin
                iVertA := rAData.aTris[iTri * 3 + iCorner];
                iVertB := rAData.aTris[iTri * 3 + (iCorner + 1) mod 3];
                if iVertA > iVertB then
                begin
                    iTmp := iVertA;
                    iVertA := iVertB;
                    iVertB := iTmp;
                end;
                iKey := (Int64(iVertA) shl 32) or Int64(iVertB);
                if oMap.TryGetValue(iKey, iEdge) then
                begin
                    if aFEdgeF1[iEdge] < 0 then
                        aFEdgeF1[iEdge] := iTri;
                end
                else
                begin
                    aFEdgeA[iEdgeCount] := iVertA;
                    aFEdgeB[iEdgeCount] := iVertB;
                    aFEdgeF0[iEdgeCount] := iTri;
                    aFEdgeF1[iEdgeCount] := -1;
                    oMap.Add(iKey, iEdgeCount);
                    Inc(iEdgeCount);
                end;
            end;
    finally
        oMap.Free;
    end;
    // tiene solo gli spigoli con due facce
    iKeptCount := 0;
    for iEdge := 0 to iEdgeCount - 1 do
        if aFEdgeF1[iEdge] >= 0 then
        begin
            aFEdgeA[iKeptCount] := aFEdgeA[iEdge];
            aFEdgeB[iKeptCount] := aFEdgeB[iEdge];
            aFEdgeF0[iKeptCount] := aFEdgeF0[iEdge];
            aFEdgeF1[iKeptCount] := aFEdgeF1[iEdge];
            Inc(iKeptCount);
        end;
    SetLength(aFEdgeA, iKeptCount);
    SetLength(aFEdgeB, iKeptCount);
    SetLength(aFEdgeF0, iKeptCount);
    SetLength(aFEdgeF1, iKeptCount);
    // tolleranza per "la camera non si e' mossa": 0,05% delle dimensioni
    if rAData.bGetBounds(rBoundsMin, rBoundsMax) then
        dFCamTol := Max(1E-5, (rBoundsMax - rBoundsMin).Length * 0.0005)
    else
        dFCamTol := 1E-4;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloObjMesh.oFindCamera
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TCamera
//** Scopo: Trovare la camera del viewport che contiene la mesh.
//** Data Ultima Modifica: 15/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloObjMesh.oFindCamera: TCamera;
var
    oNode: TFmxObject;
begin
    Result := nil;
    oNode := Parent;
    while (oNode <> nil) and not (oNode is TViewport3D) do
        oNode := oNode.Parent;
    if oNode is TViewport3D then
        Result := TViewport3D(oNode).Camera;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloObjMesh.UpdateSilhouette
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Ricalcolare il contorno se la camera si e' spostata rispetto alla mesh.
//** Data Ultima Modifica: 15/10/2026
//***********************************************************************************************************
//** Funzionamento: porta la posizione della camera nelle coordinate locali
//** della mesh (cosi' tiene conto di tutte le rotazioni dei genitori); una
//** faccia e' "davanti" se la camera sta dal lato della sua normale; uno
//** spigolo e' di contorno se separa una faccia davanti da una dietro.
//** Il buffer degli indici viene ricreato solo se cambia il numero di spigoli.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloObjMesh.UpdateSilhouette;
var
    rCamPos: TVector3D;
    rCam: TPoint3D;
    iFace, iEdge, iEdgeCount: Integer;
begin
    if (oFTriVB = nil) or (Length(aFEdgeA) = 0) then
        Exit;
    if oFCamera = nil then
        oFCamera := oFindCamera;
    if oFCamera = nil then
        Exit;
    rCamPos := oFCamera.AbsolutePosition;
    rCam := AbsoluteToLocal3D(Point3D(rCamPos.X, rCamPos.Y, rCamPos.Z));
    if bFHasCam and ((rCam - rFLastCam).Length < dFCamTol) then
        Exit;
    bFHasCam := True;
    rFLastCam := rCam;

    for iFace := 0 to High(aFFaceN) do
        aFFront[iFace] := aFFaceN[iFace].DotProduct(rCam - aFFaceC[iFace]) > 0;

    iEdgeCount := 0;
    for iEdge := 0 to High(aFEdgeA) do
        if aFFront[aFEdgeF0[iEdge]] <> aFFront[aFEdgeF1[iEdge]] then
            Inc(iEdgeCount);
    if iEdgeCount <> iFSilCount then
    begin
        FreeAndNil(oFSilIB);
        iFSilCount := iEdgeCount;
        if iEdgeCount > 0 then
            oFSilIB := TIndexBuffer.Create(iEdgeCount * 2, eFIndexFormat);
    end;
    if oFSilIB = nil then
        Exit;
    iEdgeCount := 0;
    for iEdge := 0 to High(aFEdgeA) do
        if aFFront[aFEdgeF0[iEdge]] <> aFFront[aFEdgeF1[iEdge]] then
        begin
            oFSilIB.Indices[iEdgeCount] := aFEdgeA[iEdge];
            oFSilIB.Indices[iEdgeCount + 1] := aFEdgeB[iEdge];
            Inc(iEdgeCount, 2);
        end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloObjMesh.Render
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare riempimento, spigoli vivi e contorno.
//** Data Ultima Modifica: 15/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloObjMesh.Render;
var
    dOpacity: Single;
begin
    if oKit = nil then
        Exit;
    dOpacity := oKit.dFillOpacity(eFStyle, bFActive) * dFFillScale;
    if (dOpacity > 0) and (oFTriVB <> nil) and (oFTriIB <> nil) then
        Context.DrawTriangles(oFTriVB, oFTriIB, oKit.oFillMaterial(eFStyle, bFActive).Material,
            AbsoluteOpacity * dOpacity);
    inherited;   // spigoli vivi (THoloLines)
    if bFShowSilhouette then
    begin
        UpdateSilhouette;
        if oFSilIB <> nil then
        begin
            oKit.oLineMaterial.Color := iLineColor;
            Context.DrawLines(oFTriVB, oFSilIB, oKit.oLineMaterial, AbsoluteOpacity * 0.85);
        end;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloObjMesh.iLineColor
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TAlphaColor
//** Scopo: Colore delle linee del modello OBJ in base a stile e stato acceso/spento.
//** Data Ultima Modifica: 15/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloObjMesh.iLineColor: TAlphaColor;
begin
    Result := oKit.iEdgeColor(eFStyle, bFActive);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloObjMesh.bGetActive
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Restituire lo stato acceso (evidenziato) del modello OBJ.
//** Data Ultima Modifica: 15/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloObjMesh.bGetActive: Boolean;
begin
    Result := bFActive;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloObjMesh.SetActive
//** Parametri di ingresso: bValue: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Accendere o spegnere l'evidenziazione del modello OBJ e ridisegnarlo.
//** Data Ultima Modifica: 15/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloObjMesh.SetActive(const bValue: Boolean);
begin
    if bFActive = bValue then
        Exit;
    bFActive := bValue;
    Repaint;
end;

end.
