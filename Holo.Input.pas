//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Input
//** Scopo: Acquisizione globale degli input, funzionante anche quando il gioco ha il fuoco (l'overlay non e'
//**        mai la finestra attiva).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: - Tastiera e mouse : Raw Input (WM_INPUT) con RIDEV_INPUTSINK.
//**                        La tastiera e' identificata per SCAN CODE (posizione
//**                        fisica), quindi funziona con qualunque layout (IT, US..).
//**                        Il mouse fornisce i delta grezzi anche quando il gioco
//**                        blocca/nasconde il cursore.
//**   - Gamepad          : XInput (caricato dinamicamente, slot 0..3).
//**   - Joystick/pulsantiere : identificati dall'ID WinMM (0..15, quello salvato
//**                        nel .ini). WinMM (joyGetPosEx) pero' aggiorna i dati
//**                        solo quando HoloInput e' in primo piano, quindi i
//**                        dispositivi vengono letti anche in Raw Input HID
//**                        (RIDEV_INPUTSINK, funziona in background): ogni ID
//**                        WinMM viene abbinato al dispositivo HID con lo stesso
//**                        VID/PID (a parita' di VID/PID nell'ordine dei nomi) e,
//**                        appena quel dispositivo invia dati, si usano quelli.
//**                        WinMM resta per le caratteristiche, per i dispositivi
//**                        senza abbinamento HID e finche' non arrivano dati HID.
//**                        Assi HID -> assi WinMM: X, Y, Z (o Slider/Dial),
//**                        R = Rz (o Ry/Slider/Dial), U = Rx, V = Ry (o Slider/Dial).
//**   - Hotkey globali   : RegisterHotKey.
//**
//** Tutte le API Win32 usate sono dichiarate localmente con nomi propri per non
//** dipendere dalle differenze tra le versioni di Winapi.Windows/MMSystem.
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.Input;

interface

uses
    Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Math;

const
    MAX_JOY   = 16;
    MAX_PADS  = 4;
    KEY_IDS   = 512;   // scan code 0..255 + 256 per i tasti estesi (prefisso E0)
    JOY_AXES  = 6;     // X, Y, Z, R, U, V

    //** Scan code (set 1). I tasti estesi E0 hanno +$100. **************************************************
    SC_ESC = $01; SC_1 = $02; SC_2 = $03; SC_3 = $04; SC_4 = $05; SC_5 = $06;
    SC_6 = $07; SC_7 = $08; SC_8 = $09; SC_9 = $0A; SC_0 = $0B;
    SC_MINUS = $0C; SC_EQUAL = $0D; SC_BKSP = $0E; SC_TAB = $0F;
    SC_Q = $10; SC_W = $11; SC_E = $12; SC_R = $13; SC_T = $14; SC_Y = $15;
    SC_U = $16; SC_I = $17; SC_O = $18; SC_P = $19; SC_LBR = $1A; SC_RBR = $1B;
    SC_ENTER = $1C; SC_LCTRL = $1D;
    SC_A = $1E; SC_S = $1F; SC_D = $20; SC_F = $21; SC_G = $22; SC_H = $23;
    SC_J = $24; SC_K = $25; SC_L = $26; SC_SEMI = $27; SC_QUOTE = $28; SC_GRAVE = $29;
    SC_LSHIFT = $2A; SC_BSLASH = $2B;
    SC_Z = $2C; SC_X = $2D; SC_C = $2E; SC_V = $2F; SC_B = $30; SC_N = $31; SC_M = $32;
    SC_COMMA = $33; SC_DOT = $34; SC_SLASH = $35; SC_RSHIFT = $36; SC_NUMMUL = $37;
    SC_LALT = $38; SC_SPACE = $39; SC_CAPS = $3A;
    SC_F1 = $3B; SC_F2 = $3C; SC_F3 = $3D; SC_F4 = $3E; SC_F5 = $3F; SC_F6 = $40;
    SC_F7 = $41; SC_F8 = $42; SC_F9 = $43; SC_F10 = $44;
    SC_PAUSE = $45; SC_SCROLL = $46;
    SC_NUM7 = $47; SC_NUM8 = $48; SC_NUM9 = $49; SC_NUMSUB = $4A;
    SC_NUM4 = $4B; SC_NUM5 = $4C; SC_NUM6 = $4D; SC_NUMADD = $4E;
    SC_NUM1 = $4F; SC_NUM2 = $50; SC_NUM3 = $51; SC_NUM0 = $52; SC_NUMDEL = $53;
    SC_ISO102 = $56; SC_F11 = $57; SC_F12 = $58;
    SC_NUMENTER = $11C; SC_RCTRL = $11D; SC_NUMDIV = $135; SC_PRTSC = $137;
    SC_RALT = $138; SC_NUMLOCK = $145; SC_HOME = $147; SC_UP = $148; SC_PGUP = $149;
    SC_LEFT = $14B; SC_RIGHT = $14D; SC_END = $14F; SC_DOWN = $150; SC_PGDN = $151;
    SC_INS = $152; SC_DEL = $153; SC_LWIN = $15B; SC_RWIN = $15C; SC_MENU = $15D;

    //** Pulsanti mouse (bit di TMouseState.Buttons) ********************************************************
    MBTN_LEFT = $01; MBTN_RIGHT = $02; MBTN_MIDDLE = $04; MBTN_X1 = $08; MBTN_X2 = $10;

    //** Pulsanti XInput ************************************************************************************
    XI_DPAD_UP = $0001; XI_DPAD_DOWN = $0002; XI_DPAD_LEFT = $0004; XI_DPAD_RIGHT = $0008;
    XI_START = $0010; XI_BACK = $0020; XI_LTHUMB = $0040; XI_RTHUMB = $0080;
    XI_LSHOULDER = $0100; XI_RSHOULDER = $0200;
    XI_A = $1000; XI_B = $2000; XI_X = $4000; XI_Y = $8000;

    //** Hotkey globali *************************************************************************************
    HK_LOCK    = 1;  // Ctrl+Alt+F12 : blocca/sblocca (click-through)
    HK_SETUP   = 2;  // Ctrl+Alt+F11 : apre il setup
    HK_VISIBLE = 3;  // Ctrl+Alt+F10 : mostra/nasconde l'overlay
    HK_STREAMER = 4; // Ctrl+Alt+F9  : attiva/disattiva la modalita' streamer

