//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: BtnDx.Base
//** Scopo: Base comune delle pulsantiere (button box) destre e sinistre.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: la pulsantiera e' letta come joystick WinMM: ogni controllo e' associato a
//** un indice pulsante RELATIVO; l'indice reale e' "Primo pulsante" (setup) +
//** indice relativo, cosi' due pulsantiere possono condividere lo stesso
//** dispositivo fisico (es. pulsanti 1..16 a destra e 17..32 a sinistra).
//**
//** Controlli disponibili:
//**   - pulsante (quadrato o tondo): si abbassa e si accende;
//**   - interruttore a levetta: ON = levetta in alto e accesa (il pulsante
//**     rimane premuto finche' l'interruttore e' su ON, come su quasi tutte
//**     le pulsantiere);
//**   - encoder rotativo: due indici (orario/antiorario); ad ogni impulso la
//**     manopola ruota di uno scatto e lampeggia.
//** Geometria: pannello nel piano XY, controlli verso -Z, inclinato dal widget.
//***********************************************************************************************************
//***********************************************************************************************************
unit BtnDx.Base;

interface

uses
    System.SysUtils, System.Math, System.Math.Vectors, System.Generics.Collections,
    FMX.Types, FMX.Controls3D, FMX.Objects3D,
    Holo.Config, Holo.Input, Holo.Prims, Holo.Models;

type
    TBoxItemKind = (biPush, biToggle, biEncoder);

    TBoxItem = class
    public
        Kind: TBoxItemKind;
        Shape: THoloLines;     // forma o loft arrotondato
        Pivot: TDummy;
        Index, Index2: Integer;
        Base: TPoint3D;
        Pressed, Pressed2: Boolean;
        Angle: Single;
    end;

    TButtonBoxModel = class(TDeviceModel)
    private
        FItems: TObjectList<TBoxItem>;
    protected
        const
            PANEL_Z = 0.35;      // centro della piastra
            FACE_Z = 0.15;       // superficie su cui poggiano i controlli
    protected
        /// Il discendente crea qui piastra e controlli.
        procedure BuildPanel; virtual; abstract;
        procedure Build; override;
        procedure AddPush(X, Y, ASize: Single; AIndex: Integer; const ALegend: string;
            ARound: Boolean = False);
        procedure AddToggle(X, Y: Single; AIndex: Integer; const ALegend: string);
        procedure AddEncoder(X, Y: Single; AIndexCW, AIndexCCW: Integer; const ALegend: string);
    public
        destructor Destroy; override;
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
    PUSH_TRAVEL = 0.12;
    TOGGLE_THROW = 0.2;
    ENCODER_STEP = 30;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TButtonBoxModel.Destroy
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Liberare la lista dei controlli della pulsantiera.
//** Data Ultima Modifica: 07/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
destructor TButtonBoxModel.Destroy;
begin
    FItems.Free;
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TButtonBoxModel.Kind
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TDeviceKind
//** Scopo: Tipologia (destra o sinistra se specchiata).
//** Data Ultima Modifica: 07/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TButtonBoxModel.Kind: TDeviceKind;
begin
    if Mirrored then
        Result := dkBoxLeft
    else
        Result := dkBoxRight;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TButtonBoxModel.DefaultView
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TModelView
//** Scopo: Vista di default, pannello inclinato e leggermente ruotato verso il centro.
//** Data Ultima Modifica: 07/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TButtonBoxModel.DefaultView: TModelView;
begin
    if Mirrored then
        Result := MakeView(-40, -10)
    else
        Result := MakeView(-40, 10);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TButtonBoxModel.BindDevices
//** Parametri di ingresso: AInput: TInputManager; B: TWidgetConfig
//** Parametri di uscita: nessuno
//** Scopo: Attivare la lettura del joystick (WinMM) a cui e' collegata la pulsantiera.
//** Data Ultima Modifica: 07/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TButtonBoxModel.BindDevices(AInput: TInputManager; const B: TWidgetConfig);
begin
    AInput.UseJoystick(B.DeviceIndex);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TButtonBoxModel.IsConnected
