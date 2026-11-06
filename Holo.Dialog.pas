//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Dialog
//** Scopo: Finestre di messaggio con lo stile grafico dell'applicazione (pannello con angoli smussati,
//**        colori della skin, font Bahnschrift, pulsanti THoloButton) al posto delle MessageBox di Windows.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: holoConfirm: avviso con due pulsanti, "Ok" (restituisce True) e "Annulla"
//** (restituisce False). Invio = Ok, Esc = Annulla. Se i testi dei pulsanti
//** non sono indicati si usano quelli della lingua corrente (Holo.Lang).
//** HoloMessage: messaggio con il solo pulsante "Ok".
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.Dialog;

interface

uses
    System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
    FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls,
    FMX.Controls.Presentation,
    Holo.Skins, Holo.UI;

/// Mostra un avviso modale con i colori della skin; True se l'utente sceglie Ok.
/// ACancelText = '-' nasconde il pulsante Annulla (messaggio con il solo Ok).
function HoloConfirm(const ATitle, AMessage: string; const AColors: TSkinColors;
    const AOkText: string = ''; const ACancelText: string = ''): Boolean;
/// Mostra un messaggio modale con il solo pulsante Ok.
procedure HoloMessage(const ATitle, AMessage: string; const AColors: TSkinColors);

implementation

uses
    Holo.Lang;

const
    DLG_W = 500;
    DLG_H = 230;
    DLG_PAD = 24;
    BTN_W = 130;
    BTN_H = 34;
    TITLE_LINE_Y = 56;

type
    /// Sfondo del messaggio: pannello smussato con bordo accento e riga sotto il titolo.
    THoloDialogPanel = class(TControl)
    private
        FColors: TSkinColors;
    protected
        procedure Paint; override;
    end;

    /// Form del messaggio (creata da codice, senza .fmx).
    THoloConfirmForm = class(TForm)
    private
        procedure OkClick(Sender: TObject);
        procedure CancelClick(Sender: TObject);
    protected
        procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    end;

//** THoloDialogPanel ***************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloDialogPanel.Paint
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare il pannello del messaggio.
//** Data Ultima Modifica: 22/10/2026
//***********************************************************************************************************
//** Funzionamento: stesso contorno smussato dei pulsanti (ChamferPath), sfondo
//** scuro quasi opaco tinto con la skin, bordo nel colore accento (avviso) e
//** una riga sottile che separa il titolo dal testo.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloDialogPanel.Paint;
var
    R: TRectF;
    P: TPathData;
begin
    R := LocalRect;
    R.Inflate(-1.5, -1.5);
    P := ChamferPath(R, 18);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.Fill.Color := WithAlpha(MixColors(FColors.PanelBack, TAlphaColors.Black, 0.35), $F4);
        Canvas.FillPath(P, AbsoluteOpacity);
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 2;
        Canvas.Stroke.Color := FColors.Accent;
        Canvas.DrawPath(P, AbsoluteOpacity);
    finally
        P.Free;
    end;
    Canvas.Stroke.Thickness := 1;
    Canvas.Stroke.Color := FColors.PanelBorder;
    Canvas.DrawLine(PointF(DLG_PAD, TITLE_LINE_Y), PointF(Width - DLG_PAD, TITLE_LINE_Y), AbsoluteOpacity);
end;

//** THoloConfirmForm ***************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloConfirmForm.OkClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiudere l'avviso confermando la scelta (pulsante Ok).
//** Data Ultima Modifica: 22/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloConfirmForm.OkClick(Sender: TObject);
begin
    ModalResult := mrOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloConfirmForm.CancelClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiudere l'avviso annullando la scelta (pulsante Annulla).
//** Data Ultima Modifica: 22/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloConfirmForm.CancelClick(Sender: TObject);
begin
    ModalResult := mrCancel;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloConfirmForm.KeyDown
//** Parametri di ingresso: Key: Word (var); KeyChar: WideChar (var); Shift: TShiftState
//** Parametri di uscita: Key: Word (var); KeyChar: WideChar (var)
//** Scopo: Tastiera: Invio conferma, Esc annulla.
//** Data Ultima Modifica: 22/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloConfirmForm.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
    if Key = vkReturn then
    begin
        Key := 0;
        ModalResult := mrOk;
    end
    else if Key = vkEscape then
    begin
        Key := 0;
        ModalResult := mrCancel;
    end
    else
        inherited;
end;

//** HoloConfirm ********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: MakeLabel
//** Parametri di ingresso: AParent: TFmxObject; X, Y, W, H, ASize: Single; ABold: Boolean; AColor:
//**                        TAlphaColor; AText: string
//** Parametri di uscita: Result: TLabel
//** Scopo: Creare un'etichetta con il font dell'app (non quello dello stile FMX).
//** Data Ultima Modifica: 22/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function MakeLabel(AParent: TFmxObject; X, Y, W, H, ASize: Single; ABold: Boolean;
    AColor: TAlphaColor; const AText: string): TLabel;
