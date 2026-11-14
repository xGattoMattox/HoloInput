//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Skin.MISC
//** Scopo: Skin "MISC - Musashi Industrial".
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: verde acqua con accento giallo.
//** Colori: primario FF3FD9A6, accento FFF4E05C, pannello FF0A1513.
//***********************************************************************************************************
//***********************************************************************************************************
unit Skin.MISC;

interface

implementation

uses
    System.UITypes, Holo.Skins, Holo.Lang;

type
    TSkinMISC = class(TSkin)
    public
        class function sId: string; override;
        class function sDisplayName: string; override;
        class function rColors: TSkinColors; override;
    end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinMISC.Id
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Identificativo della skin "MISC - Musashi Industrial" (chiave salvata nel file .ini).
//** Data Ultima Modifica: 11/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinMISC.sId: string;
begin
    Result := 'misc';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinMISC.sDisplayName
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Nome della skin "MISC - Musashi Industrial" mostrato nel menu del Setup.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinMISC.sDisplayName: string;
begin
    Result := sTr('skin.misc', 'MISC - Musashi Industrial');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TSkinMISC.Colors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TSkinColors
//** Scopo: Palette della skin (derivata da primario, accento e pannello).
//** Data Ultima Modifica: 11/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TSkinMISC.rColors: TSkinColors;
begin
    Result := rMakeSkinColors(TAlphaColor($FF3FD9A6), TAlphaColor($FFF4E05C), TAlphaColor($FF0A1513));
end;

initialization
    RegisterSkin(TSkinMISC);

end.
