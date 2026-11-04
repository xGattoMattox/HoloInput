//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.UI
//** Scopo: Controlli 2D con lo stesso stile grafico dell'overlay (angoli smussati, colori della skin, font
//**        Bahnschrift).
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: usati sia nella barra dell'overlay
//** (Setup / Blocca / Esci) sia nella schermata di Setup, cosi' tutti i pulsanti
//** dell'applicazione hanno lo stesso aspetto.
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.UI;

interface

uses
    System.SysUtils, System.Types, System.UITypes, System.Classes,
    FMX.Types, FMX.Controls, FMX.Graphics,
    Holo.Skins;

const
    HOLO_FONT = 'Bahnschrift';

type
    /// Pulsante olografico. Con Passive = True diventa un'etichetta "a capsula".
    THoloButton = class(TControl)
    private
        FText: string;
        FColors: TSkinColors;
        FPassive: Boolean;
        FHighlight: Boolean;
        FFontSize: Single;
        FKeepCase: Boolean;
        procedure SetText(const Value: string);
        procedure SetPassive(const Value: Boolean);
        procedure SetHighlight(const Value: Boolean);
    protected
        procedure Paint; override;
        procedure DoMouseEnter; override;
        procedure DoMouseLeave; override;
        procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
        procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    public
        constructor Create(AOwner: TComponent); override;
        procedure SetColors(const AColors: TSkinColors);
        property Text: string read FText write SetText;
        property Passive: Boolean read FPassive write SetPassive;
        property Highlight: Boolean read FHighlight write SetHighlight;
        property FontSize: Single read FFontSize write FFontSize;
        /// True = il testo e' scritto come impostato (default: tutto maiuscolo).
        property KeepCase: Boolean read FKeepCase write FKeepCase;
    published
        property OnClick;
        property Visible;
        property Opacity;
    end;

    /// Cornice sottile a angoli smussati nei colori della skin, per raggruppare
    /// controlli e testi (non riceve i click).
    THoloFrame = class(TControl)
    private
        FColors: TSkinColors;
        FStateColor: TAlphaColor;   // colore di stato del bordo (0 = colori della skin)
    protected
        procedure Paint; override;
    public
        constructor Create(AOwner: TComponent); override;
        procedure SetColors(const AColors: TSkinColors);
        procedure SetStateColor(AColor: TAlphaColor);
    end;

function ChamferPath(const R: TRectF; AChamfer: Single): TPathData;

implementation

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: ChamferPath
//** Parametri di ingresso: R: TRectF; AChamfer: Single
//** Parametri di uscita: Result: TPathData
//** Scopo: Costruire il contorno "sci-fi" con due angoli smussati (alto-sinistra e basso-destra).
//**        Il chiamante deve liberare il path.
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function ChamferPath(const R: TRectF; AChamfer: Single): TPathData;
begin
    Result := TPathData.Create;
    Result.MoveTo(PointF(R.Left + AChamfer, R.Top));
    Result.LineTo(PointF(R.Right, R.Top));
    Result.LineTo(PointF(R.Right, R.Bottom - AChamfer));
    Result.LineTo(PointF(R.Right - AChamfer, R.Bottom));
    Result.LineTo(PointF(R.Left, R.Bottom));
    Result.LineTo(PointF(R.Left, R.Top + AChamfer));
    Result.ClosePath;
end;

//** THoloButton ********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloButton.Create
//** Parametri di ingresso: AOwner: TComponent
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare il pulsante con dimensioni e colori di default.
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
constructor THoloButton.Create(AOwner: TComponent);
begin
    inherited;
    FColors := DefaultSkinColors;
    FFontSize := 13;
    HitTest := True;
    Cursor := crHandPoint;
    Width := 96;
    Height := 30;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloButton.SetColors
//** Parametri di ingresso: AColors: TSkinColors
//** Parametri di uscita: nessuno
//** Scopo: Applicare i colori della skin e ridisegnare.
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloButton.SetColors(const AColors: TSkinColors);
begin
    FColors := AColors;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloButton.SetText
//** Parametri di ingresso: Value: string
//** Parametri di uscita: nessuno
//** Scopo: Cambiare il testo del pulsante e ridisegnarlo.
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloButton.SetText(const Value: string);
begin
    FText := Value;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloButton.SetPassive
//** Parametri di ingresso: Value: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Modalita' etichetta: niente click e niente evidenziazione.
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloButton.SetPassive(const Value: Boolean);
begin
    FPassive := Value;
    HitTest := not Value;
    if Value then
        Cursor := crDefault
    else
        Cursor := crHandPoint;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloButton.SetHighlight
//** Parametri di ingresso: Value: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Evidenziazione permanente (es. pulsante "Blocca" attivo).
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloButton.SetHighlight(const Value: Boolean);
begin
    FHighlight := Value;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloButton.Paint
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare il pulsante.
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//** Funzionamento: riempie il contorno smussato con il colore pannello (piu'
//** acceso se mouse sopra/premuto/evidenziato), traccia il bordo primario o
//** accento e centra il testo (in maiuscolo, salvo KeepCase).
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloButton.Paint;
var
    R: TRectF;
    P: TPathData;
    Hot: Boolean;
    S: string;
