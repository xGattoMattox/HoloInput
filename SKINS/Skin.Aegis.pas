//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Skin.Aegis
//** Scopo: Skin "Aegis Dynamics".
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: acciaio freddo con accento rosso.
//** Colori: primario FFB9C6D2, accento FFE3252C, pannello FF0D1015.
//***********************************************************************************************************
//***********************************************************************************************************
unit Skin.Aegis;

interface

implementation

uses
    System.UITypes, Holo.Skins, Holo.Lang;

type
    TSkinAegis = class(TSkin)
    public
        class function Id: string; override;
        class function DisplayName: string; override;
        class function Colors: TSkinColors; override;
    end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinAegis.Id
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo della skin "Aegis Dynamics" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 10/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinAegis.Id: string;
begin
    Result := 'aegis';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinAegis.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome della skin "Aegis Dynamics" mostrato nel menu del Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinAegis.DisplayName: string;
begin
    Result := Tr('skin.aegis', 'Aegis Dynamics');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinAegis.Colors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TSkinColors
//** Scopo: Palette della skin (derivata da primario, accento e pannello).
//** Data Ultima Modifica: 10/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinAegis.Colors: TSkinColors;
begin
    Result := MakeSkinColors(TAlphaColor($FFB9C6D2), TAlphaColor($FFE3252C), TAlphaColor($FF0D1015));
end;

initialization
    RegisterSkin(TSkinAegis);

end.