//** Parametri di ingresso: S: TInputSnapshot; B: TWidgetConfig
//** Parametri di uscita: Result: Boolean
//** Scopo: Indicare se il joystick della pulsantiera risulta collegato.
//** Data Ultima Modifica: 07/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TButtonBoxModel.IsConnected(const S: TInputSnapshot; const B: TWidgetConfig): Boolean;
begin
    Result := S.Joys[EnsureRange(B.DeviceIndex, 0, MAX_JOY - 1)].Connected;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TButtonBoxModel.DeviceLabel
//** Parametri di ingresso: B: TWidgetConfig
//** Parametri di uscita: Result: string
//** Scopo: Etichetta del dispositivo mostrata nel widget (ID joystick e primo pulsante usato).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TButtonBoxModel.DeviceLabel(const B: TWidgetConfig): string;
begin
    Result := Format(Tr('widget.label.buttonbox', 'JOY ID %d  P%d+'), [B.DeviceIndex, B.ButtonOffset + 1]);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TButtonBoxModel.Build
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Preparare la lista dei controlli e far costruire il pannello.
//** Data Ultima Modifica: 08/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TButtonBoxModel.Build;
begin
    FItems := TObjectList<TBoxItem>.Create(True);
    BuildPanel;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TButtonBoxModel.AddPush
//** Parametri di ingresso: X, Y, ASize: Single; AIndex: Integer; ALegend: string; ARound: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Aggiungere un pulsante (quadrato o tondo) con legenda sotto.
//** Data Ultima Modifica: 08/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TButtonBoxModel.AddPush(X, Y, ASize: Single; AIndex: Integer;
    const ALegend: string; ARound: Boolean);
var
    It: TBoxItem;
begin
    It := TBoxItem.Create;
    It.Kind := biPush;
    It.Index := AIndex;
    if ARound then
        It.Shape := Kit.Cyl(Root, X, Y, FACE_Z - 0.2, ASize, 0.36, axZ)
    else
        It.Shape := Kit.RBox(Root, X, Y, FACE_Z - 0.18, ASize, ASize, 0.36, hsNormal, axZ, 0.14, 24);
    It.Base := It.Shape.Position.Point;
    Kit.Text(Root, X, Y + ASize / 2 + 0.2, FACE_Z - 0.02, 0.2, ALegend);
    FItems.Add(It);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TButtonBoxModel.AddToggle
//** Parametri di ingresso: X, Y: Single; AIndex: Integer; ALegend: string
//** Parametri di uscita: nessuno
//** Scopo: Aggiungere un interruttore a levetta con collare e legenda.
//** Data Ultima Modifica: 08/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TButtonBoxModel.AddToggle(X, Y: Single; AIndex: Integer; const ALegend: string);
var
    It: TBoxItem;
begin
    Kit.Cyl(Root, X, Y, FACE_Z - 0.06, 0.5, 0.12, axZ, hsDim);
    Kit.RBox(Root, X, Y, FACE_Z - 0.03, 0.24, 0.6, 0.06, hsGhost, axZ, 0, 16);   // guida
    It := TBoxItem.Create;
    It.Kind := biToggle;
    It.Index := AIndex;
    // levetta conica (loft lungo Z) con pomello sferico in punta
    It.Shape := Kit.Loft(Root, X, Y + TOGGLE_THROW, FACE_Z - 0.45, [
        Sec(0.35, 0, 0, 0.10, 0.10),
        Sec(-0.30, 0, 0, 0.065, 0.065),
        Sec(-0.36, 0, 0, 0.05, 0.05)], hsNormal, 16, 4, axZ);
    Kit.Ball(It.Shape, 0, 0, -0.42, 0.2, 0.2, 0.2, hsSolid);
    It.Base := Point3D(X, Y, FACE_Z - 0.45);
    Kit.Text(Root, X, Y + 0.55, FACE_Z - 0.02, 0.2, ALegend);
    FItems.Add(It);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TButtonBoxModel.AddEncoder
