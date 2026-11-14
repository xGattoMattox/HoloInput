//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Skin.Argo
//** Scopo: Skin "ARGO Astronautics".
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: giallo da cantiere con accento arancio.
//** Colori: primario FFFFC400, accento FFFF6A00, pannello FF121212.
//***********************************************************************************************************
//***********************************************************************************************************
unit Skin.Argo;

interface

implementation

uses
    System.UITypes, Holo.Skins, Holo.Lang;

type
    TSkinArgo = class(TSkin)
    public
        class function sId: string; override;
        class function sDisplayName: string; override;
        class function rColors: TSkinColors; override;
    end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinArgo.Id
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo della skin "ARGO Astronautics" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 12/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinArgo.sId: string;
begin
    Result := 'argo';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinArgo.sDisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome della skin "ARGO Astronautics" mostrato nel menu del Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinArgo.sDisplayName: string;
begin
    Result := sTr('skin.argo', 'ARGO Astronautics');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinArgo.Colors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TSkinColors
//** Scopo: Palette della skin (derivata da primario, accento e pannello).
//** Data Ultima Modifica: 12/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinArgo.rColors: TSkinColors;
begin
    Result := rMakeSkinColors(TAlphaColor($FFFFC400), TAlphaColor($FFFF6A00), TAlphaColor($FF121212));
end;

initialization
    RegisterSkin(TSkinArgo);

end.
