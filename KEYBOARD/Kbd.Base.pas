//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Kbd.Base
//** Scopo: Base comune degli sketch delle tastiere.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: offre un piccolo "linguaggio" per descrivere un layout in unita' tasto
//** (1 u = un tasto standard): Row/At/Gap/K/KBox e blocchi gia' pronti
//** (riga funzione, blocco navigazione, frecce, tastierino numerico, riga spazio).
//**
//** I tasti sono identificati per SCAN CODE (costanti SC_* di Holo.Input), cioe'
//** per posizione fisica: la stessa unit funziona con qualunque lingua di
//** Windows; le legende sono solo testo.
//**
//** Geometria: tastiera in vista dall'alto nel piano XY, tasti sporgenti verso
//** -Z; un tasto premuto si abbassa (+Z) e si accende con il colore accento.
//***********************************************************************************************************
//***********************************************************************************************************
unit Kbd.Base;

interface

uses
    System.SysUtils, System.Math, System.Math.Vectors, System.Generics.Collections,
    FMX.Types, FMX.Controls3D, FMX.Objects3D,
    Holo.Config, Holo.Input, Holo.Prims, Holo.Models;

const
    KEY_DEPTH    = 0.42;   // altezza del tasto
    KEY_GAP      = 0.10;   // spazio tra i tasti
    PRESS_TRAVEL = 0.22;   // corsa del tasto premuto
    LEGEND_SIZE  = 0.30;   // altezza massima delle legende

type
    TKeyCap = class
    public
        Id: Word;
        Shape: THoloLines;    // copritasto arrotondato (loft)
        Pressed: Boolean;
    end;

    TKeyboardModel = class(TDeviceModel)
    private
        FCaps: TObjectList<TKeyCap>;
        FKeysRoot: TDummy;
        FCurX, FCurY: Single;
        FMaxX, FMaxY: Single;
    protected
        /// Il discendente descrive qui il proprio layout.
        procedure Layout; virtual; abstract;
        procedure Build; override;
        //** linguaggio di layout ***************************************************************************
        procedure Row(AY: Single);
        procedure At(AX: Single);
        procedure Gap(AW: Single);
        procedure K(const ALegend: string; AId: Word; AW: Single = 1; AH: Single = 1);
        procedure KBox(AX, AY, AW, AH: Single; AId: Word; const ALegend: string);
        procedure Keys(const ALegends: string; AFirstId: Word);
        //** blocchi comuni (coordinate standard di una tastiera 100%) **************************************
        procedure FunctionRow;
        procedure NavCluster(AX: Single);
        procedure ArrowCluster(AX: Single);
        procedure Numpad(AX: Single);
        procedure BottomRow(const ARightAlt: string);
        procedure AnsiMainBlock;
        procedure IsoItMainBlock;
    public
        destructor Destroy; override;
        procedure Update(const S: TInputSnapshot; const B: TWidgetConfig; ADeltaT: Single); override;
        class function Kind: TDeviceKind; override;
        class function DefaultView: TModelView; override;
    end;

implementation

