//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Thr.Base
//** Scopo: Base comune delle manette (throttle) destre e sinistre: modello 3D generico disegnato da
//**        codice.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: la manetta e' letta come joystick WinMM/HID (stesso
//** dispositivo, stesso ID del Setup). Scena nel piano XY (piano della
//** scrivania), altezza verso -Z, +Y verso il pilota:
//**   - base con la guida della leva;
//**   - leva che ruota attorno all'asse X (avanti / indietro) seguendo l'asse
//**     principale; l'ampiezza totale e' "Leva" nella pagina Ampiezza;
//**   - impugnatura in cima alla leva con:
//**       * hat a 8 direzioni (POV): il cappuccio si sposta nella direzione
//**         premuta e si accende;
//**       * mini-stick analogico (2 assi) che si inclina, ampiezze "Mini-stick"
//**         nella pagina Ampiezza;
//**       * 4 pulsanti sul piano superiore e 2 sul fianco rivolto al pilota
//**         (pulsanti 1..6 a partire dal "primo pulsante" del Setup), che si
//**         abbassano e si accendono.
//** Uso dei campi di TWidgetConfig per le manette:
//**   AxisX / InvertX / RangeX = leva (asse principale);
//**   AxisY / InvertY / RangeY = mini-stick sinistra / destra;
//**   AxisZ / InvertZ / RangeZ = mini-stick su / giu'.
//** La versione sinistra (Mirrored) specchia la posizione di hat e mini-stick.
//***********************************************************************************************************
//***********************************************************************************************************
unit Thr.Base;

interface

uses
    System.SysUtils, System.Math, System.Math.Vectors,
    FMX.Types, FMX.Controls3D, FMX.Objects3D,
    Holo.Config, Holo.Input, Holo.Prims, Holo.Models;

const
    /// pulsanti dell'impugnatura generica (4 sul piano superiore + 2 sul fianco)
    THR_BUTTONS = 6;

type
    TThrottleModel = class(TDeviceModel)
    private
        FBody: TDummy;                                   // tutto il modello, centrato sull'origine
        FLever: TDummy;                                  // perno della leva
        FMini: TDummy;                                   // perno del mini-stick
        FMiniKnob: THoloLines;
        FHat: THoloLines;
        FHatBase: TPoint3D;
        FButtons: array[0..THR_BUTTONS - 1] of THoloLines;
        FBtnBase: array[0..THR_BUTTONS - 1] of TPoint3D;
        FBtnPush: array[0..THR_BUTTONS - 1] of TPoint3D; // spostamento quando il pulsante e' premuto
        FPressed: array[0..THR_BUTTONS - 1] of Boolean;
    protected
        procedure Build; override;
    public
        procedure Update(const S: TInputSnapshot; const B: TWidgetConfig; ADeltaT: Single); override;
        procedure BindDevices(AInput: TInputManager; const B: TWidgetConfig); override;
        function IsConnected(const S: TInputSnapshot; const B: TWidgetConfig): Boolean; override;
        function DeviceLabel(const B: TWidgetConfig): string; override;
        class function Kind: TDeviceKind; override;
        class function DefaultView: TModelView; override;
        class function DefaultAxes: string; override;
    end;

implementation

uses
    Holo.Lang;

const
    BODY_DZ = 2.3;          // il modello va da Z = 0 (scrivania) a Z = -4.6: lo si centra
    GRIP_TOP = -4.4;        // piano superiore dell'impugnatura (nel sistema della leva)
    HAT_STEP = 0.12;        // spostamento del cappuccio dell'hat
    BTN_TRAVEL = 0.07;      // corsa dei pulsanti

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TThrottleModel.Kind
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TDeviceKind
//** Scopo: Tipologia: manetta destra, o sinistra per le versioni specchiate.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TThrottleModel.Kind: TDeviceKind;
begin
    if Mirrored then
        Result := dkThrLeft
    else
        Result := dkThrRight;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TThrottleModel.DefaultView
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TModelView
//** Scopo: Vista predefinita: di tre quarti, leggermente dall'alto, girata verso il centro.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TThrottleModel.DefaultView: TModelView;
begin
    if Mirrored then
        Result := MakeView(-62, -28)
    else
        Result := MakeView(-62, 28);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TThrottleModel.DefaultAxes
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Mappatura assi proposta dal Setup: leva sull'asse Z, mini-stick sugli assi X e Y.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TThrottleModel.DefaultAxes: string;
begin
    Result := '2,0,1';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TThrottleModel.BindDevices
