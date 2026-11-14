//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Disclaimer
//** Scopo: Avviso legale mostrato al primo avvio (finche' non viene accettato).
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: stessa grafica dell'applicazione: finestra senza bordi con pannello dagli
//** angoli smussati nei colori della skin, titoli in Bahnschrift, testi in
//** Segoe UI, pulsanti THoloButton.
//**
//** Contenuto:
//**   - scelta della lingua e della skin (si applicano subito all'avviso e
//**     vengono salvate nel .ini quando si accetta);
//**   - software amatoriale fornito "cosi' com'e'", senza garanzie;
//**   - marchi citati di proprieta' dei rispettivi titolari;
//**   - possibile impatto non quantificabile sulle prestazioni del gioco;
//**   - software in continuo sviluppo e aggiornamento;
//**   - pulsanti "Accetto" e "Rifiuto": rifiutando l'applicazione termina.
//** Tutti i testi passano da Tr (chiavi disclaimer.*, vedi Holo.Lang).
//** La finestra si sposta trascinando la fascia del titolo.
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.Disclaimer;

interface

uses
    Holo.Config;

/// Mostra l'avviso; True se l'utente accetta. Lingua e skin scelte vengono
/// scritte in oAConfig (Language, sSkinId); la lingua scelta resta caricata.
function bRunDisclaimer(oAConfig: TAppConfig): Boolean;

implementation

uses
    System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
    FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls, FMX.ListBox,
    FMX.Controls.Presentation,
    Holo.Skins, Holo.UI, Holo.Lang;

const
    DLG_W = 760;
    DLG_H = 730;
    DLG_PAD = 24;
    TITLE_LINE_Y = 56;     // riga sotto il titolo (e limite della fascia di trascinamento)
    SEL_Y = 70;            // riga delle scelte di lingua e skin
    INTRO_Y = 114;
    ITEM_Y0 = 146;         // primo punto dell'avviso
    ITEM_DY = 114;         // distanza tra i punti
    ITEM_COUNT = 4;
    BTN_W = 150;
    BTN_H = 34;
    BODY_FONT = 'Segoe UI';

type
    /// Sfondo dell'avviso: pannello smussato con bordo accento e riga sotto il titolo.
    TDisclaimerPanel = class(TControl)
    private
        rFColors: TSkinColors;
    protected
        procedure Paint; override;
    end;

    /// Finestra dell'avviso (creata da codice, senza .fmx).
    TfrmDisclaimer = class(TForm)
    private
        oFConfig: TAppConfig;
        rFColors: TSkinColors;
        oFPanel: TDisclaimerPanel;
        oFTitle, oFIntro, oFFooter, oFLangLabel, oFSkinLabel: TLabel;
        aFHeads, aFTexts: array[0..ITEM_COUNT - 1] of TLabel;
        oFLang, oFSkin: TComboBox;
        aFLangs: TArray<TLangInfo>;
        oFAccept, oFDecline: THoloButton;
        bFLoading: Boolean;
        function oMakeText(dAPosX, dAPosY, dAWidth, dAHeight, dASize: Single; bABold,
            bAHolo: Boolean): TLabel;
        procedure BuildUI;
        procedure ApplyTexts;
        procedure ApplyColors;
        procedure LangChange(oSender: TObject);
        procedure SkinChange(oSender: TObject);
        procedure AcceptClick(oSender: TObject);
        procedure DeclineClick(oSender: TObject);
        procedure PanelMouseDown(oSender: TObject; eButton: TMouseButton; eShift: TShiftState;
            dAPosX, dAPosY: Single);
    public
        constructor CreateDisclaimer(oAConfig: TAppConfig);
    end;

//** TDisclaimerPanel ***************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TDisclaimerPanel.Paint
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare il pannello dell'avviso.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: come le finestre di messaggio dell'app (Holo.Dialog):
//** contorno smussato (oChamferPath), sfondo scuro quasi opaco tinto con la
//** skin, bordo nel colore accento, staffe d'angolo e una riga sottile sotto
//** il titolo.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDisclaimerPanel.Paint;
const
    L = 26;
var
    rRect: TRectF;
    oPath: TPathData;
    dOpacity: Single;
