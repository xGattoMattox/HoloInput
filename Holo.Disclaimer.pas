//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Disclaimer
//** Scopo: Avviso legale mostrato al primo avvio (finche' non viene accettato).
//** Data Ultima Modifica: 31/10/2026
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
/// scritte in AConfig (Language, SkinId); la lingua scelta resta caricata.
function RunDisclaimer(AConfig: TAppConfig): Boolean;

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
        FColors: TSkinColors;
    protected
        procedure Paint; override;
    end;

    /// Finestra dell'avviso (creata da codice, senza .fmx).
    TfrmDisclaimer = class(TForm)
    private
        FConfig: TAppConfig;
        FColors: TSkinColors;
        FPanel: TDisclaimerPanel;
        FTitle, FIntro, FFooter, FLangLabel, FSkinLabel: TLabel;
        FHeads, FTexts: array[0..ITEM_COUNT - 1] of TLabel;
        FLang, FSkin: TComboBox;
        FLangs: TArray<TLangInfo>;
        FAccept, FDecline: THoloButton;
        FLoading: Boolean;
        function MakeText(X, Y, W, H, ASize: Single; ABold, AHolo: Boolean): TLabel;
        procedure BuildUI;
        procedure ApplyTexts;
        procedure ApplyColors;
        procedure LangChange(Sender: TObject);
        procedure SkinChange(Sender: TObject);
        procedure AcceptClick(Sender: TObject);
        procedure DeclineClick(Sender: TObject);
        procedure PanelMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
            X, Y: Single);
    public
        constructor CreateDisclaimer(AConfig: TAppConfig);
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
//** contorno smussato (ChamferPath), sfondo scuro quasi opaco tinto con la
//** skin, bordo nel colore accento, staffe d'angolo e una riga sottile sotto
//** il titolo.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TDisclaimerPanel.Paint;
const
    L = 26;
var
    R: TRectF;
    P: TPathData;
    Op: Single;
begin
    Op := AbsoluteOpacity;
    R := LocalRect;
    R.Inflate(-1.5, -1.5);
    P := ChamferPath(R, 22);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.Fill.Color := WithAlpha(MixColors(FColors.PanelBack, TAlphaColors.Black, 0.35), $F6);
        Canvas.FillPath(P, Op);
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 2;
        Canvas.Stroke.Color := FColors.Accent;
        Canvas.DrawPath(P, Op);
    finally
        P.Free;
    end;
    // staffe d'angolo (alto a destra, basso a sinistra)
    Canvas.Stroke.Thickness := 3;
    Canvas.DrawLine(PointF(R.Right - L, R.Top + 1), PointF(R.Right - 1, R.Top + 1), Op);
    Canvas.DrawLine(PointF(R.Right - 1, R.Top + 1), PointF(R.Right - 1, R.Top + L), Op);
    Canvas.DrawLine(PointF(R.Left + 1, R.Bottom - L), PointF(R.Left + 1, R.Bottom - 1), Op);
    Canvas.DrawLine(PointF(R.Left + 1, R.Bottom - 1), PointF(R.Left + L, R.Bottom - 1), Op);
    // righe sotto il titolo e sopra i punti dell'avviso
    Canvas.Stroke.Thickness := 1;
    Canvas.Stroke.Color := FColors.PanelBorder;
    Canvas.DrawLine(PointF(DLG_PAD, TITLE_LINE_Y), PointF(Width - DLG_PAD, TITLE_LINE_Y), Op);
    Canvas.DrawLine(PointF(DLG_PAD, INTRO_Y - 8), PointF(Width - DLG_PAD, INTRO_Y - 8), Op);
end;

