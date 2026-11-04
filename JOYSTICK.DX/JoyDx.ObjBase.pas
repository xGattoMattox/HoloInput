//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: JoyDx.ObjBase
//** Scopo: Base dei joystick con MODELLI 3D REALI (file OBJ generati da immagine con TRELLIS/Pixal3D e
//**        preparati con TOOLS\holo_prep.py).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: servono due file nella cartella OBJ (o incorporati con HoloObj.rc):
//**    <base>.obj   parte fissa, pivot sulla cima della torretta (--pivot top)
//**    <grip>.obj   impugnatura, pivot sul fondo del connettore (--pivot bottom),
//**                 gia' in scala rispetto alla base (--scale)
//** e facoltativamente <grip>.ini con la posizione dei comandi (vedi sotto).
//**
//** Prolunga facoltativa (es. Flightstick Z-Extension, campo ExtName):
//**    <ext>.obj    pezzo tra torretta e impugnatura, pivot al centro della faccia
//**                 inferiore del collare che si innesta sulla torretta, asse del
//**                 collare in verticale, gia' in scala rispetto alla base
//**    <ext>.ini    punto e asse di montaggio dell'impugnatura (vedi sotto)
//** La prolunga non viene specchiata (le scritte restano leggibili); l'impugnatura
//** viene ruotata e spostata sul collare superiore della prolunga, con il proprio
//** asse allineato all'asse indicato nel file .ini. Con la prolunga gli assi X e
//** Y (pitch e roll) ruotano ancora sul gimbal della base, mentre l'asse Z
//** (twist) ruota l'impugnatura sul collare terminale della prolunga, attorno al
//** proprio asse, esattamente dove si innesta.
//**
//** Gerarchia 3D:
//**   FAll (centra il modello nel widget)
//**    |- base (THoloObjMesh, fissa)
//**    |- FPitch  (centro del gimbal, poco sotto la cima della torretta)
//**         |- FRoll
//**              |- FTwist  (twist senza prolunga)
//**                   |- FGripHolder (riporta il connettore sulla torretta)
//**                        |- impugnatura (THoloObjMesh) + punti luce comandi
//**                           (senza prolunga)
//**                        |- prolunga (THoloObjMesh, facoltativa)
//**                        |- punto di montaggio (collare terminale della prolunga)
//**                             |- FMountYaw   (orientamento fisso, rotazione su Y)
//**                                  |- FMountTilt  (orientamento fisso, rotazione su X)
//**                                       |- FGripTwist  (twist con la prolunga)
//**                                            |- impugnatura + punti luce comandi
//**
//** Assi: OBJ ha Y in alto e il davanti (grilletto) verso +Z; FMX ha Y verso il
//** basso e la camera dal lato -Z (dove sta il pilota). La conversione e' una
//** rotazione di 180 gradi attorno a Z: (x, y, z) -> (-x, -y, z). Per il
//** joystick sinistro la base e' lo stesso modello specchiato: (x, -y, z);
//** l'impugnatura e' specchiata solo se non esiste un modello sinistro dedicato
//** (GripLeft = False), altrimenti si usa il suo file senza specchiarlo.
//**
//** File <grip>.ini (coordinate come si leggono in Blender, Z in alto, dopo
//** aver importato <grip>.obj con le impostazioni standard):
//**    [Pulsanti]
//**    1=X;Y;Z;diametro        numero del pulsante come in Windows (1..32)
//**    [Hat]
//**    Centro=X;Y;Z;diametro
//**
//** File <ext>.ini (stesse coordinate Blender, riferite a <ext>.obj):
//**    [Montaggio]
//**    Punto=X;Y;Z             centro della faccia del collare dove si innesta
//**                            il connettore dell'impugnatura
//**    Asse=X;Y;Z              direzione in cui sale l'impugnatura (dal collare
//**                            verso la sua cima); non serve che sia di lunghezza 1
//**    Rollio=gradi            rotazione dell'impugnatura attorno al proprio asse
//***********************************************************************************************************
//***********************************************************************************************************
unit JoyDx.ObjBase;

interface

uses
    System.SysUtils, System.Types, System.Classes, System.Math, System.Math.Vectors,
    System.IniFiles,
    FMX.Types, FMX.Controls3D, FMX.Objects3D,
    Holo.Config, Holo.Input, Holo.Prims, Holo.Models, Holo.Obj;

