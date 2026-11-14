//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Input
//** Scopo: Acquisizione globale degli input, funzionante anche quando il gioco ha il fuoco (l'overlay non e'
//**        mai la finestra attiva).
//** Data Ultima Modifica: 11/11/2026
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
        bConnected: Boolean;
        aAxes: array[0..JOY_AXES - 1] of Single;  // -1..+1
        iButtons: UInt32;                         // bit 0 = pulsante 1
        iPOV: Integer;                            // -1 = centrato, altrimenti gradi 0..359
        function bButton(iAIndex: Integer): Boolean;
        function dAxis(iAIndex: Integer): Single;
    end;

    TPadState = record
        bConnected: Boolean;
        dLX, dLY, dRX, dRY: Single;   // -1..+1 (Y positivo = su)
        dLT, dRT: Single;           // 0..1
        iButtons: Word;            // maschera XI_*
        function bPressed(iAMask: Word): Boolean;
    end;

    TMouseState = record
        iButtons: Byte;            // maschera MBTN_*
        dDX, dDY: Single;           // movimento grezzo dell'ultimo frame (count)
        dPosX, dPosY: Single;       // posizione accumulata -1..+1 (NON si ricentra)
        dVelX, dVelY: Single;       // velocita' smussata -1..+1 (per l'inclinazione)
        dWheelDelta: Single;       // scatti della rotella nell'ultimo frame
        dWheelAngle: Single;       // angolo accumulato della rotella (gradi)
        dWheelPulse: Single;       // 1 dopo uno scatto, decade a 0
        function bPressed(iAMask: Byte): Boolean;
    end;

    TInputSnapshot = record
        aKeys: array[0..KEY_IDS - 1] of Boolean;
        rMouse: TMouseState;
        aPads: array[0..MAX_PADS - 1] of TPadState;
        aJoys: array[0..MAX_JOY - 1] of TJoyState;
        iFrame: Cardinal;
    end;
    PInputSnapshot = ^TInputSnapshot;

    TJoyDeviceInfo = record
        iId: Integer;
        bPresent: Boolean;
        sName: string;
        iNumAxes, iNumButtons: Integer;
        bHasPOV: Boolean;
        bBackground: Boolean;      // abbinato a un dispositivo HID: letto anche in background
        sBgAxes: string;           // assi HID usati per X, Y, Z, R, U, V (es. "X Y Z Rz Rx Ry")
    end;

    THotkeyEvent = procedure(oSender: TObject; iAHotkeyId: Integer) of object;

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
        iUsage: Word;              // 0 = assente
        iLink: Word;               // link collection (per HidP_GetUsageValue)
        iMin, iMax: Integer;        // range logico
        iBitSize: Word;
        bSigned: Boolean;          // range con valori negativi: va esteso il segno
    end;

    /// Un joystick/pulsantiera letto in Raw Input HID.
    THidJoyRec = record
        hHandle: THandle;          // handle Raw Input del dispositivo
        bValid: Boolean;           // e' un joystick/gamepad/controller multi-asse leggibile
        sName: string;             // percorso del dispositivo (per l'ordine a parita' di VID/PID)
        iVid, iPid: Word;
        aPreparsed: TBytes;        // dati "preparsed" per le funzioni HidP_*
        aAxis: array[0..JOY_AXES - 1] of THidAxisRec;   // X, Y, Z, R, U, V
        rHat: THidAxisRec;
        iMaxButtons: Cardinal;     // lunghezza massima della lista dei pulsanti premuti
        iJoyId: Integer;           // ID WinMM abbinato (-1 = nessuno)
        bLive: Boolean;            // ha gia' inviato almeno un rapporto
        rState: TJoyState;         // ultimo stato letto
    end;

    //** TInputManager **************************************************************************************
    TInputManager = class
    private
        hFWnd: HWND;
        rFState: TInputSnapshot;
        iFMouseButtons: Byte;
        iFRawDX, iFRawDY, iFRawWheel: Integer;
        iFLastAbsX, iFLastAbsY: Integer;
        bFHasAbs: Boolean;
        dFMouseRange: Single;
        aFUsedJoy: array[0..MAX_JOY - 1] of Boolean;
        aFUsedPad: array[0..MAX_PADS - 1] of Boolean;
        aFJoyCaps: array[0..MAX_JOY - 1] of TJoyCapsRec;
        aFJoyCapsOk: array[0..MAX_JOY - 1] of Boolean;
        aFJoyRetryAt: array[0..MAX_JOY - 1] of UInt64;
        aFPadRetryAt: array[0..MAX_PADS - 1] of UInt64;
        hFXInputLib: HMODULE;
        mFXInputGetState: TXInputGetStateFn;
        iFSafetyAt: UInt64;
        iFKeyIdleChecks, iFBtnIdleChecks: Integer;
        bFHotkeysOk: Boolean;
        bFStreamerHotkeyOk: Boolean;
        mFOnHotkey: THotkeyEvent;
        aFHid: TArray<THidJoyRec>;                 // dispositivi HID (joystick, gamepad, multi-asse)
        aFJoyHid: array[0..MAX_JOY - 1] of Integer; // ID WinMM -> indice in aFHid (-1 = nessuno)
        aFJoyCheckAt: array[0..MAX_JOY - 1] of UInt64;  // prossimo controllo di presenza (lettura HID)
        bFHidMapDirty: Boolean;                    // abbinamento ID WinMM <-> HID da ricalcolare
        aFRawBuf: TBytes;                          // buffer per i pacchetti Raw Input grandi (HID)
        aFUsageBuf: array of Word;                 // pulsanti premuti letti da HidP_GetUsages
        procedure WndProc(var rAMsg: TMessage);
        procedure HandleRawInput(iARaw: LPARAM);
        procedure RegisterRawDevices;
        procedure LoadXInput;
        function bReadJoyCaps(iAId: Integer): Boolean;
        procedure PollJoystick(iAId: Integer; iANow: UInt64);
        procedure PollPad(iAIndex: Integer; iANow: UInt64);
        procedure SafetyCheck(iANow: UInt64);
        function iHidIndex(hAHandle: THandle): Integer;
        function iAddHidDevice(hAHandle: THandle): Integer;
        procedure SyncHidDevices;
        procedure RebuildHidMap;
        procedure HandleHidInput(hADevice: THandle; pAData: PByte; iASize: Cardinal);
        procedure ParseHidReport(iAIndex: Integer; pAReport: PByte; iALength: Cardinal);
    public
        constructor Create;
        destructor Destroy; override;
        procedure Poll(dADeltaT: Single);
        procedure ClearUsage;
        procedure UseJoystick(iAId: Integer);
        procedure UsePad(iAIndex: Integer);
        procedure ResetMouse;
        function bRegisterHotkeys: Boolean;
        function aEnumJoysticks: TArray<TJoyDeviceInfo>;
        function bXInputAvailable: Boolean;
        function bPadConnected(iAIndex: Integer): Boolean;
        function pStatePtr: PInputSnapshot;
        property dMouseRange: Single read dFMouseRange write dFMouseRange;
        property bHotkeysOk: Boolean read bFHotkeysOk;
        /// True se Ctrl+Alt+F9 (modalita' streamer) e' stato registrato.
        property bStreamerHotkeyOk: Boolean read bFStreamerHotkeyOk;
        property mOnHotkey: THotkeyEvent read mFOnHotkey write mFOnHotkey;
    end;

