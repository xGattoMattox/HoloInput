//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Obj
//** Scopo: Modelli 3D reali (file OBJ preparati con TOOLS\holo_prep.py) disegnati in stile ologramma.
//** Data Ultima Modifica: 15/10/2026
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
        Verts: TArray<TPoint3D>;   // vertici usati dai triangoli (saldati)
        Tris: TArray<Integer>;     // 3 indici per triangolo
        Lines: TArray<TPoint3D>;   // coppie di punti: inizio e fine di ogni segmento
        function IsEmpty: Boolean;
        /// Ingombro di triangoli e linee. False se il modello e' vuoto.
        function GetBounds(out AMin, AMax: TPoint3D): Boolean;
        /// P := P * AScale (componente per componente) + AOffset.
        /// Uno o tre fattori negativi specchiano il modello.
        procedure Transform(const AScale, AOffset: TPoint3D);
        /// Cambio di assi: nuovo X = AX . P, nuovo Y = AY . P, nuovo Z = AZ . P
        /// (righe di una matrice di rotazione, es. per mettere in piedi un gamepad).
        procedure Reorient(const AX, AY, AZ: TPoint3D);
    end;

    /// Mesh olografica: riempimento + spigoli vivi + contorno dinamico.
    THoloObjMesh = class(THoloLines)
    private
        FStyle: THoloStyle;
        FActive: Boolean;
        FFillScale: Single;
        FShowSilhouette: Boolean;
        FTriVB: TVertexBuffer;
        FTriIB: TIndexBuffer;
        FSilIB: TIndexBuffer;
        FSilCount: Integer;
        FFaceN, FFaceC: TArray<TPoint3D>;
        FEdgeA, FEdgeB, FEdgeF0, FEdgeF1: TArray<Integer>;
        FFront: TArray<Boolean>;
        FCamera: TCamera;
        FLastCam: TPoint3D;
        FHasCam: Boolean;
        FCamTol: Single;
        FIndexFormat: TIndexFormat;
        procedure BuildFill(const AData: THoloObjData);
        procedure BuildEdges(const AData: THoloObjData);
        function FindCamera: TCamera;
        procedure UpdateSilhouette;
    protected
        procedure Render; override;
        function LineColor: TAlphaColor; override;
        function GetActive: Boolean; override;
        procedure SetActive(const Value: Boolean); override;
    public
        constructor CreateMesh(AKit: THoloKit; AParent: TFmxObject;
            const AData: THoloObjData; AStyle: THoloStyle);
        destructor Destroy; override;
        /// Moltiplica l'opacita' del riempimento: le superfici reali hanno molti
        /// strati sovrapposti (davanti + dietro), quindi va tenuta bassa.
        property FillScale: Single read FFillScale write FFillScale;
        property ShowSilhouette: Boolean read FShowSilhouette write FShowSilhouette;
        property Style: THoloStyle read FStyle;
    end;

/// Apre un file della cartella OBJ (o la risorsa NOME_EXT); nil se non esiste.
function OpenHoloAsset(const AName, AExt: string): TStream;
/// Legge un OBJ olografico da stream.
function ParseHoloObj(AStream: TStream; out AData: THoloObjData): Boolean;
/// Carica OBJ\nome.obj (o la risorsa NOME_OBJ).
function LoadHoloObj(const AName: string; out AData: THoloObjData): Boolean;
/// Carica OBJ\nome.ini (o la risorsa NOME_INI); nil se non esiste.
function LoadHoloObjIni(const AName: string): TMemIniFile;

implementation

uses
    // serve per espandere inline TVertexBuffer.SetVertices (hint H2443)
    System.RTLConsts;

type
    TControl3DAccess = class(TControl3D);

