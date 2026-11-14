//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Mouse.Base
//** Scopo: Base comune degli sketch dei mouse (2 assi).
//** Data Ultima Modifica: 06/10/2026
//***********************************************************************************************************
//** Funzionamento: scena (vista dall'alto nel piano XY, altezza verso -Z):
//**   - tappetino (piastra attenuata);
//**   - corpo del mouse che SI SPOSTA sul tappetino seguendo la posizione
//**     accumulata (non si ricentra dopo il movimento: resta dove l'ha portato
//**     l'utente, entro i bordi del tappetino);
//**   - il corpo si inclina leggermente nella direzione di movimento (velocita');
//**   - pulsanti che si abbassano e si accendono, rotella che gira ad ogni scatto;
//**   - "radar" in un angolo del tappetino con un punto che indica il vettore
//**     velocita' istantaneo.
//***********************************************************************************************************
//***********************************************************************************************************
unit Mouse.Base;

interface

uses
    System.SysUtils, System.Math, System.Math.Vectors,
    FMX.Types, FMX.Controls3D, FMX.Objects3D,
    Holo.Config, Holo.Input, Holo.Prims, Holo.Models;

type
    TMouseModel = class(TDeviceModel)
    private
        FBody: TDummy;
        FTilt: TDummy;
        FBtnL, FBtnR, FBtnX1, FBtnX2, FDpi: THoloLines;
        FWheelAxis: TDummy;
        FWheel: THoloShape;
        FRadarDot: THoloShape;
        FRadarCenter: TPoint3D;
        FLastBtn: Byte;
        FMatW, FMatH: Single;
        procedure SetButton(AShape: THoloLines; APressed: Boolean);
    protected
        /// Il modello ha i due pulsanti laterali (X1/X2) e il pulsante DPI?
        function HasSideButtons: Boolean; virtual;
        /// Larghezza/lunghezza del corpo (unita' 3D).
        function BodyWidth: Single; virtual;
        function BodyLength: Single; virtual;
        procedure Build; override;
    public
        procedure Update(const S: TInputSnapshot; const B: TWidgetConfig; ADeltaT: Single); override;
        class function eKind: TDeviceKind; override;
        class function rDefaultView: TModelView; override;
    end;

implementation