type
    TObjStickSpec = record
        BaseName: string;      // nome del file della base (senza .obj)
        GripName: string;      // nome del file dell'impugnatura (senza .obj)
        ExtName: string;       // prolunga tra base e impugnatura (senza .obj); '' = nessuna
        Left: Boolean;        // True = widget sinistro (modello specchiato)
        GripLeft: Boolean;     // True = GripName e' un'impugnatura sinistra dedicata (non specchiata)
        Height: Single;        // altezza complessiva nel widget (unita' 3D)
        GimbalDepth: Single;   // centro di rotazione sotto la torretta (unita' OBJ)
        ViewYaw: Single;       // rotazione di 3/4 della vista predefinita (gradi)
    end;

    TObjStickModel = class(TDeviceModel)
    private
        FSpec: TObjStickSpec;
        FScale, FMapX, FGripMapX: Single;    // FMapX: base, FGripMapX: impugnatura (+1 = specchiata)
        FAll, FPitch, FRoll, FTwist, FGripHolder: TDummy;
        FBase, FGrip, FExt: THoloObjMesh;
        FLights: TArray<THoloShape>;
        FLightBtn: TArray<Integer>;
        FHat: THoloShape;
        FHatBase: TPoint3D;
        FHatStep: Single;
        FHatDX, FHatDZ: TPoint3D;                      // direzioni dell'hat (impugnatura montata)
        FHasMount: Boolean;                            // impugnatura montata sulla prolunga
        FMountP: TPoint3D;                             // punto di montaggio (collare terminale)
        FMountPsi, FMountPhi, FMountRho: Single;       // orientamento: Y, poi X, poi rollio su Y (radianti)
        FMountYaw, FMountTilt, FGripTwist: TDummy;
        function BlenderToModel(BX, BY, BZ: Single): TPoint3D;
        function ParseSpot(const S: string; out P: TPoint3D; out D: Single): Boolean;
        function LoadMount(out AP, AAxis: TPoint3D; out ARoll: Single): Boolean;
        procedure SetMount(const AP, AAxis: TPoint3D; ARoll: Single);
        function MountPoint(const P: TPoint3D): TPoint3D;
        function MountedPoint(const P: TPoint3D): TPoint3D;
        procedure LoadControls;
    protected
        /// Descrizione dei file (fornita dal discendente).
        class function Spec: TObjStickSpec; virtual; abstract;
        procedure Build; override;
    public
        procedure Update(const S: TInputSnapshot; const B: TWidgetConfig; ADeltaT: Single); override;
        procedure BindDevices(AInput: TInputManager; const B: TWidgetConfig); override;
        function IsConnected(const S: TInputSnapshot; const B: TWidgetConfig): Boolean; override;
        function DeviceLabel(const B: TWidgetConfig): string; override;
        class function Kind: TDeviceKind; override;
        class function Mirrored: Boolean; override;
        class function DefaultView: TModelView; override;
    end;

/// Valori predefiniti per TObjStickSpec.
function ObjStickSpec(const ABase, AGrip: string; ALeft: Boolean): TObjStickSpec;

implementation

uses
    Holo.Lang;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: VecRotX
//** Parametri di ingresso: V: TPoint3D; A: Single
//** Parametri di uscita: Result: TPoint3D
//** Scopo: Ruotare un vettore di A radianti attorno all'asse X (regola della mano destra).
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function VecRotX(const V: TPoint3D; A: Single): TPoint3D;
begin
    Result := Point3D(V.X, V.Y * Cos(A) - V.Z * Sin(A), V.Y * Sin(A) + V.Z * Cos(A));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: VecRotY
//** Parametri di ingresso: V: TPoint3D; A: Single
//** Parametri di uscita: Result: TPoint3D
//** Scopo: Ruotare un vettore di A radianti attorno all'asse Y (regola della mano destra).
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function VecRotY(const V: TPoint3D; A: Single): TPoint3D;
begin
    Result := Point3D(V.X * Cos(A) + V.Z * Sin(A), V.Y, -V.X * Sin(A) + V.Z * Cos(A));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: FmxRotSign
