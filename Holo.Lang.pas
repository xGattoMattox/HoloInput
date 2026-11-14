//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Lang
//** Scopo: Localizzazione delle scritte dell'interfaccia (Tr / sTrBuiltin) e file di lingua.
//** Data Ultima Modifica: 11/11/2026
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
//** sTrBuiltin(chiave, testo predefinito) usa solo i testi incorporati nell'exe
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
        sId: string;      // nome del file senza estensione (es. 'english'): salvato nel .ini
        sName: string;    // nome mostrato nel Setup ([Lingua] Nome)
    end;

const
    DEF_LANGUAGE = 'italiano';

function sTr(const sAKey, sADefault: string): string;
function sTrBuiltin(const sAKey, sADefault: string): string;
procedure LoadLanguage(const sAId: string);
function sCurrentLanguage: string;
function iLanguageVersion: Integer;
function aAvailableLanguages: TArray<TLangInfo>;
function sDecodeLangText(const sAText: string): string;
/// True se sAName puo' essere usato come nome di file in una cartella dell'app (niente percorsi:
/// vuoto, "..", "\", "/", ":" o caratteri di controllo non sono ammessi).
function bIsSafeFileId(const sAName: string): Boolean;

implementation

uses
    Winapi.Windows, System.IOUtils;

const
    BUILTIN_LANGS: array[0..1] of string = ('italiano', 'english');
    SEC_INFO = 'Lingua';
    SEC_TEXT = 'Testi';

var
    oGTexts: TDictionary<string, string>;
    oGBuiltin: TDictionary<string, string>;   // testi incorporati nell'exe (sTrBuiltin)
    sGCurrent: string;
    iGVersion: Integer;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: bIsSafeFileId
//** Parametri di ingresso: sAName: string
//** Parametri di uscita: Result: Boolean
//** Scopo: Verificare che un nome letto dal .ini sia un semplice nome di file, senza percorso.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento: un nome come "..\..\altro" farebbe leggere un file fuori
//** dalla cartella prevista (LANG, OBJ): sono rifiutati il nome vuoto, ".."
//** e i caratteri \ / : e di controllo. Spazi, punti singoli e lettere
//** accentate restano ammessi (es. "deutsch v2").
//***********************************************************************************************************
//***********************************************************************************************************
function bIsSafeFileId(const sAName: string): Boolean;
var
    cCharacter: Char;
