//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.About
//** Scopo: Contenuto della pagina "Info" del Setup, disegnato interamente da codice con i colori della skin
//**        (nessuna immagine esterna).
//** Data Ultima Modifica: 06/11/2026
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
//** sTrBuiltin (solo le lingue incorporate, non i file della cartella LANG).
//** OpenUrl apre un indirizzo nel browser predefinito.
//** sAppVersion legge la versione dalle Version Info dell'eseguibile (quelle
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
        rFColors: TSkinColors;
        procedure PaintFrame(const sATitle, sARight: string);
        procedure Txt(const rARect: TRectF; const sAText: string; dASize: Single; bABold: Boolean;
            iAColor: TAlphaColor; eAAlign: TTextAlign = TTextAlign.Leading; bAWrap: Boolean = False);
    public
        constructor Create(AOwner: TComponent); override;
        procedure SetColors(const rAColors: TSkinColors);
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
procedure OpenUrl(const sAUrl: string);
/// Versione dell'eseguibile (es. "1.0.0.0") letta dalle Version Info del
/// progetto; se mancano restituisce HOLO_VERSION.
function sAppVersion: string;

implementation

uses
    Holo.Lang;

var
    sGAppVersion: string;
    oGAvatar: TBitmap = nil;
    bGAvatarTried: Boolean = False;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: oAvatar
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
function oAvatar: TBitmap;
var
    oStream: TResourceStream;
begin
    if not bGAvatarTried then
    begin
        bGAvatarTried := True;
        try
            if FindResource(HInstance, 'AVATAR_PNG', RT_RCDATA) <> 0 then
            begin
                oStream := TResourceStream.Create(HInstance, 'AVATAR_PNG', RT_RCDATA);
                try
                    oGAvatar := TBitmap.Create;
                    oGAvatar.LoadFromStream(oStream);
                finally
                    oStream.Free;
                end;
            end;
        except
            FreeAndNil(oGAvatar);
        end;
    end;
    Result := oGAvatar;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: sAppVersion
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
function sAppVersion: string;
var
    sFileName: string;
    iSize, iDummy: DWORD;
    aBuf: TBytes;
    pInfo: PVSFixedFileInfo;
    iLen: UINT;
begin
    if sGAppVersion <> '' then
        Exit(sGAppVersion);
    Result := '';
    sFileName := ParamStr(0);
    iSize := GetFileVersionInfoSize(PChar(sFileName), iDummy);
    if iSize > 0 then
    begin
        SetLength(aBuf, iSize);
        if GetFileVersionInfo(PChar(sFileName), 0, iSize, @aBuf[0]) and
            VerQueryValue(@aBuf[0], '\', Pointer(pInfo), iLen) and
            (iLen >= SizeOf(TVSFixedFileInfo)) then
            Result := Format('%d.%d.%d.%d', [HiWord(pInfo^.dwFileVersionMS),
                LoWord(pInfo^.dwFileVersionMS), HiWord(pInfo^.dwFileVersionLS),
                LoWord(pInfo^.dwFileVersionLS)]);
    end;
    if Result = '' then
        Result := HOLO_VERSION;
    sGAppVersion := Result;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: OpenUrl
//** Parametri di ingresso: sAUrl: string
//** Parametri di uscita: nessuno
//** Scopo: Aprire un indirizzo web (es. il Citizen Dossier) nel browser predefinito di Windows.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento: apre solo indirizzi "https://": qualsiasi altra cosa (un
//** file, un programma, "file://") viene ignorata, perche' ShellExecute la
//** aprirebbe o la eseguirebbe.
//***********************************************************************************************************
//***********************************************************************************************************
procedure OpenUrl(const sAUrl: string);
begin
    if sAUrl.StartsWith('https://', True) then
        ShellExecute(0, 'open', PChar(sAUrl), nil, nil, SW_SHOWNORMAL);
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
    rFColors := rDefaultSkinColors;
    HitTest := False;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloCard.SetColors
//** Parametri di ingresso: rAColors: TSkinColors
//** Parametri di uscita: nessuno
//** Scopo: Applicare i colori della skin corrente alla scheda e ridisegnarla.
//** Data Ultima Modifica: 26/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloCard.SetColors(const rAColors: TSkinColors);
begin
    rFColors := rAColors;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloCard.Txt
//** Parametri di ingresso: rARect: TRectF; sAText: string; dASize: Single; bABold: Boolean; iAColor:
//**                        TAlphaColor; eAAlign: TTextAlign; bAWrap: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Scrivere un testo con il font dell'app.
//** Data Ultima Modifica: 26/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloCard.Txt(const rARect: TRectF; const sAText: string; dASize: Single; bABold: Boolean;
    iAColor: TAlphaColor; eAAlign: TTextAlign; bAWrap: Boolean);