implementation

uses
    System.Win.Registry, Holo.SafeDll;

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
    external 'winmm.dll' name 'joyGetPosEx' delayed;
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
    external 'winmm.dll' name 'joyGetDevCapsW' delayed;

//** Dichiarazioni Raw Input HID (joystick letti in background) *********************************************
// hid.dll e winmm.dll sono "delayed": caricate al primo uso, dopo che Holo.SafeDll ha limitato la
// ricerca delle DLL a System32 (un import normale le cercherebbe prima accanto all'exe).
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
    external 'hid.dll' name 'HidP_GetCaps' delayed;
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
    PreparsedData: Pointer): Integer; stdcall; external 'hid.dll' name 'HidP_GetValueCaps' delayed;
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
    external 'hid.dll' name 'HidP_GetUsageValue' delayed;
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
    external 'hid.dll' name 'HidP_GetUsages' delayed;
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
    PreparsedData: Pointer): Cardinal; stdcall; external 'hid.dll' name 'HidP_MaxUsageListLength' delayed;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: iHidValue
//** Parametri di ingresso: iAValue: Cardinal; rAAxis: THidAxisRec
//** Parametri di uscita: Result: Int64
//** Scopo: Valore di un asse HID con il segno corretto (i valori arrivano come bit grezzi).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function iHidValue(iAValue: Cardinal; const rAAxis: THidAxisRec): Int64;
begin
    Result := iAValue;
    if rAAxis.bSigned and (rAAxis.iBitSize > 0) and (rAAxis.iBitSize < 32) and
        (((iAValue shr (rAAxis.iBitSize - 1)) and 1) <> 0) then
        Result := Int64(iAValue) - (Int64(1) shl rAAxis.iBitSize);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sHidAxisName
//** Parametri di ingresso: iAUsage: Word
//** Parametri di uscita: Result: string
//** Scopo: Nome di un asse HID (per il log del Setup); "-" se assente.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function sHidAxisName(iAUsage: Word): string;
begin
    if (iAUsage >= HID_USAGE_X) and (iAUsage <= HID_USAGE_X + 7) then
        Result := HID_AXIS_NAMES[iAUsage - HID_USAGE_X]
    else
        Result := '-';
end;

//** Funzioni di supporto ***********************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: dNormAxis
//** Parametri di ingresso: iAValue, iAMin, iAMax: Cardinal
//** Parametri di uscita: Result: Single
//** Scopo: Normalizzare un asse WinMM nell'intervallo -1..+1.
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//** Funzionamento: proporzione lineare tra minimo e massimo dichiarati dal driver.
//***********************************************************************************************************
//***********************************************************************************************************
function dNormAxis(iAValue, iAMin, iAMax: Cardinal): Single;
begin
    if iAMax <= iAMin then
        Exit(0);
    Result := ((Int64(iAValue) - Int64(iAMin)) / (Int64(iAMax) - Int64(iAMin))) * 2 - 1;
    Result := EnsureRange(Result, -1, 1);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: dNormThumb
//** Parametri di ingresso: iAValue: SmallInt; iADead: Integer
//** Parametri di uscita: Result: Single
//** Scopo: Normalizzare una levetta XInput con zona morta.
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//** Funzionamento: sotto la soglia restituisce 0, oltre riscala da 0 a 1.
//***********************************************************************************************************
//***********************************************************************************************************
function dNormThumb(iAValue: SmallInt; iADead: Integer): Single;
var
    iMagnitude: Integer;
begin
    iMagnitude := Abs(Integer(iAValue));
    if iMagnitude <= iADead then
        Exit(0);
    Result := Min(1, (iMagnitude - iADead) / (32767 - iADead));
    if iAValue < 0 then
        Result := -Result;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sJoyOemName
//** Parametri di ingresso: iAMid, iAPid: Word
//** Parametri di uscita: Result: string
//** Scopo: Leggere il nome commerciale del joystick (es. "VKB-Sim Gladiator").
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//** Funzionamento: il nome restituito da WinMM e' spesso generico; Windows salva
//** quello reale nel registro sotto ...\Joystick\OEM\VID_xxxx&PID_xxxx\OEMName.
//***********************************************************************************************************
//***********************************************************************************************************
function sJoyOemName(iAMid, iAPid: Word): string;
const
    Roots: array[0..1] of HKEY = (HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE);
var
    oReg: TRegistry;
    sKey: string;
    iRoot: Integer;
begin
    Result := '';
    sKey := Format('System\CurrentControlSet\Control\MediaProperties\PrivateProperties\Joystick\OEM\VID_%.4X&PID_%.4X',
        [iAMid, iAPid]);
    for iRoot := Low(Roots) to High(Roots) do
    begin
        oReg := TRegistry.Create(KEY_READ);
        try
            oReg.RootKey := Roots[iRoot];
            if oReg.OpenKeyReadOnly(sKey) and oReg.ValueExists('OEMName') then
                Result := Trim(oReg.ReadString('OEMName'));
        finally
            oReg.Free;
        end;
        if Result <> '' then
            Exit;
    end;
end;