begin
    Result := (sAName <> '') and not sAName.Contains('..');
    if Result then
        for cCharacter in sAName do
            if (cCharacter < ' ') or CharInSet(cCharacter, ['\', '/', ':']) then
                Exit(False);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sLangFolder
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Cartella dei file di lingua (LANG accanto all'eseguibile), con il separatore finale.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function sLangFolder: string;
begin
    Result := ExtractFilePath(ParamStr(0)) + 'LANG' + PathDelim;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: oOpenLangResource
//** Parametri di ingresso: sAId: string
//** Parametri di uscita: Result: TMemIniFile
//** Scopo: Aprire i testi di una lingua incorporati nell'exe (risorsa RCDATA LANG_<ID>); nil se la
//**        lingua non e' incorporata.
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: la risorsa e' letta come UTF-8. L'oggetto restituito va
//** liberato dal chiamante.
//***********************************************************************************************************
//***********************************************************************************************************
function oOpenLangResource(const sAId: string): TMemIniFile;
var
    sResName: string;
    oStream: TResourceStream;
    oLines: TStringList;
begin
    Result := nil;
    if sAId = '' then
        Exit;
    sResName := 'LANG_' + UpperCase(sAId);
    if FindResource(HInstance, PChar(sResName), RT_RCDATA) = 0 then
        Exit;
    oStream := TResourceStream.Create(HInstance, sResName, RT_RCDATA);
    oLines := TStringList.Create;
    try
        oLines.LoadFromStream(oStream, TEncoding.UTF8);
        Result := TMemIniFile.Create('');
        Result.SetStrings(oLines);
    finally
        oLines.Free;
        oStream.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: oOpenLangIni
//** Parametri di ingresso: sAId: string
//** Parametri di uscita: Result: TMemIniFile
//** Scopo: Aprire il file di una lingua (cartella LANG o risorsa incorporata); nil se non esiste.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento: prima cerca LANG\<id>.ini accanto all'exe, poi la risorsa
//** incorporata (oOpenLangResource); il file e' letto come UTF-8. Un nome con
//** un percorso (bIsSafeFileId) restituisce nil. L'oggetto
//** restituito va liberato dal chiamante.
//***********************************************************************************************************
//***********************************************************************************************************
function oOpenLangIni(const sAId: string): TMemIniFile;
var
    sFileName: string;
begin
    Result := nil;
    if not bIsSafeFileId(sAId) then
        Exit;
    sFileName := sLangFolder + LowerCase(sAId) + '.ini';
    if FileExists(sFileName) then
        Exit(TMemIniFile.Create(sFileName, TEncoding.UTF8));
    Result := oOpenLangResource(sAId);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sDecodeLangText
//** Parametri di ingresso: sAText: string
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
function sDecodeLangText(const sAText: string): string;
var
    sText: string;
    iPos: Integer;
    oBuilder: TStringBuilder;
begin
    sText := sAText;
    if (Length(sText) >= 2) and (sText[1] = '"') and (sText[Length(sText)] = '"') then
        sText := Copy(sText, 2, Length(sText) - 2);
    oBuilder := TStringBuilder.Create;
    try
        iPos := 1;
        while iPos <= Length(sText) do
        begin
            if (sText[iPos] = '\') and (iPos < Length(sText)) and CharInSet(sText[iPos + 1], ['n', 'N',
                '\']) then
            begin
                if sText[iPos + 1] = '\' then
                    oBuilder.Append('\')
                else
                    oBuilder.Append(sLineBreak);
                Inc(iPos, 2);
            end
            else
            begin
                oBuilder.Append(sText[iPos]);
                Inc(iPos);
            end;
        end;
        Result := oBuilder.ToString;
    finally
        oBuilder.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sTr
//** Parametri di ingresso: sAKey, sADefault: string
//** Parametri di uscita: Result: string
//** Scopo: Testo della scritta sAKey nella lingua corrente, oppure sADefault se la lingua non la
//**        contiene.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function sTr(const sAKey, sADefault: string): string;
begin
    if (oGTexts <> nil) and oGTexts.TryGetValue(LowerCase(sAKey), Result) then
        Exit;
    Result := sADefault;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sTrBuiltin
//** Parametri di ingresso: sAKey, sADefault: string
//** Parametri di uscita: Result: string
//** Scopo: Come Tr, ma solo con i testi incorporati nell'exe (non modificabili dalla cartella LANG).
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
function sTrBuiltin(const sAKey, sADefault: string): string;
begin
    if (oGBuiltin <> nil) and oGBuiltin.TryGetValue(LowerCase(sAKey), Result) then
        Exit;
    Result := sADefault;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: LoadLanguage
//** Parametri di ingresso: sAId: string
//** Parametri di uscita: nessuno
//** Scopo: Caricare i testi di una lingua (nome del file senza estensione, es. 'english').
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: svuota il dizionario e lo riempie con la sezione [Testi]
//** del file della lingua; se il file non esiste resta vuoto e valgono i testi
//** predefiniti del codice (italiano). Carica a parte i testi incorporati
//** nell'exe per sTrBuiltin (lingua corrente, oppure inglese se la lingua non
//** e' incorporata). Incrementa iLanguageVersion, cosi' chi
//** ha costruito scritte (es. i modelli 3D con le legende) sa di doverle
//** rifare.
//***********************************************************************************************************
//***********************************************************************************************************
procedure LoadLanguage(const sAId: string);

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: Fill
    //** Parametri di ingresso: oAIni: TMemIniFile; oADict: TDictionary<string, string>
    //** Parametri di uscita: nessuno
    //** Scopo: Copiare nel dizionario i testi della sezione [Testi] di un file di lingua e liberare
    //**        oAIni (nil = nessun testo).
    //** Data Ultima Modifica: 04/11/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Fill(oAIni: TMemIniFile; oADict: TDictionary<string, string>);
    var
        oLines: TStringList;
        iLine: Integer;
        sKey: string;
    begin
        if oAIni = nil then
            Exit;
        oLines := TStringList.Create;
        try
            oAIni.ReadSectionValues(SEC_TEXT, oLines);
            for iLine := 0 to oLines.Count - 1 do
            begin
                sKey := LowerCase(Trim(oLines.Names[iLine]));
                if sKey <> '' then
                    oADict.AddOrSetValue(sKey, sDecodeLangText(oLines.ValueFromIndex[iLine]));
            end;
        finally
            oLines.Free;
            oAIni.Free;
        end;
    end;

var
    oRes: TMemIniFile;
begin
    oGTexts.Clear;
    oGBuiltin.Clear;
    sGCurrent := LowerCase(Trim(sAId));
    if sGCurrent = '' then
        sGCurrent := DEF_LANGUAGE;
    Fill(oOpenLangIni(sGCurrent), oGTexts);
    // testi non modificabili (sTrBuiltin): solo quelli incorporati, in inglese per
    // le lingue aggiunte dall'utente
    oRes := oOpenLangResource(sGCurrent);
    if oRes = nil then
        oRes := oOpenLangResource('english');
    Fill(oRes, oGBuiltin);
    Inc(iGVersion);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sCurrentLanguage
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Id della lingua caricata (es. 'italiano').
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function sCurrentLanguage: string;
begin
    Result := sGCurrent;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: iLanguageVersion
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Integer
//** Scopo: Contatore che cambia a ogni caricamento di lingua (per rifare le scritte gia' costruite).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function iLanguageVersion: Integer;
begin
    Result := iGVersion;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: aAvailableLanguages
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
function aAvailableLanguages: TArray<TLangInfo>;
var
    oIds: TStringList;
    sEntry: string;
    iLang: Integer;
    oIni: TMemIniFile;
    rInfo: TLangInfo;
begin
    Result := nil;
    oIds := TStringList.Create;
    try
        oIds.Sorted := True;
        oIds.Duplicates := dupIgnore;
        oIds.CaseSensitive := False;
        for sEntry in BUILTIN_LANGS do
            oIds.Add(sEntry);
        if DirectoryExists(sLangFolder) then
            for sEntry in TDirectory.GetFiles(sLangFolder, '*.ini') do
                oIds.Add(LowerCase(TPath.GetFileNameWithoutExtension(sEntry)));
        for iLang := 0 to oIds.Count - 1 do
        begin
            oIni := oOpenLangIni(oIds[iLang]);
            if oIni = nil then
                Continue;
            try
                rInfo.sId := oIds[iLang];
                rInfo.sName := sDecodeLangText(oIni.ReadString(SEC_INFO, 'Nome', oIds[iLang]));
            finally
                oIni.Free;
            end;
            Result := Result + [rInfo];
        end;
    finally
        oIds.Free;
    end;
end;

initialization
    oGTexts := TDictionary<string, string>.Create;
    oGBuiltin := TDictionary<string, string>.Create;
    sGCurrent := DEF_LANGUAGE;

finalization
    FreeAndNil(oGBuiltin);
    FreeAndNil(oGTexts);

end.
