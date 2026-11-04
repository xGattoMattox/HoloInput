//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Pad.XboxObj
//** Scopo: Controller Xbox, modello 3D reale (generato da foto con TRELLIS e preparato con
//**        TOOLS\holo_prep.py --align pad --pivot center).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: file: OBJ\xbox_holo.obj (corpo) e OBJ\xbox_holo.ini (posizione dei comandi).
//** Vedi GAMEPAD\Pad.ObjBase.
//***********************************************************************************************************
//***********************************************************************************************************
unit Pad.XboxObj;

interface

uses
    Holo.Config, Holo.Models, Pad.ObjBase;

type
    TPadXboxObj = class(TObjPadModel)
    protected
        class function Spec: TObjPadSpec; override;
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
//** Nome funzione: TPadXboxObj.ModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Xbox (3D)" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 21/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TPadXboxObj.ModelId: string;
begin
    Result := 'pad.xboxobj';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TPadXboxObj.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello "Xbox (3D)" mostrato nel Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TPadXboxObj.DisplayName: string;
begin
    Result := Tr('model.pad.xboxobj', 'Xbox (3D)');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TPadXboxObj.Spec
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TObjPadSpec
//** Scopo: Descrivere il modello: file OBJ del controller Xbox, larghezza ed etichette dei pulsanti
//**        frontali.
//** Data Ultima Modifica: 21/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TPadXboxObj.Spec: TObjPadSpec;
begin
    Result.ObjName := 'xbox_holo';
    Result.Width := 8.0;
    Result.FaceLabels[0] := 'A';
    Result.FaceLabels[1] := 'B';
    Result.FaceLabels[2] := 'X';
    Result.FaceLabels[3] := 'Y';
end;

initialization
    RegisterModel(TPadXboxObj);

end.
