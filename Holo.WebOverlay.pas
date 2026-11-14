//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.WebOverlay
//** Scopo: Servizio "Browser Source" per OBS (server HTTP/WebSocket locale) ed elenco dei monitor.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento: un piccolo server HTTP (Indy) in ascolto solo su 127.0.0.1 (niente accessi
//** dall'esterno, niente avvisi del firewall) espone:
//**    /            pagina HTML a sfondo trasparente (da aggiungere in OBS come
//**                 Browser Source, con la stessa larghezza/altezza): apre una
//**                 connessione WebSocket e disegna ogni fotogramma ricevuto su
//**                 un canvas grande quanto la risoluzione del servizio; se la
//**                 connessione cade si ricollega da sola;
//**    /ws          connessione WebSocket: il server invia ogni nuovo fotogramma
//**                 appena e' pronto (messaggio binario, vedi sotto);
//**    /frame.png   l'ultimo fotogramma come PNG (per verifica nel browser).
//** Sicurezza: ogni richiesta deve avere come Host 127.0.0.1 o localhost con
//** la porta del servizio e, se ha un Origin, deve venire dalla pagina del
//** servizio stesso (bRequestAllowed); le altre ricevono 403. Cosi' un sito
//** aperto nel browser non puo' collegarsi alla WebSocket e vedere i
//** fotogrammi (e quindi i tasti premuti). E' ammessa una sola connessione
//** WebSocket alla volta (quella di OBS); una seconda solo se HoloInput e'
//** avviato con l'opzione "SecondConnection" (es. per una prova nel browser
//** mentre OBS e' collegato). Le connessioni in piu' ricevono 503 (la pagina
//** riprova da sola ogni secondo).
//**
//** Fotogrammi: la finestra principale fotografa i widget, li compone nella
//** sola area che occupano (il resto dello schermo e' trasparente e non viene
//** inviato) e passa i pixel a SubmitFrame. Un thread di codifica (TObsEncoder)
//** li comprime in PNG (compressione veloce) e prepara il messaggio WebSocket;
//** se arriva un fotogramma nuovo prima che il precedente sia stato codificato,
//** quello vecchio viene scartato. Ogni connessione WebSocket gira in un thread
//** di Indy e invia sempre l'ultimo fotogramma pronto.
//** Messaggio binario: 4 interi a 32 bit little-endian (X, Y, larghezza,
//** altezza dell'area nella pagina) seguiti dal PNG; larghezza 0 = nessun
//** widget visibile (la pagina si svuota).
//**
//** rNativeScreenSize: risoluzione nativa (in pixel reali) del monitor
//** principale, valore iniziale della risoluzione del servizio.
//** aListMonitors / aOtherMonitors / bFindMonitor / sMonitorText: monitor collegati,
//** per spostare la finestra su un monitor diverso dal principale mentre il
//** servizio e' attivo (il monitor scelto si salva con il nome del dispositivo,
//** es. \\.\DISPLAY2, perche' l'ordine di enumerazione puo' cambiare).
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.WebOverlay;

interface

uses
    System.SysUtils, System.Types, System.Classes, System.SyncObjs,
    IdGlobal, IdContext, IdIOHandler, IdCustomHTTPServer, IdHTTPServer;

const
    OBS_DEF_PORT = 8765;          // porta predefinita del servizio
    OBS_DEF_FPS = 30;             // fotogrammi al secondo predefiniti

type
    /// Server HTTP/WebSocket locale che pubblica l'overlay per il Browser Source di OBS.
    TWebOverlayServer = class
    private
        oFServer: TIdHTTPServer;
        oFLock: TCriticalSection;
        oFEncoder: TThread;             // thread di codifica (TObsEncoder)
        oFWake: TEvent;                 // sveglia il thread di codifica
        aFPending: TBytes;              // pixel in attesa di codifica (premoltiplicati)
        rFPendRect: TRect;              // area dei pixel in attesa, nella pagina
        bFPendBgr: Boolean;             // ordine dei canali BGRA (altrimenti RGBA)
        bFHasPending: Boolean;
        aFMessage: TIdBytes;            // ultimo fotogramma pronto, gia' come messaggio WebSocket
        aFPng: TBytes;                  // ultimo fotogramma come PNG (/frame.png)
        iFSeq: Integer;                 // numero dell'ultimo fotogramma pronto
        iFWidth, iFHeight: Integer;
        bFStopping: Boolean;
        iFClients: Integer;             // connessioni WebSocket aperte
        iFSent: Integer;                // fotogrammi inviati (somma su tutte le connessioni)
        iFEncoded: Integer;             // fotogrammi codificati
        iFEncodeMs: Integer;            // tempo di codifica dell'ultimo fotogramma
        iFVisible: Integer;             // pixel visibili nell'ultimo fotogramma
        iFMaxClients: Integer;          // connessioni WebSocket ammesse (1, o 2 con SecondConnection)
        procedure CommandGet(oAContext: TIdContext; oARequestInfo: TIdHTTPRequestInfo;
            oAResponseInfo: TIdHTTPResponseInfo);
        procedure ServeWebSocket(oAContext: TIdContext; oARequestInfo: TIdHTTPRequestInfo;
            oAResponseInfo: TIdHTTPResponseInfo);
        function bHandleIncoming(oAIO: TIdIOHandler): Boolean;
        procedure EncodePending;
        function sPageHtml: string;
        function bGetActive: Boolean;
        function iGetPort: Integer;
        function bHostAllowed(const sAValue: string; bAOrigin: Boolean): Boolean;
        function bRequestAllowed(oARequestInfo: TIdHTTPRequestInfo): Boolean;
    public
        constructor Create;
        destructor Destroy; override;
        procedure Start(iAPort, iAWidth, iAHeight: Integer);
        procedure Stop;
        /// Nuovo fotogramma: pixel dell'area rARect (righe consecutive, 4 byte per pixel,
        /// alfa premoltiplicato); aAPixels vuoto o rARect vuoto = nessun widget visibile.
        procedure SubmitFrame(const aAPixels: TBytes; const rARect: TRect; bABgr: Boolean);
        function sUrl: string;
        property bActive: Boolean read bGetActive;
        property iPort: Integer read iGetPort;
        property iClients: Integer read iFClients;
        property iFramesSent: Integer read iFSent;
        property iFramesEncoded: Integer read iFEncoded;
        property iEncodeMs: Integer read iFEncodeMs;
        property iVisiblePixels: Integer read iFVisible;
    end;

