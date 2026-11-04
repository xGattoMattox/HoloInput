//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Skin.Anvil
//** Scopo: Skin "Anvil Aerospace".
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: verde militare con accento giallo-ambra.
//** Colori: primario FF9CB65A, accento FFFFC845, pannello FF10140C.
//***********************************************************************************************************
//***********************************************************************************************************
unit Skin.Anvil;

interface

implementation

uses
    System.UITypes, Holo.Skins, Holo.Lang;

type
    TSkinAnvil = class(TSkin)
    public
        class function Id: string; override;
        class function DisplayName: string; override;
        class function Colors: TSkinColors; override;
    end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinAnvil.Id
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo della skin "Anvil Aerospace" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 10/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinAnvil.Id: string;
begin
    Result := 'anvil';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinAnvil.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome della skin "Anvil Aerospace" mostrato nel menu del Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinAnvil.DisplayName: string;
begin
    Result := Tr('skin.anvil', 'Anvil Aerospace');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinAnvil.Colors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TSkinColors
//** Scopo: Palette della skin (derivata da primario, accento e pannello).
//** Data Ultima Modifica: 11/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinAnvil.Colors: TSkinColors;
begin
    Result := MakeSkinColors(TAlphaColor($FF9CB65A), TAlphaColor($FFFFC845), TAlphaColor($FF10140C));
end;

initialization
    RegisterSkin(TSkinAnvil);

end.
