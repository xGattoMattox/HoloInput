//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Pad.ObjBase
//** Scopo: Base dei gamepad con MODELLO 3D REALE (file OBJ generato da foto con TRELLIS/Pixal3D e preparato
//**        con TOOLS\holo_prep.py --align pad --pivot center).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: lettura via XInput (slot 1..4): controller Xbox e compatibili, PlayStation
//** se tradotti in XInput (Steam Input, DS4Windows...).
//**
//** Il corpo del controller e' un'unica mesh fissa (THoloObjMesh). I comandi
//** sono "luci" olografiche sovrapposte nelle posizioni descritte nel file
//** <nome>.ini (coordinate di Blender, vedi OBJ\xbox_holo.ini):
//**    [Levette]   Sinistra / Destra   cappuccio che si sposta con la levetta
//**    [Croce]     Centro              4 luci (su, giu', sinistra, destra)
//**    [Pulsanti]  A B X Y Back Start LB RB
//**    [Grilletti] LT / RT             luce proporzionale alla pressione
//**
//** Assi: nel file OBJ il controller e' appoggiato in piano (pulsanti verso +Y,
//** bumper verso +Z, destra del giocatore verso -X). Nel widget e' messo in
//** piedi rivolto alla camera come i vecchi sketch: pulsanti verso -Z, bumper
//** in alto (-Y in FMX), destra del giocatore verso +X:
//**    FMX = (-x, -z, -y)   (rotazione, nessuno specchiamento)
//***********************************************************************************************************
//***********************************************************************************************************
unit Pad.ObjBase;

interface

uses
    System.SysUtils, System.Types, System.Classes, System.Math, System.Math.Vectors,
    System.IniFiles,
    FMX.Types, FMX.Controls3D, FMX.Objects3D,
    Holo.Config, Holo.Input, Holo.Prims, Holo.Models, Holo.Obj;

type
    TObjPadSpec = record
        ObjName: string;       // nome del file (senza .obj); <nome>.ini = comandi
        Width: Single;         // larghezza del controller nel widget (unita' 3D)
        FaceLabels: array[0..3] of string;   // legende di A, B, X, Y
    end;

    TPadStick = record
        Cap: THoloShape;
        Base: TPoint3D;
        Range: Single;
    end;

    TPadLight = record
        Shape: THoloShape;
        Mask: Word;
    end;

    TObjPadModel = class(TDeviceModel)
    private
        FSpec: TObjPadSpec;
        FScale: Single;
        FAll: TDummy;
        FBody: THoloObjMesh;
        FSticks: array[0..1] of TPadStick;
        FLights: TArray<TPadLight>;
        FTrig: array[0..1] of THoloShape;
        function BlenderToModel(BX, BY, BZ: Single): TPoint3D;
        function ReadSpot(AIni: TMemIniFile; const ASection, AKey: string;
            out P: TPoint3D; out D: Single): Boolean;
        procedure AddLight(const P: TPoint3D; D: Single; AMask: Word; AAxis: TAxis3);
        procedure LoadControls;
    protected
        class function Spec: TObjPadSpec; virtual; abstract;
        procedure Build; override;
    public
        procedure Update(const S: TInputSnapshot; const B: TWidgetConfig; ADeltaT: Single); override;
        procedure BindDevices(AInput: TInputManager; const B: TWidgetConfig); override;
        function IsConnected(const S: TInputSnapshot; const B: TWidgetConfig): Boolean; override;
        function DeviceLabel(const B: TWidgetConfig): string; override;
        class function Kind: TDeviceKind; override;
        class function DefaultView: TModelView; override;
    end;

implementation

uses
    Holo.Lang;

