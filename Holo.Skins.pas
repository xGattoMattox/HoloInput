//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Skins
//** Scopo: Registro delle skin colore dell'applicazione.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//** Funzionamento: ogni skin e' una piccola unit nella cartella SKINS che dichiara una classe
//** discendente da TSkin e la registra nella sezione "initialization".
//** Il resto dell'applicazione chiede i colori solo tramite questo registro,
//** quindi per aggiungere una skin basta aggiungere la unit al progetto.
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.Skins;

interface

uses
    System.SysUtils, System.UITypes, System.Math, System.Generics.Collections;

type
    /// Palette usata da widget, pulsanti e modelli 3D.
    TSkinColors = record
        iPrimary: TAlphaColor;      // linee olografiche e superfici normali
        iAccent: TAlphaColor;       // evidenziazione degli input attivi
        iDim: TAlphaColor;          // parti secondarie (basi, piastre)
        iText: TAlphaColor;         // testi e legende
        iPanelBack: TAlphaColor;    // sfondo semitrasparente dei widget
        iPanelBorder: TAlphaColor;  // cornici e angoli dei widget
    end;

    /// Classe base astratta di una skin (si usano solo metodi di classe).
    TSkin = class abstract
    public
        class function sId: string; virtual; abstract;           // chiave salvata nel file .ini
        class function sDisplayName: string; virtual; abstract;  // nome mostrato nel setup
        class function rColors: TSkinColors; virtual; abstract;  // palette
    end;
    TSkinClass = class of TSkin;

function iWithAlpha(iAColor: TAlphaColor; iAAlpha: Byte): TAlphaColor;
function iMixColors(iAFrom, iATo: TAlphaColor; dAAmount: Single): TAlphaColor;
function rMakeSkinColors(iAPrimary, iAAccent, iAPanel: TAlphaColor): TSkinColors;
function rDefaultSkinColors: TSkinColors;

procedure RegisterSkin(oAClass: TSkinClass);
function iSkinCount: Integer;
function oSkinByIndex(iAIndex: Integer): TSkinClass;
function iSkinIndexOf(const sAId: string): Integer;
function oFindSkin(const sAId: string): TSkinClass;

implementation

var
    oGSkins: TList<TSkinClass> = nil;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: oSkins
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TList<TSkinClass>
//** Scopo: Restituire la lista globale delle skin.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//** Funzionamento: la crea alla prima chiamata, cosi' l'ordine di
//** inizializzazione delle unit non ha importanza.
//***********************************************************************************************************
//***********************************************************************************************************
function oSkins: TList<TSkinClass>;
begin
    if oGSkins = nil then
        oGSkins := TList<TSkinClass>.Create;
    Result := oGSkins;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: iWithAlpha
//** Parametri di ingresso: iAColor: TAlphaColor; iAAlpha: Byte
//** Parametri di uscita: Result: TAlphaColor
//** Scopo: Cambiare il canale alfa di un colore.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//** Funzionamento: sovrascrive il byte A della struttura TAlphaColorRec.
//***********************************************************************************************************
//***********************************************************************************************************
function iWithAlpha(iAColor: TAlphaColor; iAAlpha: Byte): TAlphaColor;
var
    rColorRec: TAlphaColorRec;
begin
    rColorRec.Color := iAColor;
    rColorRec.A := iAAlpha;
    Result := rColorRec.Color;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: iMixColors
//** Parametri di ingresso: iAFrom, iATo: TAlphaColor; dAAmount: Single
//** Parametri di uscita: Result: TAlphaColor
//** Scopo: Interpolare linearmente due colori (T=0 -> A, T=1 -> B).
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//** Funzionamento: interpola separatamente i quattro canali ARGB.
//***********************************************************************************************************
//***********************************************************************************************************
function iMixColors(iAFrom, iATo: TAlphaColor; dAAmount: Single): TAlphaColor;
var
    rFromRec, rToRec, rResultRec: TAlphaColorRec;