begin
    Result := TLabel.Create(AParent);
    Result.Parent := AParent;
    Result.SetBounds(X, Y, W, H);
    Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Family,
        TStyledSetting.Size, TStyledSetting.Style, TStyledSetting.FontColor];
    Result.TextSettings.Font.Family := HOLO_FONT;
    Result.TextSettings.Font.Size := ASize;
    if ABold then
        Result.TextSettings.Font.Style := [TFontStyle.fsBold];
    Result.TextSettings.FontColor := AColor;
    Result.TextSettings.VertAlign := TTextAlign.Leading;
    Result.WordWrap := True;
    Result.Text := AText;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: HoloConfirm
//** Parametri di ingresso: ATitle, AMessage: string; AColors: TSkinColors; AOkText, ACancelText:
//**                        string
//** Parametri di uscita: Result: Boolean
//** Scopo: Mostrare l'avviso e restituire la scelta dell'utente.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: form senza bordi e con sfondo trasparente (si vede solo il
//** pannello smussato), sempre in primo piano e centrata sulla finestra attiva
//** (o sullo schermo); titolo nel colore accento, testo nel colore testi della
//** skin, pulsanti "Ok" e "Annulla" in basso a destra. Con ACancelText = '-'
//** il pulsante Annulla non c'e' e Ok prende il suo posto.
//***********************************************************************************************************
//***********************************************************************************************************
function HoloConfirm(const ATitle, AMessage: string; const AColors: TSkinColors;
    const AOkText, ACancelText: string): Boolean;
var
    F: THoloConfirmForm;
    Panel: THoloDialogPanel;
    BOk, BCancel: THoloButton;
    Owner: TCommonCustomForm;
begin
    F := THoloConfirmForm.CreateNew(nil);
    try
        F.BorderStyle := TFmxFormBorderStyle.None;
        F.Transparency := True;
        F.FormStyle := TFormStyle.StayOnTop;
        F.Caption := ATitle;
        F.Width := DLG_W;
        F.Height := DLG_H;
        Owner := Screen.ActiveForm;
        if Owner <> nil then
        begin
            F.Position := TFormPosition.Designed;
            F.Left := Owner.Left + (Owner.Width - DLG_W) div 2;
            F.Top := Owner.Top + (Owner.Height - DLG_H) div 2;
        end
        else
            F.Position := TFormPosition.ScreenCenter;

        Panel := THoloDialogPanel.Create(F);
        Panel.FColors := AColors;
        Panel.Parent := F;
        Panel.Align := TAlignLayout.Client;
        Panel.HitTest := False;

        MakeLabel(Panel, DLG_PAD, 16, DLG_W - 2 * DLG_PAD, 32, 16, True, AColors.Accent,
            #$26A0 + '  ' + UpperCase(ATitle));
        MakeLabel(Panel, DLG_PAD, TITLE_LINE_Y + 14, DLG_W - 2 * DLG_PAD,
            DLG_H - TITLE_LINE_Y - 14 - BTN_H - 30, 12, False, AColors.Text, AMessage);

        BCancel := THoloButton.Create(F);
        BCancel.Parent := Panel;
        BCancel.SetBounds(DLG_W - DLG_PAD - BTN_W, DLG_H - DLG_PAD - BTN_H, BTN_W, BTN_H);
        if ACancelText <> '' then
            BCancel.Text := ACancelText
        else
            BCancel.Text := Tr('dialog.cancel', 'Annulla');
        BCancel.SetColors(AColors);
        BCancel.OnClick := F.CancelClick;

        BOk := THoloButton.Create(F);
        BOk.Parent := Panel;
        BOk.SetBounds(DLG_W - DLG_PAD - 2 * BTN_W - 12, DLG_H - DLG_PAD - BTN_H, BTN_W, BTN_H);
        if AOkText <> '' then
            BOk.Text := AOkText
        else
            BOk.Text := Tr('dialog.ok', 'Ok');
        BOk.SetColors(AColors);
        BOk.OnClick := F.OkClick;
        if ACancelText = '-' then
        begin
            BCancel.Visible := False;
            BOk.Position.X := BCancel.Position.X;
        end;

        Result := F.ShowModal = mrOk;
    finally
        F.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: HoloMessage
//** Parametri di ingresso: ATitle, AMessage: string; AColors: TSkinColors
//** Parametri di uscita: nessuno
//** Scopo: Mostrare un messaggio con il solo pulsante Ok (stesso aspetto di HoloConfirm).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure HoloMessage(const ATitle, AMessage: string; const AColors: TSkinColors);
begin
    HoloConfirm(ATitle, AMessage, AColors, '', '-');
end;

end.