begin
    R := LocalRect;
    R.Inflate(-1, -1);
    Hot := (not FPassive) and (IsMouseOver or Pressed);
    P := ChamferPath(R, 8);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        if Pressed and not FPassive then
            Canvas.Fill.Color := WithAlpha(FColors.Accent, $90)
        else if Hot or FHighlight then
            Canvas.Fill.Color := WithAlpha(FColors.Primary, $50)
        else
            Canvas.Fill.Color := FColors.PanelBack;
        Canvas.FillPath(P, AbsoluteOpacity);

        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 1.5;
        if Hot or FHighlight then
            Canvas.Stroke.Color := FColors.Accent
        else
            Canvas.Stroke.Color := FColors.PanelBorder;
        Canvas.DrawPath(P, AbsoluteOpacity);
    finally
        P.Free;
    end;

    Canvas.Font.Family := HOLO_FONT;
    Canvas.Font.Size := FFontSize;
    Canvas.Font.Style := [TFontStyle.fsBold];
    if Hot or FHighlight then
        Canvas.Fill.Color := FColors.Accent
    else
        Canvas.Fill.Color := FColors.Text;
    if FKeepCase then
        S := FText
    else
        S := UpperCase(FText);
    Canvas.FillText(R, S, False, AbsoluteOpacity, [], TTextAlign.Center, TTextAlign.Center);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloButton.DoMouseEnter
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Ridisegnare il pulsante evidenziato quando il mouse ci entra.
//** Data Ultima Modifica: 27/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloButton.DoMouseEnter;
begin
    inherited;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloButton.DoMouseLeave
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Ridisegnare il pulsante normale quando il mouse esce.
//** Data Ultima Modifica: 27/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloButton.DoMouseLeave;
begin
    inherited;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloButton.MouseDown
//** Parametri di ingresso: Button: TMouseButton; Shift: TShiftState; X, Y: Single
//** Parametri di uscita: nessuno
//** Scopo: Ridisegnare il pulsante premuto.
//** Data Ultima Modifica: 27/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
    inherited;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloButton.MouseUp
//** Parametri di ingresso: Button: TMouseButton; Shift: TShiftState; X, Y: Single
//** Parametri di uscita: nessuno
//** Scopo: Ridisegnare il pulsante al rilascio del tasto del mouse.
//** Data Ultima Modifica: 27/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
    inherited;
    Repaint;
end;

//** THoloFrame *********************************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloFrame.Create
//** Parametri di ingresso: AOwner: TComponent
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare la cornice con i colori della skin predefinita, trasparente ai click.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
constructor THoloFrame.Create(AOwner: TComponent);
begin
    inherited;
    HitTest := False;
    FColors := DefaultSkinColors;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloFrame.SetColors
//** Parametri di ingresso: AColors: TSkinColors
//** Parametri di uscita: nessuno
//** Scopo: Applicare i colori della skin e ridisegnare la cornice.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloFrame.SetColors(const AColors: TSkinColors);
begin
    FColors := AColors;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloFrame.SetStateColor
//** Parametri di ingresso: AColor: TAlphaColor
//** Parametri di uscita: nessuno
//** Scopo: Impostare il colore di stato di bordo e staffe (0 = tornare ai colori della skin).
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: il colore resta anche quando cambiano i colori della skin
//** (SetColors), cosi' lo stato rappresentato non si perde.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloFrame.SetStateColor(AColor: TAlphaColor);
begin
    FStateColor := AColor;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloFrame.Paint
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Disegnare la cornice sottile con angoli smussati e le staffe d'angolo.
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: stesso disegno delle schede della pagina Info, ma piu'
//** leggero: fondo appena piu' scuro, bordo da 1 pixel nel colore PanelBorder
//** della skin e due staffe corte nel colore Accent (in alto a destra e in
//** basso a sinistra). Con un colore di stato impostato (SetStateColor) bordo e
//** staffe usano quel colore.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloFrame.Paint;
const
    L = 14;
var
    R: TRectF;
    P: TPathData;
    Op: Single;
begin
    Op := AbsoluteOpacity;
    R := LocalRect;
    R.Inflate(-1, -1);
    P := ChamferPath(R, 12);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.Fill.Color := WithAlpha(MixColors(FColors.PanelBack, TAlphaColors.Black, 0.25), $60);
        Canvas.FillPath(P, Op);
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 1;
        if FStateColor <> 0 then
            Canvas.Stroke.Color := FStateColor
        else
            Canvas.Stroke.Color := FColors.PanelBorder;
        Canvas.DrawPath(P, Op);
    finally
        P.Free;
    end;
    Canvas.Stroke.Thickness := 1.5;
    if FStateColor <> 0 then
        Canvas.Stroke.Color := FStateColor
    else
        Canvas.Stroke.Color := FColors.Accent;
    Canvas.DrawLine(PointF(R.Right - L, R.Top), PointF(R.Right, R.Top), Op);
    Canvas.DrawLine(PointF(R.Right, R.Top), PointF(R.Right, R.Top + L), Op);
    Canvas.DrawLine(PointF(R.Left, R.Bottom - L), PointF(R.Left, R.Bottom), Op);
    Canvas.DrawLine(PointF(R.Left, R.Bottom), PointF(R.Left + L, R.Bottom), Op);
end;

end.