type
    TJoyState = record
        Connected: Boolean;
        Axes: array[0..JOY_AXES - 1] of Single;  // -1..+1
        Buttons: UInt32;                         // bit 0 = pulsante 1
        POV: Integer;                            // -1 = centrato, altrimenti gradi 0..359
        function Button(AIndex: Integer): Boolean;
        function Axis(AIndex: Integer): Single;
    end;

    TPadState = record
        Connected: Boolean;
        LX, LY, RX, RY: Single;   // -1..+1 (Y positivo = su)
        LT, RT: Single;           // 0..1
        Buttons: Word;            // maschera XI_*
        function Pressed(AMask: Word): Boolean;
    end;

    TMouseState = record
        Buttons: Byte;            // maschera MBTN_*
        DX, DY: Single;           // movimento grezzo dell'ultimo frame (count)
        PosX, PosY: Single;       // posizione accumulata -1..+1 (NON si ricentra)
        VelX, VelY: Single;       // velocita' smussata -1..+1 (per l'inclinazione)
        WheelDelta: Single;       // scatti della rotella nell'ultimo frame
        WheelAngle: Single;       // angolo accumulato della rotella (gradi)
        WheelPulse: Single;       // 1 dopo uno scatto, decade a 0
        function Pressed(AMask: Byte): Boolean;
    end;

    TInputSnapshot = record
        Keys: array[0..KEY_IDS - 1] of Boolean;
        Mouse: TMouseState;
        Pads: array[0..MAX_PADS - 1] of TPadState;
        Joys: array[0..MAX_JOY - 1] of TJoyState;
        Frame: Cardinal;
    end;
    PInputSnapshot = ^TInputSnapshot;

    TJoyDeviceInfo = record
        Id: Integer;
        Present: Boolean;
        Name: string;
        NumAxes, NumButtons: Integer;
        HasPOV: Boolean;
        Background: Boolean;      // abbinato a un dispositivo HID: letto anche in background
        BgAxes: string;           // assi HID usati per X, Y, Z, R, U, V (es. "X Y Z Rz Rx Ry")
    end;

    THotkeyEvent = procedure(Sender: TObject; AHotkeyId: Integer) of object;

    //** Strutture Win32 dichiarate localmente **************************************************************
    TJoyCapsRec = record
        wMid, wPid: Word;
        szPname: array[0..31] of WideChar;
        wXmin, wXmax, wYmin, wYmax, wZmin, wZmax: UINT;
        wNumButtons, wPeriodMin, wPeriodMax: UINT;
        wRmin, wRmax, wUmin, wUmax, wVmin, wVmax: UINT;
        wCaps, wMaxAxes, wNumAxes, wMaxButtons: UINT;
        szRegKey: array[0..31] of WideChar;
        szOEMVxD: array[0..259] of WideChar;
    end;

    TJoyInfoExRec = record
        dwSize, dwFlags: DWORD;
        dwXpos, dwYpos, dwZpos, dwRpos, dwUpos, dwVpos: DWORD;
        dwButtons, dwButtonNumber, dwPOV: DWORD;
        dwReserved1, dwReserved2: DWORD;
    end;

    TXInputGamepadRec = record
        wButtons: Word;
        bLeftTrigger, bRightTrigger: Byte;
        sThumbLX, sThumbLY, sThumbRX, sThumbRY: SmallInt;
    end;

    TXInputStateRec = record
        dwPacketNumber: DWORD;
        Gamepad: TXInputGamepadRec;
    end;

    TXInputGetStateFn = function(dwUserIndex: DWORD; out State: TXInputStateRec): DWORD; stdcall;

    /// Un valore (asse o hat) di un dispositivo HID.
    THidAxisRec = record
        Usage: Word;              // 0 = assente
        Link: Word;               // link collection (per HidP_GetUsageValue)
        Min, Max: Integer;        // range logico
        BitSize: Word;
        Signed: Boolean;          // range con valori negativi: va esteso il segno
    end;

    /// Un joystick/pulsantiera letto in Raw Input HID.
    THidJoyRec = record
        Handle: THandle;          // handle Raw Input del dispositivo
        Valid: Boolean;           // e' un joystick/gamepad/controller multi-asse leggibile
        Name: string;             // percorso del dispositivo (per l'ordine a parita' di VID/PID)
        Vid, Pid: Word;
        Preparsed: TBytes;        // dati "preparsed" per le funzioni HidP_*
        Axis: array[0..JOY_AXES - 1] of THidAxisRec;   // X, Y, Z, R, U, V
        Hat: THidAxisRec;
        MaxButtons: Cardinal;     // lunghezza massima della lista dei pulsanti premuti
        JoyId: Integer;           // ID WinMM abbinato (-1 = nessuno)
        Live: Boolean;            // ha gia' inviato almeno un rapporto
        State: TJoyState;         // ultimo stato letto
    end;

    //** TInputManager **************************************************************************************
    TInputManager = class
    private
        FWnd: HWND;
        FState: TInputSnapshot;
        FMouseButtons: Byte;
        FRawDX, FRawDY, FRawWheel: Integer;
        FLastAbsX, FLastAbsY: Integer;
        FHasAbs: Boolean;
        FMouseRange: Single;
        FUsedJoy: array[0..MAX_JOY - 1] of Boolean;
        FUsedPad: array[0..MAX_PADS - 1] of Boolean;
        FJoyCaps: array[0..MAX_JOY - 1] of TJoyCapsRec;
        FJoyCapsOk: array[0..MAX_JOY - 1] of Boolean;
        FJoyRetryAt: array[0..MAX_JOY - 1] of UInt64;
        FPadRetryAt: array[0..MAX_PADS - 1] of UInt64;
        FXInputLib: HMODULE;
        FXInputGetState: TXInputGetStateFn;
        FSafetyAt: UInt64;
        FKeyIdleChecks, FBtnIdleChecks: Integer;
        FHotkeysOk: Boolean;
        FStreamerHotkeyOk: Boolean;
        FOnHotkey: THotkeyEvent;
        FHid: TArray<THidJoyRec>;                 // dispositivi HID (joystick, gamepad, multi-asse)
        FJoyHid: array[0..MAX_JOY - 1] of Integer; // ID WinMM -> indice in FHid (-1 = nessuno)
        FJoyCheckAt: array[0..MAX_JOY - 1] of UInt64;  // prossimo controllo di presenza (lettura HID)
        FHidMapDirty: Boolean;                    // abbinamento ID WinMM <-> HID da ricalcolare
        FRawBuf: TBytes;                          // buffer per i pacchetti Raw Input grandi (HID)
        FUsageBuf: array of Word;                 // pulsanti premuti letti da HidP_GetUsages
        procedure WndProc(var AMsg: TMessage);
        procedure HandleRawInput(ARaw: LPARAM);
        procedure RegisterRawDevices;
        procedure LoadXInput;
        function ReadJoyCaps(AId: Integer): Boolean;
        procedure PollJoystick(AId: Integer; ANow: UInt64);
        procedure PollPad(AIndex: Integer; ANow: UInt64);
        procedure SafetyCheck(ANow: UInt64);
        function HidIndex(AHandle: THandle): Integer;
        function AddHidDevice(AHandle: THandle): Integer;
        procedure SyncHidDevices;
        procedure RebuildHidMap;
        procedure HandleHidInput(ADevice: THandle; AData: PByte);
        procedure ParseHidReport(AIndex: Integer; AReport: PByte; ALength: Cardinal);
    public
        constructor Create;
        destructor Destroy; override;
        procedure Poll(ADeltaT: Single);
        procedure ClearUsage;
        procedure UseJoystick(AId: Integer);
        procedure UsePad(AIndex: Integer);
        procedure ResetMouse;
        function RegisterHotkeys: Boolean;
        function EnumJoysticks: TArray<TJoyDeviceInfo>;
        function XInputAvailable: Boolean;
        function PadConnected(AIndex: Integer): Boolean;
        function StatePtr: PInputSnapshot;
        property MouseRange: Single read FMouseRange write FMouseRange;
        property HotkeysOk: Boolean read FHotkeysOk;
        /// True se Ctrl+Alt+F9 (modalita' streamer) e' stato registrato.
        property StreamerHotkeyOk: Boolean read FStreamerHotkeyOk;
        property OnHotkey: THotkeyEvent read FOnHotkey write FOnHotkey;
    end;

implementation

uses
    System.Win.Registry;

//** Dichiarazioni Raw Input / WinMM ************************************************************************
const
    RIDEV_INPUTSINK = $00000100;
    RID_INPUT = $10000003;
    RIM_TYPEMOUSE = 0;
    RIM_TYPEKEYBOARD = 1;
    MOUSE_MOVE_ABSOLUTE = $01;
    RI_MOUSE_LEFT_BUTTON_DOWN = $0001;  RI_MOUSE_LEFT_BUTTON_UP = $0002;
    RI_MOUSE_RIGHT_BUTTON_DOWN = $0004; RI_MOUSE_RIGHT_BUTTON_UP = $0008;
    RI_MOUSE_MIDDLE_BUTTON_DOWN = $0010; RI_MOUSE_MIDDLE_BUTTON_UP = $0020;
    RI_MOUSE_BUTTON_4_DOWN = $0040;     RI_MOUSE_BUTTON_4_UP = $0080;
    RI_MOUSE_BUTTON_5_DOWN = $0100;     RI_MOUSE_BUTTON_5_UP = $0200;
    RI_MOUSE_WHEEL = $0400;
    RI_KEY_BREAK = $01;
    RI_KEY_E0 = $02;
    RI_KEY_E1 = $04;

    JOY_RETURNALL = $000000FF;
    JOYERR_NOERROR = 0;
    JOYCAPS_HASPOV = $0010;

    HI_MOD_NOREPEAT = $4000;

type
    TRawInputDeviceRec = record
        usUsagePage: Word;
        usUsage: Word;
        dwFlags: DWORD;
        hwndTarget: HWND;
    end;

    TRawInputHeaderRec = record
        dwType: DWORD;
        dwSize: DWORD;
        hDevice: THandle;
        wParam: WPARAM;
    end;
    PRawInputHeaderRec = ^TRawInputHeaderRec;

    TRawMouseRec = packed record
        usFlags: Word;
        usPad: Word;
        usButtonFlags: Word;
        usButtonData: Word;
        ulRawButtons: Cardinal;
        lLastX: Integer;
        lLastY: Integer;
        ulExtraInformation: Cardinal;
    end;
    PRawMouseRec = ^TRawMouseRec;

    TRawKeyboardRec = packed record
        MakeCode: Word;
        Flags: Word;
        Reserved: Word;
        VKey: Word;
        Message: Cardinal;
        ExtraInformation: Cardinal;
    end;
    PRawKeyboardRec = ^TRawKeyboardRec;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HI_RegisterRawInputDevices
//** Parametri di ingresso: pRawInputDevices: Pointer; uiNumDevices: UINT; cbSize: UINT
//** Parametri di uscita: Result: BOOL
//** Scopo: Importare da user32.dll la funzione RegisterRawInputDevices per registrare mouse e
//**        tastiera in Raw Input.
//** Data Ultima Modifica: 16/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function HI_RegisterRawInputDevices(pRawInputDevices: Pointer; uiNumDevices: UINT;
    cbSize: UINT): BOOL; stdcall; external user32 name 'RegisterRawInputDevices';
//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HI_GetRawInputData
//** Parametri di ingresso: hRawInput: THandle; uiCommand: UINT; pData: Pointer; pcbSize: UINT
//**                        (var); cbSizeHeader: UINT
//** Parametri di uscita: Result: UINT; pcbSize: UINT (var)
//** Scopo: Importare da user32.dll la funzione GetRawInputData per leggere i pacchetti Raw Input di
//**        mouse e tastiera.
//** Data Ultima Modifica: 16/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function HI_GetRawInputData(hRawInput: THandle; uiCommand: UINT; pData: Pointer;
    var pcbSize: UINT; cbSizeHeader: UINT): UINT; stdcall; external user32 name 'GetRawInputData';