//** Parametri di ingresso: AAxisX: Boolean
//** Parametri di uscita: Result: Single
//** Scopo: Ricavare il verso delle rotazioni FireMonkey (RotationAngle) rispetto alla regola della
//**        mano destra usata da VecRotX/VecRotY.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//** Funzionamento: ruota di 90 gradi un oggetto di prova senza genitore
//** attorno a X (o Y) e guarda dove finisce un asse: con la mano destra
//** Y diventa +Z (rotazione su X) e Z diventa +X (rotazione su Y). +1 se
//** FireMonkey ruota nello stesso verso, -1 altrimenti. Cosi' l'orientamento
//** fisso dell'impugnatura sulla prolunga e' corretto qualunque sia la
//** convenzione della versione di FMX.
//***********************************************************************************************************
//***********************************************************************************************************
function FmxRotSign(AAxisX: Boolean): Single;
var
    D: TDummy;
    P: TPoint3D;
begin
    D := TDummy.Create(nil);
    try
        if AAxisX then
        begin
            D.RotationAngle.X := 90;
            P := D.LocalToAbsolute3D(Point3D(0, 1, 0));
            if P.Z >= 0 then
                Result := 1
            else
                Result := -1;
        end
        else
        begin
            D.RotationAngle.Y := 90;
            P := D.LocalToAbsolute3D(Point3D(0, 0, 1));
            if P.X >= 0 then
                Result := 1
            else
                Result := -1;
        end;
    finally
        D.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: ObjStickSpec
//** Parametri di ingresso: ABase, AGrip: string; ALeft: Boolean
//** Parametri di uscita: Result: TObjStickSpec
//** Scopo: Creare la descrizione di un joystick da OBJ con i valori predefiniti (altezza, gimbal,
//**        vista).
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function ObjStickSpec(const ABase, AGrip: string; ALeft: Boolean): TObjStickSpec;
begin
    Result.BaseName := ABase;
    Result.GripName := AGrip;
    Result.ExtName := '';
    Result.Left := ALeft;
    Result.GripLeft := False;
    Result.Height := 7.5;
    Result.GimbalDepth := 0.06;
    if ALeft then
        Result.ViewYaw := -25
    else
        Result.ViewYaw := 25;
end;

//** TObjStickModel *****************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjStickModel.Kind
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TDeviceKind
//** Scopo: Tipologia di dispositivo: joystick sinistro o destro secondo la descrizione del modello.
//** Data Ultima Modifica: 16/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TObjStickModel.Kind: TDeviceKind;
begin
    if Spec.Left then
        Result := dkJoyLeft
    else
        Result := dkJoyRight;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjStickModel.Mirrored
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Indicare se il joystick e' la versione specchiata (sinistra).
//** Data Ultima Modifica: 16/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TObjStickModel.Mirrored: Boolean;
begin
    Result := Spec.Left;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjStickModel.DefaultView
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TModelView
//** Scopo: Vista di 3/4 dal lato del pilota.
//** Data Ultima Modifica: 16/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TObjStickModel.DefaultView: TModelView;
begin
    Result := MakeView(0, Spec.ViewYaw);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TObjStickModel.BindDevices
//** Parametri di ingresso: AInput: TInputManager; B: TWidgetConfig
//** Parametri di uscita: nessuno
//** Scopo: Attivare la lettura del joystick (WinMM) scelto nel Setup.
//** Data Ultima Modifica: 16/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TObjStickModel.BindDevices(AInput: TInputManager; const B: TWidgetConfig);
begin
    AInput.UseJoystick(B.DeviceIndex);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjStickModel.IsConnected
//** Parametri di ingresso: S: TInputSnapshot; B: TWidgetConfig
//** Parametri di uscita: Result: Boolean
//** Scopo: Indicare se il joystick risulta collegato.
//** Data Ultima Modifica: 17/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TObjStickModel.IsConnected(const S: TInputSnapshot; const B: TWidgetConfig): Boolean;
begin
    Result := S.Joys[EnsureRange(B.DeviceIndex, 0, MAX_JOY - 1)].Connected;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjStickModel.DeviceLabel
//** Parametri di ingresso: B: TWidgetConfig
//** Parametri di uscita: Result: string
//** Scopo: Etichetta del dispositivo mostrata nel widget (ID del joystick).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TObjStickModel.DeviceLabel(const B: TWidgetConfig): string;
begin
    Result := Format(Tr('widget.label.joystick', 'JOY ID %d'), [B.DeviceIndex]);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjStickModel.BlenderToModel
