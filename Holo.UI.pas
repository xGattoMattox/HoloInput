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
        sFText: string;
        rFColors: TSkinColors;
        bFPassive: Boolean;
        bFHighlight: Boolean;
        dFFontSize: Single;
        bFKeepCase: Boolean;
        procedure SetText(const sValue: string);
        procedure SetPassive(const bValue: Boolean);
        procedure SetHighlight(const bValue: Boolean);
    protected
        procedure Paint; override;
        procedure DoMouseEnter; override;
        procedure DoMouseLeave; override;
        procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
        procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    public
        constructor Create(AOwner: TComponent); override;
        procedure SetColors(const rAColors: TSkinColors);
        property sText: string read sFText write SetText;
        property bPassive: Boolean read bFPassive write SetPassive;
        property bHighlight: Boolean read bFHighlight write SetHighlight;
        property dFontSize: Single read dFFontSize write dFFontSize;
        /// True = il testo e' scritto come impostato (default: tutto maiuscolo).
        property bKeepCase: Boolean read bFKeepCase write bFKeepCase;
    published
        property OnClick;
        property Visible;
        property Opacity;
    end;

    /// Cornice sottile a angoli smussati nei colori della skin, per raggruppare
    /// controlli e testi (non riceve i click).
    THoloFrame = class(TControl)
    private
        rFColors: TSkinColors;
        iFStateColor: TAlphaColor;   // colore di stato del bordo (0 = colori della skin)
    protected
        procedure Paint; override;
    public
        constructor Create(AOwner: TComponent); override;
        procedure SetColors(const rAColors: TSkinColors);
        procedure SetStateColor(iAColor: TAlphaColor);
    end;

function oChamferPath(const rARect: TRectF; dAChamfer: Single): TPathData;

implementation

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: oChamferPath
//** Parametri di ingresso: rARect: TRectF; dAChamfer: Single
//** Parametri di uscita: Result: TPathData
//** Scopo: Costruire il contorno "sci-fi" con due angoli smussati (alto-sinistra e basso-destra).
//**        Il chiamante deve liberare il path.
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
function oChamferPath(const rARect: TRectF; dAChamfer: Single): TPathData;
begin
    Result := TPathData.Create;
    Result.MoveTo(PointF(rARect.Left + dAChamfer, rARect.Top));
    Result.LineTo(PointF(rARect.Right, rARect.Top));
    Result.LineTo(PointF(rARect.Right, rARect.Bottom - dAChamfer));
    Result.LineTo(PointF(rARect.Right - dAChamfer, rARect.Bottom));
    Result.LineTo(PointF(rARect.Left, rARect.Bottom));
    Result.LineTo(PointF(rARect.Left, rARect.Top + dAChamfer));
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
    rFColors := rDefaultSkinColors;
    dFFontSize := 13;
    HitTest := True;
    Cursor := crHandPoint;
    Width := 96;
    Height := 30;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloButton.SetColors
//** Parametri di ingresso: rAColors: TSkinColors
//** Parametri di uscita: nessuno
//** Scopo: Applicare i colori della skin e ridisegnare.
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloButton.SetColors(const rAColors: TSkinColors);
begin
    rFColors := rAColors;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloButton.SetText
//** Parametri di ingresso: sValue: string
//** Parametri di uscita: nessuno
//** Scopo: Cambiare il testo del pulsante e ridisegnarlo.
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloButton.SetText(const sValue: string);
begin
    sFText := sValue;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloButton.SetPassive
//** Parametri di ingresso: bValue: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Modalita' etichetta: niente click e niente evidenziazione.
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloButton.SetPassive(const bValue: Boolean);
begin
    bFPassive := bValue;
    HitTest := not bValue;
    if bValue then
        Cursor := crDefault
    else
        Cursor := crHandPoint;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloButton.SetHighlight
//** Parametri di ingresso: bValue: Boolean
//** Parametri di uscita: nessuno
//** Scopo: Evidenziazione permanente (es. pulsante "Blocca" attivo).
//** Data Ultima Modifica: 26/09/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloButton.SetHighlight(const bValue: Boolean);
begin
    bFHighlight := bValue;
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
//** accento e centra il testo (in maiuscolo, salvo bKeepCase).
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloButton.Paint;
var
    rRect: TRectF;
    oPath: TPathData;
    bHot: Boolean;
    sCaption: string;
