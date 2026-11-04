//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: BtnDx.Grid16
//** Scopo: Pulsantiera destra a griglia 4 x 4 (16 pulsanti quadrati, tipo stream deck / button box DIY).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: pulsanti relativi 1..16 (riga per riga, dall'alto).
//***********************************************************************************************************
//***********************************************************************************************************
unit BtnDx.Grid16;

interface

uses
    System.SysUtils, Holo.Config, Holo.Prims, Holo.Models, BtnDx.Base;

type
    TBtnDxGrid16 = class(TButtonBoxModel)
    protected
        procedure BuildPanel; override;
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
//** Nome funzione: TBtnDxGrid16.ModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Griglia 4x4 (16 pulsanti)" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 08/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TBtnDxGrid16.ModelId: string;
begin
    Result := 'btndx.grid16';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TBtnDxGrid16.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello "Griglia 4x4 (16 pulsanti)" mostrato nel Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TBtnDxGrid16.DisplayName: string;
begin
    Result := Tr('model.btndx.grid16', 'Griglia 4x4 (16 pulsanti)');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TBtnDxGrid16.BuildPanel
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Piastra con cornice e griglia di 16 pulsanti.
//** Data Ultima Modifica: 08/10/2026
//***********************************************************************************************************
//** Funzionamento: le colonne sono specchiate con MX nelle versioni SX, cosi'
//** il pulsante 1 resta sempre dal lato esterno superiore.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TBtnDxGrid16.BuildPanel;
const
    STEP = 1.4;
var
    R, C: Integer;
begin
    Kit.RBox(Root, 0, 0.1, PANEL_Z, 6.2, 6.5, 0.4, hsDim, axZ, 0.03, 40, 6);
    Kit.Box(Root, 0, 0.1, FACE_Z - 0.01, 5.9, 6.2, 0.02, hsGhost);
    for R := 0 to 3 do
        for C := 0 to 3 do
            AddPush(MX((C - 1.5) * STEP), (R - 1.5) * STEP - 0.1, 0.95, R * 4 + C,
                IntToStr(R * 4 + C + 1));
    SetExtent(6.2, 6.5, 1.2);
end;

initialization
    RegisterModel(TBtnDxGrid16);

end.
