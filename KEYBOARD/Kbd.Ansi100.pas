//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Kbd.Ansi100
//** Scopo: Tastiera completa 104 tasti, layout ANSI (US).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: invio orizzontale, Shift sinistro lungo.
//***********************************************************************************************************
//***********************************************************************************************************
unit Kbd.Ansi100;

interface

uses
    Holo.Config, Holo.Models, Kbd.Base;

type
    TKbdAnsi100 = class(TKeyboardModel)
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
//** Nome funzione: TKbdAnsi100.ModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Tastiera 100% ANSI" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 04/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TKbdAnsi100.ModelId: string;
begin
    Result := 'kbd.ansi100';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TKbdAnsi100.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello "Tastiera 100% ANSI" mostrato nel Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TKbdAnsi100.DisplayName: string;
begin
    Result := Tr('model.kbd.ansi100', 'Tastiera 100% ANSI');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKbdAnsi100.Layout
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Descrivere il layout.
//** Data Ultima Modifica: 04/10/2026
//***********************************************************************************************************
//** Funzionamento: riga funzione + blocco alfanumerico ANSI + navigazione e frecce a 15.25 u + tastierino a
//** 18.5 u.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKbdAnsi100.Layout;
begin
    FunctionRow;
    AnsiMainBlock;
    NavCluster(15.25);
    ArrowCluster(15.25);
    Numpad(18.5);
end;

initialization
    RegisterModel(TKbdAnsi100);

end.