//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HI_joyGetPosEx
//** Parametri di ingresso: uJoyID: UINT; pji: TJoyInfoExRec (var)
//** Parametri di uscita: Result: UINT; pji: TJoyInfoExRec (var)
//** Scopo: Importare da winmm.dll la funzione joyGetPosEx per leggere assi, pulsanti e hat dei
//**        joystick.
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function HI_joyGetPosEx(uJoyID: UINT; var pji: TJoyInfoExRec): UINT; stdcall;
    external 'winmm.dll' name 'joyGetPosEx';
//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HI_joyGetDevCaps
//** Parametri di ingresso: uJoyID: NativeUInt; pjc: TJoyCapsRec (var); cbjc: UINT
//** Parametri di uscita: Result: UINT; pjc: TJoyCapsRec (var)
//** Scopo: Importare da winmm.dll la funzione joyGetDevCapsW per leggere le caratteristiche (range
//**        degli assi) dei joystick.
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function HI_joyGetDevCaps(uJoyID: NativeUInt; var pjc: TJoyCapsRec; cbjc: UINT): UINT; stdcall;
    external 'winmm.dll' name 'joyGetDevCapsW';

//** Dichiarazioni Raw Input HID (joystick letti in background) *********************************************
const
    RIM_TYPEHID = 2;
    RIDI_PREPARSEDDATA = $20000005;
    RIDI_DEVICENAME = $20000007;
    RIDI_DEVICEINFO = $2000000B;
    HIDP_INPUT = 0;                       // HIDP_REPORT_TYPE: HidP_Input
    HIDP_STATUS_SUCCESS = $00110000;
    HID_PAGE_DESKTOP = $01;
    HID_PAGE_BUTTON = $09;
    HID_USAGE_JOYSTICK = $04;
    HID_USAGE_GAMEPAD = $05;
    HID_USAGE_MULTIAXIS = $08;
    HID_USAGE_X = $30;                    // X, Y, Z, Rx, Ry, Rz, Slider, Dial = $30..$37
    HID_USAGE_HAT = $39;
    HID_AXIS_NAMES: array[0..7] of string = ('X', 'Y', 'Z', 'Rx', 'Ry', 'Rz', 'Slider', 'Dial');

type
    TRawInputDeviceListRec = record
        hDevice: THandle;
        dwType: DWORD;
    end;

    /// RID_DEVICE_INFO con la parte "hid" dell'unione (32 byte come in Windows).
    TRidDeviceInfoRec = record
        cbSize: DWORD;
        dwType: DWORD;
        dwVendorId: DWORD;
        dwProductId: DWORD;
        dwVersionNumber: DWORD;
        usUsagePage: Word;
        usUsage: Word;
        Pad: array[0..7] of Byte;
    end;

    THidpCapsRec = record
        Usage, UsagePage: Word;
        InputReportByteLength, OutputReportByteLength, FeatureReportByteLength: Word;
        Reserved: array[0..16] of Word;
        NumberLinkCollectionNodes: Word;
        NumberInputButtonCaps, NumberInputValueCaps, NumberInputDataIndices: Word;
        NumberOutputButtonCaps, NumberOutputValueCaps, NumberOutputDataIndices: Word;
        NumberFeatureButtonCaps, NumberFeatureValueCaps, NumberFeatureDataIndices: Word;
    end;

    /// HIDP_VALUE_CAPS (72 byte); per i valori singoli (IsRange = 0) Usage = UsageMin.
    THidpValueCapsRec = packed record
        UsagePage: Word;
        ReportID: Byte;
        IsAlias: Byte;
        BitField: Word;
        LinkCollection: Word;
        LinkUsage: Word;
        LinkUsagePage: Word;
        IsRange: Byte;
        IsStringRange: Byte;
        IsDesignatorRange: Byte;
        IsAbsolute: Byte;
        HasNull: Byte;
        Reserved: Byte;
        BitSize: Word;
        ReportCount: Word;
        Reserved2: array[0..4] of Word;
        UnitsExp: Cardinal;
        Units: Cardinal;
        LogicalMin: Integer;
        LogicalMax: Integer;
        PhysicalMin: Integer;
        PhysicalMax: Integer;
        UsageMin: Word;
        UsageMax: Word;
        Other: array[0..5] of Word;
    end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HI_GetRawInputDeviceList
//** Parametri di ingresso: pList: Pointer; puiNumDevices: UINT (var); cbSize: UINT
//** Parametri di uscita: Result: UINT; puiNumDevices: UINT (var)
//** Scopo: Importare da user32.dll la funzione GetRawInputDeviceList (elenco dei dispositivi Raw
//**        Input).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function HI_GetRawInputDeviceList(pList: Pointer; var puiNumDevices: UINT; cbSize: UINT): UINT; stdcall;
    external user32 name 'GetRawInputDeviceList';
//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HI_GetRawInputDeviceInfo
//** Parametri di ingresso: hDevice: THandle; uiCommand: UINT; pData: Pointer; pcbSize: UINT (var)
//** Parametri di uscita: Result: UINT; pcbSize: UINT (var)
//** Scopo: Importare da user32.dll la funzione GetRawInputDeviceInfoW (nome, VID/PID e dati
//**        preparsed di un dispositivo).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function HI_GetRawInputDeviceInfo(hDevice: THandle; uiCommand: UINT; pData: Pointer;
    var pcbSize: UINT): UINT; stdcall; external user32 name 'GetRawInputDeviceInfoW';
//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HI_HidP_GetCaps
//** Parametri di ingresso: PreparsedData: Pointer; Capabilities: THidpCapsRec (var)
//** Parametri di uscita: Result: Integer (NTSTATUS); Capabilities: THidpCapsRec (var)
//** Scopo: Importare da hid.dll la funzione HidP_GetCaps (caratteristiche di un dispositivo HID).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function HI_HidP_GetCaps(PreparsedData: Pointer; var Capabilities: THidpCapsRec): Integer; stdcall;
    external 'hid.dll' name 'HidP_GetCaps';
//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HI_HidP_GetValueCaps
//** Parametri di ingresso: ReportType: Integer; ValueCaps: Pointer; ValueCapsLength: Word (var);
//**                        PreparsedData: Pointer
//** Parametri di uscita: Result: Integer (NTSTATUS); ValueCapsLength: Word (var)
//** Scopo: Importare da hid.dll la funzione HidP_GetValueCaps (assi e hat di un dispositivo HID).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function HI_HidP_GetValueCaps(ReportType: Integer; ValueCaps: Pointer; var ValueCapsLength: Word;
    PreparsedData: Pointer): Integer; stdcall; external 'hid.dll' name 'HidP_GetValueCaps';
//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HI_HidP_GetUsageValue
//** Parametri di ingresso: ReportType: Integer; UsagePage, LinkCollection, Usage: Word;
//**                        UsageValue: Cardinal (var); PreparsedData, Report: Pointer;
//**                        ReportLength: Cardinal
//** Parametri di uscita: Result: Integer (NTSTATUS); UsageValue: Cardinal (var)
//** Scopo: Importare da hid.dll la funzione HidP_GetUsageValue (valore di un asse in un rapporto).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function HI_HidP_GetUsageValue(ReportType: Integer; UsagePage, LinkCollection, Usage: Word;
    var UsageValue: Cardinal; PreparsedData, Report: Pointer; ReportLength: Cardinal): Integer; stdcall;
    external 'hid.dll' name 'HidP_GetUsageValue';
//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HI_HidP_GetUsages
//** Parametri di ingresso: ReportType: Integer; UsagePage, LinkCollection: Word; UsageList:
//**                        Pointer; UsageLength: Cardinal (var); PreparsedData, Report: Pointer;
//**                        ReportLength: Cardinal
//** Parametri di uscita: Result: Integer (NTSTATUS); UsageLength: Cardinal (var)
//** Scopo: Importare da hid.dll la funzione HidP_GetUsages (pulsanti premuti in un rapporto).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function HI_HidP_GetUsages(ReportType: Integer; UsagePage, LinkCollection: Word; UsageList: Pointer;
    var UsageLength: Cardinal; PreparsedData, Report: Pointer; ReportLength: Cardinal): Integer; stdcall;
    external 'hid.dll' name 'HidP_GetUsages';
//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HI_HidP_MaxUsageListLength
//** Parametri di ingresso: ReportType: Integer; UsagePage: Word; PreparsedData: Pointer
//** Parametri di uscita: Result: Cardinal
//** Scopo: Importare da hid.dll la funzione HidP_MaxUsageListLength (numero massimo di pulsanti
//**        premuti insieme).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function HI_HidP_MaxUsageListLength(ReportType: Integer; UsagePage: Word;
    PreparsedData: Pointer): Cardinal; stdcall; external 'hid.dll' name 'HidP_MaxUsageListLength';

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HidValue
//** Parametri di ingresso: AValue: Cardinal; AAxis: THidAxisRec
//** Parametri di uscita: Result: Int64
//** Scopo: Valore di un asse HID con il segno corretto (i valori arrivano come bit grezzi).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function HidValue(AValue: Cardinal; const AAxis: THidAxisRec): Int64;
begin
    Result := AValue;
    if AAxis.Signed and (AAxis.BitSize > 0) and (AAxis.BitSize < 32) and
        (((AValue shr (AAxis.BitSize - 1)) and 1) <> 0) then
        Result := Int64(AValue) - (Int64(1) shl AAxis.BitSize);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HidAxisName