begin
    rRect := LocalRect;
    rRect.Inflate(-1, -1);
    bHot := (not bFPassive) and (IsMouseOver or Pressed);
    oPath := oChamferPath(rRect, 8);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        if Pressed and not bFPassive then
            Canvas.Fill.Color := iWithAlpha(rFColors.iAccent, $90)
        else if bHot or bFHighlight then
            Canvas.Fill.Color := iWithAlpha(rFColors.iPrimary, $50)
        else
            Canvas.Fill.Color := rFColors.iPanelBack;
        Canvas.FillPath(oPath, AbsoluteOpacity);

        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 1.5;
        if bHot or bFHighlight then
            Canvas.Stroke.Color := rFColors.iAccent
        else
            Canvas.Stroke.Color := rFColors.iPanelBorder;
        Canvas.DrawPath(oPath, AbsoluteOpacity);
    finally
        oPath.Free;
    end;

    Canvas.Font.Family := HOLO_FONT;
    Canvas.Font.Size := dFFontSize;
    Canvas.Font.Style := [TFontStyle.fsBold];
    if bHot or bFHighlight then
        Canvas.Fill.Color := rFColors.iAccent
    else
        Canvas.Fill.Color := rFColors.iText;
    if bFKeepCase then
        sCaption := sFText
    else
        sCaption := UpperCase(sFText);
    Canvas.FillText(rRect, sCaption, False, AbsoluteOpacity, [], TTextAlign.Center, TTextAlign.Center);
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
    rFColors := rDefaultSkinColors;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloFrame.SetColors
//** Parametri di ingresso: rAColors: TSkinColors
//** Parametri di uscita: nessuno
//** Scopo: Applicare i colori della skin e ridisegnare la cornice.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloFrame.SetColors(const rAColors: TSkinColors);
begin
    rFColors := rAColors;
    Repaint;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: THoloFrame.SetStateColor
//** Parametri di ingresso: iAColor: TAlphaColor
//** Parametri di uscita: nessuno
//** Scopo: Impostare il colore di stato di bordo e staffe (0 = tornare ai colori della skin).
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: il colore resta anche quando cambiano i colori della skin
//** (SetColors), cosi' lo stato rappresentato non si perde.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloFrame.SetStateColor(iAColor: TAlphaColor);
begin
    iFStateColor := iAColor;
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
//** leggero: fondo appena piu' scuro, bordo da 1 pixel nel colore iPanelBorder
//** della skin e due staffe corte nel colore Accent (in alto a destra e in
//** basso a sinistra). Con un colore di stato impostato (SetStateColor) bordo e
//** staffe usano quel colore.
//***********************************************************************************************************
//***********************************************************************************************************
procedure THoloFrame.Paint;
const
    L = 14;
var
    rRect: TRectF;
    oPath: TPathData;
    dOpacity: Single;
begin
    dOpacity := AbsoluteOpacity;
    rRect := LocalRect;
    rRect.Inflate(-1, -1);
    oPath := oChamferPath(rRect, 12);
    try
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.Fill.Color := iWithAlpha(iMixColors(rFColors.iPanelBack, TAlphaColors.Black, 0.25), $60);
        Canvas.FillPath(oPath, dOpacity);
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        Canvas.Stroke.Thickness := 1;
        if iFStateColor <> 0 then
            Canvas.Stroke.Color := iFStateColor
        else
            Canvas.Stroke.Color := rFColors.iPanelBorder;
        Canvas.DrawPath(oPath, dOpacity);
    finally
        oPath.Free;
    end;
    Canvas.Stroke.Thickness := 1.5;
    if iFStateColor <> 0 then
        Canvas.Stroke.Color := iFStateColor
    else
        Canvas.Stroke.Color := rFColors.iAccent;
    Canvas.DrawLine(PointF(rRect.Right - L, rRect.Top), PointF(rRect.Right, rRect.Top), dOpacity);
    Canvas.DrawLine(PointF(rRect.Right, rRect.Top), PointF(rRect.Right, rRect.Top + L), dOpacity);
    Canvas.DrawLine(PointF(rRect.Left, rRect.Bottom - L), PointF(rRect.Left, rRect.Bottom), dOpacity);
    Canvas.DrawLine(PointF(rRect.Left, rRect.Bottom), PointF(rRect.Left + L, rRect.Bottom), dOpacity);
end;

end.