//** caricamento ********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: OpenHoloAsset
//** Parametri di ingresso: AName, AExt: string
//** Parametri di uscita: Result: TStream
//** Scopo: Trovare un file accanto all'exe o, in alternativa, la risorsa.
//** Data Ultima Modifica: 13/10/2026
//***********************************************************************************************************
//** Funzionamento: prova <exe>\OBJ\nome.ext; se manca cerca la risorsa
//** RCDATA NOME_EXT (maiuscolo). Restituisce uno stream da liberare.
//***********************************************************************************************************
//***********************************************************************************************************
function OpenHoloAsset(const AName, AExt: string): TStream;
var
    FileName, ResName: string;
begin
    Result := nil;
    FileName := ExtractFilePath(ParamStr(0)) + 'OBJ' + PathDelim + LowerCase(AName) + '.' + LowerCase(AExt);
    if FileExists(FileName) then
    begin
        try
            Result := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
            Exit;
        except
            Result := nil;
        end;
    end;
    ResName := UpperCase(AName + '_' + AExt);
    if FindResource(HInstance, PChar(ResName), RT_RCDATA) <> 0 then
        Result := TResourceStream.Create(HInstance, ResName, RT_RCDATA);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloObjData.IsEmpty
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Indicare se il modello OBJ letto non contiene ne' triangoli ne' linee.
//** Data Ultima Modifica: 13/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloObjData.IsEmpty: Boolean;
begin
    Result := (Length(Tris) = 0) and (Length(Lines) = 0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloObjData.GetBounds
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean; AMin, AMax: TPoint3D (out)
//** Scopo: Calcolare l'ingombro (minimo e massimo) di tutti i punti.
//** Data Ultima Modifica: 13/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloObjData.GetBounds(out AMin, AMax: TPoint3D): Boolean;
var
    First: Boolean;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: Grow
    //** Parametri di ingresso: P: TPoint3D
    //** Parametri di uscita: nessuno
    //** Scopo: Allargare l'ingombro minimo/massimo per includere un punto.
    //** Data Ultima Modifica: 13/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Grow(const P: TPoint3D);
    begin
        if First then
        begin
            AMin := P;
            AMax := P;
            First := False;
        end
        else
        begin
            AMin := Point3D(Min(AMin.X, P.X), Min(AMin.Y, P.Y), Min(AMin.Z, P.Z));
            AMax := Point3D(Max(AMax.X, P.X), Max(AMax.Y, P.Y), Max(AMax.Z, P.Z));
        end;
    end;

var
    P: TPoint3D;
begin
    First := True;
    AMin := Point3D(0, 0, 0);
    AMax := AMin;
    for P in Verts do
        Grow(P);
    for P in Lines do
        Grow(P);
    Result := not First;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloObjData.Transform
//** Parametri di ingresso: AScale, AOffset: TPoint3D
//** Parametri di uscita: nessuno
//** Scopo: Scalare/specchiare e spostare tutti i punti del modello.
//** Data Ultima Modifica: 13/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloObjData.Transform(const AScale, AOffset: TPoint3D);
var
    I: Integer;
begin
    for I := 0 to High(Verts) do
        Verts[I] := Point3D(Verts[I].X * AScale.X + AOffset.X, Verts[I].Y * AScale.Y + AOffset.Y,
            Verts[I].Z * AScale.Z + AOffset.Z);
    for I := 0 to High(Lines) do
        Lines[I] := Point3D(Lines[I].X * AScale.X + AOffset.X, Lines[I].Y * AScale.Y + AOffset.Y,
            Lines[I].Z * AScale.Z + AOffset.Z);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloObjData.Reorient
//** Parametri di ingresso: AX, AY, AZ: TPoint3D
//** Parametri di uscita: nessuno
//** Scopo: Ruotare tutti i punti con una matrice data per righe.
//** Data Ultima Modifica: 13/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloObjData.Reorient(const AX, AY, AZ: TPoint3D);

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: Rot
    //** Parametri di ingresso: P: TPoint3D
    //** Parametri di uscita: Result: TPoint3D
    //** Scopo: Ruotare un punto con la matrice formata dai tre assi indicati.
    //** Data Ultima Modifica: 13/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function Rot(const P: TPoint3D): TPoint3D;
    begin
        Result := Point3D(AX.X * P.X + AX.Y * P.Y + AX.Z * P.Z,
                          AY.X * P.X + AY.Y * P.Y + AY.Z * P.Z,
                          AZ.X * P.X + AZ.Y * P.Y + AZ.Z * P.Z);
    end;

var
    I: Integer;
begin
    for I := 0 to High(Verts) do
        Verts[I] := Rot(Verts[I]);
    for I := 0 to High(Lines) do
        Lines[I] := Rot(Lines[I]);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: ParseHoloObj
//** Parametri di ingresso: AStream: TStream
//** Parametri di uscita: Result: Boolean; AData: THoloObjData (out)
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
function ParseHoloObj(AStream: TStream; out AData: THoloObjData): Boolean;
var
    SL: TStringList;
    FS: TFormatSettings;
    All: TList<TPoint3D>;
    Tris: TList<Integer>;
    Lines: TList<TPoint3D>;
    Remap: TArray<Integer>;
    Weld: TDictionary<TPoint3D, Integer>;
    Tok: TArray<string>;
    Idx: TArray<Integer>;
    S: string;
    I, K, N, V: Integer;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: VertIndex
    //** Parametri di ingresso: T: string
    //** Parametri di uscita: Result: Integer
    //** Scopo: Ricavare l'indice (base 0) del vertice da un elemento di faccia OBJ del tipo v, v/vt
    //**        o v/vt/vn.
    //** Data Ultima Modifica: 13/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function VertIndex(const T: string): Integer;
    var
        P: Integer;
        Num: string;
    begin
        P := Pos('/', T);
        if P > 0 then
            Num := Copy(T, 1, P - 1)
        else
            Num := T;
        Result := StrToIntDef(Num, 0);
        if Result > 0 then
            Dec(Result)
        else if Result < 0 then
            Result := All.Count + Result
        else
            Result := -1;
        if Result >= All.Count then
            Result := -1;
    end;

begin
    AData := Default(THoloObjData);
    Result := False;
    if AStream = nil then
        Exit;
    FS := TFormatSettings.Invariant;
    SL := TStringList.Create;
    All := TList<TPoint3D>.Create;
    Tris := TList<Integer>.Create;
    Lines := TList<TPoint3D>.Create;
    Weld := TDictionary<TPoint3D, Integer>.Create;
    try
        SL.LoadFromStream(AStream, TEncoding.UTF8);
        for S in SL do
        begin
            if (Length(S) < 2) or (S[1] = '#') then
                Continue;
            Tok := S.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
            if Length(Tok) < 2 then
                Continue;
            if Tok[0] = 'v' then
            begin
                if Length(Tok) >= 4 then
                    All.Add(Point3D(StrToFloatDef(Tok[1], 0, FS), StrToFloatDef(Tok[2], 0, FS),
                        StrToFloatDef(Tok[3], 0, FS)));
            end
            else if (Tok[0] = 'f') or (Tok[0] = 'l') then
            begin
                SetLength(Idx, Length(Tok) - 1);
                N := 0;
                for K := 1 to High(Tok) do
                begin
                    V := VertIndex(Tok[K]);
                    if V >= 0 then
                    begin
                        Idx[N] := V;
                        Inc(N);
                    end;
                end;
                if Tok[0] = 'f' then
                    for K := 1 to N - 2 do
                    begin
                        Tris.Add(Idx[0]);
                        Tris.Add(Idx[K]);
                        Tris.Add(Idx[K + 1]);
                    end
                else
                    for K := 0 to N - 2 do
                    begin
                        Lines.Add(All[Idx[K]]);
                        Lines.Add(All[Idx[K + 1]]);
                    end;
            end;
        end;

        // solo i vertici dei triangoli, saldati per posizione
        SetLength(Remap, All.Count);
        for I := 0 to High(Remap) do
            Remap[I] := -1;
        SetLength(AData.Verts, All.Count);
        N := 0;
        SetLength(AData.Tris, Tris.Count);
        for I := 0 to Tris.Count - 1 do
        begin
            V := Tris[I];
            if Remap[V] < 0 then
            begin
                if not Weld.TryGetValue(All[V], K) then
                begin
                    K := N;
                    AData.Verts[N] := All[V];
                    Inc(N);
                    Weld.Add(All[V], K);
                end;
                Remap[V] := K;
            end;
            AData.Tris[I] := Remap[V];
        end;
        SetLength(AData.Verts, N);
        AData.Lines := Lines.ToArray;
        Result := not AData.IsEmpty;
    finally
        Weld.Free;
        Lines.Free;
        Tris.Free;
        All.Free;
        SL.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: LoadHoloObj
//** Parametri di ingresso: AName: string
//** Parametri di uscita: Result: Boolean; AData: THoloObjData (out)
//** Scopo: Caricare un OBJ olografico per nome (file o risorsa).
//** Data Ultima Modifica: 14/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function LoadHoloObj(const AName: string; out AData: THoloObjData): Boolean;
var
    St: TStream;
begin
    AData := Default(THoloObjData);
    St := OpenHoloAsset(AName, 'obj');
    try
        Result := (St <> nil) and ParseHoloObj(St, AData);
    finally
        St.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: LoadHoloObjIni
//** Parametri di ingresso: AName: string
//** Parametri di uscita: Result: TMemIniFile
//** Scopo: Caricare il file .ini di accompagnamento (posizione dei comandi).
//** Data Ultima Modifica: 14/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function LoadHoloObjIni(const AName: string): TMemIniFile;
var
    St: TStream;
    SL: TStringList;
begin
    Result := nil;
    St := OpenHoloAsset(AName, 'ini');
    if St = nil then
        Exit;
    SL := TStringList.Create;
    try
        SL.LoadFromStream(St, TEncoding.UTF8);
        Result := TMemIniFile.Create('');
        Result.SetStrings(SL);
    finally
        SL.Free;
        St.Free;
    end;
end;

//** THoloObjMesh *******************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloObjMesh.CreateMesh
//** Parametri di ingresso: AKit: THoloKit; AParent: TFmxObject; AData: THoloObjData; AStyle:
//**                        THoloStyle
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare la mesh olografica sotto AParent.
//** Data Ultima Modifica: 14/10/2026
//***********************************************************************************************************
//** Funzionamento: prepara i buffer del riempimento, la tabella degli spigoli
//** per il contorno e le linee degli spigoli vivi.
//***********************************************************************************************************
//***********************************************************************************************************
constructor THoloObjMesh.CreateMesh(AKit: THoloKit; AParent: TFmxObject;
    const AData: THoloObjData; AStyle: THoloStyle);
begin
    inherited Create(nil);
    AttachKit(AKit);
    FStyle := AStyle;
    FFillScale := 0.35;
    FShowSilhouette := True;
    TControl3DAccess(Self).HitTest := False;
    ZWrite := False;
    Parent := AParent;
    if Length(AData.Verts) > 65000 then
        FIndexFormat := TIndexFormat.UInt32
    else
        FIndexFormat := TIndexFormat.UInt16;
    BuildFill(AData);
    BuildEdges(AData);
    SetLines(AData.Lines);
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
    FreeAndNil(FTriVB);
    FreeAndNil(FTriIB);
    FreeAndNil(FSilIB);
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloObjMesh.BuildFill
//** Parametri di ingresso: AData: THoloObjData
//** Parametri di uscita: nessuno
//** Scopo: Buffer dei triangoli e dati per orientamento delle facce.
//** Data Ultima Modifica: 14/10/2026
//***********************************************************************************************************
//** Funzionamento: ogni triangolo e' inserito con i due ordini dei vertici
//** (visibile da entrambi i lati, come i loft); per ogni faccia si salvano
//** normale e baricentro, usati per sapere se e' rivolta verso la camera.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloObjMesh.BuildFill(const AData: THoloObjData);
var
    I, NT: Integer;
    A, B, C: TPoint3D;
begin
    NT := Length(AData.Tris) div 3;
    if (NT = 0) or (Length(AData.Verts) = 0) then
        Exit;
    FTriVB := TVertexBuffer.Create([TVertexFormat.Vertex], Length(AData.Verts));
    for I := 0 to High(AData.Verts) do
        FTriVB.Vertices[I] := AData.Verts[I];
    FTriIB := TIndexBuffer.Create(NT * 6, FIndexFormat);
    SetLength(FFaceN, NT);
    SetLength(FFaceC, NT);
    SetLength(FFront, NT);
    for I := 0 to NT - 1 do
    begin
        FTriIB.Indices[I * 6] := AData.Tris[I * 3];
        FTriIB.Indices[I * 6 + 1] := AData.Tris[I * 3 + 1];
        FTriIB.Indices[I * 6 + 2] := AData.Tris[I * 3 + 2];
        FTriIB.Indices[I * 6 + 3] := AData.Tris[I * 3];
        FTriIB.Indices[I * 6 + 4] := AData.Tris[I * 3 + 2];
        FTriIB.Indices[I * 6 + 5] := AData.Tris[I * 3 + 1];
        A := AData.Verts[AData.Tris[I * 3]];
        B := AData.Verts[AData.Tris[I * 3 + 1]];
        C := AData.Verts[AData.Tris[I * 3 + 2]];
        FFaceN[I] := (B - A).CrossProduct(C - A);
        FFaceC[I] := Point3D((A.X + B.X + C.X) / 3, (A.Y + B.Y + C.Y) / 3, (A.Z + B.Z + C.Z) / 3);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloObjMesh.BuildEdges
//** Parametri di ingresso: AData: THoloObjData
//** Parametri di uscita: nessuno
//** Scopo: Tabella degli spigoli interni (condivisi da due triangoli).
//** Data Ultima Modifica: 14/10/2026
//***********************************************************************************************************
//** Funzionamento: chiave = coppia di indici (minore, maggiore) in un Int64;
//** per ogni spigolo si memorizzano i due triangoli adiacenti. Gli spigoli
//** di bordo (un solo triangolo) sono gia' nelle linee degli spigoli vivi.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloObjMesh.BuildEdges(const AData: THoloObjData);
var
    Map: TDictionary<Int64, Integer>;
    NT, T, K, A, B, E, N, Tmp, NI: Integer;
    Key: Int64;
    Lo, Hi: TPoint3D;
begin
    NT := Length(AData.Tris) div 3;
    if NT = 0 then
        Exit;
    SetLength(FEdgeA, NT * 3);
    SetLength(FEdgeB, NT * 3);
    SetLength(FEdgeF0, NT * 3);
    SetLength(FEdgeF1, NT * 3);
    N := 0;
    Map := TDictionary<Int64, Integer>.Create(NT * 2);
    try
        for T := 0 to NT - 1 do
            for K := 0 to 2 do
            begin
                A := AData.Tris[T * 3 + K];
                B := AData.Tris[T * 3 + (K + 1) mod 3];
                if A > B then
                begin
                    Tmp := A;
                    A := B;
                    B := Tmp;
                end;
                Key := (Int64(A) shl 32) or Int64(B);
                if Map.TryGetValue(Key, E) then
                begin
                    if FEdgeF1[E] < 0 then
                        FEdgeF1[E] := T;
                end
                else
                begin
                    FEdgeA[N] := A;
                    FEdgeB[N] := B;
                    FEdgeF0[N] := T;
                    FEdgeF1[N] := -1;
                    Map.Add(Key, N);
                    Inc(N);
                end;
            end;
    finally
        Map.Free;
    end;
    // tiene solo gli spigoli con due facce
    NI := 0;
    for E := 0 to N - 1 do
        if FEdgeF1[E] >= 0 then
        begin
            FEdgeA[NI] := FEdgeA[E];
            FEdgeB[NI] := FEdgeB[E];
            FEdgeF0[NI] := FEdgeF0[E];
            FEdgeF1[NI] := FEdgeF1[E];
            Inc(NI);
        end;
    SetLength(FEdgeA, NI);
    SetLength(FEdgeB, NI);
    SetLength(FEdgeF0, NI);
    SetLength(FEdgeF1, NI);
    // tolleranza per "la camera non si e' mossa": 0,05% delle dimensioni
    if AData.GetBounds(Lo, Hi) then
        FCamTol := Max(1E-5, (Hi - Lo).Length * 0.0005)
    else
        FCamTol := 1E-4;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloObjMesh.FindCamera
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TCamera
//** Scopo: Trovare la camera del viewport che contiene la mesh.
//** Data Ultima Modifica: 15/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloObjMesh.FindCamera: TCamera;
var
    P: TFmxObject;
begin
    Result := nil;
    P := Parent;
    while (P <> nil) and not (P is TViewport3D) do
        P := P.Parent;
    if P is TViewport3D then
        Result := TViewport3D(P).Camera;
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
    V: TVector3D;
    Cam: TPoint3D;
    I, E, N: Integer;
begin
    if (FTriVB = nil) or (Length(FEdgeA) = 0) then
        Exit;
    if FCamera = nil then
        FCamera := FindCamera;
    if FCamera = nil then
        Exit;
    V := FCamera.AbsolutePosition;
    Cam := AbsoluteToLocal3D(Point3D(V.X, V.Y, V.Z));
    if FHasCam and ((Cam - FLastCam).Length < FCamTol) then
        Exit;
    FHasCam := True;
    FLastCam := Cam;

    for I := 0 to High(FFaceN) do
        FFront[I] := FFaceN[I].DotProduct(Cam - FFaceC[I]) > 0;

    N := 0;
    for E := 0 to High(FEdgeA) do
        if FFront[FEdgeF0[E]] <> FFront[FEdgeF1[E]] then
            Inc(N);
    if N <> FSilCount then
    begin
        FreeAndNil(FSilIB);
        FSilCount := N;
        if N > 0 then
            FSilIB := TIndexBuffer.Create(N * 2, FIndexFormat);
    end;
    if FSilIB = nil then
        Exit;
    N := 0;
    for E := 0 to High(FEdgeA) do
        if FFront[FEdgeF0[E]] <> FFront[FEdgeF1[E]] then
        begin
            FSilIB.Indices[N] := FEdgeA[E];
            FSilIB.Indices[N + 1] := FEdgeB[E];
            Inc(N, 2);
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
    Op: Single;
begin
    if Kit = nil then
        Exit;
    Op := Kit.FillOpacity(FStyle, FActive) * FFillScale;
    if (Op > 0) and (FTriVB <> nil) and (FTriIB <> nil) then
        Context.DrawTriangles(FTriVB, FTriIB, Kit.FillMaterial(FStyle, FActive).Material,
            AbsoluteOpacity * Op);
    inherited;   // spigoli vivi (THoloLines)
    if FShowSilhouette then
    begin
        UpdateSilhouette;
        if FSilIB <> nil then
        begin
            Kit.LineMaterial.Color := LineColor;
            Context.DrawLines(FTriVB, FSilIB, Kit.LineMaterial, AbsoluteOpacity * 0.85);
        end;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloObjMesh.LineColor
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TAlphaColor
//** Scopo: Colore delle linee del modello OBJ in base a stile e stato acceso/spento.
//** Data Ultima Modifica: 15/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloObjMesh.LineColor: TAlphaColor;
begin
    Result := Kit.EdgeColor(FStyle, FActive);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: THoloObjMesh.GetActive
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Restituire lo stato acceso (evidenziato) del modello OBJ.
//** Data Ultima Modifica: 15/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function THoloObjMesh.GetActive: Boolean;
begin
    Result := FActive;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloObjMesh.SetActive
//** Parametri di ingresso: Value: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Accendere o spegnere l'evidenziazione del modello OBJ e ridisegnarlo.
//** Data Ultima Modifica: 15/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloObjMesh.SetActive(const Value: Boolean);
begin
    if FActive = Value then
        Exit;
    FActive := Value;
    Repaint;
end;

end.