type
    /// Un monitor collegato (coordinate in pixel reali del desktop virtuale).
    TMonitorDesc = record
        sDevice: string;      // nome del dispositivo (es. \\.\DISPLAY2): salvato nel .ini
        rBounds: TRect;       // area del monitor
        bPrimary: Boolean;    // monitor principale
    end;

function rNativeScreenSize: TSize;
function sObsUrl(iAPort: Integer): string;
function aListMonitors: TArray<TMonitorDesc>;
function aOtherMonitors: TArray<TMonitorDesc>;
function bFindMonitor(const sADevice: string; out rAMonitor: TMonitorDesc): Boolean;
function rPrimaryMonitorRect: TRect;
function sMonitorText(const rAMonitor: TMonitorDesc): string;

implementation

uses
    Winapi.Windows, System.Math, System.Generics.Collections, System.Diagnostics, System.Hash,
    System.NetEncoding, System.ZLib, IdSocketHandle, Holo.Lang;

type
    /// Thread che comprime in PNG i fotogrammi passati a SubmitFrame.
    TObsEncoder = class(TThread)
    private
        oFOwner: TWebOverlayServer;
    protected
        procedure Execute; override;
    public
        constructor Create(oAOwner: TWebOverlayServer);
    end;

const
    WS_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';   // costante del protocollo WebSocket (RFC 6455)
    WS_MAX_CLIENTS = 1;           // connessioni WebSocket contemporanee: solo OBS
    WS_MAX_CLIENTS_EXTRA = 2;     // con l'opzione OPT_SECOND_CONNECTION: OBS + una prova
    OPT_SECOND_CONNECTION = 'SecondConnection';   // opzione da riga di comando

var
    aGCrcTable: array[0..255] of Cardinal;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: rNativeScreenSize
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TSize
//** Scopo: Risoluzione nativa (pixel reali, senza ridimensionamento DPI) del monitor principale.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: legge la modalita' video corrente con EnumDisplaySettings
//** (indipendente dal ridimensionamento di Windows); se non riesce usa
//** GetSystemMetrics.
//***********************************************************************************************************
//***********************************************************************************************************
function rNativeScreenSize: TSize;
const
    // ENUM_CURRENT_SETTINGS di Windows (non dichiarata in Winapi.Windows): modalita' video corrente
    CURRENT_SETTINGS = DWORD(-1);
var
    rDevMode: TDeviceMode;
