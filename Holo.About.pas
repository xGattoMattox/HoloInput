//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.About
//** Scopo: Contenuto della pagina "Info" del Setup, disegnato interamente da codice con i colori della skin
//**        (nessuna immagine esterna).
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: THoloDossierCard  scheda "Citizen Dossier" dell'autore (dati del profilo
//**                     pubblico RSI) in stile ologramma: ritratto (logo
//**                     dell'autore, ARTWORK\avatar.png incorporato come risorsa
//**                     AVATAR_PNG e non sostituibile), campi del dossier,
//**                     organizzazione con SID;
//**   THoloInfoCard     informazioni sul software (versione, funzioni,
//**                     tecnologie, tasti rapidi, nota legale).
//** I contenuti di questa pagina non sono modificabili senza ricompilare:
//** l'avatar viene solo dalla risorsa incorporata e i testi passano da
//** TrBuiltin (solo le lingue incorporate, non i file della cartella LANG).
//** OpenUrl apre un indirizzo nel browser predefinito.
//** AppVersion legge la versione dalle Version Info dell'eseguibile (quelle
//** impostate in Project > Options > Application > Version Info).
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.About;

interface

uses
    Winapi.Windows, Winapi.ShellAPI,
    System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
    FMX.Types, FMX.Controls, FMX.Graphics,
    Holo.Skins, Holo.UI;

const
    HOLO_APP_NAME = 'HoloInput Overlay';
    HOLO_VERSION = '1.0';   // usata solo se l'exe non contiene le Version Info
    HOLO_AUTHOR = 'Citizen GattoMatto';

    /// Citizen Dossier (profilo pubblico RSI)
    DOSSIER_URL = 'https://robertsspaceindustries.com/en/citizens/GattoMatto';
    DOSSIER_HANDLE = 'GattoMatto';
    DOSSIER_MONIKER = 'Wolverine';
    DOSSIER_RECORD = '1631738';
    DOSSIER_ENLISTED = '25 ottobre 2016';
    DOSSIER_FLUENCY = 'Italiano';
    DOSSIER_TITLE = 'Farewell, Port Olisar';
    DOSSIER_ORG = 'Logistic Space Economy';
    DOSSIER_ORG_SID = 'ALSE';
    DOSSIER_ORG_RANK = 'Operatore';

type
    /// Base comune: pannello smussato con colori della skin.
    THoloCard = class(TControl)
    protected
        FColors: TSkinColors;
        procedure PaintFrame(const ATitle, ARight: string);
        procedure Txt(const R: TRectF; const S: string; ASize: Single; ABold: Boolean;
            AColor: TAlphaColor; AAlign: TTextAlign = TTextAlign.Leading; AWrap: Boolean = False);
    public
        constructor Create(AOwner: TComponent); override;
        procedure SetColors(const AColors: TSkinColors);
    end;

    /// Scheda "Citizen Dossier".
    THoloDossierCard = class(THoloCard)
    protected
        procedure Paint; override;
    end;

    /// Scheda con le informazioni sul software.
    THoloInfoCard = class(THoloCard)
    protected
        procedure Paint; override;
    end;

/// Apre un indirizzo web nel browser predefinito.
procedure OpenUrl(const AUrl: string);
/// Versione dell'eseguibile (es. "1.0.0.0") letta dalle Version Info del
/// progetto; se mancano restituisce HOLO_VERSION.
function AppVersion: string;

implementation

uses
    Holo.Lang;

var
    GAppVersion: string;
    GAvatar: TBitmap = nil;
    GAvatarTried: Boolean = False;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: Avatar
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: TBitmap
//** Scopo: Immagine dell'avatar (caricata una volta sola).
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: legge solo la risorsa RCDATA AVATAR_PNG incorporata
//** nell'exe (l'avatar dell'autore non e' sostituibile con un file esterno);
//** nil se manca (la scheda mostra allora le iniziali).
//***********************************************************************************************************
//***********************************************************************************************************
function Avatar: TBitmap;
var
    RS: TResourceStream;
begin
    if not GAvatarTried then
    begin
        GAvatarTried := True;
        try
            if FindResource(HInstance, 'AVATAR_PNG', RT_RCDATA) <> 0 then
            begin
                RS := TResourceStream.Create(HInstance, 'AVATAR_PNG', RT_RCDATA);
                try
                    GAvatar := TBitmap.Create;
                    GAvatar.LoadFromStream(RS);
                finally
                    RS.Free;
                end;
            end;
        except
            FreeAndNil(GAvatar);
        end;
    end;
    Result := GAvatar;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: AppVersion
