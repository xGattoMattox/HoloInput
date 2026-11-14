//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: BtnDx.Panel
//** Scopo: Pannello di controllo destro (stile "control panel" da simulatore).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: riga alta   : 6 interruttori a levetta        -> pulsanti relativi 1..6
//**   riga centro : 4 pulsanti tondi                 -> 7..10
//**                 2 encoder (orario/antiorario)    -> 15/16 e 17/18
//**   riga bassa  : 4 pulsanti quadrati              -> 11..14
//***********************************************************************************************************
//***********************************************************************************************************
unit BtnDx.Panel;

interface

uses
    System.SysUtils, Holo.Config, Holo.Prims, Holo.Models, BtnDx.Base;

type
    TBtnDxPanel = class(TButtonBoxModel)
    protected
        procedure BuildPanel; override;
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
//** Nome funzione: TBtnDxPanel.sModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Pannello levette + encoder" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 09/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TBtnDxPanel.sModelId: string;
begin
    Result := 'btndx.panel';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TBtnDxPanel.sDisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello "Pannello levette + encoder" mostrato nel Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TBtnDxPanel.sDisplayName: string;
begin
    Result := sTr('model.btndx.panel', 'Pannello levette + encoder');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TBtnDxPanel.BuildPanel
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Piastra, interruttori, encoder e pulsanti del pannello.
//** Data Ultima Modifica: 09/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TBtnDxPanel.BuildPanel;
var
    I: Integer;
begin
    oKit.oRBox(oRoot, 0, 0, PANEL_Z, 7.8, 5.6, 0.4, hsDim, axZ, 0.03, 40, 6);
    oKit.oBox(oRoot, 0, -0.85, FACE_Z - 0.01, 7.4, 0.03, 0.02, hsGhost);   // separatori
    oKit.oBox(oRoot, 0, 0.75, FACE_Z - 0.01, 7.4, 0.03, 0.02, hsGhost);

    for I := 0 to 5 do
        AddToggle(dMX(-2.75 + I * 1.1), -1.85, I, 'T' + IntToStr(I + 1));

    AddEncoder(dMX(-2.9), -0.05, 14, 15, 'ENC1');
    for I := 0 to 3 do
        AddPush(dMX(-1.35 + I * 0.9), -0.15, 0.62, 6 + I, 'B' + IntToStr(I + 7), True);
    AddEncoder(dMX(2.9), -0.05, 16, 17, 'ENC2');

    for I := 0 to 3 do
        AddPush(dMX(-1.65 + I * 1.1), 1.55, 0.85, 10 + I, 'B' + IntToStr(I + 11));

    SetExtent(7.8, 5.6, 1.4);
end;

initialization
    RegisterModel(TBtnDxPanel);

end.
