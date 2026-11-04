//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Skin.Crusader
//** Scopo: Skin "Crusader Industries".
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: azzurro cielo con accento bianco.
//** Colori: primario FF7CC6FF, accento FFFFFFFF, pannello FF0A1422.
//***********************************************************************************************************
//***********************************************************************************************************
unit Skin.Crusader;

interface

implementation

uses
    System.UITypes, Holo.Skins, Holo.Lang;

type
    TSkinCrusader = class(TSkin)
    public
        class function Id: string; override;
        class function DisplayName: string; override;
        class function Colors: TSkinColors; override;
    end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinCrusader.Id
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo della skin "Crusader Industries" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 11/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinCrusader.Id: string;
begin
    Result := 'crusader';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinCrusader.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome della skin "Crusader Industries" mostrato nel menu del Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinCrusader.DisplayName: string;
begin
    Result := Tr('skin.crusader', 'Crusader Industries');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinCrusader.Colors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TSkinColors
//** Scopo: Palette della skin (derivata da primario, accento e pannello).
//** Data Ultima Modifica: 11/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinCrusader.Colors: TSkinColors;
begin
    Result := MakeSkinColors(TAlphaColor($FF7CC6FF), TAlphaColor($FFFFFFFF), TAlphaColor($FF0A1422));
end;

initialization
    RegisterSkin(TSkinCrusader);

end.
