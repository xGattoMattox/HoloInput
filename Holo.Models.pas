//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Models
//** Scopo: Classe base degli "sketch" 3D dei dispositivi e relativo registro.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: ogni unit nelle sottocartelle (MOUSE, KEYBOARD, GAMEPAD, JOYSTICK.DX, MANETTE, ...)
//** dichiara un discendente di TDeviceModel e lo registra con RegisterModel nella
//** sezione initialization. Il widget crea il modello scelto nel setup tramite
//** il suo sModelId (salvato nel .ini).
//**
//** Convenzioni di costruzione dei modelli:
//**   - il modello e' centrato nell'origine e rivolto verso la camera (-Z);
//**   - i dispositivi "da scrivania" (tastiera, mouse, pulsantiere) sono
//**     costruiti in VISTA DALL'ALTO nel piano XY, con l'altezza verso -Z, e poi
//**     inclinati dal widget con l'angolo rDefaultView.Tilt;
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
        dTilt: Single;   // rotazione attorno a X (gradi)
        dYaw: Single;    // rotazione attorno a Y (gradi)
    end;

    TDeviceModel = class abstract
    private
        oFKit: THoloKit;
        oFRoot: TDummy;
        dFSide: Single;
        rFExtent: TPoint3D;
    protected
        /// Costruisce la geometria sotto Root. Chiamata dal costruttore.
        procedure Build; virtual; abstract;
        /// Coordinata X specchiata per le versioni sinistre (SX).
        function dMX(dAPosX: Single): Single; inline;
        /// Angolo con il segno di rotazione corretto.
        function dRot(dADeg: Single): Single; inline;
        /// Dimensioni d'ingombro (usate dal widget per inquadrare il modello).
        procedure SetExtent(dAWidth, dAHeight, dADepth: Single);
        property oKit: THoloKit read oFKit;
        property oRoot: TDummy read oFRoot;
        property dSide: Single read dFSide;
    public
        constructor Create(oAKit: THoloKit; oARoot: TDummy); virtual;
        /// Aggiorna la scena con lo stato degli input. Chiamata ad ogni frame.
        procedure Update(const rASnapshot: TInputSnapshot; const rAWidget: TWidgetConfig; dADeltaT: Single); virtual; abstract;
        /// Registra presso il gestore degli input i dispositivi da interrogare.
        procedure BindDevices(oAInput: TInputManager; const rAWidget: TWidgetConfig); virtual;
        /// True se il dispositivo associato risulta collegato.
        function bIsConnected(const rASnapshot: TInputSnapshot; const rAWidget: TWidgetConfig): Boolean;
            virtual;
        function sDeviceLabel(const rAWidget: TWidgetConfig): string; virtual;
        /// Chiamata dal widget dopo un cambio di skin (i colori del kit sono gia'
        /// aggiornati). Serve ai modelli che hanno colori "propri", es. immagini.
        procedure SkinChanged; virtual;
        function rExtent: TPoint3D;

        class function sModelId: string; virtual; abstract;      // chiave nel .ini
        class function sDisplayName: string; virtual; abstract;  // nome nel setup
        class function eKind: TDeviceKind; virtual; abstract;    // tipologia di widget
        class function bMirrored: Boolean; virtual;              // True per le versioni SX
        class function rDefaultView: TModelView; virtual;
        /// Mappatura assi suggerita (es. '0,2,3'); '' = nessun suggerimento.
        /// Il setup la propone quando l'utente sceglie il modello.
        class function sDefaultAxes: string; virtual;
    end;
    TDeviceModelClass = class of TDeviceModel;

procedure RegisterModel(oAClass: TDeviceModelClass);
function aModelsOfKind(eAKind: TDeviceKind): TArray<TDeviceModelClass>;
function oFindModel(eAKind: TDeviceKind; const sAId: string): TDeviceModelClass;

function rMakeView(dATilt, dAYaw: Single): TModelView;
function dApproach(dACurrent, dATarget, dADeltaT, dASpeed: Single): Single;
function dJoyAxisValue(const rAJoy: TJoyState; iAIndex: Integer; bAInvert: Boolean): Single;

implementation

uses
    Holo.Lang;

var
    oGModels: TList<TDeviceModelClass> = nil;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: oModels
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TList<TDeviceModelClass>
//** Scopo: Lista globale dei modelli, creata alla prima richiesta.
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function oModels: TList<TDeviceModelClass>;
begin
    if oGModels = nil then
        oGModels := TList<TDeviceModelClass>.Create;
    Result := oGModels;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: RegisterModel
//** Parametri di ingresso: oAClass: TDeviceModelClass
//** Parametri di uscita: nessuno
//** Scopo: Registrare un modello (chiamata nella initialization delle unit).
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure RegisterModel(oAClass: TDeviceModelClass);
begin
    if (oAClass <> nil) and (oModels.IndexOf(oAClass) < 0) then
        oModels.Add(oAClass);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: aModelsOfKind
//** Parametri di ingresso: eAKind: TDeviceKind
//** Parametri di uscita: Result: TArray<TDeviceModelClass>
//** Scopo: Elenco dei modelli disponibili per una tipologia (per il setup).
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function aModelsOfKind(eAKind: TDeviceKind): TArray<TDeviceModelClass>;
var
    oModelClass: TDeviceModelClass;
begin
    Result := nil;
    for oModelClass in oModels do
        if oModelClass.eKind = eAKind then
            Result := Result + [oModelClass];
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: oFindModel
//** Parametri di ingresso: eAKind: TDeviceKind; sAId: string
//** Parametri di uscita: Result: TDeviceModelClass
//** Scopo: Trovare un modello per tipologia e id.
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//** Funzionamento: se l'id non esiste (es. .ini vecchio) restituisce il primo
//** modello registrato per quella tipologia, oppure nil se non ce ne sono.
//***********************************************************************************************************
//***********************************************************************************************************
function oFindModel(eAKind: TDeviceKind; const sAId: string): TDeviceModelClass;
var
    oModelClass: TDeviceModelClass;