//** Parametri di ingresso: AInput: TInputManager; B: TWidgetConfig
//** Parametri di uscita: nessuno
//** Scopo: Attivare la lettura del joystick (WinMM / HID) a cui e' collegata la manetta.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TThrottleModel.BindDevices(AInput: TInputManager; const B: TWidgetConfig);
begin
    AInput.UseJoystick(B.DeviceIndex);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TThrottleModel.IsConnected
//** Parametri di ingresso: S: TInputSnapshot; B: TWidgetConfig
//** Parametri di uscita: Result: Boolean
//** Scopo: Indicare se il dispositivo della manetta risulta collegato.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TThrottleModel.IsConnected(const S: TInputSnapshot; const B: TWidgetConfig): Boolean;
begin
    Result := S.Joys[EnsureRange(B.DeviceIndex, 0, MAX_JOY - 1)].Connected;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TThrottleModel.DeviceLabel
//** Parametri di ingresso: B: TWidgetConfig
//** Parametri di uscita: Result: string
//** Scopo: Etichetta del dispositivo mostrata nel widget (ID joystick).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TThrottleModel.DeviceLabel(const B: TWidgetConfig): string;
begin
    Result := Format(Tr('widget.label.joystick', 'JOY ID %d'), [B.DeviceIndex]);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TThrottleModel.Build
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Costruire base, leva, impugnatura, hat, mini-stick e pulsanti.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: tutto sta sotto FBody, spostato di BODY_DZ cosi' il modello
//** e' centrato sull'origine (il widget inquadra l'ingombro attorno al centro).
//** Il perno della leva e' dentro la base: la leva ruota attorno a X. Hat e
//** mini-stick stanno sul piano superiore dell'impugnatura, ai due lati
//** (specchiati con MX nella versione sinistra); i 4 pulsanti superiori sono
//** in fila verso il pilota, i 2 laterali sul fianco rivolto al pilota.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TThrottleModel.Build;
var
    I: Integer;
    X: Single;
begin
    FBody := Kit.Pivot(Root, 0, 0, BODY_DZ);

    // base e guida della leva
    Kit.RBox(FBody, 0, 0, -0.6, 3.0, 5.0, 1.2, hsDim, axZ, 0.08, 24);
    Kit.RBox(FBody, 0, 0, -1.22, 0.34, 3.6, 0.05, hsGhost, axZ, 0, 16);
    Kit.Box(FBody, MX(1.05), 1.7, -1.24, 0.5, 0.5, 0.06, hsGhost);     // targhetta

    // leva: perno dentro la base, asta e impugnatura
    FLever := Kit.Pivot(FBody, 0, 0, -0.4);
    Kit.Cyl(FLever, 0, 0, -1.6, 0.34, 2.4, axZ, hsSolid);
    Kit.RBox(FLever, 0, 0.1, -3.7, 1.8, 1.4, 1.4, hsNormal, axZ, 0.12, 24);

    // hat a 8 direzioni
    Kit.Cyl(FLever, MX(-0.45), -0.25, GRIP_TOP + 0.02, 0.46, 0.06, axZ, hsDim);
    FHatBase := Point3D(MX(-0.45), -0.25, GRIP_TOP - 0.08);
    FHat := Kit.Cyl(FLever, FHatBase.X, FHatBase.Y, FHatBase.Z, 0.26, 0.14, axZ, hsNormal);

    // mini-stick: base, perno e cappuccio con pomello
    Kit.Cyl(FLever, MX(0.45), -0.25, GRIP_TOP + 0.02, 0.46, 0.06, axZ, hsDim);
    FMini := Kit.Pivot(FLever, MX(0.45), -0.25, GRIP_TOP);
    FMiniKnob := Kit.Cyl(FMini, 0, 0, -0.14, 0.14, 0.28, axZ, hsNormal);
    Kit.Ball(FMini, 0, 0, -0.32, 0.24, 0.24, 0.12, hsSolid);

    // pulsanti 1-4 sul piano superiore, in fila verso il pilota
    for I := 0 to 3 do
    begin
        X := MX(-0.6 + I * 0.4);
        FButtons[I] := Kit.RBox(FLever, X, 0.4, GRIP_TOP - 0.06, 0.28, 0.28, 0.14, hsNormal, axZ, 0.1, 16);
        FBtnPush[I] := Point3D(0, 0, BTN_TRAVEL);                 // verso l'impugnatura (+Z)
    end;
    // pulsanti 5-6 sul fianco rivolto al pilota (+Y)
    for I := 4 to 5 do
    begin
        FButtons[I] := Kit.Box(FLever, MX(-0.35 + (I - 4) * 0.7), 0.86, -3.55, 0.36, 0.12, 0.36, hsNormal);
        FBtnPush[I] := Point3D(0, -BTN_TRAVEL, 0);                // verso l'impugnatura (-Y)
    end;
    for I := 0 to THR_BUTTONS - 1 do
        FBtnBase[I] := FButtons[I].Position.Point;

    SetExtent(3.4, 5.4, 4.8);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TThrottleModel.Update
