//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: ThrSx.Generic
//** Scopo: Manetta (throttle) SINISTRA generica: leva, mini-stick, hat e 6 pulsanti.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: eredita da ThrDx.Generic e specchia la disposizione di hat
//** e mini-stick (Mirrored = True); il widget e' "Manetta sinistra".
//***********************************************************************************************************
//***********************************************************************************************************
unit ThrSx.Generic;

interface

uses
    Holo.Config, Holo.Models, ThrDx.Generic;

type
    TThrSxGeneric = class(TThrDxGeneric)
    public
        class function ModelId: string; override;
        class function DisplayName: string; override;
        class function Mirrored: Boolean; override;
    end;

implementation

uses
    Holo.Lang;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TThrSxGeneric.ModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Manetta generica" sinistra (chiave salvata nel file .ini).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TThrSxGeneric.ModelId: string;
begin
    Result := 'thrsx.generic';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TThrSxGeneric.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello mostrato nel Setup.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TThrSxGeneric.DisplayName: string;
begin
    Result := Tr('model.thrsx.generic', 'Manetta generica (leva, mini-stick, hat, 6 pulsanti) (SX)');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TThrSxGeneric.Mirrored
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Versione specchiata (sinistra).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TThrSxGeneric.Mirrored: Boolean;
begin
    Result := True;
end;

initialization
    RegisterModel(TThrSxGeneric);

end.
