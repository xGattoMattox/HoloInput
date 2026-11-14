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
/// sACancelText = '-' nasconde il pulsante Annulla (messaggio con il solo Ok).
function bHoloConfirm(const sATitle, sAMessage: string; const rAColors: TSkinColors;
    const sAOkText: string = ''; const sACancelText: string = ''): Boolean;
/// Mostra un messaggio modale con il solo pulsante Ok.
procedure HoloMessage(const sATitle, sAMessage: string; const rAColors: TSkinColors);

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
        rFColors: TSkinColors;
    protected
        procedure Paint; override;
    end;

    /// Form del messaggio (creata da codice, senza .fmx).
    THoloConfirmForm = class(TForm)
    private
        procedure OkClick(oSender: TObject);
        procedure CancelClick(oSender: TObject);
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
//** Funzionamento: stesso contorno smussato dei pulsanti (oChamferPath), sfondo
//** scuro quasi opaco tinto con la skin, bordo nel colore accento (avviso) e
//** una riga sottile che separa il titolo dal testo.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloDialogPanel.Paint;
var
    rRect: TRectF;
    oPath: TPathData;
begin
    rRect := LocalRect;
    rRect.Inflate(-1.5, -1.5);
    oPath := oChamferPath(rRect, 18);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.Fill.Color := iWithAlpha(iMixColors(rFColors.iPanelBack, TAlphaColors.Black, 0.35), $F4);
        Canvas.FillPath(oPath, AbsoluteOpacity);
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 2;
        Canvas.Stroke.Color := rFColors.iAccent;
        Canvas.DrawPath(oPath, AbsoluteOpacity);
    finally
        oPath.Free;
    end;
    Canvas.Stroke.Thickness := 1;
    Canvas.Stroke.Color := rFColors.iPanelBorder;
    Canvas.DrawLine(PointF(DLG_PAD, TITLE_LINE_Y), PointF(Width - DLG_PAD, TITLE_LINE_Y), AbsoluteOpacity);
end;

//** THoloConfirmForm ***************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloConfirmForm.OkClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiudere l'avviso confermando la scelta (pulsante Ok).
//** Data Ultima Modifica: 22/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloConfirmForm.OkClick(oSender: TObject);
begin
    ModalResult := mrOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloConfirmForm.CancelClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiudere l'avviso annullando la scelta (pulsante Annulla).
//** Data Ultima Modifica: 22/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloConfirmForm.CancelClick(oSender: TObject);
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

//** bHoloConfirm
//** ********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: oMakeLabel
//** Parametri di ingresso: oAParent: TFmxObject; dAPosX, dAPosY, dAWidth, dAHeight, dASize: Single; bABold:
//**                        Boolean; iAColor:
//**                        TAlphaColor; sAText: string
//** Parametri di uscita: Result: TLabel
//** Scopo: Creare un'etichetta con il font dell'app (non quello dello stile FMX).
//** Data Ultima Modifica: 22/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function oMakeLabel(oAParent: TFmxObject; dAPosX, dAPosY, dAWidth, dAHeight, dASize: Single; bABold: Boolean;
    iAColor: TAlphaColor; const sAText: string): TLabel;
begin
    Result := TLabel.Create(oAParent);
    Result.Parent := oAParent;
    Result.SetBounds(dAPosX, dAPosY, dAWidth, dAHeight);
    Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Family,
        TStyledSetting.Size, TStyledSetting.Style, TStyledSetting.FontColor];
    Result.TextSettings.Font.Family := HOLO_FONT;
    Result.TextSettings.Font.Size := dASize;
    if bABold then
        Result.TextSettings.Font.Style := [TFontStyle.fsBold];
    Result.TextSettings.FontColor := iAColor;
    Result.TextSettings.VertAlign := TTextAlign.Leading;
    Result.WordWrap := True;
    Result.Text := sAText;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: bHoloConfirm
