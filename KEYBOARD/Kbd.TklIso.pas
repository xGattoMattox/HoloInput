//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Kbd.TklIso
//** Scopo: Tastiera tenkeyless (88 tasti, senza tastierino numerico), layout ISO italiano.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
unit Kbd.TklIso;

interface

uses
    Holo.Config, Holo.Models, Kbd.Base;

type
    TKbdTklIso = class(TKeyboardModel)
    protected
        procedure Layout; override;
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
//** Nome funzione: TKbdTklIso.ModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Tastiera TKL ISO (IT)" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 05/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TKbdTklIso.ModelId: string;
begin
    Result := 'kbd.tkliso';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TKbdTklIso.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello "Tastiera TKL ISO (IT)" mostrato nel Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TKbdTklIso.DisplayName: string;
begin
    Result := Tr('model.kbd.tkliso', 'Tastiera TKL ISO (IT)');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKbdTklIso.Layout
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Descrivere il layout.
//** Data Ultima Modifica: 05/10/2026
//***********************************************************************************************************
//** Funzionamento: come la 100% ISO ma senza il tastierino numerico.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKbdTklIso.Layout;
begin
    FunctionRow;
    IsoItMainBlock;
    NavCluster(15.25);
    ArrowCluster(15.25);
end;

initialization
    RegisterModel(TKbdTklIso);

end.