begin
    dOpacity := AbsoluteOpacity;
    rRect := LocalRect;
    rRect.Inflate(-1.5, -1.5);
    oPath := oChamferPath(rRect, 22);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.Fill.Color := iWithAlpha(iMixColors(rFColors.iPanelBack, TAlphaColors.Black, 0.35), $F6);
        Canvas.FillPath(oPath, dOpacity);
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 2;
        Canvas.Stroke.Color := rFColors.iAccent;
        Canvas.DrawPath(oPath, dOpacity);
    finally
        oPath.Free;
    end;
    // staffe d'angolo (alto a destra, basso a sinistra)
    Canvas.Stroke.Thickness := 3;
    Canvas.DrawLine(PointF(rRect.Right - L, rRect.Top + 1), PointF(rRect.Right - 1, rRect.Top + 1),
        dOpacity);
    Canvas.DrawLine(PointF(rRect.Right - 1, rRect.Top + 1), PointF(rRect.Right - 1, rRect.Top + L),
        dOpacity);
    Canvas.DrawLine(PointF(rRect.Left + 1, rRect.Bottom - L), PointF(rRect.Left + 1, rRect.Bottom - 1),
        dOpacity);
    Canvas.DrawLine(PointF(rRect.Left + 1, rRect.Bottom - 1), PointF(rRect.Left + L, rRect.Bottom - 1),
        dOpacity);
    // righe sotto il titolo e sopra i punti dell'avviso
    Canvas.Stroke.Thickness := 1;
    Canvas.Stroke.Color := rFColors.iPanelBorder;
    Canvas.DrawLine(PointF(DLG_PAD, TITLE_LINE_Y), PointF(Width - DLG_PAD, TITLE_LINE_Y), dOpacity);
    Canvas.DrawLine(PointF(DLG_PAD, INTRO_Y - 8), PointF(Width - DLG_PAD, INTRO_Y - 8), dOpacity);
end;

//** TfrmDisclaimer *****************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.CreateDisclaimer
//** Parametri di ingresso: oAConfig: TAppConfig
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare la finestra dell'avviso collegata alla configurazione.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: finestra senza bordi, sfondo trasparente (si vede solo il
//** pannello smussato), sempre in primo piano e centrata sullo schermo;
//** costruisce i controlli, poi applica testi e colori della lingua e della
//** skin attuali.
//***********************************************************************************************************
//***********************************************************************************************************
constructor TfrmDisclaimer.CreateDisclaimer(oAConfig: TAppConfig);
begin
    inherited CreateNew(nil);
    oFConfig := oAConfig;
    BorderStyle := TFmxFormBorderStyle.None;
    Transparency := True;
    FormStyle := TFormStyle.StayOnTop;
    Position := TFormPosition.ScreenCenter;
    Width := DLG_W;
    Height := DLG_H;
    BuildUI;
    ApplyTexts;
    ApplyColors;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmDisclaimer.oMakeText
//** Parametri di ingresso: dAPosX, dAPosY, dAWidth, dAHeight, dASize: Single; bABold, bAHolo: Boolean
//** Parametri di uscita: Result: TLabel
//** Scopo: Creare un testo (vuoto) sul pannello, allineato in alto e a capo automatico.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: bAHolo = font olografico dell'app (titoli), altrimenti
//** Segoe UI (testi). Font, colore e allineamento non vengono presi dallo
//** stile FMX; testo e colore si impostano in ApplyTexts / ApplyColors.
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmDisclaimer.oMakeText(dAPosX, dAPosY, dAWidth, dAHeight, dASize: Single; bABold,
    bAHolo: Boolean): TLabel;
begin
    Result := TLabel.Create(Self);
    Result.Parent := oFPanel;
    Result.SetBounds(dAPosX, dAPosY, dAWidth, dAHeight);
    Result.StyledSettings := [];
    if bAHolo then
        Result.TextSettings.Font.Family := HOLO_FONT
    else
        Result.TextSettings.Font.Family := BODY_FONT;
    Result.TextSettings.Font.Size := dASize;
    if bABold then
        Result.TextSettings.Font.Style := [TFontStyle.fsBold];
    Result.TextSettings.VertAlign := TTextAlign.Leading;
    Result.TextSettings.HorzAlign := TTextAlign.Leading;
    Result.TextSettings.WordWrap := True;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.BuildUI
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Costruire pannello, scelte di lingua e skin, punti dell'avviso e pulsanti.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: dall'alto: titolo (fascia di trascinamento), lingua e
//** skin, introduzione, quattro punti (titoletto + testo), nota finale e i
//** pulsanti Accetto / Rifiuto in basso a destra. Le combo partono con i
//** valori della configurazione.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmDisclaimer.BuildUI;
var
    iLang, iSel: Integer;
    dTextWidth: Single;
