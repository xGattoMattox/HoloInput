//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Skin.Tumbril
//** Scopo: Skin "Tumbril Land Systems".
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: sabbia desertica con accento azzurro.
//** Colori: primario FFD2AE72, accento FF4FC3F7, pannello FF15120D.
//***********************************************************************************************************
//***********************************************************************************************************
unit Skin.Tumbril;

interface

implementation

uses
    System.UITypes, Holo.Skins, Holo.Lang;

type
    TSkinTumbril = class(TSkin)
    public
        class function Id: string; override;
        class function DisplayName: string; override;
        class function Colors: TSkinColors; override;
    end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinTumbril.Id
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo della skin "Tumbril Land Systems" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 12/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinTumbril.Id: string;
begin
    Result := 'tumbril';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinTumbril.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome della skin "Tumbril Land Systems" mostrato nel menu del Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinTumbril.DisplayName: string;
begin
    Result := Tr('skin.tumbril', 'Tumbril Land Systems');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinTumbril.Colors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TSkinColors
//** Scopo: Palette della skin (derivata da primario, accento e pannello).
//** Data Ultima Modifica: 12/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinTumbril.Colors: TSkinColors;
begin
    Result := MakeSkinColors(TAlphaColor($FFD2AE72), TAlphaColor($FF4FC3F7), TAlphaColor($FF15120D));
end;

initialization
    RegisterSkin(TSkinTumbril);

end.