uses
    Holo.Lang;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.Destroy
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Liberare l'elenco dei tasti (le forme 3D appartengono alla scena).
//** Data Ultima Modifica: 02/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
destructor TKeyboardModel.Destroy;
begin
    FCaps.Free;
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TKeyboardModel.Kind
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TDeviceKind
//** Scopo: Tipologia di dispositivo gestita dal modello (tastiera).
//** Data Ultima Modifica: 02/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TKeyboardModel.Kind: TDeviceKind;
begin
    Result := dkKeyboard;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TKeyboardModel.DefaultView
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TModelView
//** Scopo: Vista di default: tastiera "appoggiata" e vista da davanti-alto.
//** Data Ultima Modifica: 03/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
class function TKeyboardModel.DefaultView: TModelView;
begin
    Result := MakeView(-50, 0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.Build
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Costruire la tastiera.
//** Data Ultima Modifica: 03/10/2026
//***********************************************************************************************************
//** Funzionamento: chiama Layout (che crea i tasti sotto FKeysRoot misurando
//** l'ingombro), poi centra il gruppo nell'origine e aggiunge la piastra base.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKeyboardModel.Build;
begin
    FCaps := TObjectList<TKeyCap>.Create(True);
    FKeysRoot := Kit.Pivot(Root, 0, 0, 0);
    FMaxX := 0;
    FMaxY := 0;
    Layout;
    FKeysRoot.Position.Point := Point3D(-FMaxX / 2, -FMaxY / 2, 0);
    Kit.RBox(Root, 0, 0, KEY_DEPTH / 2 + 0.18, FMaxX + 0.5, FMaxY + 0.5, 0.3, hsDim, axZ, 0, 40, 6);
    SetExtent(FMaxX + 0.5, FMaxY + 0.5, KEY_DEPTH + 0.6);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.Row
//** Parametri di ingresso: AY: Single
//** Parametri di uscita: nessuno
//** Scopo: Iniziare una nuova riga alla quota AY (in unita'), con X = 0.
//** Data Ultima Modifica: 03/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKeyboardModel.Row(AY: Single);
begin
    FCurY := AY;
    FCurX := 0;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.At
//** Parametri di ingresso: AX: Single
//** Parametri di uscita: nessuno
//** Scopo: Spostare il cursore orizzontale alla colonna AX.
//** Data Ultima Modifica: 03/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKeyboardModel.At(AX: Single);
begin
    FCurX := AX;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.Gap
//** Parametri di ingresso: AW: Single
//** Parametri di uscita: nessuno
//** Scopo: Lasciare uno spazio vuoto largo AW unita'.
//** Data Ultima Modifica: 03/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKeyboardModel.Gap(AW: Single);
begin
    FCurX := FCurX + AW;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.K
//** Parametri di ingresso: ALegend: string; AId: Word; AW, AH: Single
//** Parametri di uscita: nessuno
//** Scopo: Aggiungere un tasto nella posizione del cursore e avanzare.
//** Data Ultima Modifica: 03/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKeyboardModel.K(const ALegend: string; AId: Word; AW, AH: Single);
begin
    KBox(FCurX, FCurY, AW, AH, AId, ALegend);
    FCurX := FCurX + AW;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.Keys
//** Parametri di ingresso: ALegends: string; AFirstId: Word
//** Parametri di uscita: nessuno
//** Scopo: Aggiungere una sequenza di tasti da 1 u con scan code consecutivi (es. 'QWERTYUIOP' a
//**        partire da SC_Q).
//** Data Ultima Modifica: 03/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKeyboardModel.Keys(const ALegends: string; AFirstId: Word);
var
    I: Integer;
begin
    for I := 1 to Length(ALegends) do
        K(ALegends[I], AFirstId + I - 1);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.KBox
//** Parametri di ingresso: AX, AY, AW, AH: Single; AId: Word; ALegend: string
//** Parametri di uscita: nessuno
//** Scopo: Aggiungere un tasto in posizione e dimensioni arbitrarie.
//** Data Ultima Modifica: 03/10/2026
//***********************************************************************************************************
//** Funzionamento: crea il copritasto (loft arrotondato e rastremato) centrato nel rettangolo, la legenda
//** sulla faccia rivolta alla camera e aggiorna l'ingombro totale. Due KBox con
//** lo stesso id formano un tasto sagomato (es. Invio ISO a "L").
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKeyboardModel.KBox(AX, AY, AW, AH: Single; AId: Word; const ALegend: string);
var
    Cap: TKeyCap;
    Sz: Single;
begin
    Cap := TKeyCap.Create;
    Cap.Id := AId;
    // copritasto arrotondato e rastremato verso l'alto (16 lati per sezione)
    Cap.Shape := Kit.RBox(FKeysRoot, AX + AW / 2, AY + AH / 2, 0, AW - KEY_GAP, AH - KEY_GAP,
        KEY_DEPTH, hsNormal, axZ, 0.16, 16);
    if ALegend <> '' then
    begin
        Sz := Min(LEGEND_SIZE, (AW - 0.3) / (Max(1, Length(ALegend)) * 0.6));
        Kit.Text(Cap.Shape, 0, 0, -KEY_DEPTH / 2 - 0.02, Sz, ALegend);
    end;
    FCaps.Add(Cap);
    FMaxX := Max(FMaxX, AX + AW);
    FMaxY := Max(FMaxY, AY + AH);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.FunctionRow
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Riga Esc + F1..F12 (quota 0).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKeyboardModel.FunctionRow;
const
    FKeys: array[1..12] of Word = (SC_F1, SC_F2, SC_F3, SC_F4, SC_F5, SC_F6,
        SC_F7, SC_F8, SC_F9, SC_F10, SC_F11, SC_F12);
var
    I: Integer;
begin
    Row(0);
    K(Tr('kbd.esc', 'ESC'), SC_ESC);
    Gap(1);
    for I := 1 to 12 do
    begin
        K('F' + IntToStr(I), FKeys[I]);
        if (I = 4) or (I = 8) then
            Gap(0.5);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.NavCluster
//** Parametri di ingresso: AX: Single
//** Parametri di uscita: nessuno
//** Scopo: Blocco Stamp/BlocScorr/Pausa + Ins/Home/PgSu + Canc/Fine/PgGiu.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKeyboardModel.NavCluster(AX: Single);
begin
    KBox(AX, 0, 1, 1, SC_PRTSC, Tr('kbd.prt', 'PRT'));
    KBox(AX + 1, 0, 1, 1, SC_SCROLL, Tr('kbd.scr', 'SCR'));
    KBox(AX + 2, 0, 1, 1, SC_PAUSE, Tr('kbd.pau', 'PAU'));
    KBox(AX, 1.25, 1, 1, SC_INS, Tr('kbd.ins', 'INS'));
    KBox(AX + 1, 1.25, 1, 1, SC_HOME, Tr('kbd.home', 'HOM'));
    KBox(AX + 2, 1.25, 1, 1, SC_PGUP, Tr('kbd.pgup', 'PGU'));
    KBox(AX, 2.25, 1, 1, SC_DEL, Tr('kbd.del', 'DEL'));
    KBox(AX + 1, 2.25, 1, 1, SC_END, Tr('kbd.end', 'END'));
    KBox(AX + 2, 2.25, 1, 1, SC_PGDN, Tr('kbd.pgdn', 'PGD'));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.ArrowCluster
//** Parametri di ingresso: AX: Single
//** Parametri di uscita: nessuno
//** Scopo: Frecce a "T" rovesciata.
//** Data Ultima Modifica: 04/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKeyboardModel.ArrowCluster(AX: Single);
begin
    KBox(AX + 1, 4.25, 1, 1, SC_UP, #$2191);
    KBox(AX, 5.25, 1, 1, SC_LEFT, #$2190);
    KBox(AX + 1, 5.25, 1, 1, SC_DOWN, #$2193);
    KBox(AX + 2, 5.25, 1, 1, SC_RIGHT, #$2192);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.Numpad
//** Parametri di ingresso: AX: Single
//** Parametri di uscita: nessuno
//** Scopo: Tastierino numerico (4 colonne, + e Invio alti 2 u, 0 largo 2 u).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKeyboardModel.Numpad(AX: Single);
begin
    KBox(AX, 1.25, 1, 1, SC_NUMLOCK, Tr('kbd.num', 'NUM'));
    KBox(AX + 1, 1.25, 1, 1, SC_NUMDIV, '/');
    KBox(AX + 2, 1.25, 1, 1, SC_NUMMUL, '*');
    KBox(AX + 3, 1.25, 1, 1, SC_NUMSUB, '-');
    KBox(AX, 2.25, 1, 1, SC_NUM7, '7');
    KBox(AX + 1, 2.25, 1, 1, SC_NUM8, '8');
    KBox(AX + 2, 2.25, 1, 1, SC_NUM9, '9');
    KBox(AX + 3, 2.25, 1, 2, SC_NUMADD, '+');
    KBox(AX, 3.25, 1, 1, SC_NUM4, '4');
    KBox(AX + 1, 3.25, 1, 1, SC_NUM5, '5');
    KBox(AX + 2, 3.25, 1, 1, SC_NUM6, '6');
    KBox(AX, 4.25, 1, 1, SC_NUM1, '1');
    KBox(AX + 1, 4.25, 1, 1, SC_NUM2, '2');
    KBox(AX + 2, 4.25, 1, 1, SC_NUM3, '3');
    KBox(AX + 3, 4.25, 1, 2, SC_NUMENTER, Tr('kbd.numenter', 'ENT'));
    KBox(AX, 5.25, 2, 1, SC_NUM0, '0');
    KBox(AX + 2, 5.25, 1, 1, SC_NUMDEL, '.');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.BottomRow
//** Parametri di ingresso: ARightAlt: string
//** Parametri di uscita: nessuno
//** Scopo: Riga inferiore (Ctrl, Win, Alt, Spazio, AltGr, Win, Menu, Ctrl).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKeyboardModel.BottomRow(const ARightAlt: string);
begin
    Row(5.25);
    K(Tr('kbd.ctrl', 'CTRL'), SC_LCTRL, 1.25);
    K(Tr('kbd.win', 'WIN'), SC_LWIN, 1.25);
    K(Tr('kbd.alt', 'ALT'), SC_LALT, 1.25);
    K('', SC_SPACE, 6.25);
    K(ARightAlt, SC_RALT, 1.25);
    K(Tr('kbd.win', 'WIN'), SC_RWIN, 1.25);
    K(Tr('kbd.menu', 'MNU'), SC_MENU, 1.25);
    K(Tr('kbd.ctrl', 'CTRL'), SC_RCTRL, 1.25);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.AnsiMainBlock
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Blocco alfanumerico ANSI (US) largo 15 u.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKeyboardModel.AnsiMainBlock;
begin
    Row(1.25);
    K('`', SC_GRAVE);
    Keys('1234567890', SC_1);
    K('-', SC_MINUS);
    K('=', SC_EQUAL);
    K(Tr('kbd.bksp', 'BKSP'), SC_BKSP, 2);

    Row(2.25);
    K(Tr('kbd.tab', 'TAB'), SC_TAB, 1.5);
    Keys('QWERTYUIOP', SC_Q);
    K('[', SC_LBR);
    K(']', SC_RBR);
    K('\', SC_BSLASH, 1.5);

    Row(3.25);
    K(Tr('kbd.caps', 'CAPS'), SC_CAPS, 1.75);
    Keys('ASDFGHJKL', SC_A);
    K(';', SC_SEMI);
    K('''', SC_QUOTE);
    K(Tr('kbd.enter', 'ENTER'), SC_ENTER, 2.25);

    Row(4.25);
    K(Tr('kbd.shift', 'SHIFT'), SC_LSHIFT, 2.25);
    Keys('ZXCVBNM', SC_Z);
    K(',', SC_COMMA);
    K('.', SC_DOT);
    K('/', SC_SLASH);
    K(Tr('kbd.shift', 'SHIFT'), SC_RSHIFT, 2.75);

    BottomRow(Tr('kbd.alt', 'ALT'));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.IsoItMainBlock
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Blocco alfanumerico ISO con legende italiane (Invio a "L", tasto <).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKeyboardModel.IsoItMainBlock;
begin
    Row(1.25);
    K('\', SC_GRAVE);
    Keys('1234567890', SC_1);
    K('''', SC_MINUS);
    K(#$00EC, SC_EQUAL);            // ì
    K(Tr('kbd.bksp', 'BKSP'), SC_BKSP, 2);

    Row(2.25);
    K(Tr('kbd.tab', 'TAB'), SC_TAB, 1.5);
    Keys('QWERTYUIOP', SC_Q);
    K(#$00E8, SC_LBR);              // è
    K('+', SC_RBR);
    KBox(13.5, 2.25, 1.5, 1.05, SC_ENTER, Tr('kbd.enter.iso', 'INV'));

    Row(3.25);
    K(Tr('kbd.caps', 'CAPS'), SC_CAPS, 1.75);
    Keys('ASDFGHJKL', SC_A);
    K(#$00F2, SC_SEMI);             // ò
    K(#$00E0, SC_QUOTE);            // à
    K(#$00F9, SC_BSLASH);           // ù
    KBox(13.75, 3.2, 1.25, 1.05, SC_ENTER, '');

    Row(4.25);
    K(Tr('kbd.shift', 'SHIFT'), SC_LSHIFT, 1.25);
    K('<', SC_ISO102);
    Keys('ZXCVBNM', SC_Z);
    K(',', SC_COMMA);
    K('.', SC_DOT);
    K('-', SC_SLASH);
    K(Tr('kbd.shift', 'SHIFT'), SC_RSHIFT, 2.75);

    BottomRow(Tr('kbd.altgr', 'ALTGR'));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TKeyboardModel.Update
//** Parametri di ingresso: S: TInputSnapshot; B: TWidgetConfig; ADeltaT: Single
//** Parametri di uscita: nessuno
//** Scopo: Animare i tasti in base allo stato della tastiera.
//** Data Ultima Modifica: 04/10/2026
//***********************************************************************************************************
//** Funzionamento: per ogni copritasto confronta lo stato con quello del frame
//** precedente; solo se cambia sposta il tasto (corsa) e lo accende/spegne.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TKeyboardModel.Update(const S: TInputSnapshot; const B: TWidgetConfig; ADeltaT: Single);
var
    Cap: TKeyCap;
    P: Boolean;
begin
    for Cap in FCaps do
    begin
        P := (Cap.Id < KEY_IDS) and S.Keys[Cap.Id];
        if P <> Cap.Pressed then
        begin
            Cap.Pressed := P;
            Cap.Shape.Active := P;
            if P then
                Cap.Shape.Position.Z := PRESS_TRAVEL
            else
                Cap.Shape.Position.Z := 0;
        end;
    end;
end;

end.