//** TfrmDisclaimer *****************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.CreateDisclaimer
//** Parametri di ingresso: AConfig: TAppConfig
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
constructor TfrmDisclaimer.CreateDisclaimer(AConfig: TAppConfig);
begin
    inherited CreateNew(nil);
    FConfig := AConfig;
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
//** Nome funzione: TfrmDisclaimer.MakeText
//** Parametri di ingresso: X, Y, W, H, ASize: Single; ABold, AHolo: Boolean
//** Parametri di uscita: Result: TLabel
//** Scopo: Creare un testo (vuoto) sul pannello, allineato in alto e a capo automatico.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: AHolo = font olografico dell'app (titoli), altrimenti
//** Segoe UI (testi). Font, colore e allineamento non vengono presi dallo
//** stile FMX; testo e colore si impostano in ApplyTexts / ApplyColors.
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmDisclaimer.MakeText(X, Y, W, H, ASize: Single; ABold, AHolo: Boolean): TLabel;
begin
    Result := TLabel.Create(Self);
    Result.Parent := FPanel;
    Result.SetBounds(X, Y, W, H);
    Result.StyledSettings := [];
    if AHolo then
        Result.TextSettings.Font.Family := HOLO_FONT
    else
        Result.TextSettings.Font.Family := BODY_FONT;
    Result.TextSettings.Font.Size := ASize;
    if ABold then
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
    I, Sel: Integer;
    TW: Single;