begin
    FillChar(rDevMode, SizeOf(rDevMode), 0);
    rDevMode.dmSize := SizeOf(rDevMode);
    if EnumDisplaySettings(nil, CURRENT_SETTINGS, rDevMode) and (rDevMode.dmPelsWidth > 0) then
        Result := TSize.Create(rDevMode.dmPelsWidth, rDevMode.dmPelsHeight)
    else
        Result := TSize.Create(GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sObsUrl
//** Parametri di ingresso: iAPort: Integer
//** Parametri di uscita: Result: string
//** Scopo: Indirizzo da inserire nel Browser Source di OBS per la porta indicata.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function sObsUrl(iAPort: Integer): string;
begin
    Result := Format('http://127.0.0.1:%d/', [iAPort]);
end;

type
    /// MONITORINFOEXW di Windows (dichiarata qui per non dipendere dalla versione di Winapi.Windows).
    TMonInfoEx = record
        cbSize: DWORD;
        rcMonitor: TRect;
        rcWork: TRect;
        dwFlags: DWORD;
        szDevice: array[0..31] of WideChar;
    end;
    TMonEnumProc = function(AMonitor: THandle; ADC: HDC; ARect: PRect; AData: LPARAM): BOOL; stdcall;

const
    MON_PRIMARY = 1;     // MONITORINFOF_PRIMARY

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HoloEnumDisplayMonitors
//** Parametri di ingresso: ADC: HDC; AClip: PRect; AProc: TMonEnumProc; AData: LPARAM
//** Parametri di uscita: Result: BOOL
//** Scopo: Importare da user32.dll la funzione EnumDisplayMonitors (elenco dei monitor collegati).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function HoloEnumDisplayMonitors(ADC: HDC; AClip: PRect; AProc: TMonEnumProc; AData: LPARAM): BOOL;
    stdcall; external user32 name 'EnumDisplayMonitors';
//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HoloGetMonitorInfo
//** Parametri di ingresso: AMonitor: THandle; AInfo: TMonInfoEx (var)
//** Parametri di uscita: Result: BOOL; AInfo: TMonInfoEx (var)
//** Scopo: Importare da user32.dll la funzione GetMonitorInfoW (area, nome e flag di un monitor).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function HoloGetMonitorInfo(AMonitor: THandle; var AInfo: TMonInfoEx): BOOL;
    stdcall; external user32 name 'GetMonitorInfoW';

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: bMonitorEnumProc
//** Parametri di ingresso: hAMonitor: THandle; hADC: HDC; pARect: PRect; iAData: LPARAM
//** Parametri di uscita: Result: BOOL
//** Scopo: Callback di EnumDisplayMonitors: aggiungere un monitor alla lista passata in iAData.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function bMonitorEnumProc(hAMonitor: THandle; hADC: HDC; pARect: PRect; iAData: LPARAM): BOOL; stdcall;
var
    rInfo: TMonInfoEx;
    rMonitor: TMonitorDesc;
begin
    Result := True;
    FillChar(rInfo, SizeOf(rInfo), 0);
    rInfo.cbSize := SizeOf(rInfo);
    if not HoloGetMonitorInfo(hAMonitor, rInfo) then
        Exit;
    rMonitor.sDevice := string(PWideChar(@rInfo.szDevice[0]));
    rMonitor.rBounds := rInfo.rcMonitor;
    rMonitor.bPrimary := (rInfo.dwFlags and MON_PRIMARY) <> 0;
    TList<TMonitorDesc>(Pointer(iAData)).Add(rMonitor);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: aListMonitors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TArray<TMonitorDesc>
//** Scopo: Elenco dei monitor collegati (nome del dispositivo, area in pixel reali, principale).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function aListMonitors: TArray<TMonitorDesc>;
var
    oList: TList<TMonitorDesc>;
begin
    oList := TList<TMonitorDesc>.Create;
    try
        HoloEnumDisplayMonitors(0, nil, bMonitorEnumProc, LPARAM(Pointer(oList)));
        Result := oList.ToArray;
    finally
        oList.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: aOtherMonitors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TArray<TMonitorDesc>
//** Scopo: Monitor su cui spostare la finestra durante il servizio OBS: tutti tranne il principale
//**        (quello su cui l'overlay dispone i widget).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function aOtherMonitors: TArray<TMonitorDesc>;
var
    rMonitor: TMonitorDesc;
begin
    Result := nil;
    for rMonitor in aListMonitors do
        if not rMonitor.bPrimary then
            Result := Result + [rMonitor];
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: bFindMonitor
//** Parametri di ingresso: sADevice: string
//** Parametri di uscita: rAMonitor: TMonitorDesc; Result: Boolean
//** Scopo: Cercare un monitor collegato dal nome del dispositivo (es. \\.\DISPLAY2).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function bFindMonitor(const sADevice: string; out rAMonitor: TMonitorDesc): Boolean;
var
    rMonitor: TMonitorDesc;
begin
    Result := False;
    rAMonitor := Default(TMonitorDesc);
    if sADevice = '' then
        Exit;
    for rMonitor in aListMonitors do
        if SameText(rMonitor.sDevice, sADevice) then
        begin
            rAMonitor := rMonitor;
            Exit(True);
        end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: rPrimaryMonitorRect
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TRect
//** Scopo: Area del monitor principale in pixel reali.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function rPrimaryMonitorRect: TRect;
var
    rMonitor: TMonitorDesc;
begin
    Result := TRect.Create(0, 0, rNativeScreenSize.cx, rNativeScreenSize.cy);
    for rMonitor in aListMonitors do
        if rMonitor.bPrimary then
            Result := rMonitor.rBounds;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sMonitorText
//** Parametri di ingresso: rAMonitor: TMonitorDesc
//** Parametri di uscita: Result: string
//** Scopo: Descrizione di un monitor per il Setup: numero, risoluzione e posizione rispetto al
//**        monitor principale.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: il numero viene dalle cifre finali del nome del
//** dispositivo (\\.\DISPLAY2 -> 2); la posizione confronta i centri dei due
//** monitor sull'asse in cui sono piu' distanti.
//***********************************************************************************************************
//***********************************************************************************************************
function sMonitorText(const rAMonitor: TMonitorDesc): string;
var
    iPos, iNum, iDeltaX, iDeltaY: Integer;
    rPrimaryRect: TRect;
    sSide: string;
begin
    iPos := Length(rAMonitor.sDevice);
    while (iPos > 0) and CharInSet(rAMonitor.sDevice[iPos], ['0'..'9']) do
        Dec(iPos);
    iNum := StrToIntDef(Copy(rAMonitor.sDevice, iPos + 1, MaxInt), 0);
    rPrimaryRect := rPrimaryMonitorRect;
    iDeltaX := rAMonitor.rBounds.CenterPoint.X - rPrimaryRect.CenterPoint.X;
    iDeltaY := rAMonitor.rBounds.CenterPoint.Y - rPrimaryRect.CenterPoint.Y;
    if Abs(iDeltaX) >= Abs(iDeltaY) then
    begin
        if iDeltaX < 0 then
            sSide := sTr('obs.monitor.left', 'a sinistra del principale')
        else
            sSide := sTr('obs.monitor.right', 'a destra del principale');
    end
    else
    begin
        if iDeltaY < 0 then
            sSide := sTr('obs.monitor.above', 'sopra il principale')
        else
            sSide := sTr('obs.monitor.below', 'sotto il principale');
    end;
    Result := Format(sTr('obs.monitor.item', 'Monitor %d  ' + #$00B7 + '  %d x %d  ' + #$00B7 + '  %s'),
        [iNum, rAMonitor.rBounds.Width, rAMonitor.rBounds.Height, sSide]);
end;

//** PNG ****************************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: InitCrcTable
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Preparare la tabella del CRC-32 usato dai blocchi del formato PNG.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure InitCrcTable;
var
    iEntry, iBit: Integer;
    iCrc: Cardinal;
begin
    for iEntry := 0 to 255 do
    begin
        iCrc := Cardinal(iEntry);
        for iBit := 0 to 7 do
            if (iCrc and 1) <> 0 then
                iCrc := $EDB88320 xor (iCrc shr 1)
            else
                iCrc := iCrc shr 1;
        aGCrcTable[iEntry] := iCrc;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: iUpdateCrc
//** Parametri di ingresso: iACrc: Cardinal; aAData: TBytes
//** Parametri di uscita: Result: Cardinal
//** Scopo: Aggiornare un CRC-32 con i byte indicati.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function iUpdateCrc(iACrc: Cardinal; const aAData: TBytes): Cardinal;
var
    iByteIndex: Integer;
begin
    Result := iACrc;
    for iByteIndex := 0 to High(aAData) do
        Result := aGCrcTable[(Result xor aAData[iByteIndex]) and $FF] xor (Result shr 8);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: WriteBE32
//** Parametri di ingresso: oAStream: TStream; iAValue: Cardinal
//** Parametri di uscita: nessuno
//** Scopo: Scrivere un intero a 32 bit nell'ordine big-endian richiesto dal formato PNG.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure WriteBE32(oAStream: TStream; iAValue: Cardinal);
var
    aBytes: array[0..3] of Byte;
begin
    aBytes[0] := Byte(iAValue shr 24);
    aBytes[1] := Byte(iAValue shr 16);
    aBytes[2] := Byte(iAValue shr 8);
    aBytes[3] := Byte(iAValue);
    oAStream.WriteBuffer(aBytes, 4);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: WritePngChunk
//** Parametri di ingresso: oAStream: TStream; sAType: string; aAData: TBytes
//** Parametri di uscita: nessuno
//** Scopo: Scrivere un blocco PNG (lunghezza, tipo, dati, CRC).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure WritePngChunk(oAStream: TStream; const sAType: string; const aAData: TBytes);
var
    aTypeBytes: TBytes;
begin
    aTypeBytes := TEncoding.ASCII.GetBytes(sAType);
    WriteBE32(oAStream, Cardinal(Length(aAData)));
    oAStream.WriteBuffer(aTypeBytes[0], 4);
    if Length(aAData) > 0 then
        oAStream.WriteBuffer(aAData[0], Length(aAData));
    WriteBE32(oAStream, not iUpdateCrc(iUpdateCrc($FFFFFFFF, aTypeBytes), aAData));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: aEncodePng
//** Parametri di ingresso: aAPix: TBytes; iAWidth, iAHeight: Integer; bABgr: Boolean
//** Parametri di uscita: iAVisible: Integer; Result: TBytes
//** Scopo: Comprimere in PNG (RGBA a 8 bit) i pixel di un fotogramma, contando quelli visibili.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: i pixel arrivano con l'alfa premoltiplicato (come li tiene
//** FireMonkey) e vengono riportati a colori pieni, come vuole il PNG. Dove
//** un canale di colore supera l'alfa (forme traslucide sovrapposte, luci dei
//** comandi premuti: Windows le mostra come luce che si somma allo sfondo)
//** l'alfa viene portato al canale piu' alto: senza, la divisione saturerebbe
//** i colori verso il bianco e il widget "lampeggerebbe" piu' chiaro a ogni
//** input; cosi' su sfondo scuro il risultato e' identico allo schermo. Ogni
//** riga ha il filtro 0 (nessuno) e i dati sono compressi con zlib alla
//** velocita' massima: le zone trasparenti (la maggior parte) si comprimono
//** comunque benissimo. Scritto qui (e non con il codec di FireMonkey) perche'
//** gira nel thread di codifica, fuori dal thread principale.
//***********************************************************************************************************
//***********************************************************************************************************
function aEncodePng(const aAPix: TBytes; iAWidth, iAHeight: Integer; bABgr: Boolean;
    out iAVisible: Integer): TBytes;
const
    SIGNATURE: array[0..7] of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);
var
    aRaw, aCompressed, aHdr: TBytes;
    iCol, iRow, iSrc, iDst, iRowLen: Integer;
    iAlpha, iRed, iGreen, iBlue: Integer;
    oStream: TBytesStream;
begin
    iAVisible := 0;
    iRowLen := iAWidth * 4 + 1;
    SetLength(aRaw, iRowLen * iAHeight);
    for iRow := 0 to iAHeight - 1 do
    begin
        iDst := iRow * iRowLen;
        aRaw[iDst] := 0;
        Inc(iDst);
        iSrc := iRow * iAWidth * 4;
        for iCol := 0 to iAWidth - 1 do
        begin
            if bABgr then
            begin
                iRed := aAPix[iSrc + 2];
                iBlue := aAPix[iSrc];
            end
            else
            begin
                iRed := aAPix[iSrc];
                iBlue := aAPix[iSrc + 2];
            end;
            iGreen := aAPix[iSrc + 1];
            // le parti traslucide sovrapposte e le luci dei comandi premuti possono
            // avere colori piu' alti dell'alfa (luce "additiva"): l'alfa sale al canale
            // piu' alto, cosi' il colore resta lo stesso invece di saturare verso il bianco
            iAlpha := Max(Integer(aAPix[iSrc + 3]), Max(iRed, Max(iGreen, iBlue)));
            if iAlpha = 0 then
            begin
                aRaw[iDst] := 0;
                aRaw[iDst + 1] := 0;
                aRaw[iDst + 2] := 0;
                aRaw[iDst + 3] := 0;
            end
            else
            begin
                if iAlpha < 255 then
                begin
                    iRed := Min(255, (iRed * 255 + iAlpha div 2) div iAlpha);
                    iGreen := Min(255, (iGreen * 255 + iAlpha div 2) div iAlpha);
                    iBlue := Min(255, (iBlue * 255 + iAlpha div 2) div iAlpha);
                end;
                aRaw[iDst] := Byte(iRed);
                aRaw[iDst + 1] := Byte(iGreen);
                aRaw[iDst + 2] := Byte(iBlue);
                aRaw[iDst + 3] := Byte(iAlpha);
                if iAlpha > 16 then
                    Inc(iAVisible);
            end;
            Inc(iSrc, 4);
            Inc(iDst, 4);
        end;
    end;
    ZCompress(aRaw, aCompressed, zcFastest);

    SetLength(aHdr, 13);
    aHdr[0] := Byte(iAWidth shr 24);
    aHdr[1] := Byte(iAWidth shr 16);
    aHdr[2] := Byte(iAWidth shr 8);
    aHdr[3] := Byte(iAWidth);
    aHdr[4] := Byte(iAHeight shr 24);
    aHdr[5] := Byte(iAHeight shr 16);
    aHdr[6] := Byte(iAHeight shr 8);
    aHdr[7] := Byte(iAHeight);
    aHdr[8] := 8;      // bit per canale
    aHdr[9] := 6;      // RGBA
    aHdr[10] := 0;     // compressione deflate
    aHdr[11] := 0;     // filtro standard
    aHdr[12] := 0;     // non interlacciato

    oStream := TBytesStream.Create;
    try
        oStream.WriteBuffer(SIGNATURE, SizeOf(SIGNATURE));
        WritePngChunk(oStream, 'IHDR', aHdr);
        WritePngChunk(oStream, 'IDAT', aCompressed);
        WritePngChunk(oStream, 'IEND', nil);
        Result := Copy(oStream.Bytes, 0, oStream.Size);
    finally
        oStream.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: aBuildWsMessage
//** Parametri di ingresso: rARect: TRect; aAPng: TBytes
//** Parametri di uscita: Result: TIdBytes
//** Scopo: Preparare il messaggio WebSocket binario di un fotogramma (area + PNG).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: intestazione WebSocket (FIN + binario, lunghezza a 7, 16 o
//** 64 bit, nessuna maschera perche' parte dal server), poi X, Y, larghezza e
//** altezza come interi a 32 bit little-endian e infine il PNG.
//***********************************************************************************************************
//***********************************************************************************************************
function aBuildWsMessage(const rARect: TRect; const aAPng: TBytes): TIdBytes;
var
    iPayLen: Int64;
    iHeaderLen, iByteIndex, iOffset: Integer;
    aValues: array[0..3] of Integer;
begin
    iPayLen := 16 + Length(aAPng);
    if iPayLen < 126 then
        iHeaderLen := 2
    else if iPayLen < 65536 then
        iHeaderLen := 4
    else
        iHeaderLen := 10;
    SetLength(Result, Integer(iHeaderLen + iPayLen));
    Result[0] := $82;
    case iHeaderLen of
        2:
            Result[1] := Byte(iPayLen);
        4:
            begin
                Result[1] := 126;
                Result[2] := Byte(iPayLen shr 8);
                Result[3] := Byte(iPayLen);
            end;
    else
        Result[1] := 127;
        for iByteIndex := 0 to 7 do
            Result[2 + iByteIndex] := Byte(iPayLen shr (8 * (7 - iByteIndex)));
    end;
    aValues[0] := rARect.Left;
    aValues[1] := rARect.Top;
    aValues[2] := rARect.Width;
    aValues[3] := rARect.Height;
    iOffset := iHeaderLen;
    for iByteIndex := 0 to 3 do
    begin
        Result[iOffset] := Byte(aValues[iByteIndex]);
        Result[iOffset + 1] := Byte(aValues[iByteIndex] shr 8);
        Result[iOffset + 2] := Byte(aValues[iByteIndex] shr 16);
        Result[iOffset + 3] := Byte(aValues[iByteIndex] shr 24);
        Inc(iOffset, 4);
    end;
    if Length(aAPng) > 0 then
        Move(aAPng[0], Result[iOffset], Length(aAPng));
end;

//** TObsEncoder ********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TObsEncoder.Create
//** Parametri di ingresso: oAOwner: TWebOverlayServer
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare e avviare il thread di codifica dei fotogrammi del server indicato.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
constructor TObsEncoder.Create(oAOwner: TWebOverlayServer);
begin
    oFOwner := oAOwner;
    inherited Create(False);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TObsEncoder.Execute
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Ciclo del thread: attendere un fotogramma nuovo e codificarlo.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TObsEncoder.Execute;
begin
    while not Terminated do
    begin
        oFOwner.oFWake.WaitFor(250);
        if not Terminated then
            oFOwner.EncodePending;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: bCmdLineOption
//** Parametri di ingresso: sAName: string
//** Parametri di uscita: Result: Boolean
//** Scopo: Verificare se HoloInput e' stato avviato con l'opzione sAName.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento: cerca sAName tra i parametri della riga di comando, senza
//** distinguere maiuscole e minuscole e ignorando i "-" o "/" iniziali, quindi
//** valgono "SecondConnection", "-SecondConnection", "/SecondConnection" e
//** "-o SecondConnection".
//***********************************************************************************************************
//***********************************************************************************************************
function bCmdLineOption(const sAName: string): Boolean;
var
    iParam: Integer;
    sOption: string;
begin
    for iParam := 1 to ParamCount do
    begin
        sOption := ParamStr(iParam);
        while (sOption <> '') and CharInSet(sOption[1], ['-', '/']) do
            Delete(sOption, 1, 1);
        if SameText(sOption, sAName) then
            Exit(True);
    end;
    Result := False;
end;

//** TWebOverlayServer **************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWebOverlayServer.Create
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare il server (fermo), il lock dei fotogrammi e l'evento del thread di codifica.
//**        Con l'opzione "SecondConnection" ammette due connessioni WebSocket invece di una.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
constructor TWebOverlayServer.Create;
begin
    inherited;
    oFLock := TCriticalSection.Create;
    oFWake := TEvent.Create(nil, False, False, '');
    oFServer := TIdHTTPServer.Create(nil);
    oFServer.OnCommandGet := CommandGet;
    iFWidth := 1920;
    iFHeight := 1080;
    if bCmdLineOption(OPT_SECOND_CONNECTION) then
        iFMaxClients := WS_MAX_CLIENTS_EXTRA
    else
        iFMaxClients := WS_MAX_CLIENTS;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWebOverlayServer.Destroy
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Fermare il server e liberare le risorse.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
destructor TWebOverlayServer.Destroy;
begin
    Stop;
    oFServer.Free;
    oFWake.Free;
    oFLock.Free;
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWebOverlayServer.Start
//** Parametri di ingresso: iAPort, iAWidth, iAHeight: Integer
//** Parametri di uscita: nessuno
//** Scopo: Avviare il server su 127.0.0.1:iAPort per una pagina di iAWidth x iAHeight pixel.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: se il server e' gia' attivo lo riavvia con i nuovi
//** parametri (le pagine aperte in OBS si ricollegano da sole); l'ascolto e'
//** solo sull'interfaccia locale. Se la porta e' gia' occupata l'eccezione di
//** Indy arriva al chiamante. Il thread di codifica parte solo a server avviato.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TWebOverlayServer.Start(iAPort, iAWidth, iAHeight: Integer);
var
    oBinding: TIdSocketHandle;
begin
    Stop;
    iFWidth := Max(16, iAWidth);
    iFHeight := Max(16, iAHeight);
    iFSent := 0;
    iFEncoded := 0;
    iFEncodeMs := 0;
    iFVisible := 0;
    oFServer.Bindings.Clear;
    oBinding := oFServer.Bindings.Add;
    oBinding.IP := '127.0.0.1';
    oBinding.Port := iAPort;
    oFServer.DefaultPort := iAPort;
    oFServer.Active := True;
    oFEncoder := TObsEncoder.Create(Self);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWebOverlayServer.Stop
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Fermare il server (chiude anche le connessioni di OBS) e il thread di codifica.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: bFStopping fa uscire i cicli delle connessioni WebSocket;
//** Indy chiude i socket e attende i suoi thread; poi si ferma il thread di
//** codifica e si scartano i fotogrammi rimasti.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TWebOverlayServer.Stop;
begin
    bFStopping := True;
    try
        if oFServer.Active then
            oFServer.Active := False;
    finally
        if oFEncoder <> nil then
        begin
            oFEncoder.Terminate;
            oFWake.SetEvent;
            oFEncoder.WaitFor;
            FreeAndNil(oFEncoder);
        end;
        bFStopping := False;
    end;
    oFLock.Enter;
    try
        aFPending := nil;
        bFHasPending := False;
        aFMessage := nil;
        aFPng := nil;
    finally
        oFLock.Leave;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TWebOverlayServer.bGetActive
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Indicare se il server e' in ascolto.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TWebOverlayServer.bGetActive: Boolean;
begin
    Result := oFServer.Active;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TWebOverlayServer.iGetPort
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Integer
//** Scopo: Porta su cui il server e' in ascolto (o configurata).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TWebOverlayServer.iGetPort: Integer;
begin
    Result := oFServer.DefaultPort;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TWebOverlayServer.sUrl
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Indirizzo della pagina da usare in OBS.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TWebOverlayServer.sUrl: string;
begin
    Result := sObsUrl(iPort);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWebOverlayServer.SubmitFrame
//** Parametri di ingresso: aAPixels: TBytes; rARect: TRect; bABgr: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Consegnare al thread di codifica un nuovo fotogramma (chiamata dal thread principale).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: sostituisce l'eventuale fotogramma non ancora codificato
//** (cosi' il ritardo non si accumula) e sveglia il thread di codifica. Il
//** vettore dei pixel non va piu' modificato dal chiamante.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TWebOverlayServer.SubmitFrame(const aAPixels: TBytes; const rARect: TRect; bABgr: Boolean);
begin
    if oFEncoder = nil then
        Exit;
    oFLock.Enter;
    try
        aFPending := aAPixels;
        rFPendRect := rARect;
        bFPendBgr := bABgr;
        bFHasPending := True;
    finally
        oFLock.Leave;
    end;
    oFWake.SetEvent;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWebOverlayServer.EncodePending
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Codificare il fotogramma in attesa e pubblicarlo (eseguita nel thread di codifica).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: prende il fotogramma in attesa sotto lock, lo comprime in
//** PNG fuori dal lock, prepara il messaggio WebSocket e lo pubblica
//** incrementando iFSeq (le connessioni inviano ogni iFSeq nuovo). Un'area vuota
//** produce un messaggio senza PNG, che svuota la pagina.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TWebOverlayServer.EncodePending;
var
    aPix, aPng: TBytes;
    rRect: TRect;
    bBgr: Boolean;
    iVis: Integer;
    aMsg: TIdBytes;
    rWatch: TStopwatch;
begin
    oFLock.Enter;
    try
        if not bFHasPending then
            Exit;
        aPix := aFPending;
        aFPending := nil;
        rRect := rFPendRect;
        bBgr := bFPendBgr;
        bFHasPending := False;
    finally
        oFLock.Leave;
    end;
    rWatch := TStopwatch.StartNew;
    iVis := 0;
    aPng := nil;
    if (rRect.Width > 0) and (rRect.Height > 0) and (Length(aPix) >= rRect.Width * rRect.Height * 4) then
        aPng := aEncodePng(aPix, rRect.Width, rRect.Height, bBgr, iVis)
    else
        rRect := Rect(0, 0, 0, 0);
    aMsg := aBuildWsMessage(rRect, aPng);
    oFLock.Enter;
    try
        aFMessage := aMsg;
        aFPng := aPng;
        Inc(iFSeq);
        Inc(iFEncoded);
        iFVisible := iVis;
        iFEncodeMs := rWatch.ElapsedMilliseconds;
    finally
        oFLock.Leave;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TWebOverlayServer.sPageHtml
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Pagina per il Browser Source: canvas trasparente aggiornato via WebSocket.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: il canvas e' grande quanto la risoluzione del servizio.
//** Ogni messaggio contiene l'area occupata dai widget e il suo PNG, decodificato
//** con createImageBitmap (fuori dal thread della pagina); se ne arrivano altri
//** durante la decodifica si tiene solo l'ultimo, cosi' la pagina non resta
//** indietro. Se la connessione si chiude (servizio fermo) il canvas si svuota
//** e la pagina riprova a collegarsi ogni secondo.
//***********************************************************************************************************
//***********************************************************************************************************
function TWebOverlayServer.sPageHtml: string;
begin
    Result :=
        '<!DOCTYPE html><html><head><meta charset="utf-8"><title>HoloInput Overlay</title>' +
        '<style>html,body{margin:0;padding:0;background:transparent;overflow:hidden;}' +
        'canvas{position:absolute;left:0;top:0;}</style></head><body>' +
        Format('<canvas id="c" width="%d" height="%d"></canvas>', [iFWidth, iFHeight]) +
        '<script>' +
        'var c=document.getElementById("c"),g=c.getContext("2d"),busy=false,next=null;' +
        'function done(){busy=false;if(next){var d=next;next=null;show(d);}}' +
        'function show(d){busy=true;var v=new DataView(d),x=v.getInt32(0,true),y=v.getInt32(4,true),' +
        'w=v.getInt32(8,true),h=v.getInt32(12,true);' +
        'if(w<=0||h<=0){g.clearRect(0,0,c.width,c.height);done();return;}' +
        'createImageBitmap(new Blob([new Uint8Array(d,16)],{type:"image/png"})).then(function(b){' +
        'g.clearRect(0,0,c.width,c.height);g.drawImage(b,x,y);b.close();done();},done);}' +
        'function connect(){var ws=new WebSocket("ws://"+location.host+"/ws");ws.binaryType="arraybuffer";' +
        'ws.onmessage=function(e){if(busy)next=e.data;else show(e.data);};' +
        'ws.onclose=function(){g.clearRect(0,0,c.width,c.height);setTimeout(connect,1000);};}' +
        'connect();' +
        '</script></body></html>';
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TWebOverlayServer.bHandleIncoming
//** Parametri di ingresso: oAIO: TIdIOHandler
//** Parametri di uscita: Result: Boolean
//** Scopo: Leggere un messaggio WebSocket arrivato dal browser; False se la connessione va chiusa.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento: la pagina non invia dati, quindi interessano solo i
//** messaggi di controllo: "close" (si risponde e si chiude) e "ping" (si
//** risponde con "pong"); gli altri vengono letti e ignorati. Chiudono la
//** connessione, come richiede RFC 6455: un messaggio non mascherato (il
//** browser maschera sempre i suoi), una lunghezza negativa o oltre 64 KB, un
//** messaggio di controllo (close, ping, pong) oltre 125 byte.
//***********************************************************************************************************
//***********************************************************************************************************
function TWebOverlayServer.bHandleIncoming(oAIO: TIdIOHandler): Boolean;
var
    iFirstByte, iSecondByte, iOpcode: Byte;
    iLen: Int64;
    iByteIndex: Integer;
    aExt, aMask, aData, aReply: TIdBytes;
begin
    Result := True;
    iFirstByte := oAIO.ReadByte;
    iSecondByte := oAIO.ReadByte;
    iOpcode := iFirstByte and $0F;
    iLen := iSecondByte and $7F;
    if iLen = 126 then
    begin
        oAIO.ReadBytes(aExt, 2, False);
        iLen := (Int64(aExt[0]) shl 8) or aExt[1];
    end
    else if iLen = 127 then
    begin
        oAIO.ReadBytes(aExt, 8, False);
        iLen := 0;
        for iByteIndex := 0 to 7 do
            iLen := (iLen shl 8) or aExt[iByteIndex];
    end;
    // lunghezza a 64 bit "negativa" (bit alto acceso) o eccessiva
    if (iLen < 0) or (iLen > 65536) then
        Exit(False);
    // i messaggi di controllo non superano 125 byte (il pong li rimanda uguali)
    if (iOpcode >= 8) and (iLen > 125) then
        Exit(False);
    // i messaggi del browser devono essere mascherati
    if (iSecondByte and $80) = 0 then
        Exit(False);
    oAIO.ReadBytes(aMask, 4, False);
    SetLength(aData, 0);
    if iLen > 0 then
        oAIO.ReadBytes(aData, Integer(iLen), False);
    for iByteIndex := 0 to High(aData) do
        aData[iByteIndex] := aData[iByteIndex] xor aMask[iByteIndex and 3];
    case iOpcode of
        8:  // close
            begin
                SetLength(aReply, 2);
                aReply[0] := $88;
                aReply[1] := 0;
                oAIO.Write(aReply);
                Result := False;
            end;
        9:  // ping -> pong con gli stessi dati
            begin
                SetLength(aReply, 2 + Length(aData));
                aReply[0] := $8A;
                aReply[1] := Byte(Length(aData));
                if Length(aData) > 0 then
                    Move(aData[0], aReply[2], Length(aData));
                oAIO.Write(aReply);
            end;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWebOverlayServer.ServeWebSocket
//** Parametri di ingresso: oAContext: TIdContext; oARequestInfo: TIdHTTPRequestInfo; oAResponseInfo:
//**                        TIdHTTPResponseInfo
//** Parametri di uscita: nessuno
//** Scopo: Gestire una connessione WebSocket di OBS (eseguita nel thread di Indy della
//**        connessione).
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento: verifica la richiesta di upgrade; se ci sono gia'
//** iFMaxClients connessioni aperte (1, oppure 2 con l'opzione SecondConnection)
//** risponde 503 e chiude. Altrimenti risponde con
//** "101 Switching Protocols" e la chiave Sec-WebSocket-Accept (SHA-1 della
//** chiave del browser + WS_GUID, in Base64) scritti direttamente sul socket,
//** poi resta in ciclo finche' la connessione e' aperta: gestisce i messaggi
//** del browser e invia ogni fotogramma nuovo (iFSeq cambiato); tra un
//** controllo e l'altro attende 2 ms. A fine connessione Indy chiude il
//** socket (CloseConnection).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TWebOverlayServer.ServeWebSocket(oAContext: TIdContext; oARequestInfo: TIdHTTPRequestInfo;
    oAResponseInfo: TIdHTTPResponseInfo);