begin
    dTextWidth := DLG_W - 2 * DLG_PAD;
    oFPanel := TDisclaimerPanel.Create(Self);
    oFPanel.Parent := Self;
    oFPanel.Align := TAlignLayout.Client;
    oFPanel.HitTest := True;
    oFPanel.OnMouseDown := PanelMouseDown;

    oFTitle := oMakeText(DLG_PAD, 16, dTextWidth, 32, 16, True, True);

    // lingua e skin
    oFLangLabel := oMakeText(DLG_PAD, SEL_Y + 4, 80, 22, 11, False, False);
    oFLang := TComboBox.Create(Self);
    oFLang.Parent := oFPanel;
    oFLang.SetBounds(DLG_PAD + 80, SEL_Y, 230, 26);
    aFLangs := aAvailableLanguages;
    iSel := 0;
    for iLang := 0 to High(aFLangs) do
    begin
        oFLang.Items.Add(aFLangs[iLang].sName);
        if SameText(aFLangs[iLang].sId, oFConfig.sLanguage) then
            iSel := iLang;
    end;
    oFSkinLabel := oMakeText(DLG_PAD + 350, SEL_Y + 4, 70, 22, 11, False, False);
    oFSkin := TComboBox.Create(Self);
    oFSkin.Parent := oFPanel;
    oFSkin.SetBounds(DLG_PAD + 420, SEL_Y, dTextWidth - 420, 26);
    for iLang := 0 to iSkinCount - 1 do
        oFSkin.Items.Add(oSkinByIndex(iLang).sDisplayName);
    bFLoading := True;
    try
        if oFLang.Items.Count > 0 then
            oFLang.ItemIndex := iSel;
        oFSkin.ItemIndex := Max(0, iSkinIndexOf(oFConfig.sSkinId));
    finally
        bFLoading := False;
    end;
    oFLang.OnChange := LangChange;
    oFSkin.OnChange := SkinChange;

    // introduzione e punti dell'avviso
    oFIntro := oMakeText(DLG_PAD, INTRO_Y, dTextWidth, 24, 12, False, False);
    for iLang := 0 to ITEM_COUNT - 1 do
    begin
        aFHeads[iLang] := oMakeText(DLG_PAD, ITEM_Y0 + iLang * ITEM_DY, dTextWidth, 22, 12, True, True);
        aFTexts[iLang] := oMakeText(DLG_PAD, ITEM_Y0 + iLang * ITEM_DY + 22, dTextWidth, ITEM_DY - 26, 11,
            False, False);
    end;
    oFFooter := oMakeText(DLG_PAD, ITEM_Y0 + ITEM_COUNT * ITEM_DY, dTextWidth, 40, 10, False, False);

    // pulsanti
    oFDecline := THoloButton.Create(Self);
    oFDecline.Parent := oFPanel;
    oFDecline.SetBounds(DLG_W - DLG_PAD - BTN_W, DLG_H - DLG_PAD - BTN_H, BTN_W, BTN_H);
    oFDecline.OnClick := DeclineClick;
    oFAccept := THoloButton.Create(Self);
    oFAccept.Parent := oFPanel;
    oFAccept.SetBounds(DLG_W - DLG_PAD - 2 * BTN_W - 12, DLG_H - DLG_PAD - BTN_H, BTN_W, BTN_H);
    oFAccept.OnClick := AcceptClick;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.ApplyTexts
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Scrivere tutti i testi dell'avviso nella lingua corrente.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: legge ogni testo con Tr (chiavi disclaimer.*); viene
//** richiamata quando si cambia lingua, cosi' l'avviso si traduce subito.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmDisclaimer.ApplyTexts;
begin
    Caption := sTr('disclaimer.caption', 'HoloInput - Avviso legale');
    oFTitle.Text := #$26A0 + '  ' + sTr('disclaimer.title', 'AVVISO LEGALE E CONDIZIONI D''USO');
    oFLangLabel.Text := sTr('disclaimer.language', 'Lingua');
    oFSkinLabel.Text := sTr('disclaimer.skin', 'Skin');
    oFIntro.Text := sTr('disclaimer.intro', 'Prima di utilizzare HoloInput leggi con attenzione le ' +
        'seguenti condizioni.');

    aFHeads[0].Text := sTr('disclaimer.hobby.title', 'SOFTWARE AMATORIALE, SENZA GARANZIE');
    aFTexts[0].Text := sTr('disclaimer.hobby.text', 'La presente versione di HoloInput e'' un software ' +
        'amatoriale distribuito gratuitamente (freeware), realizzato da un appassionato a titolo non ' +
        'professionale; la gratuita'' riguarda esclusivamente questa versione e l''autore si riserva il ' +
        'diritto di distribuire versioni future con condizioni di licenza diverse, anche a pagamento. ' +
        'Il software e'' fornito "cosi'' com''e''" ("as is"), senza garanzie di alcun tipo, esplicite o ' +
        'implicite, incluse quelle di funzionamento, commerciabilita'' e idoneita'' a uno scopo ' +
        'particolare. L''utilizzo avviene a proprio rischio: nei limiti consentiti dalla legge l''autore ' +
        'non risponde di danni diretti o indiretti derivanti dall''uso del software.');

    aFHeads[1].Text := sTr('disclaimer.trademarks.title', 'MARCHI DI TERZI');
    aFTexts[1].Text := sTr('disclaimer.trademarks.text', 'HoloInput e'' un progetto amatoriale di un ' +
        'appassionato, non affiliato, sponsorizzato ne'' approvato da Cloud Imperium Games, Roberts Space ' +
        'Industries o da alcun produttore di hardware. Star Citizen' + #$00AE + ' e Roberts Space ' +
        'Industries' + #$00AE + ' sono marchi di Cloud Imperium Rights LLC. I nomi dei costruttori usati ' +
        'per le skin, Virpil Controls, Alpha Prime e WarBRD (Virpil) e Xbox' + #$00AE + ' (Microsoft) ' +
        'appartengono ai rispettivi proprietari. Tutti gli altri marchi, nomi di prodotti e loghi citati ' +
        'appartengono ai legittimi proprietari e sono usati a solo scopo descrittivo e identificativo.');

    aFHeads[2].Text := sTr('disclaimer.performance.title', 'IMPATTO SULLE PRESTAZIONI');
    aFTexts[2].Text := sTr('disclaimer.performance.text', 'L''overlay esegue in tempo reale il ' +
        'rendering 3D (accelerazione grafica tramite GPU) in sovrimpressione al gioco e rimane in ' +
        'esecuzione durante la partita: puo'' quindi influire sulle prestazioni di gioco (frame rate, ' +
        'frame time, latenza degli input, utilizzo di CPU e GPU) in misura non quantificabile a ' +
        'priori, variabile in base a hardware, driver, impostazioni e gioco.');

    aFHeads[3].Text := sTr('disclaimer.development.title', 'SOFTWARE IN CONTINUO SVILUPPO');
    aFTexts[3].Text := sTr('disclaimer.development.text', 'HoloInput e'' in continuo sviluppo e ' +
        'aggiornamento: funzionalita'', interfaccia, modelli 3D e formato dei file di configurazione ' +
        'possono cambiare da una versione all''altra senza preavviso e possono essere presenti ' +
        'malfunzionamenti (bug) non ancora corretti.');

    oFFooter.Text := sTr('disclaimer.footer', 'Selezionando "Accetto" dichiari di aver letto e ' +
        'compreso le condizioni sopra riportate: l''avviso non verra'' piu'' mostrato. Selezionando ' +
        '"Rifiuto" l''applicazione verra'' chiusa.');
    oFAccept.sText := sTr('disclaimer.accept', 'Accetto');
    oFDecline.sText := sTr('disclaimer.decline', 'Rifiuto');
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.ApplyColors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Colorare l'avviso con la skin scelta nella combo (anteprima immediata).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: pannello e pulsanti con la palette della skin; titolo e
//** titoletti nel colore accento, testi nel colore testi, nota finale un po'
//** attenuata.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmDisclaimer.ApplyColors;
var
    oCls: TSkinClass;
    iItem: Integer;
