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
        Primary: TAlphaColor;      // linee olografiche e superfici normali
        Accent: TAlphaColor;       // evidenziazione degli input attivi
        Dim: TAlphaColor;          // parti secondarie (basi, piastre)
        Text: TAlphaColor;         // testi e legende
        PanelBack: TAlphaColor;    // sfondo semitrasparente dei widget
        PanelBorder: TAlphaColor;  // cornici e angoli dei widget
    end;

    /// Classe base astratta di una skin (si usano solo metodi di classe).
    TSkin = class abstract
    public
        class function Id: string; virtual; abstract;           // chiave salvata nel file .ini
        class function DisplayName: string; virtual; abstract;  // nome mostrato nel setup
        class function Colors: TSkinColors; virtual; abstract;  // palette
    end;
    TSkinClass = class of TSkin;

function WithAlpha(AColor: TAlphaColor; AAlpha: Byte): TAlphaColor;
function MixColors(A, B: TAlphaColor; T: Single): TAlphaColor;
function MakeSkinColors(APrimary, AAccent, APanel: TAlphaColor): TSkinColors;
function DefaultSkinColors: TSkinColors;

procedure RegisterSkin(AClass: TSkinClass);
function SkinCount: Integer;
function SkinByIndex(AIndex: Integer): TSkinClass;
function SkinIndexOf(const AId: string): Integer;
function FindSkin(const AId: string): TSkinClass;

implementation

var
    GSkins: TList<TSkinClass> = nil;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: Skins
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TList<TSkinClass>
//** Scopo: Restituire la lista globale delle skin.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//** Funzionamento: la crea alla prima chiamata, cosi' l'ordine di
//** inizializzazione delle unit non ha importanza.
//***********************************************************************************************************
//***********************************************************************************************************
function Skins: TList<TSkinClass>;
begin
    if GSkins = nil then
        GSkins := TList<TSkinClass>.Create;
    Result := GSkins;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: WithAlpha
//** Parametri di ingresso: AColor: TAlphaColor; AAlpha: Byte
//** Parametri di uscita: Result: TAlphaColor
//** Scopo: Cambiare il canale alfa di un colore.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//** Funzionamento: sovrascrive il byte A della struttura TAlphaColorRec.
//***********************************************************************************************************
//***********************************************************************************************************
function WithAlpha(AColor: TAlphaColor; AAlpha: Byte): TAlphaColor;
var
    R: TAlphaColorRec;
begin
    R.Color := AColor;
    R.A := AAlpha;
    Result := R.Color;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: MixColors
//** Parametri di ingresso: A, B: TAlphaColor; T: Single
//** Parametri di uscita: Result: TAlphaColor
//** Scopo: Interpolare linearmente due colori (T=0 -> A, T=1 -> B).
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//** Funzionamento: interpola separatamente i quattro canali ARGB.
//***********************************************************************************************************
//***********************************************************************************************************
function MixColors(A, B: TAlphaColor; T: Single): TAlphaColor;
var
    CA, CB, CR: TAlphaColorRec;
begin
    T := EnsureRange(T, 0, 1);
    CA.Color := A;
    CB.Color := B;
    CR.A := Round(CA.A + (CB.A - CA.A) * T);
    CR.R := Round(CA.R + (CB.R - CA.R) * T);
    CR.G := Round(CA.G + (CB.G - CA.G) * T);
    CR.B := Round(CA.B + (CB.B - CA.B) * T);
    Result := CR.Color;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: MakeSkinColors
//** Parametri di ingresso: APrimary, AAccent, APanel: TAlphaColor
//** Parametri di uscita: Result: TSkinColors
//** Scopo: Costruire una palette completa partendo da tre colori chiave.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//** Funzionamento: ricava i colori secondari (dim, testo, pannello)
//** mescolando il primario con il colore del pannello o con il bianco.
//***********************************************************************************************************
//***********************************************************************************************************
function MakeSkinColors(APrimary, AAccent, APanel: TAlphaColor): TSkinColors;
begin
    Result.Primary := WithAlpha(APrimary, $FF);
    Result.Accent := WithAlpha(AAccent, $FF);
    Result.Dim := WithAlpha(MixColors(APrimary, APanel, 0.55), $FF);
    Result.Text := WithAlpha(MixColors(APrimary, TAlphaColors.White, 0.55), $FF);
    Result.PanelBack := WithAlpha(APanel, $A8);
    Result.PanelBorder := WithAlpha(APrimary, $D0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: DefaultSkinColors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TSkinColors
//** Scopo: Palette di riserva se nessuna skin e' registrata/trovata.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//** Funzionamento: usa la prima skin registrata, altrimenti un ciano/arancio.
//***********************************************************************************************************
//***********************************************************************************************************
function DefaultSkinColors: TSkinColors;
begin
    if SkinCount > 0 then
        Result := SkinByIndex(0).Colors
    else
        Result := MakeSkinColors($FF2BC4F0, $FFFF9A1F, $FF07121C);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: RegisterSkin
//** Parametri di ingresso: AClass: TSkinClass
//** Parametri di uscita: nessuno
//** Scopo: Aggiungere una skin al registro (chiamata dalle unit in SKINS).
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//** Funzionamento: evita duplicati e mantiene l'ordine di registrazione.
//***********************************************************************************************************
//***********************************************************************************************************
procedure RegisterSkin(AClass: TSkinClass);
begin
    if (AClass <> nil) and (Skins.IndexOf(AClass) < 0) then
        Skins.Add(AClass);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: SkinCount
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Integer
//** Scopo: Numero di skin disponibili.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function SkinCount: Integer;
begin
    Result := Skins.Count;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: SkinByIndex
//** Parametri di ingresso: AIndex: Integer
//** Parametri di uscita: Result: TSkinClass
//** Scopo: Skin per indice (ordine di registrazione), nil se fuori range.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function SkinByIndex(AIndex: Integer): TSkinClass;
begin
    if (AIndex >= 0) and (AIndex < Skins.Count) then
        Result := Skins[AIndex]
    else
        Result := nil;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: SkinIndexOf
//** Parametri di ingresso: AId: string
//** Parametri di uscita: Result: Integer
//** Scopo: Posizione di una skin dato il suo Id (case-insensitive), -1 se assente.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function SkinIndexOf(const AId: string): Integer;
var
    I: Integer;
begin
    for I := 0 to Skins.Count - 1 do
        if SameText(Skins[I].Id, AId) then
            Exit(I);
    Result := -1;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: FindSkin
//** Parametri di ingresso: AId: string
//** Parametri di uscita: Result: TSkinClass
//** Scopo: Cercare una skin per Id.
//** Data Ultima Modifica: 15/09/2026
//***********************************************************************************************************
//** Funzionamento: se non esiste restituisce la prima registrata (o nil).
//***********************************************************************************************************
//***********************************************************************************************************
function FindSkin(const AId: string): TSkinClass;
var
    I: Integer;
begin
    I := SkinIndexOf(AId);
    if I < 0 then
        I := 0;
    Result := SkinByIndex(I);
end;

initialization

finalization
    FreeAndNil(GSkins);

end.