//** Parametri di ingresso: BX, BY, BZ: Single
//** Parametri di uscita: Result: TPoint3D
//** Scopo: Convertire un punto letto in Blender nelle coordinate dell'impugnatura.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//** Funzionamento: Blender (Z su) -> OBJ (Y su): (x, z, -y); OBJ -> FMX:
//** (FGripMapX * x, -y, z), come i vertici dell'impugnatura; infine la scala
//** del modello.
//***********************************************************************************************************
//***********************************************************************************************************
function TObjStickModel.BlenderToModel(BX, BY, BZ: Single): TPoint3D;
begin
    Result := Point3D(FGripMapX * BX * FScale, -BZ * FScale, -BY * FScale);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjStickModel.ParseSpot
//** Parametri di ingresso: S: string
//** Parametri di uscita: Result: Boolean; P: TPoint3D (out); D: Single (out)
//** Scopo: Leggere "X;Y;Z;diametro" (punto decimale) dal file .ini.
//** Data Ultima Modifica: 17/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TObjStickModel.ParseSpot(const S: string; out P: TPoint3D; out D: Single): Boolean;
var
    T: TArray<string>;
    FS: TFormatSettings;
begin
    FS := TFormatSettings.Invariant;
    T := S.Split([';']);
    Result := Length(T) >= 3;
    if not Result then
        Exit;
    P := BlenderToModel(StrToFloatDef(Trim(T[0]), 0, FS), StrToFloatDef(Trim(T[1]), 0, FS),
        StrToFloatDef(Trim(T[2]), 0, FS));
    if Length(T) >= 4 then
        D := StrToFloatDef(Trim(T[3]), 0.03, FS) * FScale
    else
        D := 0.03 * FScale;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjStickModel.LoadMount
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean; AP, AAxis: TPoint3D (out); ARoll: Single (out)
//** Scopo: Leggere da <ext>.ini il punto e l'asse di montaggio dell'impugnatura sulla prolunga.
//** Data Ultima Modifica: 26/10/2026
//***********************************************************************************************************
//** Funzionamento: sezione [Montaggio], chiavi Punto e Asse ("X;Y;Z" in
//** coordinate Blender, Z in alto) e Rollio (gradi). Blender -> OBJ: (x, z, -y);
//** OBJ -> FMX senza specchiatura (la prolunga non viene mai specchiata):
//** (-x, -y, z). I valori restano in unita' OBJ: la scala si applica dopo.
//** False se manca il file o se Punto/Asse non sono validi.
//***********************************************************************************************************
//***********************************************************************************************************
function TObjStickModel.LoadMount(out AP, AAxis: TPoint3D; out ARoll: Single): Boolean;
var
    Ini: TMemIniFile;
    FS: TFormatSettings;
    TP, TA: TArray<string>;
begin
    Result := False;
    AP := Point3D(0, 0, 0);
    AAxis := Point3D(0, -1, 0);
    ARoll := 0;
    if FSpec.ExtName = '' then
        Exit;
    Ini := LoadHoloObjIni(FSpec.ExtName);
    if Ini = nil then
        Exit;
    try
        FS := TFormatSettings.Invariant;
        TP := Ini.ReadString('Montaggio', 'Punto', '').Split([';']);
        TA := Ini.ReadString('Montaggio', 'Asse', '').Split([';']);
        if (Length(TP) < 3) or (Length(TA) < 3) then
            Exit;
        AP := Point3D(-StrToFloatDef(Trim(TP[0]), 0, FS), -StrToFloatDef(Trim(TP[2]), 0, FS),
            -StrToFloatDef(Trim(TP[1]), 0, FS));
        AAxis := Point3D(-StrToFloatDef(Trim(TA[0]), 0, FS), -StrToFloatDef(Trim(TA[2]), 1, FS),
            -StrToFloatDef(Trim(TA[1]), 0, FS));
        ARoll := StrToFloatDef(Trim(Ini.ReadString('Montaggio', 'Rollio', '0')), 0, FS);
        Result := AAxis.Length > 1E-6;
    finally
        Ini.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TObjStickModel.SetMount