begin
    Canvas.Font.Family := HOLO_FONT;
    Canvas.Font.Size := dASize;
    if bABold then
        Canvas.Font.Style := [TFontStyle.fsBold]
    else
        Canvas.Font.Style := [];
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := iAColor;
    Canvas.FillText(rARect, sAText, bAWrap, AbsoluteOpacity, [], eAAlign, TTextAlign.Leading);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloCard.PaintFrame
//** Parametri di ingresso: sATitle, sARight: string
//** Parametri di uscita: nessuno
//** Scopo: Disegnare il pannello comune: fondo smussato, bordo, staffe agli angoli, scanline
//**        leggere, intestazione con titolo a sinistra e testo a destra.
//** Data Ultima Modifica: 26/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloCard.PaintFrame(const sATitle, sARight: string);
const
    L = 22;
var
    rRect: TRectF;
    oPath: TPathData;
    dPosY: Single;
    dOpacity: Single;
begin
    dOpacity := AbsoluteOpacity;
    rRect := LocalRect;
    rRect.Inflate(-1.5, -1.5);
    oPath := oChamferPath(rRect, 20);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.Fill.Color := iWithAlpha(iMixColors(rFColors.iPanelBack, TAlphaColors.Black, 0.25), $F0);
        Canvas.FillPath(oPath, dOpacity);
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 1.5;
        Canvas.Stroke.Color := rFColors.iPanelBorder;
        Canvas.DrawPath(oPath, dOpacity);
    finally
        oPath.Free;
    end;

    // scanline
    Canvas.Stroke.Thickness := 1;
    Canvas.Stroke.Color := iWithAlpha(rFColors.iPrimary, $0E);
    dPosY := rRect.Top + 4;
    while dPosY < rRect.Bottom - 4 do
    begin
        Canvas.DrawLine(PointF(rRect.Left + 6, dPosY), PointF(rRect.Right - 6, dPosY), dOpacity);
        dPosY := dPosY + 4;
    end;

    // staffe agli angoli (colore accento)
    Canvas.Stroke.Thickness := 2.5;
    Canvas.Stroke.Color := rFColors.iAccent;
    Canvas.DrawLine(PointF(rRect.Right - L, rRect.Top + 1), PointF(rRect.Right - 1, rRect.Top + 1),
        dOpacity);
    Canvas.DrawLine(PointF(rRect.Right - 1, rRect.Top + 1), PointF(rRect.Right - 1, rRect.Top + L),
        dOpacity);
    Canvas.DrawLine(PointF(rRect.Left + 1, rRect.Bottom - L), PointF(rRect.Left + 1, rRect.Bottom - 1),
        dOpacity);
    Canvas.DrawLine(PointF(rRect.Left + 1, rRect.Bottom - 1), PointF(rRect.Left + L, rRect.Bottom - 1),
        dOpacity);

    // intestazione
    Txt(RectF(rRect.Left + 24, rRect.Top + 12, rRect.Right - 20, rRect.Top + 38), sATitle, 16, True,
        rFColors.iAccent);
    Txt(RectF(rRect.Left + 24, rRect.Top + 15, rRect.Right - 22, rRect.Top + 38), sARight, 10, True,
        rFColors.iPrimary, TTextAlign.Trailing);
    Canvas.Stroke.Thickness := 1;
    Canvas.Stroke.Color := iWithAlpha(rFColors.iPrimary, $70);
    Canvas.DrawLine(PointF(rRect.Left + 20, rRect.Top + 44), PointF(rRect.Right - 20, rRect.Top + 44),
        dOpacity);
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
    //** Parametri di ingresso: dAPosX, dAPosY, dAWidth: Single; sALabel, sAValue: string
    //** Parametri di uscita: nessuno
    //** Scopo: Disegnare un campo del dossier: etichetta piccola in maiuscolo e valore sotto in
    //**        grassetto.
    //** Data Ultima Modifica: 26/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Field(dAPosX, dAPosY, dAWidth: Single; const sALabel, sAValue: string);
    begin
        Txt(RectF(dAPosX, dAPosY, dAPosX + dAWidth, dAPosY + 14), UpperCase(sALabel), 9, True,
            iWithAlpha(rFColors.iPrimary, $B0));
        Txt(RectF(dAPosX, dAPosY + 14, dAPosX + dAWidth, dAPosY + 36), sAValue, 14, True, rFColors.iText);
    end;

