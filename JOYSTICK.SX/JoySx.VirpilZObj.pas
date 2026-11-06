//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: JoySx.VirpilZObj
//** Scopo: Joystick SINISTRO Virpil Constellation Alpha Prime su base WarBRD con la prolunga asse Z
//**        (Flightstick Z-Extension), modello 3D reale.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: la prolunga (zaxis_holo.obj) si innesta sulla torretta della base e si muove
//** con il gimbal; l'impugnatura sinistra (vpap_l_holo.obj) e' montata
//** sul collare superiore della prolunga, con il proprio asse allineato all'asse
//** di quel collare (punto e asse in OBJ\zaxis_holo.ini).
//** Vedi JOYSTICK.DX\JoyDx.ObjBase.
//***********************************************************************************************************
//***********************************************************************************************************
unit JoySx.VirpilZObj;

interface

uses
    Holo.Config, Holo.Models, JoyDx.ObjBase;

type
    TJoySxVirpilZObj = class(TObjStickModel)
    protected
        class function Spec: TObjStickSpec; override;
    public
        class function ModelId: string; override;
        class function DisplayName: string; override;
        class function DefaultAxes: string; override;
    end;

implementation

uses
    Holo.Lang;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TJoySxVirpilZObj.ModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Virpil Alpha Prime + WarBRD + prolunga asse Z (3D) (SX)"
//**        (chiave salvata nel file .ini).
//** Data Ultima Modifica: 26/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TJoySxVirpilZObj.ModelId: string;
begin
    Result := 'joysx.virpilzobj';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TJoySxVirpilZObj.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello "Virpil Alpha Prime + WarBRD + prolunga asse Z (3D) (SX)" mostrato nel
//**        Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TJoySxVirpilZObj.DisplayName: string;
begin
    Result := Tr('model.joysx.virpilzobj', 'Virpil Alpha Prime + WarBRD + asse Z (3D) (SX)');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TJoySxVirpilZObj.Spec
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TObjStickSpec
//** Scopo: Descrivere il modello: base WarBRD, prolunga asse Z e impugnatura Alpha Prime sinistra
//**        dai file OBJ.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//** Funzionamento: parte dalla descrizione standard del joystick sinistro e
//** aggiunge la prolunga zaxis_holo; l'impugnatura e' piu' lontana dalla base,
//** quindi l'altezza complessiva nel widget resta quella predefinita e il
//** modello viene scalato per entrarci.
//***********************************************************************************************************
//***********************************************************************************************************
class function TJoySxVirpilZObj.Spec: TObjStickSpec;
begin
    Result := ObjStickSpec('warbrd_holo', 'vpap_l_holo', True);
    Result.GripLeft := True;
    Result.ExtName := 'zaxis_holo';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TJoySxVirpilZObj.DefaultAxes
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Mappatura assi proposta dal Setup quando si sceglie il modello: "0,1,2".
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: sugli stick Virpil il twist dell'impugnatura e' l'asse Z di
//** Windows (indice 2), non R: X = asse X, Y = asse Y, twist = asse Z.
//***********************************************************************************************************
//***********************************************************************************************************
class function TJoySxVirpilZObj.DefaultAxes: string;
begin
    Result := '0,1,2';
end;

initialization
    RegisterModel(TJoySxVirpilZObj);

end.