//** Parametri di ingresso: AP, AAxis: TPoint3D; ARoll: Single
//** Parametri di uscita: nessuno
//** Scopo: Calcolare l'orientamento che porta l'impugnatura sull'asse di montaggio della prolunga.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//** Funzionamento: negli assi FMX l'impugnatura sale verso -Y e ha il davanti
//** (grilletto) verso +Z. Si vuole -Y sull'asse A e +Z sul davanti F, cioe' la
//** direzione +Z resa perpendicolare ad A (se A e' quasi parallelo a Z si parte
//** da +X), ruotata di ARoll gradi attorno ad A. La rotazione viene scomposta
//** in Ry(Psi) * Rx(Phi) * Ry(Rho): Psi e Phi portano +Y su -A (orientamento
//** fisso dato a FMountYaw e FMountTilt), Rho e' il rollio attorno all'asse
//** dell'impugnatura e viene applicato ai vertici (commuta con il twist, che
//** ruota sullo stesso asse). Anche le direzioni dell'hat seguono il rollio.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TObjStickModel.SetMount(const AP, AAxis: TPoint3D; ARoll: Single);
var
    A, F, Z, U, G: TPoint3D;
    C, S, K: Single;
begin
    A := AAxis.Normalize;
    Z := Point3D(0, 0, 1);
    K := Z.DotProduct(A);
    F := Point3D(Z.X - K * A.X, Z.Y - K * A.Y, Z.Z - K * A.Z);
    if F.Length < 0.05 then
    begin
        K := A.X;
        F := Point3D(1 - K * A.X, -K * A.Y, -K * A.Z);
    end;
    F := F.Normalize;
    C := Cos(DegToRad(ARoll));
    S := Sin(DegToRad(ARoll));
    Z := A.CrossProduct(F);
    F := Point3D(F.X * C + Z.X * S, F.Y * C + Z.Y * S, F.Z * C + Z.Z * S).Normalize;
    U := Point3D(-A.X, -A.Y, -A.Z);
    FMountPhi := ArcCos(EnsureRange(U.Y, -1, 1));
    if Sin(FMountPhi) > 1E-4 then
        FMountPsi := ArcTan2(U.X, U.Z)
    else
        FMountPsi := 0;
    G := VecRotX(VecRotY(F, -FMountPsi), -FMountPhi);
    FMountRho := ArcTan2(G.X, G.Z);
    FMountP := AP;
    FHasMount := True;
    FHatDX := VecRotY(Point3D(1, 0, 0), FMountRho);
    FHatDZ := VecRotY(Point3D(0, 0, 1), FMountRho);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjStickModel.MountPoint
//** Parametri di ingresso: P: TPoint3D
//** Parametri di uscita: Result: TPoint3D
//** Scopo: Applicare a un punto dell'impugnatura (assi FMX, gia' in scala) il rollio di montaggio.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//** Funzionamento: i punti dell'impugnatura stanno dentro FGripTwist, che e'
//** gia' sul collare della prolunga e orientato lungo il suo asse: resta da
//** applicare solo il rollio attorno a Y. Senza prolunga il punto e' invariato.
//***********************************************************************************************************
//***********************************************************************************************************
function TObjStickModel.MountPoint(const P: TPoint3D): TPoint3D;
begin
    if FHasMount then
        Result := VecRotY(P, FMountRho)
    else
        Result := P;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjStickModel.MountedPoint
//** Parametri di ingresso: P: TPoint3D
//** Parametri di uscita: Result: TPoint3D
//** Scopo: Posizione finale (rispetto a FGripHolder) di un vertice dell'impugnatura montata, a
//**        riposo.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//** Funzionamento: il vertice ha gia' ricevuto il rollio (Ry(Rho), applicato
//** ai dati in Build): resta punto di montaggio + Ry(Psi) * Rx(Phi) * P, la
//** stessa trasformazione che FMountYaw / FMountTilt producono nella scena
//** (twist a zero). Serve per calcolare l'ingombro dell'insieme.
//***********************************************************************************************************
//***********************************************************************************************************
function TObjStickModel.MountedPoint(const P: TPoint3D): TPoint3D;
begin
    if FHasMount then
        Result := VecRotY(VecRotX(P, FMountPhi), FMountPsi) + FMountP
    else
        Result := P;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TObjStickModel.LoadControls
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Creare i punti luce dei comandi descritti in <grip>.ini.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//** Funzionamento: i punti sono figli dello stesso contenitore
//** dell'impugnatura, quindi si muovono con lei; restano nascosti finche' il
//** comando non viene premuto. Con la prolunga stanno in FGripTwist (ruotano
//** con il twist sul collare) e ricevono il rollio di montaggio (MountPoint).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TObjStickModel.LoadControls;
var
    Ini: TMemIniFile;
    Keys: TStringList;
    K: string;
    P: TPoint3D;
    D: Single;
    Idx: Integer;
    L: THoloShape;
    Par: TFmxObject;