var
    rRect, rOrgR, rSidR, rAvatarRect: TRectF;
    oPath: TPathData;
    oBitmap: TBitmap;
    dCenterX, dCenterY, dPosX, dPosY: Single;
    dOpacity: Single;
    iPos, iDigit: Integer;
begin
    PaintFrame(sTrBuiltin('about.dossier.title', 'CITIZEN DOSSIER'),
        sTrBuiltin('about.dossier.record', 'UEE CITIZEN RECORD  #') + DOSSIER_RECORD);
    dOpacity := AbsoluteOpacity;
    rRect := LocalRect;

    // --- avatar: ritratto (risorsa AVATAR_PNG) in una cornice smussata
    dCenterX := rRect.Left + 110;
    dCenterY := rRect.Top + 138;
    rAvatarRect := RectF(dCenterX - 75, dCenterY - 75, dCenterX + 75, dCenterY + 75);
    oPath := oChamferPath(rAvatarRect, 14);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.Fill.Color := iWithAlpha(rFColors.iPrimary, $22);
        Canvas.FillPath(oPath, dOpacity);
        oBitmap := oAvatar;
        if oBitmap <> nil then
            Canvas.DrawBitmap(oBitmap, RectF(0, 0, oBitmap.Width, oBitmap.Height), rAvatarRect, dOpacity,
                False)
        else
            Txt(RectF(dCenterX - 60, dCenterY - 26, dCenterX + 60, dCenterY + 20), 'GM', 36, True,
                rFColors.iPrimary,
                TTextAlign.Center);
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 2;
        Canvas.Stroke.Color := rFColors.iPrimary;
        Canvas.DrawPath(oPath, dOpacity);
    finally
        oPath.Free;
    end;
    // seconda cornice tratteggiata, leggermente piu' grande (effetto ologramma)
    rAvatarRect.Inflate(6, 6);
    oPath := oChamferPath(rAvatarRect, 18);
    try
        Canvas.Stroke.Thickness := 1;
        Canvas.Stroke.Dash := TStrokeDash.Dash;
        Canvas.Stroke.Color := iWithAlpha(rFColors.iPrimary, $A0);
        Canvas.DrawPath(oPath, dOpacity);
        Canvas.Stroke.Dash := TStrokeDash.Solid;
    finally
        oPath.Free;
    end;
    Txt(RectF(dCenterX - 80, dCenterY + 88, dCenterX + 80, dCenterY + 108), UpperCase(DOSSIER_MONIKER), 13,
        True,
        rFColors.iAccent, TTextAlign.Center);

    // "codice a barre" dal numero di record
    dPosX := dCenterX - 64;
    dPosY := dCenterY + 116;
    Canvas.Stroke.Color := iWithAlpha(rFColors.iPrimary, $C0);
    for iPos := 1 to Length(DOSSIER_RECORD) do
    begin
        iDigit := Ord(DOSSIER_RECORD[iPos]) - Ord('0');
        Canvas.Stroke.Thickness := 1 + (iDigit mod 3);
        Canvas.DrawLine(PointF(dPosX, dPosY), PointF(dPosX, dPosY + 18), dOpacity);
        dPosX := dPosX + 4 + iDigit mod 4;
        Canvas.Stroke.Thickness := 1;
        Canvas.DrawLine(PointF(dPosX, dPosY), PointF(dPosX, dPosY + 18), dOpacity);
        dPosX := dPosX + 5;
    end;
    Txt(RectF(dCenterX - 70, dPosY + 20, dCenterX + 70, dPosY + 34), DOSSIER_RECORD, 9, False,
        iWithAlpha(rFColors.iPrimary, $B0), TTextAlign.Center);

    // --- campi del dossier
    dPosX := rRect.Left + 220;
    dPosY := rRect.Top + 58;
    Field(dPosX, dPosY, 180, sTrBuiltin('about.dossier.handle', 'Handle'), DOSSIER_HANDLE);
    Field(dPosX + 190, dPosY, 180, sTrBuiltin('about.dossier.moniker', 'Moniker'), DOSSIER_MONIKER);
    Field(dPosX, dPosY + 46, 180, sTrBuiltin('about.dossier.enlisted', 'Arruolato'),
        sTrBuiltin('about.dossier.enlisted.value', DOSSIER_ENLISTED));
    Field(dPosX + 190, dPosY + 46, 180, sTrBuiltin('about.dossier.fluency', 'Lingua'),
        sTrBuiltin('about.dossier.fluency.value', DOSSIER_FLUENCY));
    Field(dPosX, dPosY + 92, 370, sTrBuiltin('about.dossier.titlefield', 'Titolo'), DOSSIER_TITLE);

    // --- organizzazione
    rOrgR := RectF(dPosX - 6, dPosY + 144, rRect.Right - 22, dPosY + 216);
    oPath := oChamferPath(rOrgR, 10);
    try
        Canvas.Fill.Color := iWithAlpha(rFColors.iPrimary, $14);
        Canvas.FillPath(oPath, dOpacity);
        Canvas.Stroke.Thickness := 1;
        Canvas.Stroke.Color := iWithAlpha(rFColors.iPrimary, $90);
        Canvas.DrawPath(oPath, dOpacity);
    finally
        oPath.Free;
    end;
    Txt(RectF(rOrgR.Left + 12, rOrgR.Top + 8, rOrgR.Right - 90, rOrgR.Top + 22),
        sTrBuiltin('about.dossier.mainorg', 'ORGANIZZAZIONE PRINCIPALE'), 9, True, iWithAlpha(rFColors.iPrimary, $B0));
    Txt(RectF(rOrgR.Left + 12, rOrgR.Top + 22, rOrgR.Right - 90, rOrgR.Top + 44),
        DOSSIER_ORG, 15, True, rFColors.iText);
    Txt(RectF(rOrgR.Left + 12, rOrgR.Top + 46, rOrgR.Right - 90, rOrgR.Top + 64),
        sTrBuiltin('about.dossier.rank', 'Grado: ') + sTrBuiltin('about.dossier.rank.value', DOSSIER_ORG_RANK), 11, False,
        rFColors.iText);

    rSidR := RectF(rOrgR.Right - 82, rOrgR.Top + 14, rOrgR.Right - 12, rOrgR.Bottom - 14);
    oPath := oChamferPath(rSidR, 7);
    try
        Canvas.Fill.Color := iWithAlpha(rFColors.iAccent, $40);
        Canvas.FillPath(oPath, dOpacity);
        Canvas.Stroke.Thickness := 1.5;
        Canvas.Stroke.Color := rFColors.iAccent;
        Canvas.DrawPath(oPath, dOpacity);
    finally
        oPath.Free;
    end;
    Txt(RectF(rSidR.Left, rSidR.Top + 2, rSidR.Right, rSidR.Top + 14), sTrBuiltin('about.dossier.sid', 'SID'), 8, True,
        rFColors.iAccent, TTextAlign.Center);
    Txt(RectF(rSidR.Left, rSidR.Top + 14, rSidR.Right, rSidR.Bottom), DOSSIER_ORG_SID, 15, True,
        rFColors.iText, TTextAlign.Center);
