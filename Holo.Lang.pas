//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Lang
//** Scopo: Localizzazione delle scritte dell'interfaccia (Tr / TrBuiltin) e file di lingua.
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: ogni scritta mostrata a video passa da Tr(chiave, testo
//** predefinito): il testo predefinito (italiano) e' scritto nel codice e viene
//** usato quando la lingua scelta non contiene quella chiave.
//**
//** Ogni lingua ha il suo file .ini nella cartella LANG accanto all'eseguibile:
//**    LANG\italiano.ini, LANG\english.ini, ...
//** Italiano e inglese sono anche incorporati nell'exe (risorse RCDATA
//** LANG_ITALIANO e LANG_ENGLISH, vedi HoloObj.rc), quindi funzionano anche
//** senza la cartella LANG; il file nella cartella ha la precedenza su quello
//** incorporato. Per aggiungere una lingua basta copiare un file, tradurlo e
//** dargli un nuovo nome (es. LANG\deutsch.ini): compare da solo nel Setup.
//**
//** Formato del file (UTF-8):
//**    [Lingua]
//**    Nome=English              nome mostrato nella scelta della lingua
//**    [Testi]
//**    chiave=testo              una riga per scritta
//** Nel testo "\n" e' l'a capo e "\\" la barra rovescia; un testo che inizia o
//** finisce con degli spazi va racchiuso tra virgolette ("   testo").
//** I testi usati con Format contengono i segnaposto %d / %s, da mantenere
//** nello stesso ordine.
//** TrBuiltin(chiave, testo predefinito) usa solo i testi incorporati nell'exe
//** (lingua corrente se e' incorporata, altrimenti inglese): serve per le
//** scritte che non devono essere modificabili dai file della cartella LANG,
//** come la pagina Info del Setup (dati dell'autore e del software).
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.Lang;

interface

uses
    System.SysUtils, System.Classes, System.IniFiles, System.Generics.Collections;

type
    /// Una lingua disponibile.
    TLangInfo = record
        Id: string;      // nome del file senza estensione (es. 'english'): salvato nel .ini
        Name: string;    // nome mostrato nel Setup ([Lingua] Nome)
    end;

const
    DEF_LANGUAGE = 'italiano';

function Tr(const AKey, ADefault: string): string;
function TrBuiltin(const AKey, ADefault: string): string;
procedure LoadLanguage(const AId: string);
function CurrentLanguage: string;
function LanguageVersion: Integer;
function AvailableLanguages: TArray<TLangInfo>;
function DecodeLangText(const S: string): string;

implementation

uses
    Winapi.Windows, System.IOUtils;

const
    BUILTIN_LANGS: array[0..1] of string = ('italiano', 'english');
    SEC_INFO = 'Lingua';
    SEC_TEXT = 'Testi';

var
    GTexts: TDictionary<string, string>;
    GBuiltin: TDictionary<string, string>;   // testi incorporati nell'exe (TrBuiltin)
    GCurrent: string;
    GVersion: Integer;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: LangFolder
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Cartella dei file di lingua (LANG accanto all'eseguibile), con il separatore finale.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function LangFolder: string;
begin
    Result := ExtractFilePath(ParamStr(0)) + 'LANG' + PathDelim;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: OpenLangResource
//** Parametri di ingresso: AId: string
//** Parametri di uscita: Result: TMemIniFile
//** Scopo: Aprire i testi di una lingua incorporati nell'exe (risorsa RCDATA LANG_<ID>); nil se la
//**        lingua non e' incorporata.
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: la risorsa e' letta come UTF-8. L'oggetto restituito va
//** liberato dal chiamante.
//***********************************************************************************************************
//***********************************************************************************************************
function OpenLangResource(const AId: string): TMemIniFile;
var
    ResName: string;
    RS: TResourceStream;
    L: TStringList;
begin
    Result := nil;
    if AId = '' then
        Exit;
    ResName := 'LANG_' + UpperCase(AId);
    if FindResource(HInstance, PChar(ResName), RT_RCDATA) = 0 then
        Exit;
    RS := TResourceStream.Create(HInstance, ResName, RT_RCDATA);
    L := TStringList.Create;
    try
        L.LoadFromStream(RS, TEncoding.UTF8);
        Result := TMemIniFile.Create('');
        Result.SetStrings(L);
    finally
        L.Free;
        RS.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: OpenLangIni
//** Parametri di ingresso: AId: string
//** Parametri di uscita: Result: TMemIniFile
//** Scopo: Aprire il file di una lingua (cartella LANG o risorsa incorporata); nil se non esiste.
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: prima cerca LANG\<id>.ini accanto all'exe, poi la risorsa
//** incorporata (OpenLangResource); il file e' letto come UTF-8. L'oggetto
//** restituito va liberato dal chiamante.
//***********************************************************************************************************
//***********************************************************************************************************
function OpenLangIni(const AId: string): TMemIniFile;
var
    FileName: string;
begin
    Result := nil;
    if AId = '' then
        Exit;
    FileName := LangFolder + LowerCase(AId) + '.ini';
    if FileExists(FileName) then
        Exit(TMemIniFile.Create(FileName, TEncoding.UTF8));
    Result := OpenLangResource(AId);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: DecodeLangText
//** Parametri di ingresso: S: string
//** Parametri di uscita: Result: string
//** Scopo: Convertire un testo letto dal file di lingua nel testo da mostrare.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: toglie le eventuali virgolette che racchiudono il testo
//** (servono a conservare gli spazi iniziali e finali), poi sostituisce "\n"
//** con l'a capo e "\\" con una barra rovescia; le altre sequenze restano
//** come sono.
//***********************************************************************************************************
//***********************************************************************************************************
function DecodeLangText(const S: string): string;
var
    T: string;
    I: Integer;
    SB: TStringBuilder;
begin
    T := S;
    if (Length(T) >= 2) and (T[1] = '"') and (T[Length(T)] = '"') then
        T := Copy(T, 2, Length(T) - 2);
    SB := TStringBuilder.Create;
    try
        I := 1;
        while I <= Length(T) do
        begin
            if (T[I] = '\') and (I < Length(T)) and CharInSet(T[I + 1], ['n', 'N', '\']) then
            begin
                if T[I + 1] = '\' then
                    SB.Append('\')
                else
                    SB.Append(sLineBreak);
                Inc(I, 2);
            end
            else
            begin
                SB.Append(T[I]);
                Inc(I);
            end;
        end;
        Result := SB.ToString;
    finally
        SB.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: Tr
//** Parametri di ingresso: AKey, ADefault: string
//** Parametri di uscita: Result: string
//** Scopo: Testo della scritta AKey nella lingua corrente, oppure ADefault se la lingua non la
//**        contiene.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function Tr(const AKey, ADefault: string): string;
begin
    if (GTexts <> nil) and GTexts.TryGetValue(LowerCase(AKey), Result) then
        Exit;
    Result := ADefault;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TrBuiltin
//** Parametri di ingresso: AKey, ADefault: string
//** Parametri di uscita: Result: string
//** Scopo: Come Tr, ma solo con i testi incorporati nell'exe (non modificabili dalla cartella LANG).
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TrBuiltin(const AKey, ADefault: string): string;
begin
    if (GBuiltin <> nil) and GBuiltin.TryGetValue(LowerCase(AKey), Result) then
        Exit;
    Result := ADefault;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: LoadLanguage
//** Parametri di ingresso: AId: string
//** Parametri di uscita: nessuno
//** Scopo: Caricare i testi di una lingua (nome del file senza estensione, es. 'english').
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: svuota il dizionario e lo riempie con la sezione [Testi]
//** del file della lingua; se il file non esiste resta vuoto e valgono i testi
//** predefiniti del codice (italiano). Carica a parte i testi incorporati
//** nell'exe per TrBuiltin (lingua corrente, oppure inglese se la lingua non
//** e' incorporata). Incrementa LanguageVersion, cosi' chi
//** ha costruito scritte (es. i modelli 3D con le legende) sa di doverle
//** rifare.
//***********************************************************************************************************
//***********************************************************************************************************
procedure LoadLanguage(const AId: string);

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: Fill
    //** Parametri di ingresso: AIni: TMemIniFile; ADict: TDictionary<string, string>
    //** Parametri di uscita: nessuno
    //** Scopo: Copiare nel dizionario i testi della sezione [Testi] di un file di lingua e liberare
    //**        AIni (nil = nessun testo).
    //** Data Ultima Modifica: 04/11/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Fill(AIni: TMemIniFile; ADict: TDictionary<string, string>);
    var
        Lines: TStringList;
        I: Integer;
        Key: string;
    begin
        if AIni = nil then
            Exit;
        Lines := TStringList.Create;
        try
            AIni.ReadSectionValues(SEC_TEXT, Lines);
            for I := 0 to Lines.Count - 1 do
            begin
                Key := LowerCase(Trim(Lines.Names[I]));
                if Key <> '' then
                    ADict.AddOrSetValue(Key, DecodeLangText(Lines.ValueFromIndex[I]));
            end;
        finally
            Lines.Free;
            AIni.Free;
        end;
    end;

var
    Res: TMemIniFile;
begin
    GTexts.Clear;
    GBuiltin.Clear;
    GCurrent := LowerCase(Trim(AId));
    if GCurrent = '' then
        GCurrent := DEF_LANGUAGE;
    Fill(OpenLangIni(GCurrent), GTexts);
    // testi non modificabili (TrBuiltin): solo quelli incorporati, in inglese per
    // le lingue aggiunte dall'utente
    Res := OpenLangResource(GCurrent);
    if Res = nil then
        Res := OpenLangResource('english');
    Fill(Res, GBuiltin);
    Inc(GVersion);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: CurrentLanguage
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Id della lingua caricata (es. 'italiano').
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function CurrentLanguage: string;
begin
    Result := GCurrent;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: LanguageVersion
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Integer
//** Scopo: Contatore che cambia a ogni caricamento di lingua (per rifare le scritte gia' costruite).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function LanguageVersion: Integer;
begin
    Result := GVersion;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: AvailableLanguages
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TArray<TLangInfo>
//** Scopo: Elenco delle lingue disponibili (incorporate e file nella cartella LANG).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: unisce le lingue incorporate nell'exe e i file *.ini della
//** cartella LANG (senza doppioni, in ordine alfabetico di id); per ognuna
//** legge il nome da mostrare da [Lingua] Nome. Le lingue che non si
//** riescono ad aprire vengono saltate.
//***********************************************************************************************************
//***********************************************************************************************************
function AvailableLanguages: TArray<TLangInfo>;
var
    Ids: TStringList;
    S: string;
    I: Integer;
    Ini: TMemIniFile;
    Info: TLangInfo;
begin
    Result := nil;
    Ids := TStringList.Create;
    try
        Ids.Sorted := True;
        Ids.Duplicates := dupIgnore;
        Ids.CaseSensitive := False;
        for S in BUILTIN_LANGS do
            Ids.Add(S);
        if DirectoryExists(LangFolder) then
            for S in TDirectory.GetFiles(LangFolder, '*.ini') do
                Ids.Add(LowerCase(TPath.GetFileNameWithoutExtension(S)));
        for I := 0 to Ids.Count - 1 do
        begin
            Ini := OpenLangIni(Ids[I]);
            if Ini = nil then
                Continue;
            try
                Info.Id := Ids[I];
                Info.Name := DecodeLangText(Ini.ReadString(SEC_INFO, 'Nome', Ids[I]));
            finally
                Ini.Free;
            end;
            Result := Result + [Info];
        end;
    finally
        Ids.Free;
    end;
end;

initialization
    GTexts := TDictionary<string, string>.Create;
    GBuiltin := TDictionary<string, string>.Create;
    GCurrent := DEF_LANGUAGE;

finalization
    FreeAndNil(GBuiltin);
    FreeAndNil(GTexts);

end.