const
    /// Assi del file OBJ -> assi del widget (righe della matrice): FMX = (-x, -z, -y)
    AXIS_X: TPoint3D = (X: -1; Y: 0; Z: 0);
    AXIS_Y: TPoint3D = (X: 0; Y: 0; Z: -1);
    AXIS_Z: TPoint3D = (X: 0; Y: -1; Z: 0);
    LIGHT_THICK = 0.06;     // spessore dei dischi luminosi (unita' 3D)

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjPadModel.Kind
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TDeviceKind
//** Scopo: Tipologia di dispositivo gestita dal modello (gamepad).
//** Data Ultima Modifica: 19/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TObjPadModel.Kind: TDeviceKind;
begin
    Result := dkGamepad;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjPadModel.DefaultView
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TModelView
//** Scopo: Vista di default, controller leggermente inclinato verso l'alto.
//** Data Ultima Modifica: 19/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TObjPadModel.DefaultView: TModelView;
begin
    Result := MakeView(-28, 0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TObjPadModel.BindDevices
//** Parametri di ingresso: AInput: TInputManager; B: TWidgetConfig
//** Parametri di uscita: nessuno
//** Scopo: Attivare la lettura XInput del controller scelto nel Setup.
//** Data Ultima Modifica: 19/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TObjPadModel.BindDevices(AInput: TInputManager; const B: TWidgetConfig);
begin
    AInput.UsePad(EnsureRange(B.DeviceIndex, 0, MAX_PADS - 1));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjPadModel.IsConnected
//** Parametri di ingresso: S: TInputSnapshot; B: TWidgetConfig
//** Parametri di uscita: Result: Boolean
//** Scopo: Indicare se il controller XInput risulta collegato.
//** Data Ultima Modifica: 19/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TObjPadModel.IsConnected(const S: TInputSnapshot; const B: TWidgetConfig): Boolean;
begin
    Result := S.Pads[EnsureRange(B.DeviceIndex, 0, MAX_PADS - 1)].Connected;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjPadModel.DeviceLabel
//** Parametri di ingresso: B: TWidgetConfig
//** Parametri di uscita: Result: string
//** Scopo: Etichetta del dispositivo mostrata nel widget (numero del controller XInput).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TObjPadModel.DeviceLabel(const B: TWidgetConfig): string;
begin
    Result := Format(Tr('widget.label.gamepad', 'XINPUT %d'), [EnsureRange(B.DeviceIndex, 0, MAX_PADS - 1) + 1]);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjPadModel.BlenderToModel
//** Parametri di ingresso: BX, BY, BZ: Single
//** Parametri di uscita: Result: TPoint3D
//** Scopo: Convertire un punto letto in Blender nelle coordinate del widget.
//** Data Ultima Modifica: 20/10/2026
//***********************************************************************************************************
//** Funzionamento: Blender (Z su) -> OBJ (Y su): (x, z, -y); OBJ -> widget:
//** (-x, -z, -y); quindi Blender -> widget = (-bx, by, -bz), poi la scala.
//***********************************************************************************************************
//***********************************************************************************************************
function TObjPadModel.BlenderToModel(BX, BY, BZ: Single): TPoint3D;
begin
    Result := Point3D(-BX * FScale, BY * FScale, -BZ * FScale);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TObjPadModel.ReadSpot
//** Parametri di ingresso: AIni: TMemIniFile; ASection, AKey: string
//** Parametri di uscita: Result: Boolean; P: TPoint3D (out); D: Single (out)
//** Scopo: Leggere "X;Y;Z;diametro" (punto decimale) da una voce del file .ini.
//** Data Ultima Modifica: 20/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TObjPadModel.ReadSpot(AIni: TMemIniFile; const ASection, AKey: string;
    out P: TPoint3D; out D: Single): Boolean;
var
    T: TArray<string>;
    FS: TFormatSettings;
begin
    FS := TFormatSettings.Invariant;
    T := AIni.ReadString(ASection, AKey, '').Split([';']);
    Result := Length(T) >= 3;
    if not Result then
        Exit;
    P := BlenderToModel(StrToFloatDef(Trim(T[0]), 0, FS), StrToFloatDef(Trim(T[1]), 0, FS),
        StrToFloatDef(Trim(T[2]), 0, FS));
    if Length(T) >= 4 then
        D := StrToFloatDef(Trim(T[3]), 0.05, FS) * FScale
    else
        D := 0.05 * FScale;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TObjPadModel.AddLight