//** Parametri di ingresso: S: TInputSnapshot; B: TWidgetConfig; ADeltaT: Single
//** Parametri di uscita: nessuno
//** Scopo: Muovere leva, mini-stick, hat e pulsanti con lo stato del dispositivo.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: asse a fine corsa (+/-1) = meta' dell'ampiezza impostata
//** (RangeX per la leva, RangeY / RangeZ per il mini-stick). L'hat si sposta
//** nella direzione del POV (0 = avanti, 90 = destra) e si accende; i pulsanti
//** (ButtonOffset + 0..5) si abbassano e si accendono solo quando cambiano.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TThrottleModel.Update(const S: TInputSnapshot; const B: TWidgetConfig; ADeltaT: Single);
var
    J: TJoyState;
    AL, MXv, MYv, A: Single;
    I: Integer;
    P, HatOn: Boolean;
begin
    if FLever = nil then
        Exit;
    J := S.Joys[EnsureRange(B.DeviceIndex, 0, MAX_JOY - 1)];
    AL := JoyAxisValue(J, B.AxisX, B.InvertX);
    MXv := JoyAxisValue(J, B.AxisY, B.InvertY);
    MYv := JoyAxisValue(J, B.AxisZ, B.InvertZ);

    // leva: avanti / indietro attorno all'asse X
    FLever.RotationAngle.X := Rot(AL * B.RangeX * 0.5);
    // mini-stick: sinistra / destra attorno a Y, su / giu' attorno a X
    FMini.RotationAngle.Y := Rot(MXv * B.RangeY * 0.5);
    FMini.RotationAngle.X := Rot(MYv * B.RangeZ * 0.5);
    FMiniKnob.Active := (Abs(MXv) > 0.2) or (Abs(MYv) > 0.2);

    // hat
    HatOn := J.Connected and (J.POV >= 0);
    if HatOn then
    begin
        A := DegToRad(J.POV);
        FHat.Position.Point := Point3D(FHatBase.X + Sin(A) * HAT_STEP, FHatBase.Y - Cos(A) * HAT_STEP,
            FHatBase.Z);
    end
    else
        FHat.Position.Point := FHatBase;
    if FHat.Active <> HatOn then
        FHat.Active := HatOn;

    // pulsanti
    for I := 0 to THR_BUTTONS - 1 do
    begin
        P := J.Button(B.ButtonOffset + I);
        if P <> FPressed[I] then
        begin
            FPressed[I] := P;
            FButtons[I].Active := P;
            if P then
                FButtons[I].Position.Point := FBtnBase[I] + FBtnPush[I]
            else
                FButtons[I].Position.Point := FBtnBase[I];
        end;
    end;
end;

end.