begin
    oCls := nil;
    if oFSkin.ItemIndex >= 0 then
        oCls := oSkinByIndex(oFSkin.ItemIndex);
    if oCls <> nil then
        rFColors := oCls.rColors
    else
        rFColors := rDefaultSkinColors;
    oFPanel.rFColors := rFColors;
    oFPanel.Repaint;
    oFTitle.TextSettings.FontColor := rFColors.iAccent;
    oFLangLabel.TextSettings.FontColor := rFColors.iText;
    oFSkinLabel.TextSettings.FontColor := rFColors.iText;
    oFIntro.TextSettings.FontColor := rFColors.iText;
    for iItem := 0 to ITEM_COUNT - 1 do
    begin
        aFHeads[iItem].TextSettings.FontColor := rFColors.iAccent;
        aFTexts[iItem].TextSettings.FontColor := rFColors.iText;
    end;
    oFFooter.TextSettings.FontColor := iWithAlpha(rFColors.iText, $B8);
    oFAccept.SetColors(rFColors);
    oFDecline.SetColors(rFColors);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.LangChange
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Caricare la lingua scelta e tradurre subito l'avviso.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmDisclaimer.LangChange(oSender: TObject);
begin
    if bFLoading or (oFLang.ItemIndex < 0) then
        Exit;
    LoadLanguage(aFLangs[oFLang.ItemIndex].sId);
    ApplyTexts;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.SkinChange
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Ricolorare subito l'avviso con la skin scelta.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmDisclaimer.SkinChange(oSender: TObject);
begin
    if not bFLoading then
        ApplyColors;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.AcceptClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Accettare le condizioni: scrive lingua e skin scelte nella configurazione e chiude.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmDisclaimer.AcceptClick(oSender: TObject);