//** Parametri di ingresso: P: TPoint3D; D: Single; AMask: Word; AAxis: TAxis3
//** Parametri di uscita: nessuno
//** Scopo: Aggiungere una luce (disco) che si accende con il pulsante AMask.
//** Data Ultima Modifica: 20/10/2026
//***********************************************************************************************************
//** Funzionamento: AAxis = axZ per i comandi sulla faccia (rivolti alla
//** camera), axY per i bumper sul bordo superiore.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TObjPadModel.AddLight(const P: TPoint3D; D: Single; AMask: Word; AAxis: TAxis3);
var
    L: TPadLight;
begin
    L.Shape := Kit.Cyl(FAll, P.X, P.Y, P.Z, D, LIGHT_THICK, AAxis, hsSolid);
    L.Shape.Active := True;
    L.Shape.Visible := False;
    L.Mask := AMask;
    FLights := FLights + [L];
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TObjPadModel.LoadControls
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Creare levette, croce, pulsanti e grilletti dal file <nome>.ini.
//** Data Ultima Modifica: 20/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TObjPadModel.LoadControls;
const
    BtnKeys: array[0..7] of string = ('A', 'B', 'X', 'Y', 'Back', 'Start', 'LB', 'RB');
    BtnMasks: array[0..7] of Word = (XI_A, XI_B, XI_X, XI_Y, XI_BACK, XI_START, XI_LSHOULDER, XI_RSHOULDER);
    StickKeys: array[0..1] of string = ('Sinistra', 'Destra');
    TrigKeys: array[0..1] of string = ('LT', 'RT');
var
    Ini: TMemIniFile;
    P: TPoint3D;
    D, O: Single;
    I: Integer;
begin
    Ini := LoadHoloObjIni(FSpec.ObjName);
    if Ini = nil then
        Exit;
    try
        // levette: cappuccio sempre visibile che segue l'input
        for I := 0 to 1 do
            if ReadSpot(Ini, 'Levette', StickKeys[I], P, D) then
            begin
                FSticks[I].Base := P;
                FSticks[I].Range := D * 0.35;
                FSticks[I].Cap := Kit.Cyl(FAll, P.X, P.Y, P.Z, D * 0.8, LIGHT_THICK, axZ, hsNormal);
            end;

        // croce direzionale: su, giu', sinistra, destra
        if ReadSpot(Ini, 'Croce', 'Centro', P, D) then
        begin
            O := D * 0.33;
            AddLight(P + Point3D(0, -O, 0), D * 0.3, XI_DPAD_UP, axZ);
            AddLight(P + Point3D(0, O, 0), D * 0.3, XI_DPAD_DOWN, axZ);
            AddLight(P + Point3D(-O, 0, 0), D * 0.3, XI_DPAD_LEFT, axZ);
            AddLight(P + Point3D(O, 0, 0), D * 0.3, XI_DPAD_RIGHT, axZ);
        end;

        // pulsanti (le legende A/B/X/Y sono sempre visibili se attive nel setup)
        for I := 0 to High(BtnKeys) do
            if ReadSpot(Ini, 'Pulsanti', BtnKeys[I], P, D) then
            begin
                if I >= 6 then
                    AddLight(P, D, BtnMasks[I], axY)
                else
                    AddLight(P, D, BtnMasks[I], axZ);
                if I <= 3 then
                    Kit.Text(FAll, P.X, P.Y, P.Z - LIGHT_THICK * 1.5, D * 0.6, FSpec.FaceLabels[I]);
            end;

        // grilletti: luce proporzionale alla pressione
        for I := 0 to 1 do
            if ReadSpot(Ini, 'Grilletti', TrigKeys[I], P, D) then
            begin
                FTrig[I] := Kit.Cyl(FAll, P.X, P.Y, P.Z, D, LIGHT_THICK, axY, hsSolid);
                FTrig[I].Active := True;
                FTrig[I].Visible := False;
            end;
    finally
        Ini.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TObjPadModel.Build
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Costruire la scena dal file OBJ.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: carica il corpo, lo mette in piedi rivolto alla camera,
//** lo scala alla larghezza Spec.Width, lo centra e aggiunge i comandi.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TObjPadModel.Build;
var
    Data: THoloObjData;
    Lo, Hi: TPoint3D;