var
    oHandler: TIdIOHandler;
    sKey, sAccept: string;
    iLast, iSeq: Integer;
    aMsg: TIdBytes;
begin
    sKey := Trim(oARequestInfo.RawHeaders.Values['Sec-WebSocket-Key']);
    if (sKey = '') or not SameText(Trim(oARequestInfo.RawHeaders.Values['Upgrade']), 'websocket') then
    begin
        oAResponseInfo.ResponseNo := 400;
        Exit;
    end;
    // posto prenotato prima della risposta: due richieste insieme non superano il limite
    if TInterlocked.Increment(iFClients) > iFMaxClients then
    begin
        TInterlocked.Decrement(iFClients);
        oAResponseInfo.ResponseNo := 503;
        oAResponseInfo.CloseConnection := True;
        Exit;
    end;
    try
        sAccept := TNetEncoding.Base64.EncodeBytesToString(THashSHA1.GetHashBytes(sKey + WS_GUID));
        oHandler := oAContext.Connection.IOHandler;
        oHandler.Write('HTTP/1.1 101 Switching Protocols'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Accept: ' + sAccept + #13#10#13#10);
        oAResponseInfo.HeaderHasBeenWritten := True;
        oAResponseInfo.CloseConnection := True;
        iLast := -1;
        while not bFStopping and oAContext.Connection.Connected do
        begin
            if oHandler.InputBufferIsEmpty then
                oHandler.CheckForDataOnSource(0);
            if not oHandler.InputBufferIsEmpty then
                if not bHandleIncoming(oHandler) then
                    Break;
            oFLock.Enter;
            try
                iSeq := iFSeq;
                aMsg := aFMessage;
            finally
                oFLock.Leave;
            end;
            if (iSeq <> iLast) and (Length(aMsg) > 0) then
            begin
                oHandler.Write(aMsg);
                iLast := iSeq;
                TInterlocked.Increment(iFSent);
            end
            else
                Sleep(2);
        end;
    finally
        TInterlocked.Decrement(iFClients);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TWebOverlayServer.bHostAllowed
//** Parametri di ingresso: sAValue: string; bAOrigin: Boolean
//** Parametri di uscita: Result: Boolean
//** Scopo: Verificare che un'intestazione Host (o Origin, se bAOrigin) indichi questo server locale.
//** Data Ultima Modifica: 10/11/2026
//***********************************************************************************************************
//** Funzionamento: sono accettati solo 127.0.0.1 e localhost con la porta del
//** servizio (senza porta solo se la porta e' 80, come fanno i browser); per
//** Origin e' richiesto anche il prefisso "http://" (una "/" finale e'
//** ignorata). Il confronto non distingue maiuscole e minuscole.
//***********************************************************************************************************
//***********************************************************************************************************
function TWebOverlayServer.bHostAllowed(const sAValue: string; bAOrigin: Boolean): Boolean;
var
    sHost, sName, sPortText: string;
    iColonPos: Integer;
begin
    sHost := LowerCase(Trim(sAValue));
    if bAOrigin then
    begin
        if not sHost.StartsWith('http://') then
            Exit(False);
        Delete(sHost, 1, Length('http://'));
        if sHost.EndsWith('/') then
            SetLength(sHost, Length(sHost) - 1);
    end;
    iColonPos := LastDelimiter(':', sHost);
    if iColonPos > 0 then
    begin
        sName := Copy(sHost, 1, iColonPos - 1);
        sPortText := Copy(sHost, iColonPos + 1, MaxInt);
    end
    else
    begin
        sName := sHost;
        sPortText := '80';
    end;
    Result := ((sName = '127.0.0.1') or (sName = 'localhost')) and
        (sPortText = IntToStr(oFServer.DefaultPort));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TWebOverlayServer.bRequestAllowed
//** Parametri di ingresso: oARequestInfo: TIdHTTPRequestInfo
//** Parametri di uscita: Result: Boolean
//** Scopo: Verificare che una richiesta arrivi da OBS (o dal browser) sulla pagina del servizio.
//** Data Ultima Modifica: 10/11/2026
//***********************************************************************************************************
//** Funzionamento: protezione dalle pagine web estranee aperte nel browser:
//** - Host deve indicare 127.0.0.1 o localhost con la porta del servizio:
//**   blocca il "DNS rebinding" (un sito che fa puntare il proprio nome a
//**   127.0.0.1 manda comunque il proprio nome come Host);
//** - Origin, se presente, deve essere la pagina del servizio: il browser non
//**   applica alle WebSocket le regole tra siti diversi, quindi senza questo
//**   controllo qualsiasi sito potrebbe ricevere i fotogrammi. Le richieste
//**   senza Origin (non partite da una pagina web) sono accettate.
//***********************************************************************************************************
//***********************************************************************************************************
function TWebOverlayServer.bRequestAllowed(oARequestInfo: TIdHTTPRequestInfo): Boolean;
var
    sOrigin: string;
begin
    Result := bHostAllowed(oARequestInfo.RawHeaders.Values['Host'], False);
    if Result then
    begin
        sOrigin := Trim(oARequestInfo.RawHeaders.Values['Origin']);
        Result := (sOrigin = '') or bHostAllowed(sOrigin, True);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWebOverlayServer.CommandGet
//** Parametri di ingresso: oAContext: TIdContext; oARequestInfo: TIdHTTPRequestInfo; oAResponseInfo:
//**                        TIdHTTPResponseInfo
//** Parametri di uscita: nessuno
//** Scopo: Rispondere alle richieste del browser (eseguita nei thread di Indy).
//** Data Ultima Modifica: 10/11/2026
//***********************************************************************************************************
//** Funzionamento: una richiesta non ammessa da bRequestAllowed riceve 403 e
//** la connessione viene chiusa. "/" e "/index.html" -> pagina HTML; "/ws" -> connessione
//** WebSocket (ServeWebSocket); "/frame.png" -> ultimo fotogramma (204 se non
//** ce n'e' ancora uno); tutto il resto -> 404. Nessuna risposta viene
//** memorizzata nella cache del browser.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TWebOverlayServer.CommandGet(oAContext: TIdContext; oARequestInfo: TIdHTTPRequestInfo;
    oAResponseInfo: TIdHTTPResponseInfo);