begin
    if oFLang.ItemIndex >= 0 then
        oFConfig.sLanguage := aFLangs[oFLang.ItemIndex].sId;
    if oFSkin.ItemIndex >= 0 then
        oFConfig.sSkinId := oSkinByIndex(oFSkin.ItemIndex).sId;
    ModalResult := mrOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.DeclineClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Rifiutare le condizioni (il chiamante chiude l'applicazione).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmDisclaimer.DeclineClick(oSender: TObject);
begin
    ModalResult := mrCancel;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.PanelMouseDown
//** Parametri di ingresso: oSender: TObject; eButton: TMouseButton; eShift: TShiftState; dAPosX, dAPosY:
//**                        Single
//** Parametri di uscita: nessuno
//** Scopo: Spostare la finestra trascinando la fascia del titolo (la finestra non ha bordi).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmDisclaimer.PanelMouseDown(oSender: TObject; eButton: TMouseButton; eShift: TShiftState;
    dAPosX, dAPosY: Single);
begin
    if (eButton = TMouseButton.mbLeft) and (dAPosY < TITLE_LINE_Y) then
        StartWindowDrag;
end;

//** bRunDisclaimer
//** ******************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: bRunDisclaimer
//** Parametri di ingresso: oAConfig: TAppConfig
//** Parametri di uscita: Result: Boolean
//** Scopo: Mostrare l'avviso in modo modale; True se l'utente accetta.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: la lingua di oAConfig viene caricata prima di costruire
//** l'avviso; chiudere la finestra in altro modo (es. Alt+F4) equivale a
//** rifiutare.
//***********************************************************************************************************
//***********************************************************************************************************
function bRunDisclaimer(oAConfig: TAppConfig): Boolean;
var
    oForm: TfrmDisclaimer;
begin
    if not SameText(sCurrentLanguage, oAConfig.sLanguage) then
        LoadLanguage(oAConfig.sLanguage);
    oForm := TfrmDisclaimer.CreateDisclaimer(oAConfig);
    try
        Result := oForm.ShowModal = mrOk;
    finally
        oForm.Free;
    end;
end;

end.
