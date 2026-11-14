//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: ThrDx.Generic
//** Scopo: Manetta (throttle) DESTRA generica: leva, mini-stick, hat e 6 pulsanti.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: tutto il modello e' in MANETTE\Thr.Base (TThrottleModel);
//** questa unit gli da' identificativo e nome e lo registra per il widget
//** "Manetta destra".
//***********************************************************************************************************
//***********************************************************************************************************
unit ThrDx.Generic;

interface

uses
    Holo.Config, Holo.Models, Thr.Base;

type
    TThrDxGeneric = class(TThrottleModel)
    public
        class function sModelId: string; override;
        class function sDisplayName: string; override;
    end;

implementation

uses
    Holo.Lang;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TThrDxGeneric.sModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Manetta generica" destra (chiave salvata nel file .ini).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TThrDxGeneric.sModelId: string;
begin
    Result := 'thrdx.generic';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TThrDxGeneric.sDisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello mostrato nel Setup.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TThrDxGeneric.sDisplayName: string;
begin
    Result := sTr('model.thrdx.generic', 'Manetta generica (leva, mini-stick, hat, 6 pulsanti)');
end;

initialization
    RegisterModel(TThrDxGeneric);

end.
