//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: BtnSx.Panel
//** Scopo: Versione SINISTRA della pulsantiera "Pannello levette + encoder".
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: eredita da PULSANTI.DX\BtnDx.Panel e specchia la disposizione dei controlli
//** (Mirrored = True); il widget e' "Pulsantiera sinistra".
//***********************************************************************************************************
//***********************************************************************************************************
unit BtnSx.Panel;

interface

uses
    Holo.Config, Holo.Models, BtnDx.Panel;

type
    TBtnSxPanel = class(TBtnDxPanel)
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
//** Nome funzione: TBtnSxPanel.ModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Pannello levette + encoder (SX)" (chiave salvata nel file
//**        .ini).
//** Data Ultima Modifica: 09/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TBtnSxPanel.ModelId: string;
begin
    Result := 'btnsx.panel';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TBtnSxPanel.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello "Pannello levette + encoder (SX)" mostrato nel Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TBtnSxPanel.DisplayName: string;
begin
    Result := Tr('model.btnsx.panel', 'Pannello levette + encoder (SX)');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TBtnSxPanel.Mirrored
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Attivare la disposizione specchiata e la tipologia "pulsantiera sinistra".
//** Data Ultima Modifica: 09/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TBtnSxPanel.Mirrored: Boolean;
begin
    Result := True;
end;

initialization
    RegisterModel(TBtnSxPanel);

end.