const
    BTN_TRAVEL = 0.08;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TMouseModel.Kind
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TDeviceKind
//** Scopo: Tipologia di dispositivo gestita dal modello (mouse).
//** Data Ultima Modifica: 05/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TMouseModel.eKind: TDeviceKind;
begin
    Result := dkMouse;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TMouseModel.rDefaultView
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TModelView
//** Scopo: Vista predefinita del mouse, inclinato verso l'osservatore.
//** Data Ultima Modifica: 06/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TMouseModel.rDefaultView: TModelView;
begin
    Result := rMakeView(-55, 0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TMouseModel.HasSideButtons
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Indicare se il mouse ha i pulsanti laterali (di default si').
//** Data Ultima Modifica: 06/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TMouseModel.HasSideButtons: Boolean;
begin
    Result := True;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TMouseModel.BodyWidth
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Single
//** Scopo: Larghezza della scocca del mouse (unita' del modello).
//** Data Ultima Modifica: 06/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TMouseModel.BodyWidth: Single;
begin
    Result := 2.6;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TMouseModel.BodyLength
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Single
//** Scopo: Lunghezza della scocca del mouse (unita' del modello).
//** Data Ultima Modifica: 06/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TMouseModel.BodyLength: Single;
begin
    Result := 4.4;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TMouseModel.Build
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Costruire tappetino, corpo, pulsanti, rotella e radar.
//** Data Ultima Modifica: 06/10/2026
//***********************************************************************************************************
//** Funzionamento: la scocca e' un loft ad alta definizione (9 sezioni x 32
//** lati); il corpo e' un gruppo (FBody) che verra' traslato sul
//** tappetino; dentro c'e' un secondo gruppo (FTilt) per l'inclinazione.
//** La rotella e' un cilindro con asse Y dentro un pivot ruotato di 90 gradi
//** attorno a Z (asse finale = X): ruotando il cilindro attorno al proprio
//** asse Y la rotella "gira", e le tacche figlie lo rendono visibile.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TMouseModel.Build;
var
    BW, BL: Single;
    I: Integer;
    A: Single;
begin
    BW := BodyWidth;
    BL := BodyLength;
    FMatW := 9;
    FMatH := 7.4;

    // tappetino con bordo arrotondato
    oKit.oRBox(oRoot, 0, 0, 0.95, FMatW, FMatH, 0.08, hsDim, axZ, 0, 40, 6);
    oKit.oBox(oRoot, 0, 0, 0.9, FMatW - 0.4, FMatH - 0.4, 0.02, hsGhost);

    FBody := oKit.oPivot(oRoot, 0, 0, 0);
    FTilt := oKit.oPivot(FBody, 0, 0, 0.3);

    // scocca: loft lungo Y (dalla punta al dorso), 9 sezioni x 32 lati,
    // gobba ergonomica spostata verso il dorso, vita ai lati per la presa
    //       Y            CX  CZ      A           B     N
    oKit.oLoft(FTilt, 0, 0, 0, [
        rSec(-0.50 * BL, 0,  0.25, 0.30 * BW, 0.18, 2.4),
        rSec(-0.42 * BL, 0,  0.12, 0.46 * BW, 0.38, 2.4),
        rSec(-0.28 * BL, 0,  0.00, 0.49 * BW, 0.52, 2.4),
        rSec(-0.10 * BL, 0, -0.08, 0.47 * BW, 0.62, 2.4),
        rSec( 0.08 * BL, 0, -0.14, 0.47 * BW, 0.68, 2.4),
        rSec( 0.25 * BL, 0, -0.12, 0.50 * BW, 0.66, 2.4),
        rSec( 0.38 * BL, 0, -0.02, 0.48 * BW, 0.55, 2.4),
        rSec( 0.46 * BL, 0,  0.10, 0.40 * BW, 0.40, 2.4),
        rSec( 0.50 * BL, 0,  0.25, 0.22 * BW, 0.22, 2.4)], hsSolid, 32, 2);

    // pulsanti principali (placche arrotondate sopra la scocca)
    FBtnL := oKit.oRBox(FTilt, -BW * 0.235, -BL * 0.28, -0.58, BW * 0.43, BL * 0.36, 0.12,
        hsNormal, axZ, 0.08, 20);
    FBtnR := oKit.oRBox(FTilt, BW * 0.235, -BL * 0.28, -0.58, BW * 0.43, BL * 0.36, 0.12,
        hsNormal, axZ, 0.08, 20);

    // rotella
    FWheelAxis := oKit.oPivot(FTilt, 0, -BL * 0.30, -0.62);
    FWheelAxis.RotationAngle.Z := 90;
    FWheel := oKit.oCyl(FWheelAxis, 0, 0, 0, 0.62, 0.26, axY, hsSolid);
    for I := 0 to 5 do
    begin
        A := I * Pi / 3;
        oKit.oBox(FWheel, 0.31 * Cos(A), 0, 0.31 * Sin(A), 0.07, 0.28, 0.07, hsGhost);
    end;

    if HasSideButtons then
    begin
        FBtnX1 := oKit.oRBox(FTilt, -BW / 2 - 0.04, BL * 0.02, -0.12, 0.14, 0.55, 0.26,
            hsNormal, axX, 0, 16);
        FBtnX2 := oKit.oRBox(FTilt, -BW / 2 - 0.04, -BL * 0.14, -0.12, 0.14, 0.55, 0.26,
            hsNormal, axX, 0, 16);
        FDpi := oKit.oRBox(FTilt, 0, -BL * 0.06, -0.72, 0.28, 0.4, 0.1, hsDim, axZ, 0.1, 16);
    end;

    // radar della velocita'
    FRadarCenter := Point3D(FMatW / 2 - 1.0, FMatH / 2 - 1.0, 0.8);
    oKit.oCyl(oRoot, FRadarCenter.X, FRadarCenter.Y, FRadarCenter.Z, 1.5, 0.04, axZ, hsGhost);
    oKit.oBox(oRoot, FRadarCenter.X, FRadarCenter.Y, FRadarCenter.Z, 1.4, 0.02, 0.02, hsDim);
    oKit.oBox(oRoot, FRadarCenter.X, FRadarCenter.Y, FRadarCenter.Z, 0.02, 1.4, 0.02, hsDim);
    FRadarDot := oKit.oBall(oRoot, FRadarCenter.X, FRadarCenter.Y, FRadarCenter.Z - 0.05,
        0.22, 0.22, 0.22, hsSolid);

    SetExtent(FMatW, FMatH, 2.2);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TMouseModel.SetButton
//** Parametri di ingresso: AShape: THoloLines; APressed: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Accendere/abbassare un pulsante solo quando cambia stato.
//** Data Ultima Modifica: 06/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TMouseModel.SetButton(AShape: THoloLines; APressed: Boolean);
begin
    if (AShape = nil) or (AShape.bActive = APressed) then
        Exit;
    AShape.bActive := APressed;
    if APressed then
        AShape.Position.Z := AShape.Position.Z + BTN_TRAVEL
    else
        AShape.Position.Z := AShape.Position.Z - BTN_TRAVEL;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TMouseModel.Update
//** Parametri di ingresso: S: TInputSnapshot; B: TWidgetConfig; ADeltaT: Single
//** Parametri di uscita: nessuno
//** Scopo: Aggiornare la scena con lo stato del mouse.
//** Data Ultima Modifica: 06/10/2026
//***********************************************************************************************************
//** Funzionamento:
//**  - posizione: dPosX/dPosY (-1..+1, accumulate, senza ricentraggio) mappate
//**    sull'area utile del tappetino;
//**  - inclinazione: proporzionale alla velocita' smussata;
//**  - pulsanti: corsa + colore accento; rotella: angolo accumulato e lampo
//**    ad ogni scatto (o se premuta);
//**  - radar: punto spostato secondo il vettore velocita'.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TMouseModel.Update(const S: TInputSnapshot; const B: TWidgetConfig; ADeltaT: Single);
var
    M: TMouseState;
    RX, RY: Single;
begin
    M := S.rMouse;
    RX := FMatW / 2 - BodyWidth / 2 - 0.3;
    RY := FMatH / 2 - BodyLength / 2 - 0.3;
    FBody.Position.X := M.dPosX * RX;
    FBody.Position.Y := M.dPosY * RY;

    FTilt.RotationAngle.Y := dRot(-M.dVelX * 14);
    FTilt.RotationAngle.X := dRot(M.dVelY * 14);

    if M.iButtons <> FLastBtn then
    begin
        FLastBtn := M.iButtons;
        SetButton(FBtnL, M.bPressed(MBTN_LEFT));
        SetButton(FBtnR, M.bPressed(MBTN_RIGHT));
        SetButton(FBtnX1, M.bPressed(MBTN_X1));
        SetButton(FBtnX2, M.bPressed(MBTN_X2));
    end;

    FWheel.RotationAngle.Y := M.dWheelAngle;
    FWheel.bActive := M.bPressed(MBTN_MIDDLE) or (M.dWheelPulse > 0.05);

    FRadarDot.Position.X := FRadarCenter.X + M.dVelX * 0.65;
    FRadarDot.Position.Y := FRadarCenter.Y + M.dVelY * 0.65;
    FRadarDot.bActive := (Abs(M.dVelX) + Abs(M.dVelY)) > 0.15;
end;

end.
