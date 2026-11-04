//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.WebOverlay
//** Scopo: Servizio "Browser Source" per OBS (server HTTP/WebSocket locale) ed elenco dei monitor.
//** Data Ultima Modifica: 31/10/2026
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
//** NativeScreenSize: risoluzione nativa (in pixel reali) del monitor
//** principale, valore iniziale della risoluzione del servizio.
//** ListMonitors / OtherMonitors / FindMonitor / MonitorText: monitor collegati,
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
        FServer: TIdHTTPServer;
        FLock: TCriticalSection;
        FEncoder: TThread;             // thread di codifica (TObsEncoder)
        FWake: TEvent;                 // sveglia il thread di codifica
        FPending: TBytes;              // pixel in attesa di codifica (premoltiplicati)
        FPendRect: TRect;              // area dei pixel in attesa, nella pagina
        FPendBgr: Boolean;             // ordine dei canali BGRA (altrimenti RGBA)
        FHasPending: Boolean;
        FMessage: TIdBytes;            // ultimo fotogramma pronto, gia' come messaggio WebSocket
        FPng: TBytes;                  // ultimo fotogramma come PNG (/frame.png)
        FSeq: Integer;                 // numero dell'ultimo fotogramma pronto
        FWidth, FHeight: Integer;
        FStopping: Boolean;
        FClients: Integer;             // connessioni WebSocket aperte
        FSent: Integer;                // fotogrammi inviati (somma su tutte le connessioni)
        FEncoded: Integer;             // fotogrammi codificati
        FEncodeMs: Integer;            // tempo di codifica dell'ultimo fotogramma
        FVisible: Integer;             // pixel visibili nell'ultimo fotogramma
        procedure CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
            AResponseInfo: TIdHTTPResponseInfo);
        procedure ServeWebSocket(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
            AResponseInfo: TIdHTTPResponseInfo);
        function HandleIncoming(AIO: TIdIOHandler): Boolean;
        procedure EncodePending;
        function PageHtml: string;
        function GetActive: Boolean;
        function GetPort: Integer;
    public
        constructor Create;
        destructor Destroy; override;
        procedure Start(APort, AWidth, AHeight: Integer);
        procedure Stop;
        /// Nuovo fotogramma: pixel dell'area ARect (righe consecutive, 4 byte per pixel,
        /// alfa premoltiplicato); APixels vuoto o ARect vuoto = nessun widget visibile.
        procedure SubmitFrame(const APixels: TBytes; const ARect: TRect; ABgr: Boolean);
        function Url: string;
        property Active: Boolean read GetActive;
        property Port: Integer read GetPort;
        property Clients: Integer read FClients;
        property FramesSent: Integer read FSent;
        property FramesEncoded: Integer read FEncoded;
        property EncodeMs: Integer read FEncodeMs;
        property VisiblePixels: Integer read FVisible;
    end;

type
    /// Un monitor collegato (coordinate in pixel reali del desktop virtuale).
    TMonitorDesc = record
        Device: string;      // nome del dispositivo (es. \\.\DISPLAY2): salvato nel .ini
        Bounds: TRect;       // area del monitor
        Primary: Boolean;    // monitor principale
    end;

function NativeScreenSize: TSize;
function ObsUrl(APort: Integer): string;
function ListMonitors: TArray<TMonitorDesc>;
function OtherMonitors: TArray<TMonitorDesc>;
function FindMonitor(const ADevice: string; out AMonitor: TMonitorDesc): Boolean;
function PrimaryMonitorRect: TRect;
function MonitorText(const AMonitor: TMonitorDesc): string;

implementation

uses
    Winapi.Windows, System.Math, System.Generics.Collections, System.Diagnostics, System.Hash,
    System.NetEncoding, System.ZLib, IdSocketHandle, Holo.Lang;

type
    /// Thread che comprime in PNG i fotogrammi passati a SubmitFrame.
    TObsEncoder = class(TThread)
    private
        FOwner: TWebOverlayServer;
    protected
        procedure Execute; override;
    public
        constructor Create(AOwner: TWebOverlayServer);
    end;

const
    WS_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';   // costante del protocollo WebSocket (RFC 6455)