//** Parametri di ingresso: AUsage: Word
//** Parametri di uscita: Result: string
//** Scopo: Nome di un asse HID (per il log del Setup); "-" se assente.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function HidAxisName(AUsage: Word): string;
begin
    if (AUsage >= HID_USAGE_X) and (AUsage <= HID_USAGE_X + 7) then
        Result := HID_AXIS_NAMES[AUsage - HID_USAGE_X]
    else
        Result := '-';
end;

//** Funzioni di supporto ***********************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: NormAxis
//** Parametri di ingresso: AValue, AMin, AMax: Cardinal
//** Parametri di uscita: Result: Single
//** Scopo: Normalizzare un asse WinMM nell'intervallo -1..+1.
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//** Funzionamento: proporzione lineare tra minimo e massimo dichiarati dal driver.
//***********************************************************************************************************
//***********************************************************************************************************
function NormAxis(AValue, AMin, AMax: Cardinal): Single;
begin
    if AMax <= AMin then
        Exit(0);
    Result := ((Int64(AValue) - Int64(AMin)) / (Int64(AMax) - Int64(AMin))) * 2 - 1;
    Result := EnsureRange(Result, -1, 1);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: NormThumb
//** Parametri di ingresso: AValue: SmallInt; ADead: Integer
//** Parametri di uscita: Result: Single
//** Scopo: Normalizzare una levetta XInput con zona morta.
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//** Funzionamento: sotto la soglia restituisce 0, oltre riscala da 0 a 1.
//***********************************************************************************************************
//***********************************************************************************************************
function NormThumb(AValue: SmallInt; ADead: Integer): Single;
var
    A: Integer;
begin
    A := Abs(Integer(AValue));
    if A <= ADead then
        Exit(0);
    Result := Min(1, (A - ADead) / (32767 - ADead));
    if AValue < 0 then
        Result := -Result;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: JoyOemName
//** Parametri di ingresso: AMid, APid: Word
//** Parametri di uscita: Result: string
//** Scopo: Leggere il nome commerciale del joystick (es. "VKB-Sim Gladiator").
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//** Funzionamento: il nome restituito da WinMM e' spesso generico; Windows salva
//** quello reale nel registro sotto ...\Joystick\OEM\VID_xxxx&PID_xxxx\OEMName.
//***********************************************************************************************************
//***********************************************************************************************************
function JoyOemName(AMid, APid: Word): string;
const
    Roots: array[0..1] of HKEY = (HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE);
var
    Reg: TRegistry;
    Key: string;
    I: Integer;
begin
    Result := '';
    Key := Format('System\CurrentControlSet\Control\MediaProperties\PrivateProperties\Joystick\OEM\VID_%.4X&PID_%.4X',
        [AMid, APid]);
    for I := Low(Roots) to High(Roots) do
    begin
        Reg := TRegistry.Create(KEY_READ);
        try
            Reg.RootKey := Roots[I];
            if Reg.OpenKeyReadOnly(Key) and Reg.ValueExists('OEMName') then
                Result := Trim(Reg.ReadString('OEMName'));
        finally
            Reg.Free;
        end;
        if Result <> '' then
            Exit;
    end;
end;