//** TJoyState / TPadState / TMouseState ********************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TJoyState.bButton
//** Parametri di ingresso: iAIndex: Integer
//** Parametri di uscita: Result: Boolean
//** Scopo: Stato di un pulsante (indice 0-based, 0..31).
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TJoyState.bButton(iAIndex: Integer): Boolean;
begin
    Result := bConnected and (iAIndex >= 0) and (iAIndex < 32) and
        ((iButtons and (UInt32(1) shl iAIndex)) <> 0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TJoyState.dAxis
//** Parametri di ingresso: iAIndex: Integer
//** Parametri di uscita: Result: Single
//** Scopo: Valore di un asse (0..5) oppure 0 se l'indice non e' valido.
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TJoyState.dAxis(iAIndex: Integer): Single;
begin
    if bConnected and (iAIndex >= 0) and (iAIndex < JOY_AXES) then
        Result := aAxes[iAIndex]
    else
        Result := 0;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TPadState.bPressed
//** Parametri di ingresso: iAMask: Word
//** Parametri di uscita: Result: Boolean
//** Scopo: Verificare se un pulsante XInput (maschera XI_*) e' premuto.
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TPadState.bPressed(iAMask: Word): Boolean;
begin
    Result := bConnected and ((iButtons and iAMask) <> 0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TMouseState.bPressed
//** Parametri di ingresso: iAMask: Byte
//** Parametri di uscita: Result: Boolean
//** Scopo: Verificare se un pulsante del mouse (maschera MBTN_*) e' premuto.
//** Data Ultima Modifica: 17/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TMouseState.bPressed(iAMask: Byte): Boolean;
begin
    Result := (iButtons and iAMask) <> 0;
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
    iJoy: Integer;
begin
    inherited Create;
    dFMouseRange := 3000;
    for iJoy := 0 to MAX_JOY - 1 do
        aFJoyHid[iJoy] := -1;
    bFHidMapDirty := True;
    hFWnd := AllocateHWnd(WndProc);
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
    if hFWnd <> 0 then
    begin
        UnregisterHotKey(hFWnd, HK_LOCK);
        UnregisterHotKey(hFWnd, HK_SETUP);
        UnregisterHotKey(hFWnd, HK_VISIBLE);
        UnregisterHotKey(hFWnd, HK_STREAMER);
        DeallocateHWnd(hFWnd);
        hFWnd := 0;
    end;
    if hFXInputLib <> 0 then
        FreeLibrary(hFXInputLib);
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
    aDev: array[0..4] of TRawInputDeviceRec;
begin
    aDev[0].usUsagePage := $01;
    aDev[0].usUsage := $02;        // mouse
    aDev[0].dwFlags := RIDEV_INPUTSINK;
    aDev[0].hwndTarget := hFWnd;
    aDev[1].usUsagePage := $01;
    aDev[1].usUsage := $06;        // tastiera
    aDev[1].dwFlags := RIDEV_INPUTSINK;
    aDev[1].hwndTarget := hFWnd;
    // joystick, gamepad e controller multi-asse (HID): letti anche in background
    aDev[2].usUsagePage := HID_PAGE_DESKTOP;
    aDev[2].usUsage := HID_USAGE_JOYSTICK;
    aDev[2].dwFlags := RIDEV_INPUTSINK;
    aDev[2].hwndTarget := hFWnd;
    aDev[3] := aDev[2];
    aDev[3].usUsage := HID_USAGE_GAMEPAD;
    aDev[4] := aDev[2];
    aDev[4].usUsage := HID_USAGE_MULTIAXIS;
    HI_RegisterRawInputDevices(@aDev[0], Length(aDev), SizeOf(TRawInputDeviceRec));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.bRegisterHotkeys
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Registrare le hotkey globali (Ctrl+Alt+F12/F11/F10, piu' F9 per la modalita' streamer).
//** Data Ultima Modifica: 18/09/2026
//***********************************************************************************************************
//** Funzionamento: restituisce False se un'altra applicazione usa gia' una
//** delle tre principali; l'esito di F9 e' in bStreamerHotkeyOk.
//***********************************************************************************************************
//***********************************************************************************************************
function TInputManager.bRegisterHotkeys: Boolean;
const
    Mods = MOD_CONTROL or MOD_ALT or HI_MOD_NOREPEAT;
begin
    bFHotkeysOk := RegisterHotKey(hFWnd, HK_LOCK, Mods, VK_F12);
    bFHotkeysOk := RegisterHotKey(hFWnd, HK_SETUP, Mods, VK_F11) and bFHotkeysOk;
    bFHotkeysOk := RegisterHotKey(hFWnd, HK_VISIBLE, Mods, VK_F10) and bFHotkeysOk;
    bFStreamerHotkeyOk := RegisterHotKey(hFWnd, HK_STREAMER, Mods, VK_F9);
    Result := bFHotkeysOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.LoadXInput
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Caricare XInput senza renderlo un requisito dell'eseguibile.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento: prova le DLL dalla piu' recente alla piu' vecchia, solo
//** dalla cartella di sistema (LoadLibraryEx con LOAD_LIBRARY_SEARCH_SYSTEM32):
//** una DLL con lo stesso nome accanto all'exe non viene mai caricata.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.LoadXInput;
const
    Dlls: array[0..2] of string = ('xinput1_4.dll', 'xinput1_3.dll', 'xinput9_1_0.dll');
var
    iDll: Integer;
begin
    for iDll := Low(Dlls) to High(Dlls) do
    begin
        hFXInputLib := LoadLibraryEx(PChar(Dlls[iDll]), 0, HOLO_LOAD_LIBRARY_SEARCH_SYSTEM32);
        if hFXInputLib <> 0 then
            Break;
    end;
    if hFXInputLib <> 0 then
        @mFXInputGetState := GetProcAddress(hFXInputLib, 'XInputGetState');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.bXInputAvailable
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: Boolean
//** Scopo: Indica se XInput e' disponibile sul sistema.
//** Data Ultima Modifica: 18/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TInputManager.bXInputAvailable: Boolean;
begin
    Result := Assigned(mFXInputGetState);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.bPadConnected
//** Parametri di ingresso: iAIndex: Integer
//** Parametri di uscita: Result: Boolean
//** Scopo: Interrogare subito uno slot XInput (0..3) e dire se c'e' un gamepad collegato.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//** Funzionamento: chiama direttamente XInputGetState, senza passare dal polling
//** (che legge solo gli slot usati dai widget); usata dalla scansione del Setup.
//***********************************************************************************************************
//***********************************************************************************************************
function TInputManager.bPadConnected(iAIndex: Integer): Boolean;
var
    rState: TXInputStateRec;
begin
    Result := False;
    if (not Assigned(mFXInputGetState)) or (iAIndex < 0) or (iAIndex >= MAX_PADS) then
        Exit;
    FillChar(rState, SizeOf(rState), 0);
    Result := mFXInputGetState(iAIndex, rState) = ERROR_SUCCESS;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.WndProc
//** Parametri di ingresso: rAMsg: TMessage (var)
//** Parametri di uscita: rAMsg: TMessage (var)
//** Scopo: Procedura della finestra di servizio.
//** Data Ultima Modifica: 18/09/2026
//***********************************************************************************************************
//** Funzionamento: smista WM_INPUT al parser Raw Input e WM_HOTKEY all'evento
//** mOnHotkey; tutti gli altri messaggi vanno a DefWindowProc.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.WndProc(var rAMsg: TMessage);
begin
    case rAMsg.Msg of
        WM_INPUT:
            begin
                HandleRawInput(rAMsg.LParam);
                rAMsg.Result := DefWindowProc(hFWnd, rAMsg.Msg, rAMsg.WParam, rAMsg.LParam);
            end;
        WM_HOTKEY:
            begin
                if Assigned(mFOnHotkey) then
                    mFOnHotkey(Self, Integer(rAMsg.WParam));
                rAMsg.Result := 0;
            end;
    else
        rAMsg.Result := DefWindowProc(hFWnd, rAMsg.Msg, rAMsg.WParam, rAMsg.LParam);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.HandleRawInput
//** Parametri di ingresso: iARaw: LPARAM
//** Parametri di uscita: nessuno
//** Scopo: Decodificare un pacchetto Raw Input di mouse, tastiera o controller HID.
//** Data Ultima Modifica: 11/11/2026
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
procedure TInputManager.HandleRawInput(iARaw: LPARAM);
var
    aBuf: array[0..255] of Byte;
    pPacket: PByte;
    iSize, iNeed, iGot: UINT;
    pHdr: PRawInputHeaderRec;
    pMouse: PRawMouseRec;
    pKeyboard: PRawKeyboardRec;
    iButtonFlags: Word;
    iKeyId: Integer;
begin
    // dimensione del pacchetto: mouse e tastiera stanno nel buffer locale, i
    // rapporti HID possono essere piu' grandi (buffer aFRawBuf riusato)
    iNeed := 0;
    if HI_GetRawInputData(THandle(iARaw), RID_INPUT, nil, iNeed, SizeOf(TRawInputHeaderRec)) <> 0 then
        Exit;
    if iNeed <= SizeOf(aBuf) then
        pPacket := @aBuf[0]
    else
    begin
        if Cardinal(Length(aFRawBuf)) < iNeed then
            SetLength(aFRawBuf, iNeed);
        pPacket := @aFRawBuf[0];
    end;
    iSize := iNeed;
    iGot := HI_GetRawInputData(THandle(iARaw), RID_INPUT, pPacket, iSize, SizeOf(TRawInputHeaderRec));
    if (iGot = $FFFFFFFF) or (iGot < SizeOf(TRawInputHeaderRec)) then
        Exit;
    pHdr := PRawInputHeaderRec(pPacket);

    if pHdr.dwType = RIM_TYPEHID then
        HandleHidInput(pHdr.hDevice, pPacket + SizeOf(TRawInputHeaderRec), iGot - SizeOf(TRawInputHeaderRec))
    else if pHdr.dwType = RIM_TYPEMOUSE then
    begin
        pMouse := PRawMouseRec(pPacket + SizeOf(TRawInputHeaderRec));
        if (pMouse.usFlags and MOUSE_MOVE_ABSOLUTE) <> 0 then
        begin
            if bFHasAbs then
            begin
                Inc(iFRawDX, (pMouse.lLastX - iFLastAbsX) div 16);
                Inc(iFRawDY, (pMouse.lLastY - iFLastAbsY) div 16);
            end;
            iFLastAbsX := pMouse.lLastX;
            iFLastAbsY := pMouse.lLastY;
            bFHasAbs := True;
        end
        else
        begin
            Inc(iFRawDX, pMouse.lLastX);
            Inc(iFRawDY, pMouse.lLastY);
        end;
        iButtonFlags := pMouse.usButtonFlags;
        if (iButtonFlags and RI_MOUSE_LEFT_BUTTON_DOWN) <> 0 then iFMouseButtons := iFMouseButtons
            or MBTN_LEFT;
        if (iButtonFlags and RI_MOUSE_LEFT_BUTTON_UP) <> 0 then iFMouseButtons := iFMouseButtons
            and not MBTN_LEFT;
        if (iButtonFlags and RI_MOUSE_RIGHT_BUTTON_DOWN) <> 0 then iFMouseButtons := iFMouseButtons
            or MBTN_RIGHT;
        if (iButtonFlags and RI_MOUSE_RIGHT_BUTTON_UP) <> 0 then iFMouseButtons := iFMouseButtons
            and not MBTN_RIGHT;
        if (iButtonFlags and RI_MOUSE_MIDDLE_BUTTON_DOWN) <> 0 then iFMouseButtons := iFMouseButtons
            or MBTN_MIDDLE;
        if (iButtonFlags and RI_MOUSE_MIDDLE_BUTTON_UP) <> 0 then iFMouseButtons := iFMouseButtons
            and not MBTN_MIDDLE;
        if (iButtonFlags and RI_MOUSE_BUTTON_4_DOWN) <> 0 then iFMouseButtons := iFMouseButtons or MBTN_X1;
        if (iButtonFlags and RI_MOUSE_BUTTON_4_UP) <> 0 then iFMouseButtons := iFMouseButtons
            and not MBTN_X1;
        if (iButtonFlags and RI_MOUSE_BUTTON_5_DOWN) <> 0 then iFMouseButtons := iFMouseButtons or MBTN_X2;
        if (iButtonFlags and RI_MOUSE_BUTTON_5_UP) <> 0 then iFMouseButtons := iFMouseButtons
            and not MBTN_X2;
        if (iButtonFlags and RI_MOUSE_WHEEL) <> 0 then
            Inc(iFRawWheel, SmallInt(pMouse.usButtonData));
    end
    else if pHdr.dwType = RIM_TYPEKEYBOARD then
    begin
        pKeyboard := PRawKeyboardRec(pPacket + SizeOf(TRawInputHeaderRec));
        if pKeyboard.VKey = $FF then
            Exit;                                   // tasto "finto" generato dal driver
        iKeyId := pKeyboard.MakeCode and $FF;
        case pKeyboard.VKey of
            VK_NUMLOCK:  iKeyId := SC_NUMLOCK;
            VK_PAUSE:    iKeyId := SC_PAUSE;
            VK_SNAPSHOT: iKeyId := SC_PRTSC;
        else
            if (pKeyboard.Flags and RI_KEY_E1) <> 0 then
                Exit;
            if (pKeyboard.Flags and RI_KEY_E0) <> 0 then
            begin
                if (iKeyId = SC_LSHIFT) or (iKeyId = SC_RSHIFT) then
                    Exit;                               // Shift finto inviato con i tasti cursore
                iKeyId := iKeyId or $100;
            end;
        end;
        if (iKeyId > 0) and (iKeyId < KEY_IDS) then
            rFState.aKeys[iKeyId] := (pKeyboard.Flags and RI_KEY_BREAK) = 0;
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
    FillChar(aFUsedJoy, SizeOf(aFUsedJoy), 0);
    FillChar(aFUsedPad, SizeOf(aFUsedPad), 0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.UseJoystick
//** Parametri di ingresso: iAId: Integer
//** Parametri di uscita: nessuno
//** Scopo: Segnalare che un joystick WinMM va letto ad ogni frame.
//** Data Ultima Modifica: 18/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.UseJoystick(iAId: Integer);
begin
    if (iAId >= 0) and (iAId < MAX_JOY) then
    begin
        aFUsedJoy[iAId] := True;
        aFJoyRetryAt[iAId] := 0;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.UsePad
//** Parametri di ingresso: iAIndex: Integer
//** Parametri di uscita: nessuno
//** Scopo: Segnalare che uno slot XInput va letto ad ogni frame.
//** Data Ultima Modifica: 18/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.UsePad(iAIndex: Integer);
begin
    if (iAIndex >= 0) and (iAIndex < MAX_PADS) then
    begin
        aFUsedPad[iAIndex] := True;
        aFPadRetryAt[iAIndex] := 0;
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
    rFState.rMouse.dPosX := 0;
    rFState.rMouse.dPosY := 0;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.pStatePtr
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: PInputSnapshot
//** Scopo: Puntatore allo stato corrente (evita copie del record grande).
//** Data Ultima Modifica: 19/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TInputManager.pStatePtr: PInputSnapshot;
begin
    Result := @rFState;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.bReadJoyCaps
//** Parametri di ingresso: iAId: Integer
//** Parametri di uscita: Result: Boolean
//** Scopo: Leggere le capacita' (range assi, POV) di un joystick WinMM.
//** Data Ultima Modifica: 19/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TInputManager.bReadJoyCaps(iAId: Integer): Boolean;
begin
    FillChar(aFJoyCaps[iAId], SizeOf(TJoyCapsRec), 0);
    Result := HI_joyGetDevCaps(NativeUInt(iAId), aFJoyCaps[iAId], SizeOf(TJoyCapsRec)) = JOYERR_NOERROR;
    aFJoyCapsOk[iAId] := Result;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.PollJoystick
//** Parametri di ingresso: iAId: Integer; iANow: UInt64
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
procedure TInputManager.PollJoystick(iAId: Integer; iANow: UInt64);
var
    rInfo: TJoyInfoExRec;
    pCaps: ^TJoyCapsRec;
    pJoy: ^TJoyState;
    iHidIndex: Integer;
    rCaps: TJoyCapsRec;
begin
    pJoy := @rFState.aJoys[iAId];
    if bFHidMapDirty then
        RebuildHidMap;

    // lettura HID (funziona anche in background) appena il dispositivo abbinato ha inviato dati
    iHidIndex := aFJoyHid[iAId];
    if (iHidIndex >= 0) and aFHid[iHidIndex].bLive then
    begin
        // ogni 2 s si controlla che il dispositivo sia ancora collegato
        if iANow >= aFJoyCheckAt[iAId] then
        begin
            aFJoyCheckAt[iAId] := iANow + 2000;
            FillChar(rCaps, SizeOf(rCaps), 0);
            if HI_joyGetDevCaps(NativeUInt(iAId), rCaps, SizeOf(rCaps)) <> JOYERR_NOERROR then
            begin
                bFHidMapDirty := True;
                aFJoyCapsOk[iAId] := False;
                aFJoyRetryAt[iAId] := iANow + 2000;
                pJoy^ := Default(TJoyState);
                pJoy.iPOV := -1;
                Exit;
            end;
        end;
        pJoy^ := aFHid[iHidIndex].rState;
        pJoy.bConnected := True;
        Exit;
    end;

    if not aFJoyCapsOk[iAId] then
    begin
        if iANow < aFJoyRetryAt[iAId] then
            Exit;
        aFJoyRetryAt[iAId] := iANow + 2000;
        if not bReadJoyCaps(iAId) then
        begin
            pJoy^ := Default(TJoyState);
            pJoy.iPOV := -1;
            Exit;
        end;
        bFHidMapDirty := True;    // dispositivo (ri)comparso: va (ri)abbinato al suo HID
    end;

    FillChar(rInfo, SizeOf(rInfo), 0);
    rInfo.dwSize := SizeOf(rInfo);
    rInfo.dwFlags := JOY_RETURNALL;
    if HI_joyGetPosEx(UINT(iAId), rInfo) <> JOYERR_NOERROR then
    begin
        pJoy^ := Default(TJoyState);
        pJoy.iPOV := -1;
        aFJoyCapsOk[iAId] := False;
        aFJoyRetryAt[iAId] := iANow + 2000;
        Exit;
    end;

    pCaps := @aFJoyCaps[iAId];
    pJoy.bConnected := True;
    pJoy.aAxes[0] := dNormAxis(rInfo.dwXpos, pCaps.wXmin, pCaps.wXmax);
    pJoy.aAxes[1] := dNormAxis(rInfo.dwYpos, pCaps.wYmin, pCaps.wYmax);
    pJoy.aAxes[2] := dNormAxis(rInfo.dwZpos, pCaps.wZmin, pCaps.wZmax);
    pJoy.aAxes[3] := dNormAxis(rInfo.dwRpos, pCaps.wRmin, pCaps.wRmax);
    pJoy.aAxes[4] := dNormAxis(rInfo.dwUpos, pCaps.wUmin, pCaps.wUmax);
    pJoy.aAxes[5] := dNormAxis(rInfo.dwVpos, pCaps.wVmin, pCaps.wVmax);
    pJoy.iButtons := rInfo.dwButtons;
    if ((pCaps.wCaps and JOYCAPS_HASPOV) <> 0) and (rInfo.dwPOV <= 35999) then
        pJoy.iPOV := rInfo.dwPOV div 100
    else
        pJoy.iPOV := -1;
end;

//** Joystick in Raw Input HID ******************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.iHidIndex
//** Parametri di ingresso: hAHandle: THandle
//** Parametri di uscita: Result: Integer
//** Scopo: Indice in aFHid del dispositivo con l'handle Raw Input indicato (-1 se sconosciuto).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TInputManager.iHidIndex(hAHandle: THandle): Integer;
var
    iHid: Integer;
begin
    for iHid := 0 to High(aFHid) do
        if aFHid[iHid].hHandle = hAHandle then
            Exit(iHid);
    Result := -1;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.iAddHidDevice
//** Parametri di ingresso: hAHandle: THandle
//** Parametri di uscita: Result: Integer
//** Scopo: Aggiungere a aFHid un dispositivo HID con le sue caratteristiche; restituisce l'indice.
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
function TInputManager.iAddHidDevice(hAHandle: THandle): Integer;
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
    rRec: THidJoyRec;
    rInfo: TRidDeviceInfoRec;
    iSize: UINT;
    sDevName: string;
    rCaps: THidpCapsRec;
    aValueCaps: array of THidpValueCapsRec;
    iCapsCount: Word;
    aFound: array[0..7] of THidAxisRec;
    aUsed: array[0..7] of Boolean;
    iCap, iSlot, iCandidate: Integer;
    iUsage, iUMin, iUMax: Word;
    rAxis: THidAxisRec;
begin
    rRec := Default(THidJoyRec);
    rRec.hHandle := hAHandle;
    rRec.iJoyId := -1;
    rRec.rState.iPOV := -1;
    try
        FillChar(rInfo, SizeOf(rInfo), 0);
        rInfo.cbSize := SizeOf(rInfo);
        iSize := SizeOf(rInfo);
        if HI_GetRawInputDeviceInfo(hAHandle, RIDI_DEVICEINFO, @rInfo, iSize) = $FFFFFFFF then
            Exit;
        if (rInfo.dwType <> RIM_TYPEHID) or (rInfo.usUsagePage <> HID_PAGE_DESKTOP) or
            not (rInfo.usUsage in [HID_USAGE_JOYSTICK, HID_USAGE_GAMEPAD, HID_USAGE_MULTIAXIS]) then
            Exit;
        rRec.iVid := Word(rInfo.dwVendorId);
        rRec.iPid := Word(rInfo.dwProductId);

        iSize := 0;
        HI_GetRawInputDeviceInfo(hAHandle, RIDI_DEVICENAME, nil, iSize);
        if iSize > 0 then
        begin
            SetLength(sDevName, iSize);
            if HI_GetRawInputDeviceInfo(hAHandle, RIDI_DEVICENAME, PChar(sDevName), iSize) <> $FFFFFFFF then
                rRec.sName := string(PChar(sDevName));
        end;

        iSize := 0;
        HI_GetRawInputDeviceInfo(hAHandle, RIDI_PREPARSEDDATA, nil, iSize);
        if iSize = 0 then
            Exit;
        SetLength(rRec.aPreparsed, iSize);
        if HI_GetRawInputDeviceInfo(hAHandle, RIDI_PREPARSEDDATA, @rRec.aPreparsed[0],
            iSize) = $FFFFFFFF then
            Exit;
        FillChar(rCaps, SizeOf(rCaps), 0);
        if HI_HidP_GetCaps(@rRec.aPreparsed[0], rCaps) <> HIDP_STATUS_SUCCESS then
            Exit;

        FillChar(aFound, SizeOf(aFound), 0);
        iCapsCount := rCaps.NumberInputValueCaps;
        if iCapsCount > 0 then
        begin
            SetLength(aValueCaps, iCapsCount);
            if HI_HidP_GetValueCaps(HIDP_INPUT, @aValueCaps[0], iCapsCount,
                @rRec.aPreparsed[0]) = HIDP_STATUS_SUCCESS then
                for iCap := 0 to Integer(iCapsCount) - 1 do
                    if aValueCaps[iCap].UsagePage = HID_PAGE_DESKTOP then
                    begin
                        iUMin := aValueCaps[iCap].UsageMin;
                        if aValueCaps[iCap].IsRange <> 0 then
                            iUMax := aValueCaps[iCap].UsageMax
                        else
                            iUMax := iUMin;
                        rAxis := Default(THidAxisRec);
                        rAxis.iLink := aValueCaps[iCap].LinkCollection;
                        rAxis.iBitSize := aValueCaps[iCap].BitSize;
                        rAxis.iMin := aValueCaps[iCap].LogicalMin;
                        rAxis.iMax := aValueCaps[iCap].LogicalMax;
                        rAxis.bSigned := rAxis.iMin < 0;
                        if (rAxis.iMax < rAxis.iMin) and (rAxis.iBitSize > 0) and (rAxis.iBitSize < 31) then
                        begin
                            rAxis.iMin := 0;
                            rAxis.iMax := (1 shl rAxis.iBitSize) - 1;
                            rAxis.bSigned := False;
                        end;
                        for iUsage := iUMin to iUMax do
                        begin
                            rAxis.iUsage := iUsage;
                            if iUsage = HID_USAGE_HAT then
                            begin
                                if rRec.rHat.iUsage = 0 then
                                    rRec.rHat := rAxis;
                            end
                            else if (iUsage >= HID_USAGE_X) and (iUsage <= HID_USAGE_X + 7) and
                                (aFound[iUsage - HID_USAGE_X].iUsage = 0) then
                                aFound[iUsage - HID_USAGE_X] := rAxis;
                        end;
                    end;
        end;

        FillChar(aUsed, SizeOf(aUsed), 0);
        for iSlot := 0 to JOY_AXES - 1 do
            for iCandidate := 0 to 3 do
            begin
                iCap := SLOT_CAND[iSlot, iCandidate];
                if (iCap >= 0) and not aUsed[iCap] and (aFound[iCap].iUsage <> 0) then
                begin
                    rRec.aAxis[iSlot] := aFound[iCap];
                    aUsed[iCap] := True;
                    Break;
                end;
            end;
        rRec.iMaxButtons := HI_HidP_MaxUsageListLength(HIDP_INPUT, HID_PAGE_BUTTON, @rRec.aPreparsed[0]);
        rRec.bValid := True;
    finally
        SetLength(aFHid, Length(aFHid) + 1);
        aFHid[High(aFHid)] := rRec;
        Result := High(aFHid);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.SyncHidDevices
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Allineare aFHid ai dispositivi Raw Input collegati (toglie gli scollegati, aggiunge i
//**        nuovi).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.SyncHidDevices;
var
    aList: array of TRawInputDeviceListRec;
    iDeviceCount, iCount: UINT;
    iHid, iDevice: Integer;
    aKeep: TArray<THidJoyRec>;
    bFound: Boolean;
begin
    iDeviceCount := 0;
    if HI_GetRawInputDeviceList(nil, iDeviceCount, SizeOf(TRawInputDeviceListRec)) = $FFFFFFFF then
        Exit;
    SetLength(aList, iDeviceCount + 8);
    iDeviceCount := Length(aList);
    iCount := HI_GetRawInputDeviceList(@aList[0], iDeviceCount, SizeOf(TRawInputDeviceListRec));
    if iCount = $FFFFFFFF then
        Exit;
    aKeep := nil;
    for iHid := 0 to High(aFHid) do
    begin
        bFound := False;
        for iDevice := 0 to Integer(iCount) - 1 do
            if aList[iDevice].hDevice = aFHid[iHid].hHandle then
                bFound := True;
        if bFound then
            aKeep := aKeep + [aFHid[iHid]];
    end;
    aFHid := aKeep;
    for iDevice := 0 to Integer(iCount) - 1 do
        if (aList[iDevice].dwType = RIM_TYPEHID) and (iHidIndex(aList[iDevice].hDevice) < 0) then
            iAddHidDevice(aList[iDevice].hDevice);
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
    iJoy, iHid, iBest: Integer;
    rCaps: TJoyCapsRec;
begin
    bFHidMapDirty := False;
    SyncHidDevices;
    for iJoy := 0 to MAX_JOY - 1 do
        aFJoyHid[iJoy] := -1;
    for iHid := 0 to High(aFHid) do
        aFHid[iHid].iJoyId := -1;
    for iJoy := 0 to MAX_JOY - 1 do
    begin
        FillChar(rCaps, SizeOf(rCaps), 0);
        if HI_joyGetDevCaps(NativeUInt(iJoy), rCaps, SizeOf(rCaps)) <> JOYERR_NOERROR then
            Continue;
        iBest := -1;
        for iHid := 0 to High(aFHid) do
            if aFHid[iHid].bValid and (aFHid[iHid].iJoyId < 0) and (aFHid[iHid].iVid = rCaps.wMid) and
                (aFHid[iHid].iPid = rCaps.wPid) then
                if (iBest < 0) or (CompareText(aFHid[iHid].sName, aFHid[iBest].sName) < 0) then
                    iBest := iHid;
        if iBest >= 0 then
        begin
            aFHid[iBest].iJoyId := iJoy;
            aFJoyHid[iJoy] := iBest;
        end;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.HandleHidInput
//** Parametri di ingresso: hADevice: THandle; pAData: PByte; iASize: Cardinal
//** Parametri di uscita: nessuno
//** Scopo: Gestire un pacchetto Raw Input HID (struttura RAWHID: dimensione, numero di rapporti,
//**        rapporti).
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento: un dispositivo mai visto viene aggiunto e l'abbinamento
//** ricalcolato; i rapporti vengono letti solo se il dispositivo e' abbinato a
//** un ID WinMM usato da un widget (i controller inviano centinaia di
//** rapporti al secondo). iASize e' il numero di byte disponibili in pAData: se
//** dimensione x numero dei rapporti non ci sta, il pacchetto e' ignorato.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.HandleHidInput(hADevice: THandle; pAData: PByte; iASize: Cardinal);
var
    iHid: Integer;
    iSizeHid, iCount, iReport: Cardinal;
    pRep: PByte;
begin
    iHid := iHidIndex(hADevice);
    if iHid < 0 then
    begin
        iHid := iAddHidDevice(hADevice);
        bFHidMapDirty := True;
    end;
    if not aFHid[iHid].bValid then
        Exit;
    if bFHidMapDirty then
    begin
        RebuildHidMap;
        iHid := iHidIndex(hADevice);
        if (iHid < 0) or not aFHid[iHid].bValid then
            Exit;
    end;
    if (aFHid[iHid].iJoyId < 0) or not aFUsedJoy[aFHid[iHid].iJoyId] then
        Exit;
    if iASize < 8 then
        Exit;
    iSizeHid := PCardinal(pAData)^;
    iCount := PCardinal(pAData + 4)^;
    if (iSizeHid = 0) or (UInt64(iSizeHid) * iCount > iASize - 8) then
        Exit;
    pRep := pAData + 8;
    for iReport := 1 to iCount do
    begin
        ParseHidReport(iHid, pRep, iSizeHid);
        Inc(pRep, iSizeHid);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.ParseHidReport
//** Parametri di ingresso: iAIndex: Integer; pAReport: PByte; iALength: Cardinal
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
procedure TInputManager.ParseHidReport(iAIndex: Integer; pAReport: PByte; iALength: Cardinal);
var
    pHid: ^THidJoyRec;
    pPre: Pointer;
    iAxis: Integer;
    iRawValue, iUsageCount, iUsageIndex: Cardinal;
    iAxisValue: Int64;
    iBtn: UInt32;
    iButtonUsage: Word;
begin
    pHid := @aFHid[iAIndex];
    pPre := @pHid.aPreparsed[0];
    for iAxis := 0 to JOY_AXES - 1 do
        if pHid.aAxis[iAxis].iUsage <> 0 then
            if HI_HidP_GetUsageValue(HIDP_INPUT, HID_PAGE_DESKTOP, pHid.aAxis[iAxis].iLink,
                pHid.aAxis[iAxis].iUsage, iRawValue, pPre,
                pAReport, iALength) = HIDP_STATUS_SUCCESS then
            begin
                iAxisValue := iHidValue(iRawValue, pHid.aAxis[iAxis]);
                if pHid.aAxis[iAxis].iMax > pHid.aAxis[iAxis].iMin then
                    pHid.rState.aAxes[iAxis] := EnsureRange((iAxisValue - pHid.aAxis[iAxis].iMin) / (pHid.aAxis[iAxis].iMax - pHid.aAxis[iAxis].iMin) * 2 - 1,
                        -1, 1)
                else
                    pHid.rState.aAxes[iAxis] := 0;
            end;

    if pHid.rHat.iUsage <> 0 then
        if HI_HidP_GetUsageValue(HIDP_INPUT, HID_PAGE_DESKTOP, pHid.rHat.iLink, pHid.rHat.iUsage, iRawValue,
            pPre,
            pAReport, iALength) = HIDP_STATUS_SUCCESS then
        begin
            iAxisValue := iHidValue(iRawValue, pHid.rHat);
            if (pHid.rHat.iMax > pHid.rHat.iMin) and (iAxisValue >= pHid.rHat.iMin)
                and (iAxisValue <= pHid.rHat.iMax) then
                pHid.rState.iPOV := Integer(((iAxisValue - pHid.rHat.iMin) * 360) div (pHid.rHat.iMax
                    - pHid.rHat.iMin + 1))
            else
                pHid.rState.iPOV := -1;
        end;

    if pHid.iMaxButtons > 0 then
    begin
        if Cardinal(Length(aFUsageBuf)) < pHid.iMaxButtons then
            SetLength(aFUsageBuf, pHid.iMaxButtons);
        iUsageCount := pHid.iMaxButtons;
        if HI_HidP_GetUsages(HIDP_INPUT, HID_PAGE_BUTTON, 0, @aFUsageBuf[0], iUsageCount, pPre, pAReport,
            iALength) = HIDP_STATUS_SUCCESS then
        begin
            iBtn := 0;
            for iUsageIndex := 1 to iUsageCount do
            begin
                iButtonUsage := aFUsageBuf[iUsageIndex - 1];
                if (iButtonUsage >= 1) and (iButtonUsage <= 32) then
                    iBtn := iBtn or (UInt32(1) shl (iButtonUsage - 1));
            end;
            pHid.rState.iButtons := iBtn;
        end;
    end;
    pHid.bLive := True;
    pHid.rState.bConnected := True;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.PollPad
//** Parametri di ingresso: iAIndex: Integer; iANow: UInt64
//** Parametri di uscita: nessuno
//** Scopo: Leggere lo stato di un gamepad XInput.
//** Data Ultima Modifica: 19/09/2026
//***********************************************************************************************************
//** Funzionamento: come per i joystick, uno slot vuoto viene ritentato ogni 2 s.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TInputManager.PollPad(iAIndex: Integer; iANow: UInt64);
var
    rState: TXInputStateRec;
    pPad: ^TPadState;
begin
    if not Assigned(mFXInputGetState) then
        Exit;
    pPad := @rFState.aPads[iAIndex];
    if (not pPad.bConnected) and (iANow < aFPadRetryAt[iAIndex]) then
        Exit;
    FillChar(rState, SizeOf(rState), 0);
    if mFXInputGetState(iAIndex, rState) <> ERROR_SUCCESS then
    begin
        pPad^ := Default(TPadState);
        aFPadRetryAt[iAIndex] := iANow + 2000;
        Exit;
    end;
    pPad.bConnected := True;
    pPad.iButtons := rState.Gamepad.wButtons;
    pPad.dLX := dNormThumb(rState.Gamepad.sThumbLX, 7849);
    pPad.dLY := dNormThumb(rState.Gamepad.sThumbLY, 7849);
    pPad.dRX := dNormThumb(rState.Gamepad.sThumbRX, 8689);
    pPad.dRY := dNormThumb(rState.Gamepad.sThumbRY, 8689);
    pPad.dLT := 0;
    pPad.dRT := 0;
    if rState.Gamepad.bLeftTrigger > 30 then
        pPad.dLT := rState.Gamepad.bLeftTrigger / 255;
    if rState.Gamepad.bRightTrigger > 30 then
        pPad.dRT := rState.Gamepad.bRightTrigger / 255;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.SafetyCheck
//** Parametri di ingresso: iANow: UInt64
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
procedure TInputManager.SafetyCheck(iANow: UInt64);
var
    iKey: Integer;
    bAnyState, bAnyPhys: Boolean;
begin
    if iANow < iFSafetyAt then
        Exit;
    iFSafetyAt := iANow + 1000;

    bAnyState := False;
    for iKey := 0 to KEY_IDS - 1 do
        if rFState.aKeys[iKey] then
        begin
            bAnyState := True;
            Break;
        end;
    if bAnyState then
    begin
        bAnyPhys := False;
        for iKey := 8 to 254 do
            if (GetAsyncKeyState(iKey) and $8000) <> 0 then
            begin
                bAnyPhys := True;
                Break;
            end;
        if bAnyPhys then
            iFKeyIdleChecks := 0
        else
        begin
            Inc(iFKeyIdleChecks);
            if iFKeyIdleChecks >= 2 then
            begin
                FillChar(rFState.aKeys, SizeOf(rFState.aKeys), 0);
                iFKeyIdleChecks := 0;
            end;
        end;
    end
    else
        iFKeyIdleChecks := 0;

    if iFMouseButtons <> 0 then
    begin
        bAnyPhys := ((GetAsyncKeyState(VK_LBUTTON) or GetAsyncKeyState(VK_RBUTTON) or
            GetAsyncKeyState(VK_MBUTTON) or GetAsyncKeyState(VK_XBUTTON1) or
            GetAsyncKeyState(VK_XBUTTON2)) and $8000) <> 0;
        if bAnyPhys then
            iFBtnIdleChecks := 0
        else
        begin
            Inc(iFBtnIdleChecks);
            if iFBtnIdleChecks >= 2 then
            begin
                iFMouseButtons := 0;
                iFBtnIdleChecks := 0;
            end;
        end;
    end
    else
        iFBtnIdleChecks := 0;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TInputManager.Poll
//** Parametri di ingresso: dADeltaT: Single
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
procedure TInputManager.Poll(dADeltaT: Single);
var
    iNow: UInt64;
    iJoy: Integer;
    pMouse: ^TMouseState;
    dSmoothing, dTargetX, dTargetY: Single;
begin
    iNow := GetTickCount64;
    pMouse := @rFState.rMouse;

    pMouse.dDX := iFRawDX;
    pMouse.dDY := iFRawDY;
    iFRawDX := 0;
    iFRawDY := 0;
    if dFMouseRange < 1 then
        dFMouseRange := 1;
    pMouse.dPosX := EnsureRange(pMouse.dPosX + pMouse.dDX / dFMouseRange, -1, 1);
    pMouse.dPosY := EnsureRange(pMouse.dPosY + pMouse.dDY / dFMouseRange, -1, 1);
    if dADeltaT > 0 then
    begin
        dTargetX := EnsureRange(pMouse.dDX / (dFMouseRange * 60 * dADeltaT * 0.02), -1, 1);
        dTargetY := EnsureRange(pMouse.dDY / (dFMouseRange * 60 * dADeltaT * 0.02), -1, 1);
        dSmoothing := 1 - Exp(-dADeltaT * 12);
        pMouse.dVelX := pMouse.dVelX + (dTargetX - pMouse.dVelX) * dSmoothing;
        pMouse.dVelY := pMouse.dVelY + (dTargetY - pMouse.dVelY) * dSmoothing;
    end;
    pMouse.dWheelDelta := iFRawWheel / 120;
    iFRawWheel := 0;
    if pMouse.dWheelDelta <> 0 then
    begin
        pMouse.dWheelAngle := pMouse.dWheelAngle - pMouse.dWheelDelta * 24;
        while pMouse.dWheelAngle >= 360 do pMouse.dWheelAngle := pMouse.dWheelAngle - 360;
        while pMouse.dWheelAngle < 0 do pMouse.dWheelAngle := pMouse.dWheelAngle + 360;
        pMouse.dWheelPulse := 1;
    end
    else
    begin
        pMouse.dWheelPulse := pMouse.dWheelPulse - dADeltaT * 4;
        if pMouse.dWheelPulse < 0 then
            pMouse.dWheelPulse := 0;
    end;
    pMouse.iButtons := iFMouseButtons;

    for iJoy := 0 to MAX_JOY - 1 do
        if aFUsedJoy[iJoy] then
            PollJoystick(iJoy, iNow);
    for iJoy := 0 to MAX_PADS - 1 do
        if aFUsedPad[iJoy] then
            PollPad(iJoy, iNow);

    SafetyCheck(iNow);
    Inc(rFState.iFrame);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TInputManager.aEnumJoysticks
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TArray<TJoyDeviceInfo>
//** Scopo: Elencare i 16 id joystick WinMM con nome, assi e pulsanti (usato dal Setup per scegliere
//**        il dispositivo di ogni widget), indicando se sono letti anche in background (HID) e con
//**        quali assi.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TInputManager.aEnumJoysticks: TArray<TJoyDeviceInfo>;
var
    iJoy, iHidIndex, iAxis: Integer;
    rInfo: TJoyInfoExRec;
    rCaps: TJoyCapsRec;
begin
    SetLength(Result, MAX_JOY);
    for iJoy := 0 to MAX_JOY - 1 do
    begin
        Result[iJoy] := Default(TJoyDeviceInfo);
        Result[iJoy].iId := iJoy;
        FillChar(rCaps, SizeOf(rCaps), 0);
        if HI_joyGetDevCaps(NativeUInt(iJoy), rCaps, SizeOf(rCaps)) <> JOYERR_NOERROR then
            Continue;
        FillChar(rInfo, SizeOf(rInfo), 0);
        rInfo.dwSize := SizeOf(rInfo);
        rInfo.dwFlags := JOY_RETURNALL;
        Result[iJoy].bPresent := HI_joyGetPosEx(UINT(iJoy), rInfo) = JOYERR_NOERROR;
        if not Result[iJoy].bPresent then
            Continue;
        Result[iJoy].sName := sJoyOemName(rCaps.wMid, rCaps.wPid);
        if Result[iJoy].sName = '' then
            Result[iJoy].sName := Trim(string(PWideChar(@rCaps.szPname[0])));
        Result[iJoy].iNumAxes := rCaps.wNumAxes;
        Result[iJoy].iNumButtons := rCaps.wNumButtons;
        Result[iJoy].bHasPOV := (rCaps.wCaps and JOYCAPS_HASPOV) <> 0;
    end;
    // abbinamento ai dispositivi HID (lettura in background) e assi usati
    RebuildHidMap;
    for iJoy := 0 to MAX_JOY - 1 do
        if Result[iJoy].bPresent and (aFJoyHid[iJoy] >= 0) then
        begin
            iHidIndex := aFJoyHid[iJoy];
            Result[iJoy].bBackground := True;
            Result[iJoy].sBgAxes := '';
            for iAxis := 0 to JOY_AXES - 1 do
            begin
                if iAxis > 0 then
                    Result[iJoy].sBgAxes := Result[iJoy].sBgAxes + ' ';
                Result[iJoy].sBgAxes := Result[iJoy].sBgAxes
                    + sHidAxisName(aFHid[iHidIndex].aAxis[iAxis].iUsage);
            end;
        end;
end;

end.