begin
    if FGripTwist <> nil then
        Par := FGripTwist
    else
        Par := FGripHolder;
    Ini := LoadHoloObjIni(FSpec.GripName);
    if Ini = nil then
        Exit;
    Keys := TStringList.Create;
    try
        Ini.ReadSection('Pulsanti', Keys);
        for K in Keys do
        begin
            Idx := StrToIntDef(Trim(K), 0) - 1;
            if (Idx < 0) or not ParseSpot(Ini.ReadString('Pulsanti', K, ''), P, D) then
                Continue;
            P := MountPoint(P);
            L := Kit.Ball(Par, P.X, P.Y, P.Z, D, D, D, hsSolid);
            L.Active := True;
            L.Visible := False;
            FLights := FLights + [L];
            FLightBtn := FLightBtn + [Idx];
        end;
        if ParseSpot(Ini.ReadString('Hat', 'Centro', ''), P, D) then
        begin
            P := MountPoint(P);
            FHat := Kit.Ball(Par, P.X, P.Y, P.Z, D, D, D, hsSolid);
            FHat.Active := True;
            FHat.Visible := False;
            FHatBase := P;
            FHatStep := D * 0.6;
        end;
    finally
        Keys.Free;
        Ini.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TObjStickModel.Build
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Costruire la scena dai file OBJ (base, prolunga facoltativa, impugnatura).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento:
//**  1. carica base, prolunga (se Spec.ExtName non e' vuoto) e impugnatura e le
//**     porta negli assi FMX (Y giu', pilota a -Z); la prolunga non e' mai
//**     specchiata, l'impugnatura sinistra lo e' solo se non ha un modello
//**     dedicato (Spec.GripLeft); con la prolunga l'impugnatura viene montata sul suo collare
//**     superiore (punto e asse letti da <ext>.ini): ai vertici si applica solo
//**     il rollio, la posizione e l'orientamento li danno i contenitori
//**     FMountYaw / FMountTilt, e il twist ruota FGripTwist sull'asse
//**     dell'impugnatura (non piu' sulla base);
//**  2. calcola l'ingombro dell'insieme a riposo e la scala che lo rende alto
//**     Spec.Height;
//**  3. crea la base fissa e la catena gimbal -> pitch -> roll -> twist con
//**     prolunga e impugnatura, e centra tutto nel widget;
//**  4. aggiunge i punti luce dei comandi (se c'e' il file .ini).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TObjStickModel.Build;
var
    BD, GD, ED: THoloObjData;
    HasB, HasG, HasE, Any: Boolean;
    PMin, PMax, Lo, Hi, C, MP, MA, P: TPoint3D;
    Gimbal, MR: Single;
    I: Integer;
    GripPar: TFmxObject;
    Mnt: TDummy;