//** Parametri di ingresso: nessuno
//** Parametri di uscita: Result: string
//** Scopo: Leggere la versione del file dalla risorsa VERSIONINFO dell'exe.
//** Data Ultima Modifica: 25/10/2026
//***********************************************************************************************************
//** Funzionamento: GetFileVersionInfo carica il blocco delle Version Info,
//** VerQueryValue('\') restituisce la struttura fissa con i quattro numeri
//** (Major.Minor.Release.Build). Il risultato viene letto una volta sola.
//***********************************************************************************************************
//***********************************************************************************************************
function AppVersion: string;
var
    FileName: string;
    Size, Dummy: DWORD;
    Buf: TBytes;
    Info: PVSFixedFileInfo;
    Len: UINT;
begin
    if GAppVersion <> '' then
        Exit(GAppVersion);
    Result := '';
    FileName := ParamStr(0);
    Size := GetFileVersionInfoSize(PChar(FileName), Dummy);
    if Size > 0 then
    begin
        SetLength(Buf, Size);
        if GetFileVersionInfo(PChar(FileName), 0, Size, @Buf[0]) and
            VerQueryValue(@Buf[0], '\', Pointer(Info), Len) and
            (Len >= SizeOf(TVSFixedFileInfo)) then
            Result := Format('%d.%d.%d.%d', [HiWord(Info^.dwFileVersionMS),
                LoWord(Info^.dwFileVersionMS), HiWord(Info^.dwFileVersionLS),
                LoWord(Info^.dwFileVersionLS)]);
    end;
    if Result = '' then
        Result := HOLO_VERSION;
    GAppVersion := Result;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: OpenUrl
//** Parametri di ingresso: AUrl: string
//** Parametri di uscita: nessuno
//** Scopo: Aprire un indirizzo web (es. il Citizen Dossier) nel browser predefinito di Windows.
//** Data Ultima Modifica: 25/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure OpenUrl(const AUrl: string);
begin
    ShellExecute(0, 'open', PChar(AUrl), nil, nil, SW_SHOWNORMAL);
end;

//** THoloCard **********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloCard.Create
//** Parametri di ingresso: AOwner: TComponent
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Inizializzare la scheda della pagina Info con i colori della skin predefinita, senza
//**        intercettare il mouse.
//** Data Ultima Modifica: 25/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
constructor THoloCard.Create(AOwner: TComponent);
begin
    inherited;
    FColors := DefaultSkinColors;
    HitTest := False;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloCard.SetColors
//** Parametri di ingresso: AColors: TSkinColors
//** Parametri di uscita: nessuno
//** Scopo: Applicare i colori della skin corrente alla scheda e ridisegnarla.
//** Data Ultima Modifica: 26/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloCard.SetColors(const AColors: TSkinColors);
begin
    FColors := AColors;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloCard.Txt
//** Parametri di ingresso: R: TRectF; S: string; ASize: Single; ABold: Boolean; AColor:
//**                        TAlphaColor; AAlign: TTextAlign; AWrap: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Scrivere un testo con il font dell'app.
//** Data Ultima Modifica: 26/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloCard.Txt(const R: TRectF; const S: string; ASize: Single; ABold: Boolean;
    AColor: TAlphaColor; AAlign: TTextAlign; AWrap: Boolean);
begin
    Canvas.Font.Family := HOLO_FONT;
    Canvas.Font.Size := ASize;
    if ABold then
        Canvas.Font.Style := [TFontStyle.fsBold]
    else
        Canvas.Font.Style := [];
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := AColor;
    Canvas.FillText(R, S, AWrap, AbsoluteOpacity, [], AAlign, TTextAlign.Leading);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloCard.PaintFrame
//** Parametri di ingresso: ATitle, ARight: string
//** Parametri di uscita: nessuno
//** Scopo: Disegnare il pannello comune: fondo smussato, bordo, staffe agli angoli, scanline
//**        leggere, intestazione con titolo a sinistra e testo a destra.
//** Data Ultima Modifica: 26/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloCard.PaintFrame(const ATitle, ARight: string);
const
    L = 22;
var
    R: TRectF;
    P: TPathData;
    Y: Single;
    Op: Single;