//** Parametri di ingresso: sATitle, sAMessage: string; rAColors: TSkinColors; sAOkText, sACancelText:
//**                        string
//** Parametri di uscita: Result: Boolean
//** Scopo: Mostrare l'avviso e restituire la scelta dell'utente.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: form senza bordi e con sfondo trasparente (si vede solo il
//** pannello smussato), sempre in primo piano e centrata sulla finestra attiva
//** (o sullo schermo); titolo nel colore accento, testo nel colore testi della
//** skin, pulsanti "Ok" e "Annulla" in basso a destra. Con sACancelText = '-'
//** il pulsante Annulla non c'e' e Ok prende il suo posto.
//***********************************************************************************************************
//***********************************************************************************************************
function bHoloConfirm(const sATitle, sAMessage: string; const rAColors: TSkinColors;
    const sAOkText, sACancelText: string): Boolean;
var
    oForm: THoloConfirmForm;
    oPanel: THoloDialogPanel;
    oBOk, oBCancel: THoloButton;
    oOwner: TCommonCustomForm;
begin
    oForm := THoloConfirmForm.CreateNew(nil);
    try
        oForm.BorderStyle := TFmxFormBorderStyle.None;
        oForm.Transparency := True;
        oForm.FormStyle := TFormStyle.StayOnTop;
        oForm.Caption := sATitle;
        oForm.Width := DLG_W;
        oForm.Height := DLG_H;
        oOwner := Screen.ActiveForm;
        if oOwner <> nil then
        begin
            oForm.Position := TFormPosition.Designed;
            oForm.Left := oOwner.Left + (oOwner.Width - DLG_W) div 2;
            oForm.Top := oOwner.Top + (oOwner.Height - DLG_H) div 2;
        end
        else
            oForm.Position := TFormPosition.ScreenCenter;

        oPanel := THoloDialogPanel.Create(oForm);
        oPanel.rFColors := rAColors;
        oPanel.Parent := oForm;
        oPanel.Align := TAlignLayout.Client;
        oPanel.HitTest := False;

        oMakeLabel(oPanel, DLG_PAD, 16, DLG_W - 2 * DLG_PAD, 32, 16, True, rAColors.iAccent,
            #$26A0 + '  ' + UpperCase(sATitle));
        oMakeLabel(oPanel, DLG_PAD, TITLE_LINE_Y + 14, DLG_W - 2 * DLG_PAD,
            DLG_H - TITLE_LINE_Y - 14 - BTN_H - 30, 12, False, rAColors.iText, sAMessage);

        oBCancel := THoloButton.Create(oForm);
        oBCancel.Parent := oPanel;
        oBCancel.SetBounds(DLG_W - DLG_PAD - BTN_W, DLG_H - DLG_PAD - BTN_H, BTN_W, BTN_H);
        if sACancelText <> '' then
            oBCancel.sText := sACancelText
        else
            oBCancel.sText := sTr('dialog.cancel', 'Annulla');
        oBCancel.SetColors(rAColors);
        oBCancel.OnClick := oForm.CancelClick;

        oBOk := THoloButton.Create(oForm);
        oBOk.Parent := oPanel;
        oBOk.SetBounds(DLG_W - DLG_PAD - 2 * BTN_W - 12, DLG_H - DLG_PAD - BTN_H, BTN_W, BTN_H);
        if sAOkText <> '' then
            oBOk.sText := sAOkText
        else
            oBOk.sText := sTr('dialog.ok', 'Ok');
        oBOk.SetColors(rAColors);
        oBOk.OnClick := oForm.OkClick;
        if sACancelText = '-' then
        begin
            oBCancel.Visible := False;
            oBOk.Position.X := oBCancel.Position.X;
        end;

        Result := oForm.ShowModal = mrOk;
    finally
        oForm.Free;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: HoloMessage
//** Parametri di ingresso: sATitle, sAMessage: string; rAColors: TSkinColors
//** Parametri di uscita: nessuno
//** Scopo: Mostrare un messaggio con il solo pulsante Ok (stesso aspetto di bHoloConfirm).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure HoloMessage(const sATitle, sAMessage: string; const rAColors: TSkinColors);
begin
    bHoloConfirm(sATitle, sAMessage, rAColors, '', '-');
end;

end.
