//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Mouse.Gaming
//** Scopo: Mouse da gioco.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: 5 pulsanti (sinistro, destro, rotella, laterali X1/X2),
//** pulsante DPI e corpo ergonomico.
//***********************************************************************************************************
//***********************************************************************************************************
unit Mouse.Gaming;

interface

uses
    Holo.Config, Holo.Models, Mouse.Base;

type
    TMouseGaming = class(TMouseModel)
    protected
        function HasSideButtons: Boolean; override;
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
//** Nome funzione: TMouseGaming.ModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Mouse gaming 5 tasti" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 07/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TMouseGaming.ModelId: string;
begin
    Result := 'mouse.gaming';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TMouseGaming.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello "Mouse gaming 5 tasti" mostrato nel Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TMouseGaming.DisplayName: string;
begin
    Result := Tr('model.mouse.gaming', 'Mouse gaming 5 tasti');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TMouseGaming.HasSideButtons
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Abilitare pulsanti laterali e DPI.
//** Data Ultima Modifica: 07/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TMouseGaming.HasSideButtons: Boolean;
begin
    Result := True;
end;

initialization
    RegisterModel(TMouseGaming);

end.
