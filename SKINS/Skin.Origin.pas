//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Skin.Origin
//** Scopo: Skin "Origin Jumpworks".
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: bianco perla e oro su grafite, lusso essenziale.
//** Colori: primario FFE9E4D6, accento FFD4AF62, pannello FF15161A.
//***********************************************************************************************************
//***********************************************************************************************************
unit Skin.Origin;

interface

implementation

uses
    System.UITypes, Holo.Skins, Holo.Lang;

type
    TSkinOrigin = class(TSkin)
    public
        class function sId: string; override;
        class function sDisplayName: string; override;
        class function rColors: TSkinColors; override;
    end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinOrigin.Id
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo della skin "Origin Jumpworks" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 10/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinOrigin.sId: string;
begin
    Result := 'origin';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinOrigin.sDisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome della skin "Origin Jumpworks" mostrato nel menu del Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinOrigin.sDisplayName: string;
begin
    Result := sTr('skin.origin', 'Origin Jumpworks');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinOrigin.Colors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TSkinColors
//** Scopo: Palette della skin (derivata da primario, accento e pannello).
//** Data Ultima Modifica: 10/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinOrigin.rColors: TSkinColors;
begin
    Result := rMakeSkinColors(TAlphaColor($FFE9E4D6), TAlphaColor($FFD4AF62), TAlphaColor($FF15161A));
end;

initialization
    RegisterSkin(TSkinOrigin);

end.
