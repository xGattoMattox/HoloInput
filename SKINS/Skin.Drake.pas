//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Skin.Drake
//** Scopo: Skin "Drake Interplanetary".
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: ambra industriale con avvisi rossi su metallo scuro.
//** Colori: primario FFF2A007, accento FFFF4122, pannello FF17140F.
//***********************************************************************************************************
//***********************************************************************************************************
unit Skin.Drake;

interface

implementation

uses
    System.UITypes, Holo.Skins, Holo.Lang;

type
    TSkinDrake = class(TSkin)
    public
        class function Id: string; override;
        class function DisplayName: string; override;
        class function Colors: TSkinColors; override;
    end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinDrake.Id
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo della skin "Drake Interplanetary" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 11/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinDrake.Id: string;
begin
    Result := 'drake';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinDrake.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome della skin "Drake Interplanetary" mostrato nel menu del Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinDrake.DisplayName: string;
begin
    Result := Tr('skin.drake', 'Drake Interplanetary');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinDrake.Colors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TSkinColors
//** Scopo: Palette della skin (derivata da primario, accento e pannello).
//** Data Ultima Modifica: 11/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinDrake.Colors: TSkinColors;
begin
    Result := MakeSkinColors(TAlphaColor($FFF2A007), TAlphaColor($FFFF4122), TAlphaColor($FF17140F));
end;

initialization
    RegisterSkin(TSkinDrake);

end.
