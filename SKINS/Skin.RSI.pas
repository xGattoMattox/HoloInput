//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Skin.RSI
//** Scopo: Skin "RSI - Roberts Space Industries".
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: ciano olografico con evidenziazioni arancioni, come le interfacce RSI.
//** Colori: primario FF2BC4F0, accento FFFF9A1F, pannello FF06121C.
//***********************************************************************************************************
//***********************************************************************************************************
unit Skin.RSI;

interface

implementation

uses
    System.UITypes, Holo.Skins, Holo.Lang;

type
    TSkinRSI = class(TSkin)
    public
        class function Id: string; override;
        class function DisplayName: string; override;
        class function Colors: TSkinColors; override;
    end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinRSI.Id
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo della skin "RSI - Roberts Space Industries" (chiave salvata nel file
//**        .ini).
//** Data Ultima Modifica: 09/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinRSI.Id: string;
begin
    Result := 'rsi';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinRSI.DisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome della skin "RSI - Roberts Space Industries" mostrato nel menu del Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinRSI.DisplayName: string;
begin
    Result := Tr('skin.rsi', 'RSI - Roberts Space Industries');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinRSI.Colors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TSkinColors
//** Scopo: Palette della skin (derivata da primario, accento e pannello).
//** Data Ultima Modifica: 10/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinRSI.Colors: TSkinColors;
begin
    Result := MakeSkinColors(TAlphaColor($FF2BC4F0), TAlphaColor($FFFF9A1F), TAlphaColor($FF06121C));
end;

initialization
    RegisterSkin(TSkinRSI);

end.