begin
    Op := AbsoluteOpacity;
    R := LocalRect;
    R.Inflate(-1.5, -1.5);
    P := ChamferPath(R, 20);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.Fill.Color := WithAlpha(MixColors(FColors.PanelBack, TAlphaColors.Black, 0.25), $F0);
        Canvas.FillPath(P, Op);
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 1.5;
        Canvas.Stroke.Color := FColors.PanelBorder;
        Canvas.DrawPath(P, Op);
    finally
        P.Free;
    end;

    // scanline
    Canvas.Stroke.Thickness := 1;
    Canvas.Stroke.Color := WithAlpha(FColors.Primary, $0E);
    Y := R.Top + 4;
    while Y < R.Bottom - 4 do
    begin
        Canvas.DrawLine(PointF(R.Left + 6, Y), PointF(R.Right - 6, Y), Op);
        Y := Y + 4;
    end;

    // staffe agli angoli (colore accento)
    Canvas.Stroke.Thickness := 2.5;
    Canvas.Stroke.Color := FColors.Accent;
    Canvas.DrawLine(PointF(R.Right - L, R.Top + 1), PointF(R.Right - 1, R.Top + 1), Op);
    Canvas.DrawLine(PointF(R.Right - 1, R.Top + 1), PointF(R.Right - 1, R.Top + L), Op);
    Canvas.DrawLine(PointF(R.Left + 1, R.Bottom - L), PointF(R.Left + 1, R.Bottom - 1), Op);
    Canvas.DrawLine(PointF(R.Left + 1, R.Bottom - 1), PointF(R.Left + L, R.Bottom - 1), Op);

    // intestazione
    Txt(RectF(R.Left + 24, R.Top + 12, R.Right - 20, R.Top + 38), ATitle, 16, True, FColors.Accent);
    Txt(RectF(R.Left + 24, R.Top + 15, R.Right - 22, R.Top + 38), ARight, 10, True,
        FColors.Primary, TTextAlign.Trailing);
    Canvas.Stroke.Thickness := 1;
    Canvas.Stroke.Color := WithAlpha(FColors.Primary, $70);
    Canvas.DrawLine(PointF(R.Left + 20, R.Top + 44), PointF(R.Right - 20, R.Top + 44), Op);
end;

//** THoloDossierCard ***************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloDossierCard.Paint
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare il dossier.
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: a sinistra il ritratto dell'autore (immagine AVATAR_PNG in
//** una doppia cornice smussata), il moniker e un "codice a barre" ricavato dal
//** numero di record; a
//** destra i campi del dossier su due colonne; in basso il riquadro
//** dell'organizzazione con il SID in evidenza e il grado.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloDossierCard.Paint;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: Field
    //** Parametri di ingresso: X, Y, W: Single; ALabel, AValue: string
    //** Parametri di uscita: nessuno
    //** Scopo: Disegnare un campo del dossier: etichetta piccola in maiuscolo e valore sotto in
    //**        grassetto.
    //** Data Ultima Modifica: 26/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Field(X, Y, W: Single; const ALabel, AValue: string);
    begin
        Txt(RectF(X, Y, X + W, Y + 14), UpperCase(ALabel), 9, True, WithAlpha(FColors.Primary, $B0));
        Txt(RectF(X, Y + 14, X + W, Y + 36), AValue, 14, True, FColors.Text);
    end;

var
    R, OrgR, SidR, AR: TRectF;
    P: TPathData;
    B: TBitmap;
    CX, CY, X, Y: Single;
    Op: Single;
    I, D: Integer;
