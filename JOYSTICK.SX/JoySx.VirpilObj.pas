//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: JoySx.VirpilObj
//** Scopo: Joystick SINISTRO Virpil Constellation Alpha Prime su base WarBRD, modello 3D reale.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: la base e' quella del destro specchiata, l'impugnatura e' il
//** modello sinistro dedicato (vpap_l_holo.obj). Vedi JOYSTICK.DX\JoyDx.ObjBase.
//***********************************************************************************************************
//***********************************************************************************************************
unit JoySx.VirpilObj;

interface

uses
    Holo.Config, Holo.Models, JoyDx.ObjBase;

type
    TJoySxVirpilObj = class(TObjStickModel)
    protected
        class function Spec: TObjStickSpec; override;
    public
        class function ModelId: string; override;
        class function DisplayName: string; override;
    end;

implementation

uses
    Holo.Lang;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TJoySxVirpilObj.ModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Virpil Alpha Prime + WarBRD (3D) (SX)" (chiave salvata nel
//**        file .ini).
//** Data Ultima Modifica: 18/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TJoySxVirpilObj.ModelId: string;
begin
    Result := 'joysx.virpilobj';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TJoySxVirpilObj.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello "Virpil Alpha Prime + WarBRD (3D) (SX)" mostrato nel Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TJoySxVirpilObj.DisplayName: string;
begin
    Result := Tr('model.joysx.virpilobj', 'Virpil Alpha Prime + WarBRD (3D) (SX)');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TJoySxVirpilObj.Spec
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TObjStickSpec
//** Scopo: Descrivere il modello: base WarBRD (specchiata) e impugnatura Alpha Prime sinistra
//**        dai file OBJ.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TJoySxVirpilObj.Spec: TObjStickSpec;
begin
    Result := ObjStickSpec('warbrd_holo', 'vpap_l_holo', True);
    Result.GripLeft := True;
end;

initialization
    RegisterModel(TJoySxVirpilObj);

end.