begin
    TW := DLG_W - 2 * DLG_PAD;
    FPanel := TDisclaimerPanel.Create(Self);
    FPanel.Parent := Self;
    FPanel.Align := TAlignLayout.Client;
    FPanel.HitTest := True;
    FPanel.OnMouseDown := PanelMouseDown;

    FTitle := MakeText(DLG_PAD, 16, TW, 32, 16, True, True);

    // lingua e skin
    FLangLabel := MakeText(DLG_PAD, SEL_Y + 4, 80, 22, 11, False, False);
    FLang := TComboBox.Create(Self);
    FLang.Parent := FPanel;
    FLang.SetBounds(DLG_PAD + 80, SEL_Y, 230, 26);
    FLangs := AvailableLanguages;
    Sel := 0;
    for I := 0 to High(FLangs) do
    begin
        FLang.Items.Add(FLangs[I].Name);
        if SameText(FLangs[I].Id, FConfig.Language) then
            Sel := I;
    end;
    FSkinLabel := MakeText(DLG_PAD + 350, SEL_Y + 4, 70, 22, 11, False, False);
    FSkin := TComboBox.Create(Self);
    FSkin.Parent := FPanel;
    FSkin.SetBounds(DLG_PAD + 420, SEL_Y, TW - 420, 26);
    for I := 0 to SkinCount - 1 do
        FSkin.Items.Add(SkinByIndex(I).DisplayName);
    FLoading := True;
    try
        if FLang.Items.Count > 0 then
            FLang.ItemIndex := Sel;
        FSkin.ItemIndex := Max(0, SkinIndexOf(FConfig.SkinId));
    finally
        FLoading := False;
    end;
    FLang.OnChange := LangChange;
    FSkin.OnChange := SkinChange;

    // introduzione e punti dell'avviso
    FIntro := MakeText(DLG_PAD, INTRO_Y, TW, 24, 12, False, False);
    for I := 0 to ITEM_COUNT - 1 do
    begin
        FHeads[I] := MakeText(DLG_PAD, ITEM_Y0 + I * ITEM_DY, TW, 22, 12, True, True);
        FTexts[I] := MakeText(DLG_PAD, ITEM_Y0 + I * ITEM_DY + 22, TW, ITEM_DY - 26, 11, False, False);
    end;
    FFooter := MakeText(DLG_PAD, ITEM_Y0 + ITEM_COUNT * ITEM_DY, TW, 40, 10, False, False);

    // pulsanti
    FDecline := THoloButton.Create(Self);
    FDecline.Parent := FPanel;
    FDecline.SetBounds(DLG_W - DLG_PAD - BTN_W, DLG_H - DLG_PAD - BTN_H, BTN_W, BTN_H);
    FDecline.OnClick := DeclineClick;
    FAccept := THoloButton.Create(Self);
    FAccept.Parent := FPanel;
    FAccept.SetBounds(DLG_W - DLG_PAD - 2 * BTN_W - 12, DLG_H - DLG_PAD - BTN_H, BTN_W, BTN_H);
    FAccept.OnClick := AcceptClick;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.ApplyTexts
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Scrivere tutti i testi dell'avviso nella lingua corrente.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: legge ogni testo con Tr (chiavi disclaimer.*); viene
//** richiamata quando si cambia lingua, cosi' l'avviso si traduce subito.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmDisclaimer.ApplyTexts;
begin
    Caption := Tr('disclaimer.caption', 'HoloInput - Avviso legale');
    FTitle.Text := #$26A0 + '  ' + Tr('disclaimer.title', 'AVVISO LEGALE E CONDIZIONI D''USO');
    FLangLabel.Text := Tr('disclaimer.language', 'Lingua');
    FSkinLabel.Text := Tr('disclaimer.skin', 'Skin');
    FIntro.Text := Tr('disclaimer.intro', 'Prima di utilizzare HoloInput leggi con attenzione le ' +
        'seguenti condizioni.');

    FHeads[0].Text := Tr('disclaimer.hobby.title', 'SOFTWARE AMATORIALE, SENZA GARANZIE');
    FTexts[0].Text := Tr('disclaimer.hobby.text', 'La presente versione di HoloInput e'' un software ' +
        'amatoriale distribuito gratuitamente (freeware), realizzato da un appassionato a titolo non ' +
        'professionale; la gratuita'' riguarda esclusivamente questa versione e l''autore si riserva il ' +
        'diritto di distribuire versioni future con condizioni di licenza diverse, anche a pagamento. ' +
        'Il software e'' fornito "cosi'' com''e''" ("as is"), senza garanzie di alcun tipo, esplicite o ' +
        'implicite, incluse quelle di funzionamento, commerciabilita'' e idoneita'' a uno scopo ' +
        'particolare. L''utilizzo avviene a proprio rischio: nei limiti consentiti dalla legge l''autore ' +
        'non risponde di danni diretti o indiretti derivanti dall''uso del software.');

    FHeads[1].Text := Tr('disclaimer.trademarks.title', 'MARCHI DI TERZI');
    FTexts[1].Text := Tr('disclaimer.trademarks.text', 'Tutti i marchi, i marchi registrati, i nomi ' +
        'commerciali, i nomi di prodotti e i loghi citati nel software (tra cui Star Citizen' + #$00AE +
        ', Roberts Space Industries' + #$00AE + ', Cloud Imperium Games, i costruttori delle skin, ' +
        'Virpil Controls, Xbox' + #$00AE + ') appartengono ai legittimi proprietari e sono usati a solo ' +
        'scopo descrittivo e identificativo. Il software non e'' affiliato, sponsorizzato ne'' approvato ' +
        'da tali titolari.');

    FHeads[2].Text := Tr('disclaimer.performance.title', 'IMPATTO SULLE PRESTAZIONI');
    FTexts[2].Text := Tr('disclaimer.performance.text', 'L''overlay esegue in tempo reale il ' +
        'rendering 3D (accelerazione grafica tramite GPU) in sovrimpressione al gioco e rimane in ' +
        'esecuzione durante la partita: puo'' quindi influire sulle prestazioni di gioco (frame rate, ' +
        'frame time, latenza degli input, utilizzo di CPU e GPU) in misura non quantificabile a ' +
        'priori, variabile in base a hardware, driver, impostazioni e gioco.');

    FHeads[3].Text := Tr('disclaimer.development.title', 'SOFTWARE IN CONTINUO SVILUPPO');
    FTexts[3].Text := Tr('disclaimer.development.text', 'HoloInput e'' in continuo sviluppo e ' +
        'aggiornamento: funzionalita'', interfaccia, modelli 3D e formato dei file di configurazione ' +
        'possono cambiare da una versione all''altra senza preavviso e possono essere presenti ' +
        'malfunzionamenti (bug) non ancora corretti.');

    FFooter.Text := Tr('disclaimer.footer', 'Selezionando "Accetto" dichiari di aver letto e ' +
        'compreso le condizioni sopra riportate: l''avviso non verra'' piu'' mostrato. Selezionando ' +
        '"Rifiuto" l''applicazione verra'' chiusa.');
    FAccept.Text := Tr('disclaimer.accept', 'Accetto');
    FDecline.Text := Tr('disclaimer.decline', 'Rifiuto');
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
    Cls: TSkinClass;
    I: Integer;