var
    sDoc: string;
    aData: TBytes;
begin
    if not bRequestAllowed(oARequestInfo) then
    begin
        oAResponseInfo.ResponseNo := 403;
        oAResponseInfo.CloseConnection := True;
        Exit;
    end;
    sDoc := LowerCase(oARequestInfo.Document);
    if sDoc = '/ws' then
    begin
        ServeWebSocket(oAContext, oARequestInfo, oAResponseInfo);
        Exit;
    end;
    oAResponseInfo.CustomHeaders.Values['Cache-Control'] := 'no-store';
    if (sDoc = '/') or (sDoc = '/index.html') then
    begin
        oAResponseInfo.ContentType := 'text/html';
        oAResponseInfo.CharSet := 'utf-8';
        oAResponseInfo.ContentText := sPageHtml;
    end
    else if sDoc = '/frame.png' then
    begin
        oFLock.Enter;
        try
            aData := aFPng;
        finally
            oFLock.Leave;
        end;
        if Length(aData) = 0 then
            oAResponseInfo.ResponseNo := 204
        else
        begin
            oAResponseInfo.ContentType := 'image/png';
            oAResponseInfo.ContentStream := TBytesStream.Create(aData);
            oAResponseInfo.FreeContentStream := True;
        end;
    end
    else
        oAResponseInfo.ResponseNo := 404;
end;

initialization
    InitCrcTable;

end.