var
    GCrcTable: array[0..255] of Cardinal;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: NativeScreenSize
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
function NativeScreenSize: TSize;
const
    // ENUM_CURRENT_SETTINGS di Windows (non dichiarata in Winapi.Windows): modalita' video corrente
    CURRENT_SETTINGS = DWORD(-1);
var
    DM: TDeviceMode;
begin
    FillChar(DM, SizeOf(DM), 0);
    DM.dmSize := SizeOf(DM);
    if EnumDisplaySettings(nil, CURRENT_SETTINGS, DM) and (DM.dmPelsWidth > 0) then
        Result := TSize.Create(DM.dmPelsWidth, DM.dmPelsHeight)
    else
        Result := TSize.Create(GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: ObsUrl
//** Parametri di ingresso: APort: Integer
//** Parametri di uscita: Result: string
//** Scopo: Indirizzo da inserire nel Browser Source di OBS per la porta indicata.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function ObsUrl(APort: Integer): string;
begin
    Result := Format('http://127.0.0.1:%d/', [APort]);
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
//** Nome funzione: MonitorEnumProc
//** Parametri di ingresso: AMonitor: THandle; ADC: HDC; ARect: PRect; AData: LPARAM
//** Parametri di uscita: Result: BOOL
//** Scopo: Callback di EnumDisplayMonitors: aggiungere un monitor alla lista passata in AData.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function MonitorEnumProc(AMonitor: THandle; ADC: HDC; ARect: PRect; AData: LPARAM): BOOL; stdcall;
var
    Info: TMonInfoEx;
    M: TMonitorDesc;
begin
    Result := True;
    FillChar(Info, SizeOf(Info), 0);
    Info.cbSize := SizeOf(Info);
    if not HoloGetMonitorInfo(AMonitor, Info) then
        Exit;
    M.Device := string(PWideChar(@Info.szDevice[0]));
    M.Bounds := Info.rcMonitor;
    M.Primary := (Info.dwFlags and MON_PRIMARY) <> 0;
    TList<TMonitorDesc>(Pointer(AData)).Add(M);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: ListMonitors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TArray<TMonitorDesc>
//** Scopo: Elenco dei monitor collegati (nome del dispositivo, area in pixel reali, principale).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function ListMonitors: TArray<TMonitorDesc>;
var
    List: TList<TMonitorDesc>;
begin
    List := TList<TMonitorDesc>.Create;
    try
        HoloEnumDisplayMonitors(0, nil, MonitorEnumProc, LPARAM(Pointer(List)));
        Result := List.ToArray;
    finally
        List.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: OtherMonitors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TArray<TMonitorDesc>
//** Scopo: Monitor su cui spostare la finestra durante il servizio OBS: tutti tranne il principale
//**        (quello su cui l'overlay dispone i widget).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function OtherMonitors: TArray<TMonitorDesc>;
var
    M: TMonitorDesc;
begin
    Result := nil;
    for M in ListMonitors do
        if not M.Primary then
            Result := Result + [M];
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: FindMonitor
//** Parametri di ingresso: ADevice: string
//** Parametri di uscita: AMonitor: TMonitorDesc; Result: Boolean
//** Scopo: Cercare un monitor collegato dal nome del dispositivo (es. \\.\DISPLAY2).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function FindMonitor(const ADevice: string; out AMonitor: TMonitorDesc): Boolean;
var
    M: TMonitorDesc;
begin
    Result := False;
    AMonitor := Default(TMonitorDesc);
    if ADevice = '' then
        Exit;
    for M in ListMonitors do
        if SameText(M.Device, ADevice) then
        begin
            AMonitor := M;
            Exit(True);
        end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: PrimaryMonitorRect
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TRect
//** Scopo: Area del monitor principale in pixel reali.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function PrimaryMonitorRect: TRect;
var
    M: TMonitorDesc;
begin
    Result := TRect.Create(0, 0, NativeScreenSize.cx, NativeScreenSize.cy);
    for M in ListMonitors do
        if M.Primary then
            Result := M.Bounds;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: MonitorText
//** Parametri di ingresso: AMonitor: TMonitorDesc
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
function MonitorText(const AMonitor: TMonitorDesc): string;
var
    I, Num, DX, DY: Integer;
    P: TRect;
    Side: string;
begin
    I := Length(AMonitor.Device);
    while (I > 0) and CharInSet(AMonitor.Device[I], ['0'..'9']) do
        Dec(I);
    Num := StrToIntDef(Copy(AMonitor.Device, I + 1, MaxInt), 0);
    P := PrimaryMonitorRect;
    DX := AMonitor.Bounds.CenterPoint.X - P.CenterPoint.X;
    DY := AMonitor.Bounds.CenterPoint.Y - P.CenterPoint.Y;
    if Abs(DX) >= Abs(DY) then
    begin
        if DX < 0 then
            Side := Tr('obs.monitor.left', 'a sinistra del principale')
        else
            Side := Tr('obs.monitor.right', 'a destra del principale');
    end
    else
    begin
        if DY < 0 then
            Side := Tr('obs.monitor.above', 'sopra il principale')
        else
            Side := Tr('obs.monitor.below', 'sotto il principale');
    end;
    Result := Format(Tr('obs.monitor.item', 'Monitor %d  ' + #$00B7 + '  %d x %d  ' + #$00B7 + '  %s'),
        [Num, AMonitor.Bounds.Width, AMonitor.Bounds.Height, Side]);
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
    N, K: Integer;
    C: Cardinal;
begin
    for N := 0 to 255 do
    begin
        C := Cardinal(N);
        for K := 0 to 7 do
            if (C and 1) <> 0 then
                C := $EDB88320 xor (C shr 1)
            else
                C := C shr 1;
        GCrcTable[N] := C;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: UpdateCrc
//** Parametri di ingresso: ACrc: Cardinal; AData: TBytes
//** Parametri di uscita: Result: Cardinal
//** Scopo: Aggiornare un CRC-32 con i byte indicati.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function UpdateCrc(ACrc: Cardinal; const AData: TBytes): Cardinal;
var
    I: Integer;
begin
    Result := ACrc;
    for I := 0 to High(AData) do
        Result := GCrcTable[(Result xor AData[I]) and $FF] xor (Result shr 8);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: WriteBE32
//** Parametri di ingresso: AStream: TStream; AValue: Cardinal
//** Parametri di uscita: nessuno
//** Scopo: Scrivere un intero a 32 bit nell'ordine big-endian richiesto dal formato PNG.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure WriteBE32(AStream: TStream; AValue: Cardinal);
var
    B: array[0..3] of Byte;
begin
    B[0] := Byte(AValue shr 24);
    B[1] := Byte(AValue shr 16);
    B[2] := Byte(AValue shr 8);
    B[3] := Byte(AValue);
    AStream.WriteBuffer(B, 4);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: WritePngChunk
//** Parametri di ingresso: AStream: TStream; AType: string; AData: TBytes
//** Parametri di uscita: nessuno
//** Scopo: Scrivere un blocco PNG (lunghezza, tipo, dati, CRC).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure WritePngChunk(AStream: TStream; const AType: string; const AData: TBytes);
var
    T: TBytes;
begin
    T := TEncoding.ASCII.GetBytes(AType);
    WriteBE32(AStream, Cardinal(Length(AData)));
    AStream.WriteBuffer(T[0], 4);
    if Length(AData) > 0 then
        AStream.WriteBuffer(AData[0], Length(AData));
    WriteBE32(AStream, not UpdateCrc(UpdateCrc($FFFFFFFF, T), AData));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: EncodePng
//** Parametri di ingresso: APix: TBytes; AW, AH: Integer; ABgr: Boolean
//** Parametri di uscita: AVisible: Integer; Result: TBytes
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
function EncodePng(const APix: TBytes; AW, AH: Integer; ABgr: Boolean; out AVisible: Integer): TBytes;
const
    SIGNATURE: array[0..7] of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);
var
    Raw, Z, Hdr: TBytes;
    X, Y, S, D, RowLen: Integer;
    A, R, G, B: Integer;
    MS: TBytesStream;
begin
    AVisible := 0;
    RowLen := AW * 4 + 1;
    SetLength(Raw, RowLen * AH);
    for Y := 0 to AH - 1 do
    begin
        D := Y * RowLen;
        Raw[D] := 0;
        Inc(D);
        S := Y * AW * 4;
        for X := 0 to AW - 1 do
        begin
            if ABgr then
            begin
                R := APix[S + 2];
                B := APix[S];
            end
            else
            begin
                R := APix[S];
                B := APix[S + 2];
            end;
            G := APix[S + 1];
            // le parti traslucide sovrapposte e le luci dei comandi premuti possono
            // avere colori piu' alti dell'alfa (luce "additiva"): l'alfa sale al canale
            // piu' alto, cosi' il colore resta lo stesso invece di saturare verso il bianco
            A := Max(Integer(APix[S + 3]), Max(R, Max(G, B)));
            if A = 0 then
            begin
                Raw[D] := 0;
                Raw[D + 1] := 0;
                Raw[D + 2] := 0;
                Raw[D + 3] := 0;
            end
            else
            begin
                if A < 255 then
                begin
                    R := Min(255, (R * 255 + A div 2) div A);
                    G := Min(255, (G * 255 + A div 2) div A);
                    B := Min(255, (B * 255 + A div 2) div A);
                end;
                Raw[D] := Byte(R);
                Raw[D + 1] := Byte(G);
                Raw[D + 2] := Byte(B);
                Raw[D + 3] := Byte(A);
                if A > 16 then
                    Inc(AVisible);
            end;
            Inc(S, 4);
            Inc(D, 4);
        end;
    end;
    ZCompress(Raw, Z, zcFastest);

    SetLength(Hdr, 13);
    Hdr[0] := Byte(AW shr 24);
    Hdr[1] := Byte(AW shr 16);
    Hdr[2] := Byte(AW shr 8);
    Hdr[3] := Byte(AW);
    Hdr[4] := Byte(AH shr 24);
    Hdr[5] := Byte(AH shr 16);
    Hdr[6] := Byte(AH shr 8);
    Hdr[7] := Byte(AH);
    Hdr[8] := 8;      // bit per canale
    Hdr[9] := 6;      // RGBA
    Hdr[10] := 0;     // compressione deflate
    Hdr[11] := 0;     // filtro standard
    Hdr[12] := 0;     // non interlacciato

    MS := TBytesStream.Create;
    try
        MS.WriteBuffer(SIGNATURE, SizeOf(SIGNATURE));
        WritePngChunk(MS, 'IHDR', Hdr);
        WritePngChunk(MS, 'IDAT', Z);
        WritePngChunk(MS, 'IEND', nil);
        Result := Copy(MS.Bytes, 0, MS.Size);
    finally
        MS.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: BuildWsMessage
//** Parametri di ingresso: ARect: TRect; APng: TBytes
//** Parametri di uscita: Result: TIdBytes
//** Scopo: Preparare il messaggio WebSocket binario di un fotogramma (area + PNG).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: intestazione WebSocket (FIN + binario, lunghezza a 7, 16 o
//** 64 bit, nessuna maschera perche' parte dal server), poi X, Y, larghezza e
//** altezza come interi a 32 bit little-endian e infine il PNG.
//***********************************************************************************************************
//***********************************************************************************************************
function BuildWsMessage(const ARect: TRect; const APng: TBytes): TIdBytes;
var
    PayLen: Int64;
    HL, I, P: Integer;
    V: array[0..3] of Integer;
begin
    PayLen := 16 + Length(APng);
    if PayLen < 126 then
        HL := 2
    else if PayLen < 65536 then
        HL := 4
    else
        HL := 10;
    SetLength(Result, Integer(HL + PayLen));
    Result[0] := $82;
    case HL of
        2:
            Result[1] := Byte(PayLen);
        4:
            begin
                Result[1] := 126;
                Result[2] := Byte(PayLen shr 8);
                Result[3] := Byte(PayLen);
            end;
    else
        Result[1] := 127;
        for I := 0 to 7 do
            Result[2 + I] := Byte(PayLen shr (8 * (7 - I)));
    end;
    V[0] := ARect.Left;
    V[1] := ARect.Top;
    V[2] := ARect.Width;
    V[3] := ARect.Height;
    P := HL;
    for I := 0 to 3 do
    begin
        Result[P] := Byte(V[I]);
        Result[P + 1] := Byte(V[I] shr 8);
        Result[P + 2] := Byte(V[I] shr 16);
        Result[P + 3] := Byte(V[I] shr 24);
        Inc(P, 4);
    end;
    if Length(APng) > 0 then
        Move(APng[0], Result[P], Length(APng));
end;

//** TObsEncoder ********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TObsEncoder.Create
//** Parametri di ingresso: AOwner: TWebOverlayServer
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare e avviare il thread di codifica dei fotogrammi del server indicato.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
constructor TObsEncoder.Create(AOwner: TWebOverlayServer);
begin
    FOwner := AOwner;
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
        FOwner.FWake.WaitFor(250);
        if not Terminated then
            FOwner.EncodePending;
    end;
end;

//** TWebOverlayServer **************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWebOverlayServer.Create
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare il server (fermo), il lock dei fotogrammi e l'evento del thread di codifica.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
constructor TWebOverlayServer.Create;
begin
    inherited;
    FLock := TCriticalSection.Create;
    FWake := TEvent.Create(nil, False, False, '');
    FServer := TIdHTTPServer.Create(nil);
    FServer.OnCommandGet := CommandGet;
    FWidth := 1920;
    FHeight := 1080;
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
    FServer.Free;
    FWake.Free;
    FLock.Free;
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWebOverlayServer.Start
//** Parametri di ingresso: APort, AWidth, AHeight: Integer
//** Parametri di uscita: nessuno
//** Scopo: Avviare il server su 127.0.0.1:APort per una pagina di AWidth x AHeight pixel.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: se il server e' gia' attivo lo riavvia con i nuovi
//** parametri (le pagine aperte in OBS si ricollegano da sole); l'ascolto e'
//** solo sull'interfaccia locale. Se la porta e' gia' occupata l'eccezione di
//** Indy arriva al chiamante. Il thread di codifica parte solo a server avviato.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TWebOverlayServer.Start(APort, AWidth, AHeight: Integer);
var
    B: TIdSocketHandle;
begin
    Stop;
    FWidth := Max(16, AWidth);
    FHeight := Max(16, AHeight);
    FSent := 0;
    FEncoded := 0;
    FEncodeMs := 0;
    FVisible := 0;
    FServer.Bindings.Clear;
    B := FServer.Bindings.Add;
    B.IP := '127.0.0.1';
    B.Port := APort;
    FServer.DefaultPort := APort;
    FServer.Active := True;
    FEncoder := TObsEncoder.Create(Self);
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
//** Funzionamento: FStopping fa uscire i cicli delle connessioni WebSocket;
//** Indy chiude i socket e attende i suoi thread; poi si ferma il thread di
//** codifica e si scartano i fotogrammi rimasti.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TWebOverlayServer.Stop;
begin
    FStopping := True;
    try
        if FServer.Active then
            FServer.Active := False;
    finally
        if FEncoder <> nil then
        begin
            FEncoder.Terminate;
            FWake.SetEvent;
            FEncoder.WaitFor;
            FreeAndNil(FEncoder);
        end;
        FStopping := False;
    end;
    FLock.Enter;
    try
        FPending := nil;
        FHasPending := False;
        FMessage := nil;
        FPng := nil;
    finally
        FLock.Leave;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TWebOverlayServer.GetActive
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Indicare se il server e' in ascolto.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TWebOverlayServer.GetActive: Boolean;
begin
    Result := FServer.Active;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TWebOverlayServer.GetPort
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Integer
//** Scopo: Porta su cui il server e' in ascolto (o configurata).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TWebOverlayServer.GetPort: Integer;
begin
    Result := FServer.DefaultPort;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TWebOverlayServer.Url
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Indirizzo della pagina da usare in OBS.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TWebOverlayServer.Url: string;
begin
    Result := ObsUrl(Port);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWebOverlayServer.SubmitFrame
//** Parametri di ingresso: APixels: TBytes; ARect: TRect; ABgr: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Consegnare al thread di codifica un nuovo fotogramma (chiamata dal thread principale).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: sostituisce l'eventuale fotogramma non ancora codificato
//** (cosi' il ritardo non si accumula) e sveglia il thread di codifica. Il
//** vettore dei pixel non va piu' modificato dal chiamante.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TWebOverlayServer.SubmitFrame(const APixels: TBytes; const ARect: TRect; ABgr: Boolean);
begin
    if FEncoder = nil then
        Exit;
    FLock.Enter;
    try
        FPending := APixels;
        FPendRect := ARect;
        FPendBgr := ABgr;
        FHasPending := True;
    finally
        FLock.Leave;
    end;
    FWake.SetEvent;
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
//** incrementando FSeq (le connessioni inviano ogni FSeq nuovo). Un'area vuota
//** produce un messaggio senza PNG, che svuota la pagina.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TWebOverlayServer.EncodePending;
var
    Pix, Png: TBytes;
    R: TRect;
    Bgr: Boolean;
    Vis: Integer;
    Msg: TIdBytes;
    Watch: TStopwatch;
begin
    FLock.Enter;
    try
        if not FHasPending then
            Exit;
        Pix := FPending;
        FPending := nil;
        R := FPendRect;
        Bgr := FPendBgr;
        FHasPending := False;
    finally
        FLock.Leave;
    end;
    Watch := TStopwatch.StartNew;
    Vis := 0;
    Png := nil;
    if (R.Width > 0) and (R.Height > 0) and (Length(Pix) >= R.Width * R.Height * 4) then
        Png := EncodePng(Pix, R.Width, R.Height, Bgr, Vis)
    else
        R := Rect(0, 0, 0, 0);
    Msg := BuildWsMessage(R, Png);
    FLock.Enter;
    try
        FMessage := Msg;
        FPng := Png;
        Inc(FSeq);
        Inc(FEncoded);
        FVisible := Vis;
        FEncodeMs := Watch.ElapsedMilliseconds;
    finally
        FLock.Leave;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TWebOverlayServer.PageHtml
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
function TWebOverlayServer.PageHtml: string;
begin
    Result :=
        '<!DOCTYPE html><html><head><meta charset="utf-8"><title>HoloInput Overlay</title>' +
        '<style>html,body{margin:0;padding:0;background:transparent;overflow:hidden;}' +
        'canvas{position:absolute;left:0;top:0;}</style></head><body>' +
        Format('<canvas id="c" width="%d" height="%d"></canvas>', [FWidth, FHeight]) +
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
//** Nome funzione: TWebOverlayServer.HandleIncoming
//** Parametri di ingresso: AIO: TIdIOHandler
//** Parametri di uscita: Result: Boolean
//** Scopo: Leggere un messaggio WebSocket arrivato dal browser; False se la connessione va chiusa.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: la pagina non invia dati, quindi interessano solo i
//** messaggi di controllo: "close" (si risponde e si chiude) e "ping" (si
//** risponde con "pong"); gli altri vengono letti e ignorati. I messaggi del
//** browser sono sempre mascherati (RFC 6455). Un messaggio troppo grande e'
//** considerato anomalo e chiude la connessione.
//***********************************************************************************************************
//***********************************************************************************************************
function TWebOverlayServer.HandleIncoming(AIO: TIdIOHandler): Boolean;
var
    B0, B1, Op: Byte;
    Len: Int64;
    I: Integer;
    Ext, Mask, Data, Reply: TIdBytes;
begin
    Result := True;
    B0 := AIO.ReadByte;
    B1 := AIO.ReadByte;
    Op := B0 and $0F;
    Len := B1 and $7F;
    if Len = 126 then
    begin
        AIO.ReadBytes(Ext, 2, False);
        Len := (Int64(Ext[0]) shl 8) or Ext[1];
    end
    else if Len = 127 then
    begin
        AIO.ReadBytes(Ext, 8, False);
        Len := 0;
        for I := 0 to 7 do
            Len := (Len shl 8) or Ext[I];
    end;
    if Len > 65536 then
        Exit(False);
    SetLength(Mask, 0);
    if (B1 and $80) <> 0 then
        AIO.ReadBytes(Mask, 4, False);
    SetLength(Data, 0);
    if Len > 0 then
        AIO.ReadBytes(Data, Integer(Len), False);
    if Length(Mask) = 4 then
        for I := 0 to High(Data) do
            Data[I] := Data[I] xor Mask[I and 3];
    case Op of
        8:  // close
            begin
                SetLength(Reply, 2);
                Reply[0] := $88;
                Reply[1] := 0;
                AIO.Write(Reply);
                Result := False;
            end;
        9:  // ping -> pong con gli stessi dati
            begin
                SetLength(Reply, 2 + Length(Data));
                Reply[0] := $8A;
                Reply[1] := Byte(Length(Data));
                if Length(Data) > 0 then
                    Move(Data[0], Reply[2], Length(Data));
                AIO.Write(Reply);
            end;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWebOverlayServer.ServeWebSocket
//** Parametri di ingresso: AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo:
//**                        TIdHTTPResponseInfo
//** Parametri di uscita: nessuno
//** Scopo: Gestire una connessione WebSocket di OBS (eseguita nel thread di Indy della
//**        connessione).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: verifica la richiesta di upgrade, risponde con
//** "101 Switching Protocols" e la chiave Sec-WebSocket-Accept (SHA-1 della
//** chiave del browser + WS_GUID, in Base64) scritti direttamente sul socket,
//** poi resta in ciclo finche' la connessione e' aperta: gestisce i messaggi
//** del browser e invia ogni fotogramma nuovo (FSeq cambiato); tra un
//** controllo e l'altro attende 2 ms. A fine connessione Indy chiude il
//** socket (CloseConnection).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TWebOverlayServer.ServeWebSocket(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
    AResponseInfo: TIdHTTPResponseInfo);
