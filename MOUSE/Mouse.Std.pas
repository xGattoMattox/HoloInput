//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Mouse.Std
//** Scopo: Mouse standard da ufficio.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: 3 pulsanti (sinistro, destro, rotella cliccabile),
//** corpo piu' compatto e senza pulsanti laterali.
//***********************************************************************************************************
//***********************************************************************************************************
unit Mouse.Std;

interface

uses
    Holo.Config, Holo.Models, Mouse.Base;

type
    TMouseStd = class(TMouseModel)
    protected
        function HasSideButtons: Boolean; override;
        function BodyWidth: Single; override;
        function BodyLength: Single; override;
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
//** Nome funzione: TMouseStd.ModelId
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo del modello "Mouse standard 3 tasti" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 06/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TMouseStd.ModelId: string;
begin
    Result := 'mouse.std';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TMouseStd.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome del modello "Mouse standard 3 tasti" mostrato nel Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TMouseStd.DisplayName: string;
begin
    Result := Tr('model.mouse.std', 'Mouse standard 3 tasti');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TMouseStd.HasSideButtons
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Nessun pulsante laterale ne' DPI.
//** Data Ultima Modifica: 06/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TMouseStd.HasSideButtons: Boolean;
begin
    Result := False;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TMouseStd.BodyWidth
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Single
//** Scopo: Corpo leggermente piu' stretto.
//** Data Ultima Modifica: 07/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TMouseStd.BodyWidth: Single;
begin
    Result := 2.4;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TMouseStd.BodyLength
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Single
//** Scopo: Corpo leggermente piu' corto.
//** Data Ultima Modifica: 07/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TMouseStd.BodyLength: Single;
begin
    Result := 4.0;
end;

initialization
    RegisterModel(TMouseStd);

end.
