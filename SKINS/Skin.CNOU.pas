//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Skin.CNOU
//** Scopo: Skin "Consolidated Outland".
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: rosso acceso con accento bianco.
//** Colori: primario FFE8493B, accento FFF2F2F2, pannello FF140C0C.
//***********************************************************************************************************
//***********************************************************************************************************
unit Skin.CNOU;

interface

implementation

uses
    System.UITypes, Holo.Skins, Holo.Lang;

type
    TSkinCNOU = class(TSkin)
    public
        class function Id: string; override;
        class function DisplayName: string; override;
        class function Colors: TSkinColors; override;
    end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinCNOU.Id
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo della skin "Consolidated Outland" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 12/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinCNOU.Id: string;
begin
    Result := 'cnou';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinCNOU.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome della skin "Consolidated Outland" mostrato nel menu del Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinCNOU.DisplayName: string;
begin
    Result := Tr('skin.cnou', 'Consolidated Outland');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinCNOU.Colors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TSkinColors
//** Scopo: Palette della skin (derivata da primario, accento e pannello).
//** Data Ultima Modifica: 12/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinCNOU.Colors: TSkinColors;
begin
    Result := MakeSkinColors(TAlphaColor($FFE8493B), TAlphaColor($FFF2F2F2), TAlphaColor($FF140C0C));
end;

initialization
    RegisterSkin(TSkinCNOU);

end.
