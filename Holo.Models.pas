//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Models
//** Scopo: Classe base degli "sketch" 3D dei dispositivi e relativo registro.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: ogni unit nelle sottocartelle (MOUSE, KEYBOARD, GAMEPAD, JOYSTICK.DX, ...)
//** dichiara un discendente di TDeviceModel e lo registra con RegisterModel nella
//** sezione initialization. Il widget crea il modello scelto nel setup tramite
//** il suo ModelId (salvato nel .ini).
//**
//** Convenzioni di costruzione dei modelli:
//**   - il modello e' centrato nell'origine e rivolto verso la camera (-Z);
//**   - i dispositivi "da scrivania" (tastiera, mouse, pulsantiere) sono
//**     costruiti in VISTA DALL'ALTO nel piano XY, con l'altezza verso -Z, e poi
//**     inclinati dal widget con l'angolo DefaultView.Tilt;
//**   - i joystick sono costruiti in piedi (impugnatura verso -Y).
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.Models;

interface

uses
    System.SysUtils, System.Math, System.Math.Vectors, System.Generics.Collections,
    FMX.Types, FMX.Controls3D, FMX.Objects3D,
    Holo.Config, Holo.Input, Holo.Prims;

const
    /// Segno delle rotazioni FMX. Se nella propria versione di FireMonkey gli
    /// stick o le inclinazioni risultano ribaltati, impostare -1.
    ROT_SIGN = 1;

type
    TModelView = record
        Tilt: Single;   // rotazione attorno a X (gradi)
        Yaw: Single;    // rotazione attorno a Y (gradi)
    end;

    TDeviceModel = class abstract
    private
        FKit: THoloKit;
        FRoot: TDummy;
        FSide: Single;
        FExtent: TPoint3D;
    protected
        /// Costruisce la geometria sotto Root. Chiamata dal costruttore.
        procedure Build; virtual; abstract;
        /// Coordinata X specchiata per le versioni sinistre (SX).
        function MX(AX: Single): Single; inline;
        /// Angolo con il segno di rotazione corretto.
        function Rot(ADeg: Single): Single; inline;
        /// Dimensioni d'ingombro (usate dal widget per inquadrare il modello).
        procedure SetExtent(AW, AH, AD: Single);
        property Kit: THoloKit read FKit;
        property Root: TDummy read FRoot;
        property Side: Single read FSide;
    public
        constructor Create(AKit: THoloKit; ARoot: TDummy); virtual;
        /// Aggiorna la scena con lo stato degli input. Chiamata ad ogni frame.
        procedure Update(const S: TInputSnapshot; const B: TWidgetConfig; ADeltaT: Single); virtual; abstract;
        /// Registra presso il gestore degli input i dispositivi da interrogare.
        procedure BindDevices(AInput: TInputManager; const B: TWidgetConfig); virtual;
        /// True se il dispositivo associato risulta collegato.
        function IsConnected(const S: TInputSnapshot; const B: TWidgetConfig): Boolean; virtual;
        function DeviceLabel(const B: TWidgetConfig): string; virtual;
        /// Chiamata dal widget dopo un cambio di skin (i colori del kit sono gia'
        /// aggiornati). Serve ai modelli che hanno colori "propri", es. immagini.
        procedure SkinChanged; virtual;
        function Extent: TPoint3D;

        class function ModelId: string; virtual; abstract;      // chiave nel .ini
        class function DisplayName: string; virtual; abstract;  // nome nel setup
        class function Kind: TDeviceKind; virtual; abstract;    // tipologia di widget
        class function Mirrored: Boolean; virtual;              // True per le versioni SX
        class function DefaultView: TModelView; virtual;
        /// Mappatura assi suggerita (es. '0,2,3'); '' = nessun suggerimento.
        /// Il setup la propone quando l'utente sceglie il modello.
        class function DefaultAxes: string; virtual;
    end;
    TDeviceModelClass = class of TDeviceModel;

procedure RegisterModel(AClass: TDeviceModelClass);
function ModelsOfKind(AKind: TDeviceKind): TArray<TDeviceModelClass>;
function FindModel(AKind: TDeviceKind; const AId: string): TDeviceModelClass;

function MakeView(ATilt, AYaw: Single): TModelView;
function Approach(ACurrent, ATarget, ADeltaT, ASpeed: Single): Single;
function JoyAxisValue(const J: TJoyState; AIndex: Integer; AInvert: Boolean): Single;

implementation

uses
    Holo.Lang;

var
    GModels: TList<TDeviceModelClass> = nil;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: Models
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TList<TDeviceModelClass>
//** Scopo: Lista globale dei modelli, creata alla prima richiesta.
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function Models: TList<TDeviceModelClass>;
begin
    if GModels = nil then
        GModels := TList<TDeviceModelClass>.Create;
    Result := GModels;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: RegisterModel
//** Parametri di ingresso: AClass: TDeviceModelClass
//** Parametri di uscita: nessuno
//** Scopo: Registrare un modello (chiamata nella initialization delle unit).
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure RegisterModel(AClass: TDeviceModelClass);
begin
    if (AClass <> nil) and (Models.IndexOf(AClass) < 0) then
        Models.Add(AClass);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: ModelsOfKind
//** Parametri di ingresso: AKind: TDeviceKind
//** Parametri di uscita: Result: TArray<TDeviceModelClass>
//** Scopo: Elenco dei modelli disponibili per una tipologia (per il setup).
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function ModelsOfKind(AKind: TDeviceKind): TArray<TDeviceModelClass>;
var
    C: TDeviceModelClass;