var
    IO: TIdIOHandler;
    Key, Accept: string;
    Last, Seq: Integer;
    Msg: TIdBytes;
begin
    Key := Trim(ARequestInfo.RawHeaders.Values['Sec-WebSocket-Key']);
    if (Key = '') or not SameText(Trim(ARequestInfo.RawHeaders.Values['Upgrade']), 'websocket') then
    begin
        AResponseInfo.ResponseNo := 400;
        Exit;
    end;
    Accept := TNetEncoding.Base64.EncodeBytesToString(THashSHA1.GetHashBytes(Key + WS_GUID));
    IO := AContext.Connection.IOHandler;
    IO.Write('HTTP/1.1 101 Switching Protocols'#13#10 +
        'Upgrade: websocket'#13#10 +
        'Connection: Upgrade'#13#10 +
        'Sec-WebSocket-Accept: ' + Accept + #13#10#13#10);
    AResponseInfo.HeaderHasBeenWritten := True;
    AResponseInfo.CloseConnection := True;
    TInterlocked.Increment(FClients);
    try
        Last := -1;
        while not FStopping and AContext.Connection.Connected do
        begin
            if IO.InputBufferIsEmpty then
                IO.CheckForDataOnSource(0);
            if not IO.InputBufferIsEmpty then
                if not HandleIncoming(IO) then
                    Break;
            FLock.Enter;
            try
                Seq := FSeq;
                Msg := FMessage;
            finally
                FLock.Leave;
            end;
            if (Seq <> Last) and (Length(Msg) > 0) then
            begin
                IO.Write(Msg);
                Last := Seq;
                TInterlocked.Increment(FSent);
            end
            else
                Sleep(2);
        end;
    finally
        TInterlocked.Decrement(FClients);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TWebOverlayServer.CommandGet
//** Parametri di ingresso: AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo:
//**                        TIdHTTPResponseInfo
//** Parametri di uscita: nessuno
//** Scopo: Rispondere alle richieste del browser (eseguita nei thread di Indy).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: "/" e "/index.html" -> pagina HTML; "/ws" -> connessione
//** WebSocket (ServeWebSocket); "/frame.png" -> ultimo fotogramma (204 se non
//** ce n'e' ancora uno); tutto il resto -> 404. Nessuna risposta viene
//** memorizzata nella cache del browser.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TWebOverlayServer.CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
    AResponseInfo: TIdHTTPResponseInfo);
var
    Doc: string;
    Data: TBytes;
begin
    Doc := LowerCase(ARequestInfo.Document);
    if Doc = '/ws' then
    begin
        ServeWebSocket(AContext, ARequestInfo, AResponseInfo);
        Exit;
    end;
    AResponseInfo.CustomHeaders.Values['Cache-Control'] := 'no-store';
    if (Doc = '/') or (Doc = '/index.html') then
    begin
        AResponseInfo.ContentType := 'text/html';
        AResponseInfo.CharSet := 'utf-8';
        AResponseInfo.ContentText := PageHtml;
    end
    else if Doc = '/frame.png' then
    begin
        FLock.Enter;
        try
            Data := FPng;
        finally
            FLock.Leave;
        end;
        if Length(Data) = 0 then
            AResponseInfo.ResponseNo := 204
        else
        begin
            AResponseInfo.ContentType := 'image/png';
            AResponseInfo.ContentStream := TBytesStream.Create(Data);
            AResponseInfo.FreeContentStream := True;
        end;
    end
    else
        AResponseInfo.ResponseNo := 404;
end;

initialization
    InitCrcTable;

end.