begin
    Result := nil;
    for oModelClass in oModels do
        if oModelClass.eKind = eAKind then
        begin
            if SameText(oModelClass.sModelId, sAId) then
                Exit(oModelClass);
            if Result = nil then
                Result := oModelClass;
        end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: rMakeView
//** Parametri di ingresso: dATilt, dAYaw: Single
//** Parametri di uscita: Result: TModelView
//** Scopo: Costruire un TModelView.
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function rMakeView(dATilt, dAYaw: Single): TModelView;
begin
    Result.dTilt := dATilt;
    Result.dYaw := dAYaw;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: dApproach
//** Parametri di ingresso: dACurrent, dATarget, dADeltaT, dASpeed: Single
//** Parametri di uscita: Result: Single
//** Scopo: Avvicinare un valore al bersaglio in modo esponenziale (movimento morbido indipendente
//**        dal frame rate).
//** Data Ultima Modifica: 24/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function dApproach(dACurrent, dATarget, dADeltaT, dASpeed: Single): Single;
begin
    Result := dACurrent + (dATarget - dACurrent) * (1 - Exp(-dADeltaT * dASpeed));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: dJoyAxisValue
//** Parametri di ingresso: rAJoy: TJoyState; iAIndex: Integer; bAInvert: Boolean
//** Parametri di uscita: Result: Single
//** Scopo: Leggere un asse del joystick applicando l'eventuale inversione.
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function dJoyAxisValue(const rAJoy: TJoyState; iAIndex: Integer; bAInvert: Boolean): Single;
begin
    Result := rAJoy.dAxis(iAIndex);
    if bAInvert then
        Result := -Result;
end;

//** TDeviceModel *******************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceModel.Create
//** Parametri di ingresso: oAKit: THoloKit; oARoot: TDummy
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare il modello sotto il nodo oARoot e costruirne la geometria.
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//** Funzionamento: memorizza kit e radice, calcola il lato (1 destro, -1
//** sinistro/specchiato) e chiama il metodo virtuale Build del discendente.
//***********************************************************************************************************
//***********************************************************************************************************
constructor TDeviceModel.Create(oAKit: THoloKit; oARoot: TDummy);
begin
    inherited Create;
    oFKit := oAKit;
    oFRoot := oARoot;
    if bMirrored then
        dFSide := -1
    else
        dFSide := 1;
    rFExtent := Point3D(4, 4, 4);
    Build;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceModel.dMX
//** Parametri di ingresso: dAPosX: Single
//** Parametri di uscita: Result: Single
//** Scopo: Specchiare una coordinata X per i modelli sinistri (moltiplica per il lato del modello).
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceModel.dMX(dAPosX: Single): Single;
begin
    Result := dAPosX * dFSide;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceModel.dRot
//** Parametri di ingresso: dADeg: Single
//** Parametri di uscita: Result: Single
//** Scopo: Convertire un angolo nel verso di rotazione usato dai modelli FMX.
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceModel.dRot(dADeg: Single): Single;
begin
    Result := dADeg * ROT_SIGN;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceModel.SetExtent
//** Parametri di ingresso: dAWidth, dAHeight, dADepth: Single
//** Parametri di uscita: nessuno
//** Scopo: Memorizzare l'ingombro del modello.
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceModel.SetExtent(dAWidth, dAHeight, dADepth: Single);
begin
    rFExtent := Point3D(dAWidth, dAHeight, dADepth);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceModel.rExtent
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TPoint3D
//** Scopo: Ingombro del modello (W, H, D) in unita' 3D.
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceModel.rExtent: TPoint3D;
begin
    Result := rFExtent;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDeviceModel.BindDevices
//** Parametri di ingresso: oAInput: TInputManager; rAWidget: TWidgetConfig
//** Parametri di uscita: nessuno
//** Scopo: Default = nessun dispositivo da interrogare (tastiera/mouse sono globali).
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDeviceModel.BindDevices(oAInput: TInputManager; const rAWidget: TWidgetConfig);
begin
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceModel.bIsConnected
//** Parametri di ingresso: rASnapshot: TInputSnapshot; rAWidget: TWidgetConfig
//** Parametri di uscita: Result: Boolean
//** Scopo: Default = sempre collegato (tastiera e mouse di sistema).
//** Data Ultima Modifica: 25/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceModel.bIsConnected(const rASnapshot: TInputSnapshot; const rAWidget: TWidgetConfig): Boolean;
begin
    Result := True;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceModel.sDeviceLabel
//** Parametri di ingresso: rAWidget: TWidgetConfig
//** Parametri di uscita: Result: string
//** Scopo: Etichetta della sorgente mostrata nell'intestazione del widget.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TDeviceModel.sDeviceLabel(const rAWidget: TWidgetConfig): string;
begin
    Result := sTr('widget.label.system', 'SISTEMA');
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
class function TDeviceModel.bMirrored: Boolean;
begin
    Result := False;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceModel.rDefaultView
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TModelView
//** Scopo: Vista predefinita del modello (inclinazione e rotazione della camera).
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TDeviceModel.rDefaultView: TModelView;
begin
    Result := rMakeView(-45, 0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TDeviceModel.sDefaultAxes
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Assi predefiniti del modello (stringa vuota = nessuna impostazione specifica).
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TDeviceModel.sDefaultAxes: string;
begin
    Result := '';
end;

initialization

finalization
    FreeAndNil(oGModels);

end.