end;

//** THoloInfoCard ******************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloInfoCard.Paint
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare le informazioni sul software (con copyright e licenza).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloInfoCard.Paint;
var
    rRect: TRectF;
    dPosX, dPosY, dWidth: Single;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome procedura: Line
    //** Parametri di ingresso: sAText: string; dASize: Single; bABold: Boolean; iAColor: TAlphaColor;
    //**                        dAHeight: Single
    //** Parametri di uscita: nessuno
    //** Scopo: Scrivere una riga di testo della scheda informazioni e avanzare alla riga
    //**        successiva.
    //** Data Ultima Modifica: 26/10/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    procedure Line(const sAText: string; dASize: Single; bABold: Boolean; iAColor: TAlphaColor;
        dAHeight: Single);
    begin
        Txt(RectF(dPosX, dPosY, dPosX + dWidth, dPosY + dAHeight), sAText, dASize, bABold, iAColor,
            TTextAlign.Leading, True);
        dPosY := dPosY + dAHeight;
    end;

begin
    PaintFrame(sTrBuiltin('about.info.title', 'INFORMAZIONI'),
        sTrBuiltin('about.info.version', 'VERSIONE ') + sAppVersion);
    rRect := LocalRect;
    dPosX := rRect.Left + 24;
    dWidth := rRect.Width - 48;
    dPosY := rRect.Top + 54;

    Line(UpperCase(HOLO_APP_NAME), 20, True, rFColors.iPrimary, 28);
    Line(sTrBuiltin('about.info.by', 'by ') + HOLO_AUTHOR, 12, True, rFColors.iAccent, 24);
    Line(sTrBuiltin('about.info.description', 'Overlay olografico che mostra in tempo reale tastiera, mouse, ' +
        'gamepad, joystick, manette e pulsantiere mentre giochi, con modelli 3D e skin ispirate ai ' +
        'costruttori di Star Citizen.'), 11, False, rFColors.iText, 52);

    Line(sTrBuiltin('about.info.tech', 'TECNOLOGIA'), 9, True, iWithAlpha(rFColors.iPrimary, $B0), 15);
    Line(sTrBuiltin('about.info.tech.line1', 'Delphi 13  ' + #$00B7 + '  FireMonkey 3D  ' + #$00B7 +
        '  Raw Input (HID), XInput, WinMM'), 11, False, rFColors.iText, 18);
    Line(sTrBuiltin('about.info.tech.line2', 'Modelli 3D da foto con IA locale (ComfyUI + Pixal3D)'), 11, False,
        rFColors.iText, 24);

    Line(sTrBuiltin('about.info.hotkeys', 'TASTI RAPIDI'), 9, True, iWithAlpha(rFColors.iPrimary, $B0), 15);
    Line(sTrBuiltin('about.info.hotkeys.line1', 'Ctrl+Alt+F12 blocca/sblocca layout   ' + #$00B7 +
        '   Ctrl+Alt+F11 setup'), 11, False, rFColors.iText, 18);
    Line(sTrBuiltin('about.info.hotkeys.line2', 'Ctrl+Alt+F10 mostra/nasconde   ' + #$00B7 +
        '   Ctrl+Alt+F9 modalita'' streamer'), 11, False, rFColors.iText, 24);

    Line(sTrBuiltin('about.info.disclaimer', 'Progetto amatoriale non affiliato a Cloud Imperium Games, ' +
        'Roberts Space Industries o produttori di hardware. Star Citizen' + #$00AE + ' e Roberts Space ' +
        'Industries' + #$00AE + ' sono marchi di Cloud Imperium Rights LLC; tutti gli altri marchi ' +
        'appartengono ai rispettivi proprietari.'), 9, False, iWithAlpha(rFColors.iText, $A0), 40);
    Line(sTrBuiltin('about.info.license', #$00A9 + ' 2026 Citizen GattoMatto  ' + #$00B7 +
        '  Licenza GNU GPL v3 con termini aggiuntivi (file LICENSE)'), 9, False,
        iWithAlpha(rFColors.iText, $A0), 16);
end;

initialization

finalization
    FreeAndNil(oGAvatar);

end.