begin
    FSpec := Spec;
    FScale := 1;
    if not LoadHoloObj(FSpec.ObjName, Data) then
    begin
        Kit.Text(Root, 0, 0, 0, 0.45, Tr('model.err.objmissing1', 'FILE OBJ NON TROVATO'), True);
        Kit.Text(Root, 0, 0.6, 0, 0.3, FSpec.ObjName, True);
        SetExtent(7, 3, 1);
        Exit;
    end;

    Data.Reorient(AXIS_X, AXIS_Y, AXIS_Z);
    Data.GetBounds(Lo, Hi);
    FScale := FSpec.Width / Max(1E-6, Hi.X - Lo.X);
    Data.Transform(Point3D(FScale, FScale, FScale), Point3D(0, 0, 0));
    Lo := Point3D(Lo.X * FScale, Lo.Y * FScale, Lo.Z * FScale);
    Hi := Point3D(Hi.X * FScale, Hi.Y * FScale, Hi.Z * FScale);

    FAll := Kit.Pivot(Root, -(Lo.X + Hi.X) / 2, -(Lo.Y + Hi.Y) / 2, -(Lo.Z + Hi.Z) / 2);
    FBody := THoloObjMesh.CreateMesh(Kit, FAll, Data, hsSolid);
    LoadControls;
    SetExtent(Hi.X - Lo.X, Hi.Y - Lo.Y, Hi.Z - Lo.Z);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TObjPadModel.Update
//** Parametri di ingresso: S: TInputSnapshot; B: TWidgetConfig; ADeltaT: Single
//** Parametri di uscita: nessuno
//** Scopo: Aggiornare il gamepad con lo stato XInput.
//** Data Ultima Modifica: 20/10/2026
//***********************************************************************************************************
//** Funzionamento: i cappucci delle levette si spostano (X destra, Y in alto =
//** -Y nel widget) e si accendono se premuti (L3/R3) o fuori dal centro; le
//** luci dei pulsanti compaiono quando sono premuti; i grilletti si
//** illuminano in proporzione alla pressione.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TObjPadModel.Update(const S: TInputSnapshot; const B: TWidgetConfig; ADeltaT: Single);
var
    P: TPadState;
    I: Integer;
    IsOn: Boolean;
    V: Single;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: MoveStick
    //** Parametri di ingresso: ASt: TPadStick (var); AX, AY: Single; AThumb: Word
    //** Parametri di uscita: ASt: TPadStick (var)
    //** Scopo: Spostare il cappuccio di una levetta in base agli assi e accenderlo se premuta o
    //**        inclinata.
    //** Data Ultima Modifica: 20/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure MoveStick(var ASt: TPadStick; AX, AY: Single; AThumb: Word);
    begin
        if ASt.Cap = nil then
            Exit;
        ASt.Cap.Position.Point := ASt.Base + Point3D(AX * ASt.Range, -AY * ASt.Range, 0);
        ASt.Cap.Active := P.Pressed(AThumb) or (Abs(AX) + Abs(AY) > 0.2);
    end;

begin
    if FAll = nil then
        Exit;
    P := S.Pads[EnsureRange(B.DeviceIndex, 0, MAX_PADS - 1)];

    MoveStick(FSticks[0], P.LX, P.LY, XI_LTHUMB);
    MoveStick(FSticks[1], P.RX, P.RY, XI_RTHUMB);

    for I := 0 to High(FLights) do
    begin
        IsOn := P.Pressed(FLights[I].Mask);
        if FLights[I].Shape.Visible <> IsOn then
            FLights[I].Shape.Visible := IsOn;
    end;

    for I := 0 to 1 do
        if FTrig[I] <> nil then
        begin
            if I = 0 then
                V := P.LT
            else
                V := P.RT;
            IsOn := V > 0.05;
            if FTrig[I].Visible <> IsOn then
                FTrig[I].Visible := IsOn;
            if IsOn then
                SetObjOpacity(FTrig[I], 0.3 + 0.7 * V);
        end;
end;

end.
