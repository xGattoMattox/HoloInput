//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Kbd.TklAnsi
//** Scopo: Tastiera tenkeyless (87 tasti, senza tastierino numerico), layout ANSI.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
unit Kbd.TklAnsi;

interface

uses
    Holo.Config, Holo.Models, Kbd.Base;

type
    TKbdTklAnsi = class(TKeyboardModel)
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
//** Nome funzione: TKbdTklAnsi.ModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Tastiera TKL ANSI" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 05/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TKbdTklAnsi.ModelId: string;
begin
    Result := 'kbd.tklansi';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TKbdTklAnsi.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello "Tastiera TKL ANSI" mostrato nel Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TKbdTklAnsi.DisplayName: string;
begin
    Result := Tr('model.kbd.tklansi', 'Tastiera TKL ANSI');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKbdTklAnsi.Layout
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Descrivere il layout.
//** Data Ultima Modifica: 05/10/2026
//***********************************************************************************************************
//** Funzionamento: come la 100% ANSI ma senza il tastierino numerico.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKbdTklAnsi.Layout;
begin
    FunctionRow;
    AnsiMainBlock;
    NavCluster(15.25);
    ArrowCluster(15.25);
end;

initialization
    RegisterModel(TKbdTklAnsi);

end.