begin
    PaintFrame(TrBuiltin('about.dossier.title', 'CITIZEN DOSSIER'),
        TrBuiltin('about.dossier.record', 'UEE CITIZEN RECORD  #') + DOSSIER_RECORD);
    Op := AbsoluteOpacity;
    R := LocalRect;

    // --- avatar: ritratto (risorsa AVATAR_PNG) in una cornice smussata
    CX := R.Left + 110;
    CY := R.Top + 138;
    AR := RectF(CX - 75, CY - 75, CX + 75, CY + 75);
    P := ChamferPath(AR, 14);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.Fill.Color := WithAlpha(FColors.Primary, $22);
        Canvas.FillPath(P, Op);
        B := Avatar;
        if B <> nil then
            Canvas.DrawBitmap(B, RectF(0, 0, B.Width, B.Height), AR, Op, False)
        else
            Txt(RectF(CX - 60, CY - 26, CX + 60, CY + 20), 'GM', 36, True, FColors.Primary,
                TTextAlign.Center);
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 2;
        Canvas.Stroke.Color := FColors.Primary;
        Canvas.DrawPath(P, Op);
    finally
        P.Free;
    end;
    // seconda cornice tratteggiata, leggermente piu' grande (effetto ologramma)
    AR.Inflate(6, 6);
    P := ChamferPath(AR, 18);
    try
        Canvas.Stroke.Thickness := 1;
        Canvas.Stroke.Dash := TStrokeDash.Dash;
        Canvas.Stroke.Color := WithAlpha(FColors.Primary, $A0);
        Canvas.DrawPath(P, Op);
        Canvas.Stroke.Dash := TStrokeDash.Solid;
    finally
        P.Free;
    end;
    Txt(RectF(CX - 80, CY + 88, CX + 80, CY + 108), UpperCase(DOSSIER_MONIKER), 13, True,
        FColors.Accent, TTextAlign.Center);

    // "codice a barre" dal numero di record
    X := CX - 64;
    Y := CY + 116;
    Canvas.Stroke.Color := WithAlpha(FColors.Primary, $C0);
    for I := 1 to Length(DOSSIER_RECORD) do
    begin
        D := Ord(DOSSIER_RECORD[I]) - Ord('0');
        Canvas.Stroke.Thickness := 1 + (D mod 3);
        Canvas.DrawLine(PointF(X, Y), PointF(X, Y + 18), Op);
        X := X + 4 + D mod 4;
        Canvas.Stroke.Thickness := 1;
        Canvas.DrawLine(PointF(X, Y), PointF(X, Y + 18), Op);
        X := X + 5;
    end;
    Txt(RectF(CX - 70, Y + 20, CX + 70, Y + 34), DOSSIER_RECORD, 9, False,
        WithAlpha(FColors.Primary, $B0), TTextAlign.Center);

    // --- campi del dossier
    X := R.Left + 220;
    Y := R.Top + 58;
    Field(X, Y, 180, TrBuiltin('about.dossier.handle', 'Handle'), DOSSIER_HANDLE);
    Field(X + 190, Y, 180, TrBuiltin('about.dossier.moniker', 'Moniker'), DOSSIER_MONIKER);
    Field(X, Y + 46, 180, TrBuiltin('about.dossier.enlisted', 'Arruolato'),
        TrBuiltin('about.dossier.enlisted.value', DOSSIER_ENLISTED));
    Field(X + 190, Y + 46, 180, TrBuiltin('about.dossier.fluency', 'Lingua'),
        TrBuiltin('about.dossier.fluency.value', DOSSIER_FLUENCY));
    Field(X, Y + 92, 370, TrBuiltin('about.dossier.titlefield', 'Titolo'), DOSSIER_TITLE);

    // --- organizzazione
    OrgR := RectF(X - 6, Y + 144, R.Right - 22, Y + 216);
    P := ChamferPath(OrgR, 10);
    try
        Canvas.Fill.Color := WithAlpha(FColors.Primary, $14);
        Canvas.FillPath(P, Op);
        Canvas.Stroke.Thickness := 1;
        Canvas.Stroke.Color := WithAlpha(FColors.Primary, $90);
        Canvas.DrawPath(P, Op);
    finally
        P.Free;
    end;
    Txt(RectF(OrgR.Left + 12, OrgR.Top + 8, OrgR.Right - 90, OrgR.Top + 22),
        TrBuiltin('about.dossier.mainorg', 'ORGANIZZAZIONE PRINCIPALE'), 9, True, WithAlpha(FColors.Primary, $B0));
    Txt(RectF(OrgR.Left + 12, OrgR.Top + 22, OrgR.Right - 90, OrgR.Top + 44),
        DOSSIER_ORG, 15, True, FColors.Text);
    Txt(RectF(OrgR.Left + 12, OrgR.Top + 46, OrgR.Right - 90, OrgR.Top + 64),
        TrBuiltin('about.dossier.rank', 'Grado: ') + TrBuiltin('about.dossier.rank.value', DOSSIER_ORG_RANK), 11, False,
        FColors.Text);

    SidR := RectF(OrgR.Right - 82, OrgR.Top + 14, OrgR.Right - 12, OrgR.Bottom - 14);
    P := ChamferPath(SidR, 7);
    try
        Canvas.Fill.Color := WithAlpha(FColors.Accent, $40);
        Canvas.FillPath(P, Op);
        Canvas.Stroke.Thickness := 1.5;
        Canvas.Stroke.Color := FColors.Accent;
        Canvas.DrawPath(P, Op);
    finally
        P.Free;
    end;
    Txt(RectF(SidR.Left, SidR.Top + 2, SidR.Right, SidR.Top + 14), TrBuiltin('about.dossier.sid', 'SID'), 8, True,
        FColors.Accent, TTextAlign.Center);
    Txt(RectF(SidR.Left, SidR.Top + 14, SidR.Right, SidR.Bottom), DOSSIER_ORG_SID, 15, True,
        FColors.Text, TTextAlign.Center);