begin
    Cls := nil;
    if FSkin.ItemIndex >= 0 then
        Cls := SkinByIndex(FSkin.ItemIndex);
    if Cls <> nil then
        FColors := Cls.Colors
    else
        FColors := DefaultSkinColors;
    FPanel.FColors := FColors;
    FPanel.Repaint;
    FTitle.TextSettings.FontColor := FColors.Accent;
    FLangLabel.TextSettings.FontColor := FColors.Text;
    FSkinLabel.TextSettings.FontColor := FColors.Text;
    FIntro.TextSettings.FontColor := FColors.Text;
    for I := 0 to ITEM_COUNT - 1 do
    begin
        FHeads[I].TextSettings.FontColor := FColors.Accent;
        FTexts[I].TextSettings.FontColor := FColors.Text;
    end;
    FFooter.TextSettings.FontColor := WithAlpha(FColors.Text, $B8);
    FAccept.SetColors(FColors);
    FDecline.SetColors(FColors);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.LangChange
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Caricare la lingua scelta e tradurre subito l'avviso.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmDisclaimer.LangChange(Sender: TObject);
begin
    if FLoading or (FLang.ItemIndex < 0) then
        Exit;
    LoadLanguage(FLangs[FLang.ItemIndex].Id);
    ApplyTexts;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.SkinChange
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Ricolorare subito l'avviso con la skin scelta.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmDisclaimer.SkinChange(Sender: TObject);
begin
    if not FLoading then
        ApplyColors;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.AcceptClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Accettare le condizioni: scrive lingua e skin scelte nella configurazione e chiude.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmDisclaimer.AcceptClick(Sender: TObject);
begin
    if FLang.ItemIndex >= 0 then
        FConfig.Language := FLangs[FLang.ItemIndex].Id;
    if FSkin.ItemIndex >= 0 then
        FConfig.SkinId := SkinByIndex(FSkin.ItemIndex).Id;
    ModalResult := mrOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.DeclineClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Rifiutare le condizioni (il chiamante chiude l'applicazione).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmDisclaimer.DeclineClick(Sender: TObject);
begin
    ModalResult := mrCancel;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmDisclaimer.PanelMouseDown
//** Parametri di ingresso: Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single
//** Parametri di uscita: nessuno
//** Scopo: Spostare la finestra trascinando la fascia del titolo (la finestra non ha bordi).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmDisclaimer.PanelMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
    X, Y: Single);
begin
    if (Button = TMouseButton.mbLeft) and (Y < TITLE_LINE_Y) then
        StartWindowDrag;
end;

//** RunDisclaimer ******************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: RunDisclaimer
//** Parametri di ingresso: AConfig: TAppConfig
//** Parametri di uscita: Result: Boolean
//** Scopo: Mostrare l'avviso in modo modale; True se l'utente accetta.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: la lingua di AConfig viene caricata prima di costruire
//** l'avviso; chiudere la finestra in altro modo (es. Alt+F4) equivale a
//** rifiutare.
//***********************************************************************************************************
//***********************************************************************************************************
function RunDisclaimer(AConfig: TAppConfig): Boolean;
var
    F: TfrmDisclaimer;
begin
    if not SameText(CurrentLanguage, AConfig.Language) then
        LoadLanguage(AConfig.Language);
    F := TfrmDisclaimer.CreateDisclaimer(AConfig);
    try
        Result := F.ShowModal = mrOk;
    finally
        F.Free;
    end;
end;

end.