//** TJoyState / TPadState / TMouseState ********************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TJoyState.Button
//** Parametri di ingresso: AIndex: Integer
//** Parametri di uscita: Result: Boolean
//** Scopo: Stato di un pulsante (indice 0-based, 0..31).
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TJoyState.Button(AIndex: Integer): Boolean;
begin
    Result := Connected and (AIndex >= 0) and (AIndex < 32) and
        ((Buttons and (UInt32(1) shl AIndex)) <> 0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TJoyState.Axis
//** Parametri di ingresso: AIndex: Integer
//** Parametri di uscita: Result: Single
//** Scopo: Valore di un asse (0..5) oppure 0 se l'indice non e' valido.
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TJoyState.Axis(AIndex: Integer): Single;
begin
    if Connected and (AIndex >= 0) and (AIndex < JOY_AXES) then
        Result := Axes[AIndex]
    else
        Result := 0;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TPadState.Pressed
//** Parametri di ingresso: AMask: Word
//** Parametri di uscita: Result: Boolean
//** Scopo: Verificare se un pulsante XInput (maschera XI_*) e' premuto.
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TPadState.Pressed(AMask: Word): Boolean;
begin
    Result := Connected and ((Buttons and AMask) <> 0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TMouseState.Pressed
//** Parametri di ingresso: AMask: Byte
//** Parametri di uscita: Result: Boolean
//** Scopo: Verificare se un pulsante del mouse (maschera MBTN_*) e' premuto.
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TMouseState.Pressed(AMask: Byte): Boolean;
begin
    Result := (Buttons and AMask) <> 0;
end;

//** TInputManager ******************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.Create
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Inizializzare l'acquisizione degli input.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: crea una finestra nascosta che riceve WM_INPUT e WM_HOTKEY,
//** registra tastiera, mouse e controller HID in Raw Input e carica XInput se
//** presente. L'abbinamento ID WinMM <-> HID si calcola alla prima lettura.
//***********************************************************************************************************
//***********************************************************************************************************
constructor TInputManager.Create;
var
    I: Integer;
begin
    inherited Create;
    FMouseRange := 3000;
    for I := 0 to MAX_JOY - 1 do
        FJoyHid[I] := -1;
    FHidMapDirty := True;
    FWnd := AllocateHWnd(WndProc);
    RegisterRawDevices;
    LoadXInput;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.Destroy
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Rilasciare hotkey, finestra di servizio e libreria XInput.
//** Data Ultima Modifica: 18/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
destructor TInputManager.Destroy;
begin
    if FWnd <> 0 then
    begin
        UnregisterHotKey(FWnd, HK_LOCK);
        UnregisterHotKey(FWnd, HK_SETUP);
        UnregisterHotKey(FWnd, HK_VISIBLE);
        UnregisterHotKey(FWnd, HK_STREAMER);
        DeallocateHWnd(FWnd);
        FWnd := 0;
    end;
    if FXInputLib <> 0 then
        FreeLibrary(FXInputLib);
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.RegisterRawDevices
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Registrare mouse (usage 1/2), tastiera (1/6), joystick (1/4), gamepad (1/5) e
//**        controller multi-asse (1/8) in Raw Input.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: RIDEV_INPUTSINK consegna i messaggi anche quando
//** l'applicazione non e' in primo piano (cioe' mentre si gioca).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.RegisterRawDevices;
var
    Dev: array[0..4] of TRawInputDeviceRec;
begin
    Dev[0].usUsagePage := $01;
    Dev[0].usUsage := $02;        // mouse
    Dev[0].dwFlags := RIDEV_INPUTSINK;
    Dev[0].hwndTarget := FWnd;
    Dev[1].usUsagePage := $01;
    Dev[1].usUsage := $06;        // tastiera
    Dev[1].dwFlags := RIDEV_INPUTSINK;
    Dev[1].hwndTarget := FWnd;
    // joystick, gamepad e controller multi-asse (HID): letti anche in background
    Dev[2].usUsagePage := HID_PAGE_DESKTOP;
    Dev[2].usUsage := HID_USAGE_JOYSTICK;
    Dev[2].dwFlags := RIDEV_INPUTSINK;
    Dev[2].hwndTarget := FWnd;
    Dev[3] := Dev[2];
    Dev[3].usUsage := HID_USAGE_GAMEPAD;
    Dev[4] := Dev[2];
    Dev[4].usUsage := HID_USAGE_MULTIAXIS;
    HI_RegisterRawInputDevices(@Dev[0], Length(Dev), SizeOf(TRawInputDeviceRec));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.RegisterHotkeys
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Registrare le hotkey globali (Ctrl+Alt+F12/F11/F10, piu' F9 per la modalita' streamer).
//** Data Ultima Modifica: 18/09/2026
//***********************************************************************************************************
//** Funzionamento: restituisce False se un'altra applicazione usa gia' una
//** delle tre principali; l'esito di F9 e' in StreamerHotkeyOk.
//***********************************************************************************************************
//***********************************************************************************************************
function TInputManager.RegisterHotkeys: Boolean;
const
    Mods = MOD_CONTROL or MOD_ALT or HI_MOD_NOREPEAT;
begin
    FHotkeysOk := RegisterHotKey(FWnd, HK_LOCK, Mods, VK_F12);
    FHotkeysOk := RegisterHotKey(FWnd, HK_SETUP, Mods, VK_F11) and FHotkeysOk;
    FHotkeysOk := RegisterHotKey(FWnd, HK_VISIBLE, Mods, VK_F10) and FHotkeysOk;
    FStreamerHotkeyOk := RegisterHotKey(FWnd, HK_STREAMER, Mods, VK_F9);
    Result := FHotkeysOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.LoadXInput
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Caricare XInput senza renderlo un requisito dell'eseguibile.
//** Data Ultima Modifica: 18/09/2026
//***********************************************************************************************************
//** Funzionamento: prova le DLL dalla piu' recente alla piu' vecchia.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.LoadXInput;
const
    Dlls: array[0..2] of string = ('xinput1_4.dll', 'xinput1_3.dll', 'xinput9_1_0.dll');
var
    I: Integer;
begin
    for I := Low(Dlls) to High(Dlls) do
    begin
        FXInputLib := LoadLibrary(PChar(Dlls[I]));
        if FXInputLib <> 0 then
            Break;
    end;
    if FXInputLib <> 0 then
        @FXInputGetState := GetProcAddress(FXInputLib, 'XInputGetState');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.XInputAvailable
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Indica se XInput e' disponibile sul sistema.
//** Data Ultima Modifica: 18/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TInputManager.XInputAvailable: Boolean;
begin
    Result := Assigned(FXInputGetState);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.PadConnected
//** Parametri di ingresso: AIndex: Integer
//** Parametri di uscita: Result: Boolean
//** Scopo: Interrogare subito uno slot XInput (0..3) e dire se c'e' un gamepad collegato.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//** Funzionamento: chiama direttamente XInputGetState, senza passare dal polling
//** (che legge solo gli slot usati dai widget); usata dalla scansione del Setup.
//***********************************************************************************************************
//***********************************************************************************************************
function TInputManager.PadConnected(AIndex: Integer): Boolean;
var
    XS: TXInputStateRec;
begin
    Result := False;
    if (not Assigned(FXInputGetState)) or (AIndex < 0) or (AIndex >= MAX_PADS) then
        Exit;
    FillChar(XS, SizeOf(XS), 0);
    Result := FXInputGetState(AIndex, XS) = ERROR_SUCCESS;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.WndProc
//** Parametri di ingresso: AMsg: TMessage (var)
//** Parametri di uscita: AMsg: TMessage (var)
//** Scopo: Procedura della finestra di servizio.
//** Data Ultima Modifica: 18/09/2026
//***********************************************************************************************************
//** Funzionamento: smista WM_INPUT al parser Raw Input e WM_HOTKEY all'evento
//** OnHotkey; tutti gli altri messaggi vanno a DefWindowProc.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.WndProc(var AMsg: TMessage);
begin
    case AMsg.Msg of
        WM_INPUT:
            begin
                HandleRawInput(AMsg.LParam);
                AMsg.Result := DefWindowProc(FWnd, AMsg.Msg, AMsg.WParam, AMsg.LParam);
            end;
        WM_HOTKEY:
            begin
                if Assigned(FOnHotkey) then
                    FOnHotkey(Self, Integer(AMsg.WParam));
                AMsg.Result := 0;
            end;
    else
        AMsg.Result := DefWindowProc(FWnd, AMsg.Msg, AMsg.WParam, AMsg.LParam);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.HandleRawInput
//** Parametri di ingresso: ARaw: LPARAM
//** Parametri di uscita: nessuno
//** Scopo: Decodificare un pacchetto Raw Input di mouse, tastiera o controller HID.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento:
//**  - mouse: accumula i delta (relativi o assoluti per desktop remoto/tablet),
//**    aggiorna la maschera dei pulsanti e accumula la rotella;
//**  - tastiera: ricava un id = scan code (+$100 se E0), corregge le anomalie
//**    note (Pause, NumLock, Stamp, Shift "finti") e aggiorna l'array Keys;
//**  - controller HID: passa i rapporti a HandleHidInput.
//** Il pacchetto viene letto in due passi (prima la dimensione) perche' i
//** rapporti HID possono superare il buffer locale.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.HandleRawInput(ARaw: LPARAM);
var
    Buf: array[0..255] of Byte;
    P: PByte;
    Size, Need: UINT;
    Hdr: PRawInputHeaderRec;
    M: PRawMouseRec;
    K: PRawKeyboardRec;
    F: Word;
    Id: Integer;
begin
    // dimensione del pacchetto: mouse e tastiera stanno nel buffer locale, i
    // rapporti HID possono essere piu' grandi (buffer FRawBuf riusato)
    Need := 0;
    if HI_GetRawInputData(THandle(ARaw), RID_INPUT, nil, Need, SizeOf(TRawInputHeaderRec)) <> 0 then
        Exit;
    if Need <= SizeOf(Buf) then
        P := @Buf[0]
    else
    begin
        if Cardinal(Length(FRawBuf)) < Need then
            SetLength(FRawBuf, Need);
        P := @FRawBuf[0];
    end;
    Size := Need;
    if HI_GetRawInputData(THandle(ARaw), RID_INPUT, P, Size,
        SizeOf(TRawInputHeaderRec)) = $FFFFFFFF then
        Exit;
    Hdr := PRawInputHeaderRec(P);

    if Hdr.dwType = RIM_TYPEHID then
        HandleHidInput(Hdr.hDevice, P + SizeOf(TRawInputHeaderRec))
    else if Hdr.dwType = RIM_TYPEMOUSE then
    begin
        M := PRawMouseRec(P + SizeOf(TRawInputHeaderRec));
        if (M.usFlags and MOUSE_MOVE_ABSOLUTE) <> 0 then
        begin
            if FHasAbs then
            begin
                Inc(FRawDX, (M.lLastX - FLastAbsX) div 16);
                Inc(FRawDY, (M.lLastY - FLastAbsY) div 16);
            end;
            FLastAbsX := M.lLastX;
            FLastAbsY := M.lLastY;
            FHasAbs := True;
        end
        else
        begin
            Inc(FRawDX, M.lLastX);
            Inc(FRawDY, M.lLastY);
        end;
        F := M.usButtonFlags;
        if (F and RI_MOUSE_LEFT_BUTTON_DOWN) <> 0 then FMouseButtons := FMouseButtons or MBTN_LEFT;
        if (F and RI_MOUSE_LEFT_BUTTON_UP) <> 0 then FMouseButtons := FMouseButtons and not MBTN_LEFT;
        if (F and RI_MOUSE_RIGHT_BUTTON_DOWN) <> 0 then FMouseButtons := FMouseButtons or MBTN_RIGHT;
        if (F and RI_MOUSE_RIGHT_BUTTON_UP) <> 0 then FMouseButtons := FMouseButtons and not MBTN_RIGHT;
        if (F and RI_MOUSE_MIDDLE_BUTTON_DOWN) <> 0 then FMouseButtons := FMouseButtons or MBTN_MIDDLE;
        if (F and RI_MOUSE_MIDDLE_BUTTON_UP) <> 0 then FMouseButtons := FMouseButtons and not MBTN_MIDDLE;
        if (F and RI_MOUSE_BUTTON_4_DOWN) <> 0 then FMouseButtons := FMouseButtons or MBTN_X1;
        if (F and RI_MOUSE_BUTTON_4_UP) <> 0 then FMouseButtons := FMouseButtons and not MBTN_X1;
        if (F and RI_MOUSE_BUTTON_5_DOWN) <> 0 then FMouseButtons := FMouseButtons or MBTN_X2;
        if (F and RI_MOUSE_BUTTON_5_UP) <> 0 then FMouseButtons := FMouseButtons and not MBTN_X2;
        if (F and RI_MOUSE_WHEEL) <> 0 then
            Inc(FRawWheel, SmallInt(M.usButtonData));
    end
    else if Hdr.dwType = RIM_TYPEKEYBOARD then
    begin
        K := PRawKeyboardRec(P + SizeOf(TRawInputHeaderRec));
        if K.VKey = $FF then
            Exit;                                   // tasto "finto" generato dal driver
        Id := K.MakeCode and $FF;
        case K.VKey of
            VK_NUMLOCK:  Id := SC_NUMLOCK;
            VK_PAUSE:    Id := SC_PAUSE;
            VK_SNAPSHOT: Id := SC_PRTSC;
        else
            if (K.Flags and RI_KEY_E1) <> 0 then
                Exit;
            if (K.Flags and RI_KEY_E0) <> 0 then
            begin
                if (Id = SC_LSHIFT) or (Id = SC_RSHIFT) then
                    Exit;                               // Shift finto inviato con i tasti cursore
                Id := Id or $100;
            end;
        end;
        if (Id > 0) and (Id < KEY_IDS) then
            FState.Keys[Id] := (K.Flags and RI_KEY_BREAK) = 0;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.ClearUsage
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Azzerare l'elenco dei dispositivi da interrogare.
//** Data Ultima Modifica: 18/09/2026
//***********************************************************************************************************
//** Funzionamento: chiamata prima di riapplicare la configurazione; poi ogni
//** widget registra con UseJoystick/UsePad i dispositivi che gli servono.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.ClearUsage;
begin
    FillChar(FUsedJoy, SizeOf(FUsedJoy), 0);
    FillChar(FUsedPad, SizeOf(FUsedPad), 0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.UseJoystick
//** Parametri di ingresso: AId: Integer
//** Parametri di uscita: nessuno
//** Scopo: Segnalare che un joystick WinMM va letto ad ogni frame.
//** Data Ultima Modifica: 18/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.UseJoystick(AId: Integer);
begin
    if (AId >= 0) and (AId < MAX_JOY) then
    begin
        FUsedJoy[AId] := True;
        FJoyRetryAt[AId] := 0;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.UsePad
//** Parametri di ingresso: AIndex: Integer
//** Parametri di uscita: nessuno
//** Scopo: Segnalare che uno slot XInput va letto ad ogni frame.
//** Data Ultima Modifica: 18/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.UsePad(AIndex: Integer);
begin
    if (AIndex >= 0) and (AIndex < MAX_PADS) then
    begin
        FUsedPad[AIndex] := True;
        FPadRetryAt[AIndex] := 0;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.ResetMouse
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Riportare al centro la posizione accumulata del mouse.
//** Data Ultima Modifica: 19/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.ResetMouse;
begin
    FState.Mouse.PosX := 0;
    FState.Mouse.PosY := 0;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.StatePtr
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: PInputSnapshot
//** Scopo: Puntatore allo stato corrente (evita copie del record grande).
//** Data Ultima Modifica: 19/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TInputManager.StatePtr: PInputSnapshot;
begin
    Result := @FState;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.ReadJoyCaps
//** Parametri di ingresso: AId: Integer
//** Parametri di uscita: Result: Boolean
//** Scopo: Leggere le capacita' (range assi, POV) di un joystick WinMM.
//** Data Ultima Modifica: 19/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TInputManager.ReadJoyCaps(AId: Integer): Boolean;
begin
    FillChar(FJoyCaps[AId], SizeOf(TJoyCapsRec), 0);
    Result := HI_joyGetDevCaps(NativeUInt(AId), FJoyCaps[AId], SizeOf(TJoyCapsRec)) = JOYERR_NOERROR;
    FJoyCapsOk[AId] := Result;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.PollJoystick
//** Parametri di ingresso: AId: Integer; ANow: UInt64
//** Parametri di uscita: nessuno
//** Scopo: Leggere lo stato di un joystick (ID WinMM): da HID se possibile, altrimenti da WinMM.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: se l'ID e' abbinato a un dispositivo HID che ha gia'
//** inviato dati si usa il suo stato (aggiornato anche quando HoloInput non e'
//** in primo piano), controllando ogni 2 s che sia ancora collegato.
//** Altrimenti si legge WinMM (joyGetPosEx, aggiornato solo con HoloInput in
//** primo piano): se il dispositivo non risponde viene marcato scollegato e
//** riprovato solo dopo 2 secondi (joyGetPosEx su id assenti e' lento).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.PollJoystick(AId: Integer; ANow: UInt64);
var
    Info: TJoyInfoExRec;
    C: ^TJoyCapsRec;
    J: ^TJoyState;
    H: Integer;
    Caps: TJoyCapsRec;
begin
    J := @FState.Joys[AId];
    if FHidMapDirty then
        RebuildHidMap;

    // lettura HID (funziona anche in background) appena il dispositivo abbinato ha inviato dati
    H := FJoyHid[AId];
    if (H >= 0) and FHid[H].Live then
    begin
        // ogni 2 s si controlla che il dispositivo sia ancora collegato
        if ANow >= FJoyCheckAt[AId] then
        begin
            FJoyCheckAt[AId] := ANow + 2000;
            FillChar(Caps, SizeOf(Caps), 0);
            if HI_joyGetDevCaps(NativeUInt(AId), Caps, SizeOf(Caps)) <> JOYERR_NOERROR then
            begin
                FHidMapDirty := True;
                FJoyCapsOk[AId] := False;
                FJoyRetryAt[AId] := ANow + 2000;
                J^ := Default(TJoyState);
                J.POV := -1;
                Exit;
            end;
        end;
        J^ := FHid[H].State;
        J.Connected := True;
        Exit;
    end;

    if not FJoyCapsOk[AId] then
    begin
        if ANow < FJoyRetryAt[AId] then
            Exit;
        FJoyRetryAt[AId] := ANow + 2000;
        if not ReadJoyCaps(AId) then
        begin
            J^ := Default(TJoyState);
            J.POV := -1;
            Exit;
        end;
        FHidMapDirty := True;    // dispositivo (ri)comparso: va (ri)abbinato al suo HID
    end;

    FillChar(Info, SizeOf(Info), 0);
    Info.dwSize := SizeOf(Info);
    Info.dwFlags := JOY_RETURNALL;
    if HI_joyGetPosEx(UINT(AId), Info) <> JOYERR_NOERROR then
    begin
        J^ := Default(TJoyState);
        J.POV := -1;
        FJoyCapsOk[AId] := False;
        FJoyRetryAt[AId] := ANow + 2000;
        Exit;
    end;

    C := @FJoyCaps[AId];
    J.Connected := True;
    J.Axes[0] := NormAxis(Info.dwXpos, C.wXmin, C.wXmax);
    J.Axes[1] := NormAxis(Info.dwYpos, C.wYmin, C.wYmax);
    J.Axes[2] := NormAxis(Info.dwZpos, C.wZmin, C.wZmax);
    J.Axes[3] := NormAxis(Info.dwRpos, C.wRmin, C.wRmax);
    J.Axes[4] := NormAxis(Info.dwUpos, C.wUmin, C.wUmax);
    J.Axes[5] := NormAxis(Info.dwVpos, C.wVmin, C.wVmax);
    J.Buttons := Info.dwButtons;
    if ((C.wCaps and JOYCAPS_HASPOV) <> 0) and (Info.dwPOV <= 35999) then
        J.POV := Info.dwPOV div 100
    else
        J.POV := -1;
end;

//** Joystick in Raw Input HID ******************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.HidIndex
//** Parametri di ingresso: AHandle: THandle
//** Parametri di uscita: Result: Integer
//** Scopo: Indice in FHid del dispositivo con l'handle Raw Input indicato (-1 se sconosciuto).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TInputManager.HidIndex(AHandle: THandle): Integer;
var
    I: Integer;
begin
    for I := 0 to High(FHid) do
        if FHid[I].Handle = AHandle then
            Exit(I);
    Result := -1;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.AddHidDevice
//** Parametri di ingresso: AHandle: THandle
//** Parametri di uscita: Result: Integer
//** Scopo: Aggiungere a FHid un dispositivo HID con le sue caratteristiche; restituisce l'indice.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: il dispositivo viene sempre aggiunto (cosi' i suoi
//** rapporti non vengono riesaminati ogni volta) ma e' Valid solo se e' un
//** joystick, un gamepad o un controller multi-asse leggibile. Legge VID/PID,
//** nome (percorso), dati preparsed e caratteristiche dei valori: gli assi
//** della pagina "Generic Desktop" (X..Dial) vengono assegnati alle sei
//** posizioni WinMM X, Y, Z, R, U, V secondo SLOT_CAND (prima scelta libera),
//** l'hat diventa il POV. Un range dichiarato con segno ma usato senza (max <
//** min) viene trattato come 0..2^bit-1.
//***********************************************************************************************************
//***********************************************************************************************************
function TInputManager.AddHidDevice(AHandle: THandle): Integer;
const
    // per ogni posizione WinMM, gli assi HID candidati (0 = X .. 7 = Dial), in ordine di preferenza
    SLOT_CAND: array[0..JOY_AXES - 1, 0..3] of Integer = (
        (0, -1, -1, -1),     // X: X
        (1, -1, -1, -1),     // Y: Y
        (2, 6, 7, -1),       // Z: Z, Slider, Dial
        (5, 4, 6, 7),        // R: Rz, Ry, Slider, Dial
        (3, 6, 7, -1),       // U: Rx, Slider, Dial
        (4, 6, 7, -1));      // V: Ry, Slider, Dial
var
    Rec: THidJoyRec;
    Info: TRidDeviceInfoRec;
    Size: UINT;
    DevName: string;
    Caps: THidpCapsRec;
    VC: array of THidpValueCapsRec;
    N: Word;
    Found: array[0..7] of THidAxisRec;
    Used: array[0..7] of Boolean;
    I, S, C: Integer;
    U, UMin, UMax: Word;
    Ax: THidAxisRec;
begin
    Rec := Default(THidJoyRec);
    Rec.Handle := AHandle;
    Rec.JoyId := -1;
    Rec.State.POV := -1;
    try
        FillChar(Info, SizeOf(Info), 0);
        Info.cbSize := SizeOf(Info);
        Size := SizeOf(Info);
        if HI_GetRawInputDeviceInfo(AHandle, RIDI_DEVICEINFO, @Info, Size) = $FFFFFFFF then
            Exit;
        if (Info.dwType <> RIM_TYPEHID) or (Info.usUsagePage <> HID_PAGE_DESKTOP) or
            not (Info.usUsage in [HID_USAGE_JOYSTICK, HID_USAGE_GAMEPAD, HID_USAGE_MULTIAXIS]) then
            Exit;
        Rec.Vid := Word(Info.dwVendorId);
        Rec.Pid := Word(Info.dwProductId);

        Size := 0;
        HI_GetRawInputDeviceInfo(AHandle, RIDI_DEVICENAME, nil, Size);
        if Size > 0 then
        begin
            SetLength(DevName, Size);
            if HI_GetRawInputDeviceInfo(AHandle, RIDI_DEVICENAME, PChar(DevName), Size) <> $FFFFFFFF then
                Rec.Name := string(PChar(DevName));
        end;

        Size := 0;
        HI_GetRawInputDeviceInfo(AHandle, RIDI_PREPARSEDDATA, nil, Size);
        if Size = 0 then
            Exit;
        SetLength(Rec.Preparsed, Size);
        if HI_GetRawInputDeviceInfo(AHandle, RIDI_PREPARSEDDATA, @Rec.Preparsed[0], Size) = $FFFFFFFF then
            Exit;
        FillChar(Caps, SizeOf(Caps), 0);
        if HI_HidP_GetCaps(@Rec.Preparsed[0], Caps) <> HIDP_STATUS_SUCCESS then
            Exit;

        FillChar(Found, SizeOf(Found), 0);
        N := Caps.NumberInputValueCaps;
        if N > 0 then
        begin
            SetLength(VC, N);
            if HI_HidP_GetValueCaps(HIDP_INPUT, @VC[0], N, @Rec.Preparsed[0]) = HIDP_STATUS_SUCCESS then
                for I := 0 to Integer(N) - 1 do
                    if VC[I].UsagePage = HID_PAGE_DESKTOP then
                    begin
                        UMin := VC[I].UsageMin;
                        if VC[I].IsRange <> 0 then
                            UMax := VC[I].UsageMax
                        else
                            UMax := UMin;
                        Ax := Default(THidAxisRec);
                        Ax.Link := VC[I].LinkCollection;
                        Ax.BitSize := VC[I].BitSize;
                        Ax.Min := VC[I].LogicalMin;
                        Ax.Max := VC[I].LogicalMax;
                        Ax.Signed := Ax.Min < 0;
                        if (Ax.Max < Ax.Min) and (Ax.BitSize > 0) and (Ax.BitSize < 31) then
                        begin
                            Ax.Min := 0;
                            Ax.Max := (1 shl Ax.BitSize) - 1;
                            Ax.Signed := False;
                        end;
                        for U := UMin to UMax do
                        begin
                            Ax.Usage := U;
                            if U = HID_USAGE_HAT then
                            begin
                                if Rec.Hat.Usage = 0 then
                                    Rec.Hat := Ax;
                            end
                            else if (U >= HID_USAGE_X) and (U <= HID_USAGE_X + 7) and
                                (Found[U - HID_USAGE_X].Usage = 0) then
                                Found[U - HID_USAGE_X] := Ax;
                        end;
                    end;
        end;

        FillChar(Used, SizeOf(Used), 0);
        for S := 0 to JOY_AXES - 1 do
            for C := 0 to 3 do
            begin
                I := SLOT_CAND[S, C];
                if (I >= 0) and not Used[I] and (Found[I].Usage <> 0) then
                begin
                    Rec.Axis[S] := Found[I];
                    Used[I] := True;
                    Break;
                end;
            end;
        Rec.MaxButtons := HI_HidP_MaxUsageListLength(HIDP_INPUT, HID_PAGE_BUTTON, @Rec.Preparsed[0]);
        Rec.Valid := True;
    finally
        SetLength(FHid, Length(FHid) + 1);
        FHid[High(FHid)] := Rec;
        Result := High(FHid);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.SyncHidDevices
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Allineare FHid ai dispositivi Raw Input collegati (toglie gli scollegati, aggiunge i
//**        nuovi).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.SyncHidDevices;
var
    List: array of TRawInputDeviceListRec;
    N, Count: UINT;
    I, J: Integer;
    Keep: TArray<THidJoyRec>;
    Found: Boolean;
begin
    N := 0;
    if HI_GetRawInputDeviceList(nil, N, SizeOf(TRawInputDeviceListRec)) = $FFFFFFFF then
        Exit;
    SetLength(List, N + 8);
    N := Length(List);
    Count := HI_GetRawInputDeviceList(@List[0], N, SizeOf(TRawInputDeviceListRec));
    if Count = $FFFFFFFF then
        Exit;
    Keep := nil;
    for I := 0 to High(FHid) do
    begin
        Found := False;
        for J := 0 to Integer(Count) - 1 do
            if List[J].hDevice = FHid[I].Handle then
                Found := True;
        if Found then
            Keep := Keep + [FHid[I]];
    end;
    FHid := Keep;
    for J := 0 to Integer(Count) - 1 do
        if (List[J].dwType = RIM_TYPEHID) and (HidIndex(List[J].hDevice) < 0) then
            AddHidDevice(List[J].hDevice);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.RebuildHidMap
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Abbinare ogni ID WinMM al dispositivo HID corrispondente.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: aggiorna l'elenco dei dispositivi HID, poi per ogni ID
//** WinMM presente cerca, tra i dispositivi HID validi non ancora abbinati,
//** quello con lo stesso VID/PID (wMid/wPid di WinMM); a parita' di VID/PID
//** sceglie il primo in ordine di nome, cosi' ID crescenti corrispondono a
//** nomi crescenti. Chiamata solo quando serve (avvio, dispositivi aggiunti o
//** scollegati, scansione del Setup).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.RebuildHidMap;
var
    J, I, Best: Integer;
    Caps: TJoyCapsRec;
begin
    FHidMapDirty := False;
    SyncHidDevices;
    for J := 0 to MAX_JOY - 1 do
        FJoyHid[J] := -1;
    for I := 0 to High(FHid) do
        FHid[I].JoyId := -1;
    for J := 0 to MAX_JOY - 1 do
    begin
        FillChar(Caps, SizeOf(Caps), 0);
        if HI_joyGetDevCaps(NativeUInt(J), Caps, SizeOf(Caps)) <> JOYERR_NOERROR then
            Continue;
        Best := -1;
        for I := 0 to High(FHid) do
            if FHid[I].Valid and (FHid[I].JoyId < 0) and (FHid[I].Vid = Caps.wMid) and
                (FHid[I].Pid = Caps.wPid) then
                if (Best < 0) or (CompareText(FHid[I].Name, FHid[Best].Name) < 0) then
                    Best := I;
        if Best >= 0 then
        begin
            FHid[Best].JoyId := J;
            FJoyHid[J] := Best;
        end;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.HandleHidInput
//** Parametri di ingresso: ADevice: THandle; AData: PByte
//** Parametri di uscita: nessuno
//** Scopo: Gestire un pacchetto Raw Input HID (struttura RAWHID: dimensione, numero di rapporti,
//**        rapporti).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: un dispositivo mai visto viene aggiunto e l'abbinamento
//** ricalcolato; i rapporti vengono letti solo se il dispositivo e' abbinato a
//** un ID WinMM usato da un widget (i controller inviano centinaia di
//** rapporti al secondo).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.HandleHidInput(ADevice: THandle; AData: PByte);
var
    I: Integer;
    SizeHid, Count, R: Cardinal;
    Rep: PByte;
begin
    I := HidIndex(ADevice);
    if I < 0 then
    begin
        I := AddHidDevice(ADevice);
        FHidMapDirty := True;
    end;
    if not FHid[I].Valid then
        Exit;
    if FHidMapDirty then
    begin
        RebuildHidMap;
        I := HidIndex(ADevice);
        if (I < 0) or not FHid[I].Valid then
            Exit;
    end;
    if (FHid[I].JoyId < 0) or not FUsedJoy[FHid[I].JoyId] then
        Exit;
    SizeHid := PCardinal(AData)^;
    Count := PCardinal(AData + 4)^;
    Rep := AData + 8;
    for R := 1 to Count do
    begin
        ParseHidReport(I, Rep, SizeHid);
        Inc(Rep, SizeHid);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.ParseHidReport
//** Parametri di ingresso: AIndex: Integer; AReport: PByte; ALength: Cardinal
//** Parametri di uscita: nessuno
//** Scopo: Leggere assi, hat e pulsanti da un rapporto HID e aggiornare lo stato del dispositivo.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: assi normalizzati in -1..+1 sul range logico; hat -> POV
//** in gradi (fuori range = centrato); pulsanti dalla lista dei premuti
//** (pulsante n -> bit n-1, primi 32). I valori assenti dal rapporto (alcuni
//** dispositivi usano piu' rapporti) restano quelli precedenti.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.ParseHidReport(AIndex: Integer; AReport: PByte; ALength: Cardinal);
var
    H: ^THidJoyRec;
    Pre: Pointer;
    A: Integer;
    V, N, K: Cardinal;
    X: Int64;
    Btn: UInt32;
    U: Word;
begin
    H := @FHid[AIndex];
    Pre := @H.Preparsed[0];
    for A := 0 to JOY_AXES - 1 do
        if H.Axis[A].Usage <> 0 then
            if HI_HidP_GetUsageValue(HIDP_INPUT, HID_PAGE_DESKTOP, H.Axis[A].Link, H.Axis[A].Usage, V, Pre,
                AReport, ALength) = HIDP_STATUS_SUCCESS then
            begin
                X := HidValue(V, H.Axis[A]);
                if H.Axis[A].Max > H.Axis[A].Min then
                    H.State.Axes[A] := EnsureRange((X - H.Axis[A].Min) / (H.Axis[A].Max - H.Axis[A].Min) * 2 - 1,
                        -1, 1)
                else
                    H.State.Axes[A] := 0;
            end;

    if H.Hat.Usage <> 0 then
        if HI_HidP_GetUsageValue(HIDP_INPUT, HID_PAGE_DESKTOP, H.Hat.Link, H.Hat.Usage, V, Pre,
            AReport, ALength) = HIDP_STATUS_SUCCESS then
        begin
            X := HidValue(V, H.Hat);
            if (H.Hat.Max > H.Hat.Min) and (X >= H.Hat.Min) and (X <= H.Hat.Max) then
                H.State.POV := Integer(((X - H.Hat.Min) * 360) div (H.Hat.Max - H.Hat.Min + 1))
            else
                H.State.POV := -1;
        end;

    if H.MaxButtons > 0 then
    begin
        if Cardinal(Length(FUsageBuf)) < H.MaxButtons then
            SetLength(FUsageBuf, H.MaxButtons);
        N := H.MaxButtons;
        if HI_HidP_GetUsages(HIDP_INPUT, HID_PAGE_BUTTON, 0, @FUsageBuf[0], N, Pre, AReport,
            ALength) = HIDP_STATUS_SUCCESS then
        begin
            Btn := 0;
            for K := 1 to N do
            begin
                U := FUsageBuf[K - 1];
                if (U >= 1) and (U <= 32) then
                    Btn := Btn or (UInt32(1) shl (U - 1));
            end;
            H.State.Buttons := Btn;
        end;
    end;
    H.Live := True;
    H.State.Connected := True;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.PollPad
//** Parametri di ingresso: AIndex: Integer; ANow: UInt64
//** Parametri di uscita: nessuno
//** Scopo: Leggere lo stato di un gamepad XInput.
//** Data Ultima Modifica: 19/09/2026
//***********************************************************************************************************
//** Funzionamento: come per i joystick, uno slot vuoto viene ritentato ogni 2 s.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.PollPad(AIndex: Integer; ANow: UInt64);
var
    XS: TXInputStateRec;
    P: ^TPadState;
begin
    if not Assigned(FXInputGetState) then
        Exit;
    P := @FState.Pads[AIndex];
    if (not P.Connected) and (ANow < FPadRetryAt[AIndex]) then
        Exit;
    FillChar(XS, SizeOf(XS), 0);
    if FXInputGetState(AIndex, XS) <> ERROR_SUCCESS then
    begin
        P^ := Default(TPadState);
        FPadRetryAt[AIndex] := ANow + 2000;
        Exit;
    end;
    P.Connected := True;
    P.Buttons := XS.Gamepad.wButtons;
    P.LX := NormThumb(XS.Gamepad.sThumbLX, 7849);
    P.LY := NormThumb(XS.Gamepad.sThumbLY, 7849);
    P.RX := NormThumb(XS.Gamepad.sThumbRX, 8689);
    P.RY := NormThumb(XS.Gamepad.sThumbRY, 8689);
    P.LT := 0;
    P.RT := 0;
    if XS.Gamepad.bLeftTrigger > 30 then
        P.LT := XS.Gamepad.bLeftTrigger / 255;
    if XS.Gamepad.bRightTrigger > 30 then
        P.RT := XS.Gamepad.bRightTrigger / 255;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.SafetyCheck
//** Parametri di ingresso: ANow: UInt64
//** Parametri di uscita: nessuno
//** Scopo: Evitare tasti "incollati" se un rilascio va perso (es. Ctrl+Alt+Canc, schermata UAC,
//**        cambio desktop).
//** Data Ultima Modifica: 19/09/2026
//***********************************************************************************************************
//** Funzionamento: una volta al secondo, se risultano tasti premuti ma il
//** sistema non ne vede nessuno fisicamente premuto per 2 controlli
//** consecutivi, azzera lo stato. Idem per i pulsanti del mouse.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.SafetyCheck(ANow: UInt64);
var
    VK: Integer;
    AnyState, AnyPhys: Boolean;
begin
    if ANow < FSafetyAt then
        Exit;
    FSafetyAt := ANow + 1000;

    AnyState := False;
    for VK := 0 to KEY_IDS - 1 do
        if FState.Keys[VK] then
        begin
            AnyState := True;
            Break;
        end;
    if AnyState then
    begin
        AnyPhys := False;
        for VK := 8 to 254 do
            if (GetAsyncKeyState(VK) and $8000) <> 0 then
            begin
                AnyPhys := True;
                Break;
            end;
        if AnyPhys then
            FKeyIdleChecks := 0
        else
        begin
            Inc(FKeyIdleChecks);
            if FKeyIdleChecks >= 2 then
            begin
                FillChar(FState.Keys, SizeOf(FState.Keys), 0);
                FKeyIdleChecks := 0;
            end;
        end;
    end
    else
        FKeyIdleChecks := 0;

    if FMouseButtons <> 0 then
    begin
        AnyPhys := ((GetAsyncKeyState(VK_LBUTTON) or GetAsyncKeyState(VK_RBUTTON) or
            GetAsyncKeyState(VK_MBUTTON) or GetAsyncKeyState(VK_XBUTTON1) or
            GetAsyncKeyState(VK_XBUTTON2)) and $8000) <> 0;
        if AnyPhys then
            FBtnIdleChecks := 0
        else
        begin
            Inc(FBtnIdleChecks);
            if FBtnIdleChecks >= 2 then
            begin
                FMouseButtons := 0;
                FBtnIdleChecks := 0;
            end;
        end;
    end
    else
        FBtnIdleChecks := 0;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.Poll
//** Parametri di ingresso: ADeltaT: Single
//** Parametri di uscita: nessuno
//** Scopo: Aggiornare lo snapshot degli input; va chiamata una volta per frame.
//** Data Ultima Modifica: 19/09/2026
//***********************************************************************************************************
//** Funzionamento:
//**  - mouse: trasferisce i delta accumulati, integra la posizione (limitata a
//**    -1..+1, senza ricentraggio), smussa la velocita' in modo indipendente
//**    dal frame rate e gestisce rotella/impulso;
//**  - interroga solo joystick e gamepad effettivamente usati dai widget;
//**  - esegue il controllo anti-tasti-incollati.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.Poll(ADeltaT: Single);
var
    Now: UInt64;
    I: Integer;
    M: ^TMouseState;
    K, TX, TY: Single;
begin
    Now := GetTickCount64;
    M := @FState.Mouse;

    M.DX := FRawDX;
    M.DY := FRawDY;
    FRawDX := 0;
    FRawDY := 0;
    if FMouseRange < 1 then
        FMouseRange := 1;
    M.PosX := EnsureRange(M.PosX + M.DX / FMouseRange, -1, 1);
    M.PosY := EnsureRange(M.PosY + M.DY / FMouseRange, -1, 1);
    if ADeltaT > 0 then
    begin
        TX := EnsureRange(M.DX / (FMouseRange * 60 * ADeltaT * 0.02), -1, 1);
        TY := EnsureRange(M.DY / (FMouseRange * 60 * ADeltaT * 0.02), -1, 1);
        K := 1 - Exp(-ADeltaT * 12);
        M.VelX := M.VelX + (TX - M.VelX) * K;
        M.VelY := M.VelY + (TY - M.VelY) * K;
    end;
    M.WheelDelta := FRawWheel / 120;
    FRawWheel := 0;
    if M.WheelDelta <> 0 then
    begin
        M.WheelAngle := M.WheelAngle - M.WheelDelta * 24;
        while M.WheelAngle >= 360 do M.WheelAngle := M.WheelAngle - 360;
        while M.WheelAngle < 0 do M.WheelAngle := M.WheelAngle + 360;
        M.WheelPulse := 1;
    end
    else
    begin
        M.WheelPulse := M.WheelPulse - ADeltaT * 4;
        if M.WheelPulse < 0 then
            M.WheelPulse := 0;
    end;
    M.Buttons := FMouseButtons;

    for I := 0 to MAX_JOY - 1 do
        if FUsedJoy[I] then
            PollJoystick(I, Now);
    for I := 0 to MAX_PADS - 1 do
        if FUsedPad[I] then
            PollPad(I, Now);

    SafetyCheck(Now);
    Inc(FState.Frame);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.EnumJoysticks
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TArray<TJoyDeviceInfo>
//** Scopo: Elencare i 16 id joystick WinMM con nome, assi e pulsanti (usato dal Setup per scegliere
//**        il dispositivo di ogni widget), indicando se sono letti anche in background (HID) e con
//**        quali assi.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TInputManager.EnumJoysticks: TArray<TJoyDeviceInfo>;
var
    I, H, A: Integer;
    Info: TJoyInfoExRec;
    Caps: TJoyCapsRec;
begin
    SetLength(Result, MAX_JOY);
    for I := 0 to MAX_JOY - 1 do
    begin
        Result[I] := Default(TJoyDeviceInfo);
        Result[I].Id := I;
        FillChar(Caps, SizeOf(Caps), 0);
        if HI_joyGetDevCaps(NativeUInt(I), Caps, SizeOf(Caps)) <> JOYERR_NOERROR then
            Continue;
        FillChar(Info, SizeOf(Info), 0);
        Info.dwSize := SizeOf(Info);
        Info.dwFlags := JOY_RETURNALL;
        Result[I].Present := HI_joyGetPosEx(UINT(I), Info) = JOYERR_NOERROR;
        if not Result[I].Present then
            Continue;
        Result[I].Name := JoyOemName(Caps.wMid, Caps.wPid);
        if Result[I].Name = '' then
            Result[I].Name := Trim(string(PWideChar(@Caps.szPname[0])));
        Result[I].NumAxes := Caps.wNumAxes;
        Result[I].NumButtons := Caps.wNumButtons;
        Result[I].HasPOV := (Caps.wCaps and JOYCAPS_HASPOV) <> 0;
    end;
    // abbinamento ai dispositivi HID (lettura in background) e assi usati
    RebuildHidMap;
    for I := 0 to MAX_JOY - 1 do
        if Result[I].Present and (FJoyHid[I] >= 0) then
        begin
            H := FJoyHid[I];
            Result[I].Background := True;
            Result[I].BgAxes := '';
            for A := 0 to JOY_AXES - 1 do
            begin
                if A > 0 then
                    Result[I].BgAxes := Result[I].BgAxes + ' ';
                Result[I].BgAxes := Result[I].BgAxes + HidAxisName(FHid[H].Axis[A].Usage);
            end;
        end;
end;

end.
