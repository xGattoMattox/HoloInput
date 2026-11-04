//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Kbd.Iso100
//** Scopo: Tastiera completa 105 tasti, layout ISO con legende italiane.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: invio a "L" e tasto < accanto allo Shift sinistro.
//***********************************************************************************************************
//***********************************************************************************************************
unit Kbd.Iso100;

interface

uses
    Holo.Config, Holo.Models, Kbd.Base;

type
    TKbdIso100 = class(TKeyboardModel)
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
//** Nome funzione: TKbdIso100.ModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Tastiera 100% ISO (IT)" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 05/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TKbdIso100.ModelId: string;
begin
    Result := 'kbd.iso100';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TKbdIso100.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello "Tastiera 100% ISO (IT)" mostrato nel Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TKbdIso100.DisplayName: string;
begin
    Result := Tr('model.kbd.iso100', 'Tastiera 100% ISO (IT)');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKbdIso100.Layout
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Descrivere il layout.
//** Data Ultima Modifica: 05/10/2026
//***********************************************************************************************************
//** Funzionamento: riga funzione + blocco alfanumerico ISO + navigazione e frecce a 15.25 u + tastierino a
//** 18.5 u.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKbdIso100.Layout;
begin
    FunctionRow;
    IsoItMainBlock;
    NavCluster(15.25);
    ArrowCluster(15.25);
    Numpad(18.5);
end;

initialization
    RegisterModel(TKbdIso100);

end.