begin
    dAAmount := EnsureRange(dAAmount, 0, 1);
    rFromRec.Color := iAFrom;
    rToRec.Color := iATo;
    rResultRec.A := Round(rFromRec.A + (rToRec.A - rFromRec.A) * dAAmount);
    rResultRec.R := Round(rFromRec.R + (rToRec.R - rFromRec.R) * dAAmount);
    rResultRec.G := Round(rFromRec.G + (rToRec.G - rFromRec.G) * dAAmount);
    rResultRec.B := Round(rFromRec.B + (rToRec.B - rFromRec.B) * dAAmount);
    Result := rResultRec.Color;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: rMakeSkinColors
//** Parametri di ingresso: iAPrimary, iAAccent, iAPanel: TAlphaColor
//** Parametri di uscita: Result: TSkinColors
//** Scopo: Costruire una palette completa partendo da tre colori chiave.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//** Funzionamento: ricava i colori secondari (dim, testo, pannello)
//** mescolando il primario con il colore del pannello o con il bianco.
//***********************************************************************************************************
//***********************************************************************************************************
function rMakeSkinColors(iAPrimary, iAAccent, iAPanel: TAlphaColor): TSkinColors;
begin
    Result.iPrimary := iWithAlpha(iAPrimary, $FF);
    Result.iAccent := iWithAlpha(iAAccent, $FF);
    Result.iDim := iWithAlpha(iMixColors(iAPrimary, iAPanel, 0.55), $FF);
    Result.iText := iWithAlpha(iMixColors(iAPrimary, TAlphaColors.White, 0.55), $FF);
    Result.iPanelBack := iWithAlpha(iAPanel, $A8);
    Result.iPanelBorder := iWithAlpha(iAPrimary, $D0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: rDefaultSkinColors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TSkinColors
//** Scopo: Palette di riserva se nessuna skin e' registrata/trovata.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//** Funzionamento: usa la prima skin registrata, altrimenti un ciano/arancio.
//***********************************************************************************************************
//***********************************************************************************************************
function rDefaultSkinColors: TSkinColors;
begin
    if iSkinCount > 0 then
        Result := oSkinByIndex(0).rColors
    else
        Result := rMakeSkinColors($FF2BC4F0, $FFFF9A1F, $FF07121C);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: RegisterSkin
//** Parametri di ingresso: oAClass: TSkinClass
//** Parametri di uscita: nessuno
//** Scopo: Aggiungere una skin al registro (chiamata dalle unit in SKINS).
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//** Funzionamento: evita duplicati e mantiene l'ordine di registrazione.
//***********************************************************************************************************
//***********************************************************************************************************
procedure RegisterSkin(oAClass: TSkinClass);
begin
    if (oAClass <> nil) and (oSkins.IndexOf(oAClass) < 0) then
        oSkins.Add(oAClass);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: iSkinCount
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Integer
//** Scopo: Numero di skin disponibili.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function iSkinCount: Integer;
begin
    Result := oSkins.Count;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: oSkinByIndex
//** Parametri di ingresso: iAIndex: Integer
//** Parametri di uscita: Result: TSkinClass
//** Scopo: Skin per indice (ordine di registrazione), nil se fuori range.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function oSkinByIndex(iAIndex: Integer): TSkinClass;
begin
    if (iAIndex >= 0) and (iAIndex < oSkins.Count) then
        Result := oSkins[iAIndex]
    else
        Result := nil;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: iSkinIndexOf
//** Parametri di ingresso: sAId: string
//** Parametri di uscita: Result: Integer
//** Scopo: Posizione di una skin dato il suo Id (case-insensitive), -1 se assente.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function iSkinIndexOf(const sAId: string): Integer;
var
    iSkin: Integer;
begin
    for iSkin := 0 to oSkins.Count - 1 do
        if SameText(oSkins[iSkin].sId, sAId) then
            Exit(iSkin);
    Result := -1;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: oFindSkin
//** Parametri di ingresso: sAId: string
//** Parametri di uscita: Result: TSkinClass
//** Scopo: Cercare una skin per Id.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//** Funzionamento: se non esiste restituisce la prima registrata (o nil).
//***********************************************************************************************************
//***********************************************************************************************************
function oFindSkin(const sAId: string): TSkinClass;
var
    iSkinIndex: Integer;
begin
    iSkinIndex := iSkinIndexOf(sAId);
    if iSkinIndex < 0 then
        iSkinIndex := 0;
    Result := oSkinByIndex(iSkinIndex);
end;

initialization

finalization
    FreeAndNil(oGSkins);

end.