end;

//** THoloInfoCard ******************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloInfoCard.Paint
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare le informazioni sul software (con copyright e licenza).
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloInfoCard.Paint;
var
    R: TRectF;
    X, Y, W: Single;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: Line
    //** Parametri di ingresso: S: string; ASize: Single; ABold: Boolean; AColor: TAlphaColor;
    //**                        AHeight: Single
    //** Parametri di uscita: nessuno
    //** Scopo: Scrivere una riga di testo della scheda informazioni e avanzare alla riga
    //**        successiva.
    //** Data Ultima Modifica: 26/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Line(const S: string; ASize: Single; ABold: Boolean; AColor: TAlphaColor;
        AHeight: Single);
    begin
        Txt(RectF(X, Y, X + W, Y + AHeight), S, ASize, ABold, AColor, TTextAlign.Leading, True);
        Y := Y + AHeight;
    end;

begin
    PaintFrame(TrBuiltin('about.info.title', 'INFORMAZIONI'),
        TrBuiltin('about.info.version', 'VERSIONE ') + AppVersion);
    R := LocalRect;
    X := R.Left + 24;
    W := R.Width - 48;
    Y := R.Top + 54;

    Line(UpperCase(HOLO_APP_NAME), 20, True, FColors.Primary, 28);
    Line(TrBuiltin('about.info.by', 'by ') + HOLO_AUTHOR, 12, True, FColors.Accent, 24);
    Line(TrBuiltin('about.info.description', 'Overlay olografico che mostra in tempo reale tastiera, mouse, ' +
        'gamepad, joystick e pulsantiere mentre giochi, con modelli 3D e skin ispirate ai ' +
        'costruttori di Star Citizen.'), 11, False, FColors.Text, 52);

    Line(TrBuiltin('about.info.tech', 'TECNOLOGIA'), 9, True, WithAlpha(FColors.Primary, $B0), 15);
    Line(TrBuiltin('about.info.tech.line1', 'Delphi 13  ' + #$00B7 + '  FireMonkey 3D  ' + #$00B7 +
        '  Raw Input (HID), XInput, WinMM'), 11, False, FColors.Text, 18);
    Line(TrBuiltin('about.info.tech.line2', 'Modelli 3D da foto con IA locale (ComfyUI + Pixal3D)'), 11, False,
        FColors.Text, 24);

    Line(TrBuiltin('about.info.hotkeys', 'TASTI RAPIDI'), 9, True, WithAlpha(FColors.Primary, $B0), 15);
    Line(TrBuiltin('about.info.hotkeys.line1', 'Ctrl+Alt+F12 blocca/sblocca layout   ' + #$00B7 +
        '   Ctrl+Alt+F11 setup'), 11, False, FColors.Text, 18);
    Line(TrBuiltin('about.info.hotkeys.line2', 'Ctrl+Alt+F10 mostra/nasconde   ' + #$00B7 +
        '   Ctrl+Alt+F9 modalita'' streamer'), 11, False, FColors.Text, 26);

    Line(TrBuiltin('about.info.disclaimer', 'Progetto amatoriale di un appassionato, non affiliato a ' +
        'Cloud Imperium Games o Roberts Space Industries. Star Citizen' + #$00AE + ' e'' un ' +
        'marchio di Cloud Imperium Rights LLC.'), 9, False, WithAlpha(FColors.Text, $A0), 38);
    Line(TrBuiltin('about.info.license', #$00A9 + ' 2026 Citizen GattoMatto  ' + #$00B7 +
        '  Licenza GNU GPL v3 con termini aggiuntivi (file LICENSE)'), 9, False,
        WithAlpha(FColors.Text, $A0), 16);
end;

initialization

finalization
    FreeAndNil(GAvatar);

end.