begin
    FSpec := Spec;
    if FSpec.Left then
        FMapX := 1
    else
        FMapX := -1;
    // impugnatura sinistra dedicata: si usa cosi' com'e', senza specchiarla
    if FSpec.GripLeft then
        FGripMapX := -1
    else
        FGripMapX := FMapX;
    FScale := 1;
    FHasMount := False;
    FMountP := Point3D(0, 0, 0);
    FMountPsi := 0;
    FMountPhi := 0;
    FMountRho := 0;
    FHatDX := Point3D(1, 0, 0);
    FHatDZ := Point3D(0, 0, 1);

    HasB := LoadHoloObj(FSpec.BaseName, BD);
    HasG := LoadHoloObj(FSpec.GripName, GD);
    HasE := (FSpec.ExtName <> '') and LoadHoloObj(FSpec.ExtName, ED);
    if not (HasB or HasG or HasE) then
    begin
        Kit.Text(Root, 0, 0, 0, 0.45, Tr('model.err.objmissing', 'FILE OBJ NON TROVATI'), True);
        Kit.Text(Root, 0, 0.6, 0, 0.3, FSpec.BaseName + ' / ' + FSpec.GripName, True);
        SetExtent(7, 3, 1);
        Exit;
    end;

    // 1. assi OBJ -> FMX; la prolunga non si specchia; impugnatura montata sulla prolunga
    BD.Transform(Point3D(FMapX, -1, 1), Point3D(0, 0, 0));
    GD.Transform(Point3D(FGripMapX, -1, 1), Point3D(0, 0, 0));
    if HasE then
    begin
        ED.Transform(Point3D(-1, -1, 1), Point3D(0, 0, 0));
        if LoadMount(MP, MA, MR) then
        begin
            SetMount(MP, MA, MR);
            GD.Reorient(Point3D(Cos(FMountRho), 0, Sin(FMountRho)), Point3D(0, 1, 0),
                        Point3D(-Sin(FMountRho), 0, Cos(FMountRho)));
        end;
    end;

    // 2. ingombro a riposo (il connettore sulla torretta sta in 0,0,0) e scala
    Any := False;
    Lo := Point3D(0, 0, 0);
    Hi := Point3D(0, 0, 0);
    if BD.GetBounds(PMin, PMax) then
    begin
        Lo := PMin;
        Hi := PMax;
        Any := True;
    end;
    if HasE and ED.GetBounds(PMin, PMax) then
    begin
        if Any then
        begin
            Lo := Point3D(Min(Lo.X, PMin.X), Min(Lo.Y, PMin.Y), Min(Lo.Z, PMin.Z));
            Hi := Point3D(Max(Hi.X, PMax.X), Max(Hi.Y, PMax.Y), Max(Hi.Z, PMax.Z));
        end
        else
        begin
            Lo := PMin;
            Hi := PMax;
        end;
        Any := True;
    end;
    // impugnatura: vertici nella posizione montata (MountedPoint)
    for I := 0 to High(GD.Verts) do
    begin
        P := MountedPoint(GD.Verts[I]);
        if Any then
        begin
            Lo := Point3D(Min(Lo.X, P.X), Min(Lo.Y, P.Y), Min(Lo.Z, P.Z));
            Hi := Point3D(Max(Hi.X, P.X), Max(Hi.Y, P.Y), Max(Hi.Z, P.Z));
        end
        else
        begin
            Lo := P;
            Hi := P;
            Any := True;
        end;
    end;
    FScale := FSpec.Height / Max(1E-6, Hi.Y - Lo.Y);
    BD.Transform(Point3D(FScale, FScale, FScale), Point3D(0, 0, 0));
    GD.Transform(Point3D(FScale, FScale, FScale), Point3D(0, 0, 0));
    if HasE then
        ED.Transform(Point3D(FScale, FScale, FScale), Point3D(0, 0, 0));
    FMountP := Point3D(FMountP.X * FScale, FMountP.Y * FScale, FMountP.Z * FScale);
    Lo := Point3D(Lo.X * FScale, Lo.Y * FScale, Lo.Z * FScale);
    Hi := Point3D(Hi.X * FScale, Hi.Y * FScale, Hi.Z * FScale);
    Gimbal := FSpec.GimbalDepth * FScale;   // positivo = verso il basso in FMX

    // 3. scena
    C := Point3D((Lo.X + Hi.X) / 2, (Lo.Y + Hi.Y) / 2, (Lo.Z + Hi.Z) / 2);
    FAll := Kit.Pivot(Root, -C.X, -C.Y, -C.Z);
    if not BD.IsEmpty then
        FBase := THoloObjMesh.CreateMesh(Kit, FAll, BD, hsNormal);

    FPitch := Kit.Pivot(FAll, 0, Gimbal, 0);
    FRoll := Kit.Pivot(FPitch, 0, 0, 0);
    FTwist := Kit.Pivot(FRoll, 0, 0, 0);
    FGripHolder := Kit.Pivot(FTwist, 0, -Gimbal, 0);
    if HasE and not ED.IsEmpty then
        FExt := THoloObjMesh.CreateMesh(Kit, FGripHolder, ED, hsSolid);
    GripPar := FGripHolder;
    if FHasMount then
    begin
        // collare terminale della prolunga: orientamento fisso + twist sull'asse dell'impugnatura
        Mnt := Kit.Pivot(FGripHolder, FMountP.X, FMountP.Y, FMountP.Z);
        FMountYaw := Kit.Pivot(Mnt, 0, 0, 0);
        FMountYaw.RotationAngle.Y := RadToDeg(FMountPsi) * FmxRotSign(False);
        FMountTilt := Kit.Pivot(FMountYaw, 0, 0, 0);
        FMountTilt.RotationAngle.X := RadToDeg(FMountPhi) * FmxRotSign(True);
        FGripTwist := Kit.Pivot(FMountTilt, 0, 0, 0);
        GripPar := FGripTwist;
    end;
    if not GD.IsEmpty then
        FGrip := THoloObjMesh.CreateMesh(Kit, GripPar, GD, hsSolid);

    // 4. comandi
    LoadControls;

    // margine per l'impugnatura inclinata
    SetExtent((Hi.X - Lo.X) * 1.12, (Hi.Y - Lo.Y) * 1.04, (Hi.Z - Lo.Z) * 1.12);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TObjStickModel.Update
