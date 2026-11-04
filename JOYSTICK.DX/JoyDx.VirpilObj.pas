//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: JoyDx.VirpilObj
//** Scopo: Joystick DESTRO Virpil Constellation Alpha Prime su base WarBRD, modello 3D reale (generato da
//**        foto con TRELLIS e preparato con TOOLS\holo_prep.py).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: file: OBJ\warbrd_holo.obj (base), OBJ\vpap_r_holo.obj (impugnatura),
//**       OBJ\vpap_r_holo.ini (posizione dei comandi, facoltativo).
//** L'impugnatura ruota sui tre assi reali attorno al gimbal (JoyDx.ObjBase).
//***********************************************************************************************************
//***********************************************************************************************************
unit JoyDx.VirpilObj;

interface

uses
    Holo.Config, Holo.Models, JoyDx.ObjBase;

type
    TJoyDxVirpilObj = class(TObjStickModel)
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
//** Nome funzione: TJoyDxVirpilObj.ModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Virpil Alpha Prime + WarBRD (3D)" (chiave salvata nel file
//**        .ini).
//** Data Ultima Modifica: 18/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TJoyDxVirpilObj.ModelId: string;
begin
    Result := 'joydx.virpilobj';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TJoyDxVirpilObj.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello "Virpil Alpha Prime + WarBRD (3D)" mostrato nel Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TJoyDxVirpilObj.DisplayName: string;
begin
    Result := Tr('model.joydx.virpilobj', 'Virpil Alpha Prime + WarBRD (3D)');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TJoyDxVirpilObj.Spec
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TObjStickSpec
//** Scopo: Descrivere il modello: base WarBRD e impugnatura Alpha Prime dai file OBJ, versione
//**        destra.
//** Data Ultima Modifica: 18/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TJoyDxVirpilObj.Spec: TObjStickSpec;
begin
    Result := ObjStickSpec('warbrd_holo', 'vpap_r_holo', False);
end;

initialization
    RegisterModel(TJoyDxVirpilObj);

end.
