//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: BtnSx.Grid16
//** Scopo: Versione SINISTRA della pulsantiera "Griglia 4x4 (16 pulsanti)".
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: eredita da PULSANTI.DX\BtnDx.Grid16 e specchia la disposizione dei controlli
//** (Mirrored = True); il widget e' "Pulsantiera sinistra".
//***********************************************************************************************************
//***********************************************************************************************************
unit BtnSx.Grid16;

interface

uses
    Holo.Config, Holo.Models, BtnDx.Grid16;

type
    TBtnSxGrid16 = class(TBtnDxGrid16)
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
//** Nome funzione: TBtnSxGrid16.ModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Griglia 4x4 (16 pulsanti) (SX)" (chiave salvata nel file
//**        .ini).
//** Data Ultima Modifica: 09/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TBtnSxGrid16.ModelId: string;
begin
    Result := 'btnsx.grid16';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TBtnSxGrid16.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello "Griglia 4x4 (16 pulsanti) (SX)" mostrato nel Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TBtnSxGrid16.DisplayName: string;
begin
    Result := Tr('model.btnsx.grid16', 'Griglia 4x4 (16 pulsanti) (SX)');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TBtnSxGrid16.Mirrored
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Attivare la disposizione specchiata e la tipologia "pulsantiera sinistra".
//** Data Ultima Modifica: 09/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TBtnSxGrid16.Mirrored: Boolean;
begin
    Result := True;
end;

initialization
    RegisterModel(TBtnSxGrid16);

end.