//** Parametri di ingresso: S: TInputSnapshot; B: TWidgetConfig; ADeltaT: Single
//** Parametri di uscita: nessuno
//** Scopo: Muovere l'impugnatura e accendere i comandi.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//** Funzionamento: assi (mappati/invertiti dal setup) -> rotazioni del gimbal;
//** l'angolo di ogni asse e' meta' dell'ampiezza impostata nel setup (RangeX/Y/Z):
//** con 60 gradi l'asse a fine corsa vale -30/+30 gradi. Con la prolunga il twist ruota FGripTwist, cioe'
//** l'impugnatura attorno al proprio asse sul collare della prolunga, mentre
//** pitch e roll restano sul gimbal della base. Pulsanti -> punti luce visibili
//** quando premuti; hat -> punto luce spostato nella direzione del POV (sul
//** piano dell'impugnatura, anche quando e' montata inclinata sulla prolunga).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TObjStickModel.Update(const S: TInputSnapshot; const B: TWidgetConfig; ADeltaT: Single);
var
    J: TJoyState;
    AX, AY, AZ, A: Single;
    I: Integer;
    IsOn: Boolean;
begin
    if FPitch = nil then
        Exit;
    J := S.Joys[EnsureRange(B.DeviceIndex, 0, MAX_JOY - 1)];
    AX := JoyAxisValue(J, B.AxisX, B.InvertX);
    AY := JoyAxisValue(J, B.AxisY, B.InvertY);
    AZ := JoyAxisValue(J, B.AxisZ, B.InvertZ);

    // Y negativo = stick spinto in avanti (lontano dal pilota, +Z)
    // asse a fine corsa (+/-1) = meta' dell'ampiezza totale impostata
    FPitch.RotationAngle.X := Rot(AY * B.RangeY * 0.5);
    FRoll.RotationAngle.Z := Rot(AX * B.RangeX * 0.5);
    // con la prolunga il twist ruota l'impugnatura sul collare terminale
    if FGripTwist <> nil then
        FGripTwist.RotationAngle.Y := Rot(AZ * B.RangeZ * 0.5)
    else
        FTwist.RotationAngle.Y := Rot(AZ * B.RangeZ * 0.5);

    for I := 0 to High(FLights) do
    begin
        IsOn := J.Button(FLightBtn[I]);
        if FLights[I].Visible <> IsOn then
            FLights[I].Visible := IsOn;
    end;

    if FHat <> nil then
    begin
        IsOn := J.Connected and (J.POV >= 0);
        if IsOn then
        begin
            A := DegToRad(J.POV);
            FHat.Position.Point := Point3D(
                FHatBase.X + (FHatDX.X * Sin(A) + FHatDZ.X * Cos(A)) * FHatStep,
                FHatBase.Y + (FHatDX.Y * Sin(A) + FHatDZ.Y * Cos(A)) * FHatStep,
                FHatBase.Z + (FHatDX.Z * Sin(A) + FHatDZ.Z * Cos(A)) * FHatStep);
        end;
        if FHat.Visible <> IsOn then
            FHat.Visible := IsOn;
    end;
end;

end.