begin
    Result := nil;
    for C in Models do
        if C.Kind = AKind then
            Result := Result + [C];
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: FindModel
//** Parametri di ingresso: AKind: TDeviceKind; AId: string
//** Parametri di uscita: Result: TDeviceModelClass
//** Scopo: Trovare un modello per tipologia e id.
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//** Funzionamento: se l'id non esiste (es. .ini vecchio) restituisce il primo
//** modello registrato per quella tipologia, oppure nil se non ce ne sono.
//***********************************************************************************************************
//***********************************************************************************************************
function FindModel(AKind: TDeviceKind; const AId: string): TDeviceModelClass;
var
    C: TDeviceModelClass;
begin
    Result := nil;
    for C in Models do
        if C.Kind = AKind then
        begin
            if SameText(C.ModelId, AId) then
                Exit(C);
            if Result = nil then
                Result := C;
        end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: MakeView
//** Parametri di ingresso: ATilt, AYaw: Single
//** Parametri di uscita: Result: TModelView
//** Scopo: Costruire un TModelView.
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function MakeView(ATilt, AYaw: Single): TModelView;
begin
    Result.Tilt := ATilt;
    Result.Yaw := AYaw;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: Approach
//** Parametri di ingresso: ACurrent, ATarget, ADeltaT, ASpeed: Single
//** Parametri di uscita: Result: Single
//** Scopo: Avvicinare un valore al bersaglio in modo esponenziale (movimento morbido indipendente
//**        dal frame rate).
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function Approach(ACurrent, ATarget, ADeltaT, ASpeed: Single): Single;
begin
    Result := ACurrent + (ATarget - ACurrent) * (1 - Exp(-ADeltaT * ASpeed));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: JoyAxisValue
//** Parametri di ingresso: J: TJoyState; AIndex: Integer; AInvert: Boolean
//** Parametri di uscita: Result: Single
//** Scopo: Leggere un asse del joystick applicando l'eventuale inversione.
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function JoyAxisValue(const J: TJoyState; AIndex: Integer; AInvert: Boolean): Single;
begin
    Result := J.Axis(AIndex);
    if AInvert then
        Result := -Result;
end;

//** TDeviceModel *******************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceModel.Create
//** Parametri di ingresso: AKit: THoloKit; ARoot: TDummy
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare il modello sotto il nodo ARoot e costruirne la geometria.
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//** Funzionamento: memorizza kit e radice, calcola il lato (1 destro, -1
//** sinistro/specchiato) e chiama il metodo virtuale Build del discendente.
//***********************************************************************************************************
//***********************************************************************************************************
constructor TDeviceModel.Create(AKit: THoloKit; ARoot: TDummy);
begin
    inherited Create;
    FKit := AKit;
    FRoot := ARoot;
    if Mirrored then
        FSide := -1
    else
        FSide := 1;
    FExtent := Point3D(4, 4, 4);
    Build;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceModel.MX
//** Parametri di ingresso: AX: Single
//** Parametri di uscita: Result: Single
//** Scopo: Specchiare una coordinata X per i modelli sinistri (moltiplica per il lato del modello).
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceModel.MX(AX: Single): Single;
begin
    Result := AX * FSide;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceModel.Rot
//** Parametri di ingresso: ADeg: Single
//** Parametri di uscita: Result: Single
//** Scopo: Convertire un angolo nel verso di rotazione usato dai modelli FMX.
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceModel.Rot(ADeg: Single): Single;
begin
    Result := ADeg * ROT_SIGN;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceModel.SetExtent
//** Parametri di ingresso: AW, AH, AD: Single
//** Parametri di uscita: nessuno
//** Scopo: Memorizzare l'ingombro del modello.
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceModel.SetExtent(AW, AH, AD: Single);
begin
    FExtent := Point3D(AW, AH, AD);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceModel.Extent
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TPoint3D
//** Scopo: Ingombro del modello (W, H, D) in unita' 3D.
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceModel.Extent: TPoint3D;
begin
    Result := FExtent;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceModel.BindDevices
//** Parametri di ingresso: AInput: TInputManager; B: TWidgetConfig
//** Parametri di uscita: nessuno
//** Scopo: Default = nessun dispositivo da interrogare (tastiera/mouse sono globali).
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceModel.BindDevices(AInput: TInputManager; const B: TWidgetConfig);
begin
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceModel.IsConnected
//** Parametri di ingresso: S: TInputSnapshot; B: TWidgetConfig
//** Parametri di uscita: Result: Boolean
//** Scopo: Default = sempre collegato (tastiera e mouse di sistema).
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceModel.IsConnected(const S: TInputSnapshot; const B: TWidgetConfig): Boolean;
begin
    Result := True;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceModel.DeviceLabel
//** Parametri di ingresso: B: TWidgetConfig
//** Parametri di uscita: Result: string
//** Scopo: Etichetta della sorgente mostrata nell'intestazione del widget.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceModel.DeviceLabel(const B: TWidgetConfig): string;
begin
    Result := Tr('widget.label.system', 'SISTEMA');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceModel.SkinChanged
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Default = nulla da fare (le forme leggono i colori dal kit).
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceModel.SkinChanged;
begin
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceModel.Mirrored
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Indicare se il modello e' la versione specchiata (sinistra); di default no.
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TDeviceModel.Mirrored: Boolean;
begin
    Result := False;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceModel.DefaultView
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TModelView
//** Scopo: Vista predefinita del modello (inclinazione e rotazione della camera).
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TDeviceModel.DefaultView: TModelView;
begin
    Result := MakeView(-45, 0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceModel.DefaultAxes
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Assi predefiniti del modello (stringa vuota = nessuna impostazione specifica).
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TDeviceModel.DefaultAxes: string;
begin
    Result := '';
end;

initialization

finalization
    FreeAndNil(GModels);

end.