//** Parametri di ingresso: X, Y: Single; AIndexCW, AIndexCCW: Integer; ALegend: string
//** Parametri di uscita: nessuno
//** Scopo: Aggiungere un encoder rotativo (manopola con tacca) e legenda.
//** Data Ultima Modifica: 08/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TButtonBoxModel.AddEncoder(X, Y: Single; AIndexCW, AIndexCCW: Integer;
    const ALegend: string);
var
    It: TBoxItem;
    I: Integer;
begin
    Kit.Cyl(Root, X, Y, FACE_Z - 0.04, 1.1, 0.08, axZ, hsDim);
    It := TBoxItem.Create;
    It.Kind := biEncoder;
    It.Index := AIndexCW;
    It.Index2 := AIndexCCW;
    It.Pivot := Kit.Pivot(Root, X, Y, FACE_Z - 0.3);
    It.Shape := Kit.Cyl(It.Pivot, 0, 0, 0, 0.8, 0.5, axZ, hsSolid);
    Kit.Box(It.Pivot, 0, -0.3, -0.27, 0.08, 0.22, 0.04, hsGhost);    // tacca
    for I := 0 to 15 do                                                // zigrinatura
        Kit.Box(It.Pivot, 0.41 * Cos(I * Pi / 8), 0.41 * Sin(I * Pi / 8), 0, 0.04, 0.04, 0.46, hsGhost);
    Kit.Text(Root, X, Y + 0.75, FACE_Z - 0.02, 0.2, ALegend);
    FItems.Add(It);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TButtonBoxModel.Update
//** Parametri di ingresso: S: TInputSnapshot; B: TWidgetConfig; ADeltaT: Single
//** Parametri di uscita: nessuno
//** Scopo: Aggiornare i controlli con lo stato del joystick associato.
//** Data Ultima Modifica: 08/10/2026
//***********************************************************************************************************
//** Funzionamento: legge i pulsanti a partire da ButtonOffset; aggiorna la
//** grafica solo quando lo stato cambia; per gli encoder ruota la manopola
//** sul fronte di salita di ciascun impulso.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TButtonBoxModel.Update(const S: TInputSnapshot; const B: TWidgetConfig; ADeltaT: Single);
var
    J: TJoyState;
    It: TBoxItem;
    P, P2: Boolean;
begin
    J := S.Joys[EnsureRange(B.DeviceIndex, 0, MAX_JOY - 1)];
    for It in FItems do
    begin
        P := J.Button(B.ButtonOffset + It.Index);
        case It.Kind of
            biPush:
                if P <> It.Pressed then
                begin
                    It.Pressed := P;
                    It.Shape.Active := P;
                    if P then
                        It.Shape.Position.Z := It.Base.Z + PUSH_TRAVEL
                    else
                        It.Shape.Position.Z := It.Base.Z;
                end;
            biToggle:
                if P <> It.Pressed then
                begin
                    It.Pressed := P;
                    It.Shape.Active := P;
                    if P then
                        It.Shape.Position.Y := It.Base.Y - TOGGLE_THROW
                    else
                        It.Shape.Position.Y := It.Base.Y + TOGGLE_THROW;
                end;
            biEncoder:
                begin
                    P2 := J.Button(B.ButtonOffset + It.Index2);
                    if P and not It.Pressed then
                        It.Angle := It.Angle + ENCODER_STEP;
                    if P2 and not It.Pressed2 then
                        It.Angle := It.Angle - ENCODER_STEP;
                    if (P <> It.Pressed) or (P2 <> It.Pressed2) then
                    begin
                        It.Pressed := P;
                        It.Pressed2 := P2;
                        It.Pivot.RotationAngle.Z := Rot(It.Angle);
                        It.Shape.Active := P or P2;
                    end;
                end;
        end;
    end;
end;

end.
