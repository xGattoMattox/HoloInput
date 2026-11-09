//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.Setup
//** Scopo: Schermata di configurazione (Setup) dell'applicazione.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: lavora su una COPIA della configurazione:
//**   SALVA   -> chiude con mrOk (la form principale applica e scrive il .ini)
//**   CHIUDI  -> chiude con mrCancel senza applicare nulla (le modifiche vanno perse)
//** La finestra e' divisa in pagine (pulsanti in alto):
//**   GENERALE    skin, lingua, layout (Orizzontale Basso/Alto, Verticale
//**               Destra/Sinistra, Personalizzato), margine, spaziatura, opzioni
//**               (tra cui "nascondi i widget inattivi" dopo N secondi, contrassegnato
//**               "SOLO BLOCCATO"),
//**               stile dei widget (pannello / solo dispositivo) ed effetti di base;
//**   DISPOSITIVI per ogni widget: visibilita', modello 3D, dispositivo
//**               sorgente (scelto tra quelli rilevati), posizione, dimensioni, assi;
//**   AMPIEZZA    ampiezza del movimento (gradi) e inversione (Si/No) di ogni asse
//**               dei due joystick e delle due manette (leva e mini-stick);
//**   MODALITA'   modalita' streamer (barra senza pulsanti) e modalita'
//**               privacy (tastiera sempre nascosta);
//**   LOG         log del rilevamento dispositivi e pulsante "Esegui scansione";
//**   OBS         parametri del servizio Browser Source per OBS (porta,
//**               risoluzione, fotogrammi al secondo, avvio automatico, occultamento della finestra:
//**               nascosta, fuori dallo
//**               schermo o su un altro monitor, scelto tra quelli collegati
//**               escluso il principale, su cui gira l'overlay), indirizzo da copiare,
//**               stato e pulsanti "Avvia il servizio" / "Ferma il servizio" (ObsAction dice
//**               alla finestra principale cosa fare dopo la chiusura);
//**   INFO        Citizen Dossier dell'autore e informazioni sul software;
//**               pulsante "Controlla aggiornamenti" (UpdateRequested) e casella
//**               "Controlla all'avvio".
//** Le coordinate X/Y si modificano solo con il layout Personalizzato; con gli
//** altri layout vengono ricalcolate (al salvataggio) secondo la voce scelta.
//** L'interfaccia e' costruita da codice (il .fmx contiene solo la form vuota).
//** Tutte le scritte passano da Tr (Holo.Lang); cambiando lingua il setup si
//** chiude con mrRetry e la finestra principale lo riapre nella nuova lingua.
//** La finestra e' senza barra del titolo di Windows: si sposta trascinando la
//** fascia in alto (titolo "HOLOINPUT - SETUP") e si chiude con Salva/Chiudi.
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.Setup;

interface

uses
    System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
    System.Generics.Collections,
    FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls, FMX.ListBox,
    FMX.Edit, FMX.NumberBox, FMX.Layouts, FMX.Controls.Presentation,
    FMX.Memo, FMX.Memo.Types, FMX.ScrollBox,
    Holo.Config, Holo.Skins, Holo.Input, Holo.Models, Holo.UI, Holo.Dialog, Holo.About, Holo.Lang,
    Holo.WebOverlay;

type
    /// Azione sul servizio OBS chiesta dal Setup (eseguita dalla finestra principale).
    TObsAction = (oaNone, oaStart, oaStop);
    /// Cambio dei fotogrammi al secondo di OBS con il servizio attivo (eseguito subito
    /// dalla finestra principale, senza attendere Salva).
    TObsFpsChangeEvent = procedure(Sender: TObject; AFps: Integer) of object;

    TWidgetRow = record
        Visible: TCheckBox;
        Model: TComboBox;
        Device: TComboBox;
        X, Y, W, H: TNumberBox;
        Axes: TEdit;
        Offset: TNumberBox;
        RangeX, RangeY, RangeZ: TNumberBox;  // solo joystick (pagina Ampiezza), altrimenti nil
        InvX, InvY, InvZ: TComboBox;         // solo joystick (pagina Ampiezza): 0 = No, 1 = Si
        Models: TArray<TDeviceModelClass>;
    end;

    TfrmSetup = class(TForm)
    private
        FConfig: TAppConfig;
        FInput: TInputManager;
        FColors: TSkinColors;
        FJoys: TArray<TJoyDeviceInfo>;
        FSkin, FLayout, FLang: TComboBox;
        FLangs: TArray<TLangInfo>;              // lingue elencate in FLang (stesso ordine)
        FMargin, FSpacing, FMouseRange: TNumberBox;
        FOpacity: TTrackBar;
        FLegends, FOnTop, FStartLocked, FStreamer, FPrivacy: TCheckBox;
        FWidgetStyle: TComboBox;                 // stile dei widget (pannello / solo dispositivo)
        FBaseEffects: TCheckBox;                 // effetti di base (anelli e scanline)
        FAutoHide: TCheckBox;                    // nascondi i widget inattivi
        FAutoHideSecs: TNumberBox;               // secondi di inattivita' prima di nasconderli
        FCheckUpdates: TCheckBox;                // pagina Info: controlla gli aggiornamenti all'avvio
        FUpdateRequested: Boolean;               // chiuso con "Controlla aggiornamenti"
        FPage: TFmxObject;                       // contenitore dei controlli creati da Add*
        FPages: array[0..6] of TLayout;
        FPageBtns: array[0..6] of THoloButton;
        FDossier: THoloDossierCard;
        FInfoCard: THoloInfoCard;
        FActivePage: Integer;
        FRows: array[TDeviceKind] of TWidgetRow;
        FTexts: TList<TPresentedTextControl>;
        FButtons: TList<THoloButton>;
        FFrames: TList<THoloFrame>;              // cornici dei riquadri (colori della skin)
        FLog: TMemo;                             // log del rilevamento dispositivi (pagina Log)
        FRangeInfo: TLabel;                      // riepilogo delle ampiezze nella pagina Ampiezza
        FLoading: Boolean;
        FInLegendsPrompt: Boolean;
        FObsPort, FObsWidth, FObsHeight: TNumberBox;   // pagina OBS: parametri del servizio
        FObsHide: TComboBox;                     // pagina OBS: occultamento della finestra
        FObsFps: TComboBox;                      // pagina OBS: fotogrammi al secondo (OBS_FPS_CHOICES)
        FObsMonitor: TComboBox;                  // pagina OBS: monitor di destinazione
        FObsMonitors: TArray<TMonitorDesc>;      // monitor elencati in FObsMonitor (stesso ordine)
        FObsUrl, FObsStatus: TLabel;             // pagina OBS: indirizzo e stato del servizio
        FObsBtnStart, FObsBtnStop: THoloButton;
        FObsStateFrame: THoloFrame;              // pagina OBS: cornice "Stato del servizio" (colore = stato)
        FObsAuto: TCheckBox;                     // pagina OBS: avvio automatico del servizio
        FObsAction: TObsAction;                  // azione chiesta alla chiusura (vedi ObsAction)
        FObsRunning: Boolean;                    // servizio OBS attivo (da SetObsState)
        FInFpsPrompt: Boolean;                   // avviso di riavvio per il cambio degli FPS aperto
        FOnObsFpsChange: TObsFpsChangeEvent;     // cambio degli FPS con il servizio attivo
        procedure BuildUI;
        procedure LoadValues;
        procedure ReadValues;
        procedure FillDeviceCombos;
        procedure ApplyColors;
        procedure UpdateRowState(AKind: TDeviceKind);
        function AddLabel(X, Y, W: Single; const S: string; ASize: Single = 12;
            ABold: Boolean = False): TLabel;
        function AddCheck(X, Y, W: Single; const S: string): TCheckBox;
        function AddCombo(X, Y, W: Single): TComboBox;
        function AddNumber(X, Y, W: Single; AMin, AMax: Integer): TNumberBox;
        function AddEdit(X, Y, W: Single): TEdit;
        function AddText(X, Y, W, H: Single; const S: string): TLabel;
        function AddFrame(X, Y, W, H: Single): THoloFrame;
        function AddButton(X, Y, W: Single; const S: string; AClick: TNotifyEvent): THoloButton;
        function AddLockBadge(X, Y: Single): THoloButton;
        procedure SkinChange(Sender: TObject);
        procedure LangChange(Sender: TObject);
        procedure RowChange(Sender: TObject);
        procedure LayoutChange(Sender: TObject);
        procedure LegendsChange(Sender: TObject);
        procedure AutoHideChange(Sender: TObject);
        procedure PageClick(Sender: TObject);
        procedure ShowPage(AIndex: Integer);
        function NewPage(AIndex: Integer; const ACaption: string): TLayout;
        procedure ModelChange(Sender: TObject);
        procedure BtnSaveClick(Sender: TObject);
        procedure BtnCloseClick(Sender: TObject);
        procedure BtnDefaultsClick(Sender: TObject);
        procedure BtnRangeDefaultsClick(Sender: TObject);
        procedure RangeChange(Sender: TObject);
        procedure UpdateRangeInfo;
        procedure BtnScanClick(Sender: TObject);
        procedure DragBarMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
            X, Y: Single);
        procedure RunScan;
        procedure LogLine(const S: string);
        procedure BtnDossierClick(Sender: TObject);
        procedure BtnUpdateClick(Sender: TObject);
        procedure BtnObsNativeClick(Sender: TObject);
        procedure BtnObsCopyClick(Sender: TObject);
        procedure BtnObsStartClick(Sender: TObject);
        procedure BtnObsStopClick(Sender: TObject);
        procedure ObsPortChange(Sender: TObject);
        procedure ObsHideChange(Sender: TObject);
        procedure ObsFpsChange(Sender: TObject);
        procedure UpdateObsUrl;
    public
        constructor CreateSetup(AOwner: TComponent; AConfig: TAppConfig; AInput: TInputManager);
        destructor Destroy; override;
        /// Mostra lo stato del servizio OBS (chiamata dalla finestra principale prima di ShowModal).
        procedure SetObsState(ARunning: Boolean; const AStatus: string);
        /// Azione sul servizio OBS chiesta con i pulsanti della pagina OBS (oaNone se nessuna).
        property ObsAction: TObsAction read FObsAction;
        /// True se il Setup e' stato chiuso con "Controlla aggiornamenti" (pagina Info).
        property UpdateRequested: Boolean read FUpdateRequested;
        /// Chiamato quando si cambiano gli FPS di OBS con il servizio attivo: la finestra
        /// principale ferma e riavvia subito il servizio con i nuovi FPS.
        property OnObsFpsChange: TObsFpsChangeEvent read FOnObsFpsChange write FOnObsFpsChange;
    end;

implementation

{$R *.fmx}

uses
    System.Rtti, FMX.Platform;

const
    PAGE_BTN_Y = 54;     // riga dei pulsanti delle pagine
    PAGE_TOP = 100;      // inizio dell'area delle pagine
    PAGE_BTN_STEP = 158; // passo dei pulsanti delle pagine (7 pulsanti in 1140 pixel)
    PAGE_BTN_W = 150;    // larghezza dei pulsanti delle pagine
    OBS_FPS_CHOICES: array[0..2] of Integer = (15, 30, 60);   // fotogrammi al secondo proposti per OBS
    OBS_ON_COLOR: TAlphaColor = $FF5FAE7A;    // cornice dello stato OBS: servizio attivo (verde tenue)
    OBS_OFF_COLOR: TAlphaColor = $FFA85C5C;   // cornice dello stato OBS: servizio fermo (rosso sbiadito)
    ROW_Y0 = 36;         // prima riga della tabella dispositivi (nella pagina)
    ROW_DY = 34;
    DEV_ROWS = Ord(High(TDeviceKind)) + 1;   // righe della tabella dispositivi
    /// testi del setup: font di sistema, piu' leggibile; i titoli dei riquadri e
    /// dei pulsanti restano nel font olografico dell'app (HOLO_FONT)
    SETUP_FONT = 'Segoe UI';
    SETUP_MIN_SIZE: Single = 11;  // dimensione minima dei testi descrittivi

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.CreateSetup
//** Parametri di ingresso: AOwner: TComponent; AConfig: TAppConfig; AInput: TInputManager
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare il setup collegato alla copia della configurazione.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: carica il .fmx (form vuota), costruisce i controlli, esegue
//** la prima scansione dei dispositivi (scritta nella pagina Log) e popola i
//** campi con i valori correnti.
//***********************************************************************************************************
//***********************************************************************************************************
constructor TfrmSetup.CreateSetup(AOwner: TComponent; AConfig: TAppConfig;
    AInput: TInputManager);
begin
    inherited Create(AOwner);
    FConfig := AConfig;
    FInput := AInput;
    FTexts := TList<TPresentedTextControl>.Create;
    FButtons := TList<THoloButton>.Create;
    FFrames := TList<THoloFrame>.Create;
    Caption := Tr('setup.caption', 'HoloInput - Setup');   // nome nella barra delle applicazioni
    BuildUI;
    RunScan;
    LoadValues;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.Destroy
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Liberare le liste di testi, pulsanti e cornici della finestra di Setup.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
destructor TfrmSetup.Destroy;
begin
    FTexts.Free;
    FButtons.Free;
    FFrames.Free;
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.DragBarMouseDown
//** Parametri di ingresso: Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single
//** Parametri di uscita: nessuno
//** Scopo: Spostare la finestra trascinando la fascia del titolo (la form non ha la barra del
//**        titolo di Windows).
//** Data Ultima Modifica: 28/10/2026
//***********************************************************************************************************
//** Funzionamento: la fascia del titolo e' un TLayout trasparente sopra la riga
//** dei pulsanti delle pagine; il clic sinistro su di essa avvia il
//** trascinamento della finestra gestito dal sistema.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.DragBarMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
    X, Y: Single);
begin
    if Button = TMouseButton.mbLeft then
        StartWindowDrag;
end;

//** Costruttori di controlli *******************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.AddLabel
//** Parametri di ingresso: X, Y, W: Single; S: string; ASize: Single; ABold: Boolean
//** Parametri di uscita: Result: TLabel
//** Scopo: Creare un'etichetta con font e colore dell'app (non quelli dello stile).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: i titoli (grassetto da 12 in su) usano il font olografico
//** HOLO_FONT; tutti gli altri testi usano SETUP_FONT (Segoe UI), piu'
//** leggibile, e non scendono sotto SETUP_MIN_SIZE.
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.AddLabel(X, Y, W: Single; const S: string; ASize: Single;
    ABold: Boolean): TLabel;
begin
    Result := TLabel.Create(Self);
    Result.Parent := FPage;
    Result.SetBounds(X, Y, W, 22);
    Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Family,
        TStyledSetting.Size, TStyledSetting.Style, TStyledSetting.FontColor];
    if ABold and (ASize >= 12) then
    begin
        Result.TextSettings.Font.Family := HOLO_FONT;
        Result.TextSettings.Font.Size := ASize;
    end
    else
    begin
        Result.TextSettings.Font.Family := SETUP_FONT;
        Result.TextSettings.Font.Size := Max(ASize, SETUP_MIN_SIZE);
    end;
    if ABold then
        Result.TextSettings.Font.Style := [TFontStyle.fsBold];
    Result.Text := S;
    FTexts.Add(Result);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.AddCheck
//** Parametri di ingresso: X, Y, W: Single; S: string
//** Parametri di uscita: Result: TCheckBox
//** Scopo: Creare una casella di spunta con testo (Segoe UI) nel colore dell'app.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.AddCheck(X, Y, W: Single; const S: string): TCheckBox;
begin
    Result := TCheckBox.Create(Self);
    Result.Parent := FPage;
    Result.SetBounds(X, Y, W, 22);
    Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Family,
        TStyledSetting.Size, TStyledSetting.FontColor];
    Result.TextSettings.Font.Family := SETUP_FONT;
    Result.TextSettings.Font.Size := 12;
    Result.Text := S;
    FTexts.Add(Result);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.AddCombo
//** Parametri di ingresso: X, Y, W: Single
//** Parametri di uscita: Result: TComboBox
//** Scopo: Creare una combo box.
//** Data Ultima Modifica: 01/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.AddCombo(X, Y, W: Single): TComboBox;
begin
    Result := TComboBox.Create(Self);
    Result.Parent := FPage;
    Result.SetBounds(X, Y, W, 24);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.AddNumber
//** Parametri di ingresso: X, Y, W: Single; AMin, AMax: Integer
//** Parametri di uscita: Result: TNumberBox
//** Scopo: Creare un campo numerico intero con limiti.
//** Data Ultima Modifica: 01/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.AddNumber(X, Y, W: Single; AMin, AMax: Integer): TNumberBox;
begin
    Result := TNumberBox.Create(Self);
    Result.Parent := FPage;
    Result.SetBounds(X, Y, W, 24);
    Result.DecimalDigits := 0;
    Result.Min := AMin;
    Result.Max := AMax;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.AddEdit
//** Parametri di ingresso: X, Y, W: Single
//** Parametri di uscita: Result: TEdit
//** Scopo: Creare un campo di testo.
//** Data Ultima Modifica: 01/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.AddEdit(X, Y, W: Single): TEdit;
begin
    Result := TEdit.Create(Self);
    Result.Parent := FPage;
    Result.SetBounds(X, Y, W, 24);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.AddText
//** Parametri di ingresso: X, Y, W, H: Single; S: string
//** Parametri di uscita: Result: TLabel
//** Scopo: Creare un testo su piu' righe, allineato in alto e a capo automatico.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//** Funzionamento: parte da AddLabel (font e colore dell'app) e toglie anche
//** l'allineamento dello stile, cosi' il testo comincia subito sotto il titolo
//** invece di essere centrato in verticale nell'area.
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.AddText(X, Y, W, H: Single; const S: string): TLabel;
begin
    Result := AddLabel(X, Y, W, S, 10);
    Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Other];
    Result.TextSettings.VertAlign := TTextAlign.Leading;
    Result.TextSettings.HorzAlign := TTextAlign.Leading;
    Result.TextSettings.WordWrap := True;
    Result.Height := H;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.AddFrame
//** Parametri di ingresso: X, Y, W, H: Single
//** Parametri di uscita: Result: THoloFrame
//** Scopo: Creare una cornice sottile nei colori della skin attorno a un gruppo di controlli.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.AddFrame(X, Y, W, H: Single): THoloFrame;
begin
    Result := THoloFrame.Create(Self);
    Result.Parent := FPage;
    Result.SetBounds(X, Y, W, H);
    FFrames.Add(Result);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.AddButton
//** Parametri di ingresso: X, Y, W: Single; S: string; AClick: TNotifyEvent
//** Parametri di uscita: Result: THoloButton
//** Scopo: Creare un pulsante con lo stesso stile della barra dell'overlay.
//** Data Ultima Modifica: 01/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.AddButton(X, Y, W: Single; const S: string;
    AClick: TNotifyEvent): THoloButton;
begin
    Result := THoloButton.Create(Self);
    Result.Parent := FPage;
    Result.SetBounds(X, Y, W, 34);
    Result.Text := S;
    Result.OnClick := AClick;
    FButtons.Add(Result);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.AddLockBadge
//** Parametri di ingresso: X, Y: Single
//** Parametri di uscita: Result: THoloButton
//** Scopo: Creare il contrassegno "SOLO BLOCCATO" accanto ai comandi che agiscono solo con il
//**        layout bloccato.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: piccola etichetta nello stile dei pulsanti, evidenziata
//** (bordo e testo nel colore accento della skin), che non riceve i click.
//** Tutti i comandi senza contrassegno funzionano sia con il layout bloccato
//** sia con quello sbloccato (la legenda e' in basso, accanto a Default).
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.AddLockBadge(X, Y: Single): THoloButton;
begin
    Result := AddButton(X, Y, 118, Tr('setup.badge.locked', 'Solo bloccato'), nil);
    Result.Height := 20;
    Result.Passive := True;
    Result.Highlight := True;
    Result.FontSize := 9;
    Result.HitTest := False;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.NewPage
//** Parametri di ingresso: AIndex: Integer; ACaption: string
//** Parametri di uscita: Result: TLayout
//** Scopo: Creare una pagina (area che occupa la parte centrale della finestra) e il pulsante che
//**        la seleziona.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.NewPage(AIndex: Integer; const ACaption: string): TLayout;
begin
    FPage := Self;
    FPageBtns[AIndex] := AddButton(20 + AIndex * PAGE_BTN_STEP, PAGE_BTN_Y, PAGE_BTN_W, ACaption, PageClick);
    FPageBtns[AIndex].Tag := AIndex;
    Result := TLayout.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(0, PAGE_TOP, ClientWidth, ClientHeight - PAGE_TOP - 64);
    Result.Visible := False;
    FPages[AIndex] := Result;
    FPage := Result;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.ShowPage
//** Parametri di ingresso: AIndex: Integer
//** Parametri di uscita: nessuno
//** Scopo: Mostrare una pagina ed evidenziarne il pulsante.
//** Data Ultima Modifica: 24/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.ShowPage(AIndex: Integer);
var
    I: Integer;
begin
    FActivePage := AIndex;
    for I := 0 to High(FPages) do
    begin
        FPages[I].Visible := I = AIndex;
        FPageBtns[I].Highlight := I = AIndex;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.PageClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Mostrare la pagina del Setup associata al pulsante cliccato (Tag).
//** Data Ultima Modifica: 24/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.PageClick(Sender: TObject);
begin
    ShowPage((Sender as THoloButton).Tag);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BuildUI
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Costruire tutta l'interfaccia del setup.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: cornice attorno alla finestra (che non ha la barra del
//** titolo di Windows), titolo e pulsanti delle pagine in alto, sette pagine
//** (Generale, Dispositivi, Ampiezza, Modalita', Log, OBS, Info) al centro, pulsanti
//** di comando in basso. Le zone dal significato contiguo sono raccolte in
//** riquadri (THoloFrame) nei colori della skin. I comandi che agiscono solo
//** con il layout bloccato (nascondi i widget inattivi, servizio OBS) hanno il
//** contrassegno "SOLO BLOCCATO" (AddLockBadge), spiegato dalla legenda in basso.
//** I controlli sono creati dentro la pagina corrente (FPage).
//** Nella pagina Dispositivi la colonna "Dispositivo sorgente" e' sempre
//** visibile: ogni widget sceglie il dispositivo tra quelli rilevati. La
//** pagina Ampiezza ha un riquadro per i joystick e uno per le manette (leva e
//** mini-stick, con le stesse colonne ampiezza / Inverti).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BuildUI;
const
    RANGE_COL: array[0..2] of Single = (200, 420, 640);   // colonne X, Y, Z della pagina Ampiezza
    INV_DX = 130;                                          // posizione del dropdown "Inverti" nella colonna
var
    K: TDeviceKind;
    L: TLayoutMode;
    I: Integer;
    Y, FW: Single;
    R: TWidgetRow;
    Boxes: array[0..2] of TNumberBox;
    Invs: array[0..2] of TComboBox;
    DragBar: TLayout;
begin
    FPage := Self;
    // finestra senza barra del titolo: cornice attorno a tutta la form
    AddFrame(0, 0, ClientWidth, ClientHeight);
    AddLabel(20, 12, 700, Tr('setup.title', 'HOLOINPUT  ' + #$00B7 + '  SETUP'), 20, True).Height := 32;
    // fascia del titolo trasparente: trascinandola si sposta la finestra
    DragBar := TLayout.Create(Self);
    DragBar.Parent := Self;
    DragBar.SetBounds(0, 0, ClientWidth, PAGE_BTN_Y - 4);
    DragBar.HitTest := True;
    DragBar.Cursor := crSizeAll;
    DragBar.OnMouseDown := DragBarMouseDown;

    //** pagina GENERALE ************************************************************************************
    // ogni gruppo di impostazioni sta in un riquadro (cornice creata prima dei controlli)
    NewPage(0, Tr('setup.page.general', 'Generale'));
    FW := ClientWidth - 16;
    AddFrame(8, 0, FW, 76);
    AddLabel(20, 10, 300, Tr('setup.gen.look', 'ASPETTO'), 13, True);
    AddLabel(20, 42, 60, Tr('setup.gen.skin', 'Skin'));
    FSkin := AddCombo(70, 40, 210);
    for I := 0 to SkinCount - 1 do
        FSkin.Items.Add(SkinByIndex(I).DisplayName);
    FSkin.OnChange := SkinChange;
    AddLabel(300, 42, 70, Tr('setup.gen.opacity', 'Opacita'''));
    FOpacity := TTrackBar.Create(Self);
    FOpacity.Parent := FPage;
    FOpacity.SetBounds(370, 42, 250, 22);
    FOpacity.Min := 20;
    FOpacity.Max := 100;
    // lingua dell'interfaccia: cambiandola il setup si riapre nella nuova lingua
    AddLabel(650, 42, 70, Tr('setup.gen.language', 'Lingua'));
    FLang := AddCombo(720, 40, 210);
    FLangs := AvailableLanguages;
    for I := 0 to High(FLangs) do
        FLang.Items.Add(FLangs[I].Name);
    FLang.OnChange := LangChange;

    AddFrame(8, 88, FW, 76);
    AddLabel(20, 98, 300, Tr('setup.gen.arrangement', 'DISPOSIZIONE'), 13, True);
    AddLabel(20, 130, 70, Tr('setup.gen.layout', 'Layout'));
    FLayout := AddCombo(80, 128, 200);
    for L := Low(TLayoutMode) to High(TLayoutMode) do
        FLayout.Items.Add(LayoutText(L));
    FLayout.OnChange := LayoutChange;
    AddLabel(300, 130, 70, Tr('setup.gen.margin', 'Margine'));
    FMargin := AddNumber(370, 128, 65, 0, 500);
    AddLabel(455, 130, 80, Tr('setup.gen.spacing', 'Spaziatura'));
    FSpacing := AddNumber(535, 128, 60, 0, 200);

    AddFrame(8, 176, FW, 112);
    AddLabel(20, 186, 300, Tr('setup.gen.options', 'OPZIONI'), 13, True);
    // le animazioni non si scelgono piu' dal Setup: resta il valore del .ini (Animazioni)
    FLegends := AddCheck(20, 216, 160, Tr('setup.gen.legends', 'Legende sui tasti'));
    FLegends.OnChange := LegendsChange;
    FOnTop := AddCheck(185, 216, 200, Tr('setup.gen.ontop', 'Sempre in primo piano'));
    FStartLocked := AddCheck(390, 216, 240, Tr('setup.gen.startlocked', 'Avvia bloccato (click-through)'));
    // nascondi i widget dei dispositivi inattivi dopo N secondi (da bloccato)
    FAutoHide := AddCheck(650, 254, 250, Tr('setup.gen.autohide', 'Nascondi i widget inattivi dopo'));
    FAutoHide.OnChange := AutoHideChange;
    FAutoHideSecs := AddNumber(905, 252, 60, AUTOHIDE_MIN, AUTOHIDE_MAX);
    AddLabel(972, 254, 140, Tr('setup.gen.autohide.secs', 'secondi'));
    // prima riga: contrassegno "solo bloccato"; seconda riga: la casella con i secondi
    AddLockBadge(650, 214);
    AddLabel(778, 216, 340, Tr('setup.gen.autohide.hint', 'ricompaiono al primo input'), 10);
    AddLabel(20, 254, 100, Tr('setup.gen.mouserange', 'Corsa mouse'));
    FMouseRange := AddNumber(120, 252, 85, 200, 50000);
    AddLabel(215, 254, 420, Tr('setup.gen.mouserange.hint', 'count del mouse per percorrere tutto il tappetino'), 10);

    // stile dei widget: subito dopo le opzioni
    AddFrame(8, 300, FW, 100);
    AddLabel(20, 310, 400, Tr('setup.gen.style', 'STILE DEI WIDGET'), 13, True);
    AddLabel(20, 342, 60, Tr('setup.gen.style.label', 'Stile'));
    FWidgetStyle := AddCombo(80, 340, 340);
    FWidgetStyle.Items.Add(Tr('setup.gen.style.panel', 'Pannello (sfondo, cornice e titolo)'));
    FWidgetStyle.Items.Add(Tr('setup.gen.style.deviceonly', 'Solo dispositivo (sfondo trasparente)'));
    FBaseEffects := AddCheck(445, 341, 420, Tr('setup.gen.baseeffects',
        'Effetti di base (anelli del proiettore e scansione)'));
    AddLabel(20, 372, 1100, Tr('setup.gen.style.hint',
        'Solo dispositivo: con il layout sbloccato titolo e cornice compaiono passando con il mouse ' +
        'sul widget; lo stato compare solo se il dispositivo non e'' collegato.'), 10);

    AddFrame(8, 412, FW, 70);
    AddLabel(20, 422, 300, Tr('setup.gen.hotkeys', 'HOTKEY'), 13, True);
    AddLabel(20, 450, 1100,
        Tr('setup.gen.hotkeys.text', 'Ctrl+Alt+F12 blocca/sblocca  ' + #$00B7 + '  Ctrl+Alt+F11 setup  ' +
        #$00B7 + '  Ctrl+Alt+F10 mostra/nasconde  ' + #$00B7 + '  Ctrl+Alt+F9 modalita'' streamer.'), 10);

    //** pagina DISPOSITIVI *********************************************************************************
    NewPage(1, Tr('setup.page.devices', 'Dispositivi'));
    // tabella dei widget in un riquadro
    AddFrame(8, 0, FW, ROW_Y0 + DEV_ROWS * ROW_DY + 8);
    Y := 10;
    AddLabel(20, Y, 170, Tr('setup.dev.col.visible', 'Visibile / tipo'), 10);
    AddLabel(200, Y, 240, Tr('setup.dev.col.model', 'Modello 3D'), 10);
    AddLabel(450, Y, 230, Tr('setup.dev.col.device', 'Dispositivo sorgente'), 10);
    AddLabel(690, Y, 60, 'X', 10);
    AddLabel(755, Y, 60, 'Y', 10);
    AddLabel(820, Y, 60, Tr('setup.dev.col.width', 'Largh.'), 10);
    AddLabel(885, Y, 60, Tr('setup.dev.col.height', 'Alt.'), 10);
    AddLabel(950, Y, 60, Tr('setup.dev.col.axes', 'Assi XYZ'), 10);
    AddLabel(1015, Y, 60, Tr('setup.dev.col.firstbutton', '1' + #$00B0 + ' puls.'), 10);

    for K := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        Y := ROW_Y0 + Ord(K) * ROW_DY;
        R := Default(TWidgetRow);
        R.Visible := AddCheck(20, Y + 1, 175, KindText(K));
        R.Visible.OnChange := RowChange;
        R.Model := AddCombo(200, Y, 240);
        R.Models := ModelsOfKind(K);
        for I := 0 to High(R.Models) do
            R.Model.Items.Add(R.Models[I].DisplayName);
        R.Model.Tag := Ord(K);
        R.Model.OnChange := ModelChange;
        // dispositivo sorgente: scelto tra quelli rilevati dall'ultima scansione
        R.Device := AddCombo(450, Y, 230);
        R.X := AddNumber(690, Y, 60, -20000, 20000);
        R.Y := AddNumber(755, Y, 60, -20000, 20000);
        R.W := AddNumber(820, Y, 60, 80, 4000);
        R.H := AddNumber(885, Y, 60, 80, 4000);
        R.Axes := AddEdit(950, Y, 60);
        R.Offset := AddNumber(1015, Y, 55, 1, 32);
        FRows[K] := R;
    end;

    // spiegazione della colonna "Assi XYZ" (cornice creata prima dei testi)
    Y := ROW_Y0 + DEV_ROWS * ROW_DY + 20;
    AddFrame(8, Y, FW, 146);
    AddLabel(20, Y + 10, 520, Tr('setup.dev.axes.title', 'ASSI XYZ'), 12, True);
    AddText(20, Y + 34, 1100, 108, Tr('setup.dev.axes.text',
        'Tre indici separati da virgola: dicono quale asse fisico del dispositivo muove ogni ' +
        'movimento del modello 3D, nell''ordine' + sLineBreak +
        '   joystick:  X inclinazione sinistra / destra,  Y inclinazione avanti / indietro,  ' +
        'Z rotazione dell''impugnatura (twist)' + sLineBreak +
        '   manette:   leva avanti / indietro,  mini-stick sinistra / destra,  mini-stick su / giu''' +
        sLineBreak +
        'Indici degli assi di Windows: 0 = X   1 = Y   2 = Z   3 = R   4 = U   5 = V.' + sLineBreak +
        'Esempio "0,1,3": X dall''asse X, Y dall''asse Y, twist dall''asse R. Se il twist ' +
        'dello stick e'' sull''asse Z scrivere "0,1,2".' + sLineBreak +
        'Il verso di ogni movimento (Inverti Si/No) e l''ampiezza si impostano nella pagina Ampiezza.'));

    // spiegazione delle colonne "primo pulsante" e X / Y
    Y := Y + 154;
    AddFrame(8, Y, FW, 90);
    AddLabel(20, Y + 8, 520, Tr('setup.dev.cols.title', 'ALTRE COLONNE'), 12, True);
    AddText(20, Y + 32, 1100, 54, Tr('setup.dev.cols.text',
        '1' + #$00B0 + ' puls. (pulsantiere e manette): numero del pulsante del dispositivo da cui il ' +
        'modello comincia a leggere. Con 1 il primo tasto del modello 3D e'' il pulsante 1; con 17 ' +
        'una pulsantiera da 16 tasti mostra i pulsanti 17-32 (per dividere tra due pulsantiere un ' +
        'dispositivo con 32 pulsanti, o per mostrare i pulsanti della base di un joystick).' + sLineBreak +
        'X / Y (posizione sullo schermo): modificabili solo con il layout Personalizzato.'));

    //** pagina AMPIEZZA ************************************************************************************
    NewPage(2, Tr('setup.page.range', 'Ampiezza'));
    // riquadro con la spiegazione dell'ampiezza degli angoli e i valori risultanti
    AddFrame(8, 0, FW, 160);
    AddLabel(20, 10, 520, Tr('setup.amp.angles.title', 'AMPIEZZA DEGLI ANGOLI'), 12, True);
    AddText(20, 34, 1100, 48, Format(Tr('setup.amp.angles.text',
        'Angolo totale di escursione di ogni movimento (X, Y, Z), in gradi da %d a %d, impostato qui ' +
        'sotto: con 60' + #$00B0 + ' l''asse a fine corsa va da -30' + #$00B0 + ' a +30' + #$00B0 +
        ' rispetto al centro.' + sLineBreak + 'Gli assi X, Y e Z sono quelli assegnati nella pagina ' +
        'Dispositivi (colonna "Assi XYZ"); con Inverti = Si il movimento va nel verso opposto.'),
        [JOY_RANGE_MIN, JOY_RANGE_MAX]));
    AddText(20, 88, 1100, 22, Tr('setup.amp.current', 'Valori attuali:'));
    FRangeInfo := AddText(36, 110, 1080, 44, '');
    FRangeInfo.TextSettings.Font.Style := [TFontStyle.fsBold];

    // riquadro con le impostazioni dei due joystick
    AddFrame(8, 172, FW, 202);
    AddLabel(20, 182, 400, Tr('setup.amp.move.title', 'AMPIEZZA DEL MOVIMENTO'), 13, True);
    AddLabel(20, 212, 170, Tr('setup.amp.col.joystick', 'Joystick'), 10);
    AddLabel(RANGE_COL[0], 212, 125, Tr('setup.amp.col.x', 'X  sinistra / destra'), 10);
    AddLabel(RANGE_COL[1], 212, 125, Tr('setup.amp.col.y', 'Y  avanti / indietro'), 10);
    AddLabel(RANGE_COL[2], 212, 125, Tr('setup.amp.col.z', 'Z  rotazione (twist)'), 10);
    for I := 0 to 2 do
        AddLabel(RANGE_COL[I] + INV_DX, 212, 80, Tr('setup.amp.col.invert', 'Inverti'), 10);
    Y := 238;
    for K in [dkJoyLeft, dkJoyRight] do
    begin
        AddLabel(20, Y + 2, 170, KindText(K));
        for I := 0 to 2 do
        begin
            Boxes[I] := AddNumber(RANGE_COL[I], Y, 80, JOY_RANGE_MIN, JOY_RANGE_MAX);
            Boxes[I].OnChange := RangeChange;
            AddLabel(RANGE_COL[I] + 84, Y + 2, 20, #$00B0);
            Invs[I] := AddCombo(RANGE_COL[I] + INV_DX, Y, 64);
            Invs[I].Items.Add(Tr('setup.amp.invert.no', 'No'));
            Invs[I].Items.Add(Tr('setup.amp.invert.yes', 'Si'));
            Invs[I].ItemIndex := 0;
            Invs[I].OnChange := RangeChange;
        end;
        FRows[K].RangeX := Boxes[0];
        FRows[K].RangeY := Boxes[1];
        FRows[K].RangeZ := Boxes[2];
        FRows[K].InvX := Invs[0];
        FRows[K].InvY := Invs[1];
        FRows[K].InvZ := Invs[2];
        Y := Y + ROW_DY;
    end;
    AddButton(20, Y + 16, 240, Tr('setup.amp.btn.defaults', 'Ampiezze predefinite'), BtnRangeDefaultsClick);
    AddLabel(280, Y + 24, 800,
        Format(Tr('setup.amp.defaults.hint', 'X %d' + #$00B0 + '   Y %d' + #$00B0 + '   Z %d' + #$00B0 +
        '   (non salvate finche'' non si preme Salva)'), [DEF_RANGE_X, DEF_RANGE_Y, DEF_RANGE_Z]), 10);

    // riquadro con le impostazioni delle due manette (leva e mini-stick)
    AddFrame(8, 386, FW, 150);
    AddLabel(20, 396, 400, Tr('setup.amp.thr.title', 'MANETTE'), 13, True);
    AddLabel(560, 400, 560, Format(Tr('setup.amp.thr.defaults', 'predefinite: leva %d' + #$00B0 +
        ', mini-stick %d' + #$00B0), [DEF_THR_LEVER, DEF_THR_MINI]), 10);
    AddLabel(20, 426, 170, Tr('setup.amp.col.throttle', 'Manetta'), 10);
    AddLabel(RANGE_COL[0], 426, 125, Tr('setup.amp.col.lever', 'Leva  avanti / indietro'), 10);
    AddLabel(RANGE_COL[1], 426, 125, Tr('setup.amp.col.ministickx', 'Mini-stick  sx / dx'), 10);
    AddLabel(RANGE_COL[2], 426, 125, Tr('setup.amp.col.ministicky', 'Mini-stick  su / giu'''), 10);
    for I := 0 to 2 do
        AddLabel(RANGE_COL[I] + INV_DX, 426, 80, Tr('setup.amp.col.invert', 'Inverti'), 10);
    Y := 452;
    for K in [dkThrLeft, dkThrRight] do
    begin
        AddLabel(20, Y + 2, 170, KindText(K));
        for I := 0 to 2 do
        begin
            Boxes[I] := AddNumber(RANGE_COL[I], Y, 80, JOY_RANGE_MIN, JOY_RANGE_MAX);
            AddLabel(RANGE_COL[I] + 84, Y + 2, 20, #$00B0);
            Invs[I] := AddCombo(RANGE_COL[I] + INV_DX, Y, 64);
            Invs[I].Items.Add(Tr('setup.amp.invert.no', 'No'));
            Invs[I].Items.Add(Tr('setup.amp.invert.yes', 'Si'));
            Invs[I].ItemIndex := 0;
        end;
        FRows[K].RangeX := Boxes[0];
        FRows[K].RangeY := Boxes[1];
        FRows[K].RangeZ := Boxes[2];
        FRows[K].InvX := Invs[0];
        FRows[K].InvY := Invs[1];
        FRows[K].InvZ := Invs[2];
        Y := Y + ROW_DY;
    end;

    //** pagina MODALITA' ***********************************************************************************
    NewPage(3, Tr('setup.page.modes', 'Modalita'''));
    // per ogni modalita': titolo, descrizione e poi la casella per attivarla
    AddFrame(8, 0, FW, 116);
    AddLabel(20, 10, 400, Tr('setup.modes.streamer.title', 'MODALITA'' STREAMER'), 13, True);
    AddText(20, 36, 1100, 40, Tr('setup.modes.streamer.text',
        'Nasconde i pulsanti della barra comandi (Setup, Blocca layout, Esci): resta solo ' +
        'l''etichetta, che mostra il tasto rapido per farli ricomparire: Ctrl+Alt+F9.' + sLineBreak +
        'Se Ctrl+Alt+F9 e'' gia'' usato da un''altra applicazione i pulsanti restano visibili.'))
        .TextSettings.Font.Size := 11;
    FStreamer := AddCheck(20, 82, 400, Tr('setup.modes.streamer.check', 'Attiva modalita'' streamer'));

    AddFrame(8, 128, FW, 116);
    AddLabel(20, 138, 400, Tr('setup.modes.privacy.title', 'MODALITA'' PRIVACY'), 13, True);
    AddText(20, 164, 1100, 40, Tr('setup.modes.privacy.text',
        'Nasconde sempre il widget della tastiera, anche se e'' attivo tra i dispositivi, ' +
        'per non mostrare cio'' che si digita (ad esempio una password).' + sLineBreak +
        'Il widget della tastiera ricompare solo disattivando questa modalita''.'))
        .TextSettings.Font.Size := 11;
    FPrivacy := AddCheck(20, 210, 400, Tr('setup.modes.privacy.check', 'Attiva modalita'' privacy'));
    FPrivacy.OnChange := RowChange;

    //** pagina LOG *****************************************************************************************
    NewPage(4, Tr('setup.page.log', 'Log'));
    AddFrame(8, 0, FW, TControl(FPage).Height - 4);
    AddLabel(20, 10, 600, Tr('setup.log.title', 'LOG DEL RILEVAMENTO DISPOSITIVI'), 13, True);
    AddButton(ClientWidth - 260, 6, 240, Tr('setup.log.btn.scan', 'Esegui scansione'), BtnScanClick);
    FLog := TMemo.Create(Self);
    FLog.Parent := FPage;
    FLog.SetBounds(20, 48, ClientWidth - 40, TControl(FPage).Height - 66);
    FLog.ReadOnly := True;
    FLog.WordWrap := False;
    FLog.StyledSettings := FLog.StyledSettings - [TStyledSetting.Family, TStyledSetting.Size];
    FLog.TextSettings.Font.Family := 'Consolas';
    FLog.TextSettings.Font.Size := 12;

    //** pagina OBS *****************************************************************************************
    NewPage(5, Tr('setup.page.obs', 'OBS'));
    // parametri del servizio Browser Source
    AddFrame(8, 0, FW, 176);
    AddLabel(20, 10, 340, Tr('setup.obs.service.title', 'SERVIZIO BROWSER SOURCE PER OBS'), 13, True);
    // il servizio funziona solo con il layout bloccato (all'avvio lo blocca da solo)
    AddLockBadge(370, 10);
    AddLabel(20, 46, 60, Tr('setup.obs.port', 'Porta'));
    FObsPort := AddNumber(80, 44, 90, OBS_PORT_MIN, OBS_PORT_MAX);
    FObsPort.OnChange := ObsPortChange;
    AddLabel(200, 46, 100, Tr('setup.obs.resolution', 'Risoluzione'));
    FObsWidth := AddNumber(300, 44, 80, OBS_SIZE_MIN, OBS_SIZE_MAX);
    AddLabel(386, 46, 14, 'x');
    FObsHeight := AddNumber(402, 44, 80, OBS_SIZE_MIN, OBS_SIZE_MAX);
    AddButton(500, 39, 220, Tr('setup.obs.btn.native', 'Risoluzione nativa'), BtnObsNativeClick);
    AddLabel(735, 46, 380, Format(Tr('setup.obs.native.hint', 'monitor principale: %d x %d pixel'),
        [NativeScreenSize.cx, NativeScreenSize.cy]), 10);
    AddLabel(20, 90, 175, Tr('setup.obs.hide', 'Con il servizio attivo'));
    FObsHide := AddCombo(200, 88, 300);
    FObsHide.Items.Add(Tr('setup.obs.hide.window', 'Nascondi la finestra'));
    FObsHide.Items.Add(Tr('setup.obs.hide.offscreen', 'Sposta la finestra fuori dallo schermo'));
    FObsHide.Items.Add(Tr('setup.obs.hide.monitor', 'Sposta la finestra su un altro monitor'));
    FObsHide.OnChange := ObsHideChange;
    // monitor di destinazione: tutti quelli collegati tranne il principale (dove gira l'overlay)
    FObsMonitor := AddCombo(515, 88, 600);
    FObsMonitors := OtherMonitors;
    for I := 0 to High(FObsMonitors) do
        FObsMonitor.Items.Add(MonitorText(FObsMonitors[I]));
    if Length(FObsMonitors) = 0 then
        FObsMonitor.Items.Add(Tr('setup.obs.monitor.none', 'Nessun altro monitor collegato'));
    AddLabel(20, 134, 175, Tr('setup.obs.url', 'Indirizzo per OBS'));
    FObsUrl := AddLabel(200, 134, 290, '', 12);
    FObsUrl.TextSettings.Font.Style := [TFontStyle.fsBold];
    AddButton(500, 127, 220, Tr('setup.obs.btn.copy', 'Copia indirizzo'), BtnObsCopyClick);
    // fotogrammi al secondo inviati a OBS
    AddLabel(740, 134, 150, Tr('setup.obs.fps', 'Fotogrammi al secondo'));
    FObsFps := AddCombo(895, 132, 120);
    for I := 0 to High(OBS_FPS_CHOICES) do
        FObsFps.Items.Add(Format('%d fps', [OBS_FPS_CHOICES[I]]));
    FObsFps.OnChange := ObsFpsChange;

    // stato del servizio e comandi
    FObsStateFrame := AddFrame(8, 188, FW, 138);
    FObsStateFrame.SetStateColor(OBS_OFF_COLOR);
    AddLabel(20, 198, 600, Tr('setup.obs.status.title', 'STATO DEL SERVIZIO'), 13, True);
    FObsStatus := AddText(20, 224, 1100, 56, '');
    FObsBtnStart := AddButton(20, 284, 240, Tr('setup.obs.btn.start', 'Avvia il servizio'), BtnObsStartClick);
    FObsBtnStop := AddButton(280, 284, 240, Tr('setup.obs.btn.stop', 'Ferma il servizio'), BtnObsStopClick);
    FObsAuto := AddCheck(550, 290, 560, Tr('setup.obs.autostart', 'Avvia il servizio all''avvio di HoloInput'));

    // istruzioni
    AddFrame(8, 338, FW, 210);
    AddLabel(20, 348, 600, Tr('setup.obs.howto.title', 'COME USARLO IN OBS'), 13, True);
    AddText(20, 374, 1100, 168, Tr('setup.obs.howto.text',
        '1.  Premere "Avvia il servizio": HoloInput scompare dallo schermo e invia a OBS ' +
        'l''immagine dei widget attraverso una connessione continua (WebSocket).' + sLineBreak +
        '2.  In OBS: Fonti > + > Browser. Come URL usare l''indirizzo qui sopra, come larghezza e ' +
        'altezza la risoluzione impostata qui sopra; spuntare "Usa frequenza fotogrammi ' +
        'personalizzata" con gli stessi fps e togliere "Spegni la fonte quando non visibile".' + sLineBreak +
        '3.  Con la risoluzione nativa del monitor i widget compaiono nella scena esattamente dove ' +
        'sono sullo schermo; se il canvas di OBS e'' piu'' piccolo, impostare qui la sua risoluzione ' +
        '(OBS: Impostazioni > Video > Risoluzione di base) e la disposizione viene scalata.' + sLineBreak +
        '4.  Per far ricomparire HoloInput premere Ctrl+Alt+F11: si apre questo Setup, da cui si ' +
        'ferma il servizio.'));

    //** pagina INFO ****************************************************************************************
    NewPage(6, Tr('setup.page.info', 'Info'));
    FDossier := THoloDossierCard.Create(Self);
    FDossier.Parent := FPage;
    FDossier.SetBounds(20, 10, 600, 340);
    FInfoCard := THoloInfoCard.Create(Self);
    FInfoCard.Parent := FPage;
    FInfoCard.SetBounds(640, 10, 480, 340);
    AddButton(20, 364, 300, Tr('setup.info.btn.dossier', 'Apri il Citizen Dossier su RSI'), BtnDossierClick);
    // aggiornamenti dalla pagina delle release su GitHub
    AddButton(640, 364, 260, Tr('setup.info.btn.update', 'Controlla aggiornamenti'), BtnUpdateClick);
    FCheckUpdates := AddCheck(915, 370, 210, Tr('setup.info.checkupdates', 'Controlla all''avvio'));

    //** comandi in basso ***********************************************************************************
    FPage := Self;
    Y := ClientHeight - 52;
    AddButton(20, Y, 130, Tr('setup.btn.default', 'Default'), BtnDefaultsClick);
    // legenda del contrassegno "SOLO BLOCCATO"
    AddLockBadge(170, Y + 7);
    AddLabel(296, Y + 8, ClientWidth - 296 - 300, Tr('setup.badge.legend', 'funziona solo con il layout ' +
        'bloccato (Ctrl+Alt+F12); tutto il resto vale sia bloccato sia sbloccato'), 10);
    AddButton(ClientWidth - 290, Y, 130, Tr('setup.btn.save', 'Salva'), BtnSaveClick);
    AddButton(ClientWidth - 150, Y, 130, Tr('setup.btn.close', 'Chiudi'), BtnCloseClick);

    ShowPage(0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.FillDeviceCombos
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Riempire le combo dei dispositivi in base alla tipologia.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: tastiera/mouse sono sempre "di sistema"; gamepad = slot
//** XInput 1..4; joystick e pulsantiere = id WinMM 0..15 con nome e caratteristiche.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.FillDeviceCombos;
var
    K: TDeviceKind;
    I: Integer;
    C: TComboBox;
begin
    for K := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        C := FRows[K].Device;
        C.Items.BeginUpdate;
        try
            C.Items.Clear;
            case K of
                dkKeyboard, dkMouse:
                    C.Items.Add(Tr('setup.dev.system', 'Sistema (Raw Input)'));
                dkGamepad:
                    for I := 0 to MAX_PADS - 1 do
                        if FInput.XInputAvailable then
                            C.Items.Add(Format(Tr('setup.dev.xinput', 'XInput %d'), [I + 1]))
                        else
                            C.Items.Add(Format(Tr('setup.dev.xinput.na', 'XInput %d (XInput non disponibile)'), [I + 1]));
            else
                for I := 0 to MAX_JOY - 1 do
                    if FJoys[I].Present then
                        C.Items.Add(Format(Tr('setup.dev.joy', 'ID %d - %s (%d assi, %d puls.)'),
                            [I, FJoys[I].Name, FJoys[I].NumAxes, FJoys[I].NumButtons]))
                    else
                        C.Items.Add(Format(Tr('setup.dev.joy.none', 'ID %d - non collegato'), [I]));
            end;
        finally
            C.Items.EndUpdate;
        end;
        C.ItemIndex := EnsureRange(FConfig.Widgets[K].DeviceIndex, 0, C.Items.Count - 1);
        C.Enabled := not (K in [dkKeyboard, dkMouse]);
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.LoadValues
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Copiare i valori della configurazione nei controlli.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.LoadValues;
var
    K: TDeviceKind;
    I: Integer;
    W: TWidgetConfig;
begin
    FLoading := True;
    try
    FSkin.ItemIndex := Max(0, SkinIndexOf(FConfig.SkinId));
    FLang.ItemIndex := -1;
    for I := 0 to High(FLangs) do
        if SameText(FLangs[I].Id, FConfig.Language) then
            FLang.ItemIndex := I;
    FLayout.ItemIndex := Ord(FConfig.Layout);
    FMargin.Value := FConfig.Margin;
    FSpacing.Value := FConfig.Spacing;
    FMouseRange.Value := FConfig.MouseRange;
    FWidgetStyle.ItemIndex := Ord(FConfig.WidgetStyle);
    FBaseEffects.IsChecked := FConfig.BaseEffects;
    FAutoHide.IsChecked := FConfig.AutoHide;
    FAutoHideSecs.Value := FConfig.AutoHideSecs;
    FCheckUpdates.IsChecked := FConfig.CheckUpdates;
    AutoHideChange(nil);
    FLegends.IsChecked := FConfig.ShowLegends;
    FOnTop.IsChecked := FConfig.StayOnTop;
    FStartLocked.IsChecked := FConfig.StartLocked;
    FStreamer.IsChecked := FConfig.StreamerMode;
    FPrivacy.IsChecked := FConfig.PrivacyMode;
    FOpacity.Value := Round(FConfig.Opacity * 100);
    FObsPort.Value := FConfig.ObsPort;
    FObsWidth.Value := FConfig.ObsWidth;
    FObsHeight.Value := FConfig.ObsHeight;
    FObsHide.ItemIndex := EnsureRange(FConfig.ObsHideMode, OBS_HIDE_WINDOW, OBS_HIDE_MONITOR);
    FObsAuto.IsChecked := FConfig.ObsAutoStart;
    FObsFps.ItemIndex := High(OBS_FPS_CHOICES);
    for I := High(OBS_FPS_CHOICES) downto 0 do
        if FConfig.ObsFps <= OBS_FPS_CHOICES[I] then
            FObsFps.ItemIndex := I;
    FObsMonitor.ItemIndex := 0;
    for I := 0 to High(FObsMonitors) do
        if SameText(FObsMonitors[I].Device, FConfig.ObsMonitor) then
            FObsMonitor.ItemIndex := I;
    ObsHideChange(nil);
    UpdateObsUrl;

    for K := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        W := FConfig.Widgets[K];
        FRows[K].Visible.IsChecked := W.Visible;
        FRows[K].Model.ItemIndex := -1;
        for I := 0 to High(FRows[K].Models) do
            if SameText(FRows[K].Models[I].ModelId, W.ModelId) then
                FRows[K].Model.ItemIndex := I;
        if (FRows[K].Model.ItemIndex < 0) and (FRows[K].Model.Items.Count > 0) then
            FRows[K].Model.ItemIndex := 0;
        FRows[K].X.Value := W.X;
        FRows[K].Y.Value := W.Y;
        FRows[K].W.Value := W.W;
        FRows[K].H.Value := W.H;
        FRows[K].Axes.Text := Format('%d,%d,%d', [W.AxisX, W.AxisY, W.AxisZ]);
        FRows[K].Offset.Value := W.ButtonOffset + 1;
        if FRows[K].RangeX <> nil then
        begin
            FRows[K].RangeX.Value := W.RangeX;
            FRows[K].RangeY.Value := W.RangeY;
            FRows[K].RangeZ.Value := W.RangeZ;
            FRows[K].InvX.ItemIndex := Ord(W.InvertX);
            FRows[K].InvY.ItemIndex := Ord(W.InvertY);
            FRows[K].InvZ.ItemIndex := Ord(W.InvertZ);
        end;
    end;
    FillDeviceCombos;
    for K := Low(TDeviceKind) to High(TDeviceKind) do
        UpdateRowState(K);
    UpdateRangeInfo;
    ApplyColors;
    finally
        FLoading := False;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.ReadValues
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Copiare i valori dei controlli nella configurazione.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: converte il campo testuale degli assi ("0,1,3") ignorando
//** i valori non validi; l'inversione viene dai dropdown della pagina Ampiezza.
//** I campi numerici si leggono con NumValue (testo scritto, anche se non
//** ancora confermato con Invio).
//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: NumValue
//** Parametri di ingresso: ABox: TNumberBox
//** Parametri di uscita: Result: Single
//** Scopo: Valore di un campo numerico come lo vede l'utente, anche se non e' ancora stato
//**        confermato.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: TNumberBox aggiorna Value solo quando il campo perde il
//** fuoco o si preme Invio; i pulsanti del Setup non prendono il fuoco, quindi
//** premendo Salva subito dopo aver scritto un numero si leggerebbe il valore
//** vecchio (o quello intermedio, ad esempio il minimo dopo aver cancellato il
//** testo). Si legge quindi il testo del campo, riportato tra Min e Max; se
//** non e' un numero valido si usa Value.
//***********************************************************************************************************
//***********************************************************************************************************
function NumValue(ABox: TNumberBox): Single;
var
    V: Double;
begin
    if TryStrToFloat(Trim(ABox.Text), V) then
        Result := EnsureRange(V, ABox.Min, ABox.Max)
    else
        Result := ABox.Value;
end;

//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.ReadValues;
var
    K: TDeviceKind;
    W: TWidgetConfig;
    Parts: TArray<string>;
begin
    if FSkin.ItemIndex >= 0 then
        FConfig.SkinId := SkinByIndex(FSkin.ItemIndex).Id;
    if FLang.ItemIndex >= 0 then
        FConfig.Language := FLangs[FLang.ItemIndex].Id;
    // con un layout predefinito le posizioni vengono ricalcolate all'applicazione
    FConfig.SetLayout(TLayoutMode(EnsureRange(FLayout.ItemIndex, 0, Ord(High(TLayoutMode)))));
    FConfig.Margin := Round(NumValue(FMargin));
    FConfig.Spacing := Round(NumValue(FSpacing));
    FConfig.MouseRange := Round(NumValue(FMouseRange));
    if FWidgetStyle.ItemIndex >= 0 then
        FConfig.WidgetStyle := TWidgetStyle(EnsureRange(FWidgetStyle.ItemIndex, 0, Ord(High(TWidgetStyle))));
    FConfig.BaseEffects := FBaseEffects.IsChecked;
    FConfig.AutoHide := FAutoHide.IsChecked;
    FConfig.AutoHideSecs := EnsureRange(Round(NumValue(FAutoHideSecs)), AUTOHIDE_MIN, AUTOHIDE_MAX);
    FConfig.CheckUpdates := FCheckUpdates.IsChecked;
    FConfig.ShowLegends := FLegends.IsChecked;
    FConfig.StayOnTop := FOnTop.IsChecked;
    FConfig.StartLocked := FStartLocked.IsChecked;
    FConfig.StreamerMode := FStreamer.IsChecked;
    FConfig.PrivacyMode := FPrivacy.IsChecked;
    FConfig.Opacity := FOpacity.Value / 100;
    FConfig.ObsPort := EnsureRange(Round(NumValue(FObsPort)), OBS_PORT_MIN, OBS_PORT_MAX);
    FConfig.ObsWidth := EnsureRange(Round(NumValue(FObsWidth)), OBS_SIZE_MIN, OBS_SIZE_MAX);
    FConfig.ObsHeight := EnsureRange(Round(NumValue(FObsHeight)), OBS_SIZE_MIN, OBS_SIZE_MAX);
    if FObsHide.ItemIndex >= 0 then
        FConfig.ObsHideMode := FObsHide.ItemIndex;
    if FObsFps.ItemIndex >= 0 then
        FConfig.ObsFps := OBS_FPS_CHOICES[FObsFps.ItemIndex];
    FConfig.ObsAutoStart := FObsAuto.IsChecked;
    // senza altri monitor la finestra va fuori dallo schermo
    if (FConfig.ObsHideMode = OBS_HIDE_MONITOR) and (Length(FObsMonitors) = 0) then
        FConfig.ObsHideMode := OBS_HIDE_OFFSCREEN;
    if (FObsMonitor.ItemIndex >= 0) and (FObsMonitor.ItemIndex <= High(FObsMonitors)) then
        FConfig.ObsMonitor := FObsMonitors[FObsMonitor.ItemIndex].Device;

    for K := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        W := FConfig.Widgets[K];
        W.Visible := FRows[K].Visible.IsChecked;
        if FRows[K].Model.ItemIndex >= 0 then
            W.ModelId := FRows[K].Models[FRows[K].Model.ItemIndex].ModelId;
        if FRows[K].Device.Enabled and (FRows[K].Device.ItemIndex >= 0) then
            W.DeviceIndex := FRows[K].Device.ItemIndex;
        W.X := Round(NumValue(FRows[K].X));
        W.Y := Round(NumValue(FRows[K].Y));
        W.W := Round(NumValue(FRows[K].W));
        W.H := Round(NumValue(FRows[K].H));
        Parts := FRows[K].Axes.Text.Split([',', ';', ' '], TStringSplitOptions.ExcludeEmpty);
        if Length(Parts) >= 3 then
        begin
            W.AxisX := EnsureRange(StrToIntDef(Parts[0], W.AxisX), 0, 5);
            W.AxisY := EnsureRange(StrToIntDef(Parts[1], W.AxisY), 0, 5);
            W.AxisZ := EnsureRange(StrToIntDef(Parts[2], W.AxisZ), 0, 5);
        end;
        W.ButtonOffset := EnsureRange(Round(NumValue(FRows[K].Offset)) - 1, 0, 31);
        if FRows[K].RangeX <> nil then
        begin
            W.RangeX := EnsureRange(Round(NumValue(FRows[K].RangeX)), JOY_RANGE_MIN, JOY_RANGE_MAX);
            W.RangeY := EnsureRange(Round(NumValue(FRows[K].RangeY)), JOY_RANGE_MIN, JOY_RANGE_MAX);
            W.RangeZ := EnsureRange(Round(NumValue(FRows[K].RangeZ)), JOY_RANGE_MIN, JOY_RANGE_MAX);
            W.InvertX := FRows[K].InvX.ItemIndex = 1;
            W.InvertY := FRows[K].InvY.ItemIndex = 1;
            W.InvertZ := FRows[K].InvZ.ItemIndex = 1;
        end;
        FConfig.Widgets[K] := W;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.UpdateRowState
//** Parametri di ingresso: AKind: TDeviceKind
//** Parametri di uscita: nessuno
//** Scopo: Abilitare solo i campi pertinenti di una riga.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: X/Y solo con il layout Personalizzato; assi, ampiezza e
//** inversione del movimento (pagina Ampiezza) per joystick e manette; primo
//** pulsante per pulsantiere e manette; tutto grigio se il widget non e'
//** visibile. Con la modalita' privacy la riga della tastiera e' completamente
//** bloccata (si riattiva solo spegnendo la modalita').
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.UpdateRowState(AKind: TDeviceKind);
var
    R: TWidgetRow;
    IsOn, Locked: Boolean;
begin
    R := FRows[AKind];
    Locked := (AKind = dkKeyboard) and FPrivacy.IsChecked;
    R.Visible.Enabled := not Locked;
    if Locked then
        R.Visible.Text := KindText(AKind) + Tr('setup.dev.privacysuffix', ' (PRIVACY)')
    else
        R.Visible.Text := KindText(AKind);
    IsOn := R.Visible.IsChecked and not Locked;
    R.Model.Enabled := IsOn;
    R.Device.Enabled := IsOn and not (AKind in [dkKeyboard, dkMouse]);
    R.X.Enabled := IsOn and (FLayout.ItemIndex = Ord(lmCustom));
    R.Y.Enabled := IsOn and (FLayout.ItemIndex = Ord(lmCustom));
    R.W.Enabled := IsOn;
    R.H.Enabled := IsOn;
    R.Axes.Enabled := IsOn and (AKind in [dkJoyLeft, dkJoyRight, dkThrLeft, dkThrRight]);
    R.Offset.Enabled := IsOn and (AKind in [dkBoxLeft, dkBoxRight, dkThrLeft, dkThrRight]);
    if R.RangeX <> nil then
    begin
        R.RangeX.Enabled := IsOn;
        R.RangeY.Enabled := IsOn;
        R.RangeZ.Enabled := IsOn;
        R.InvX.Enabled := IsOn;
        R.InvY.Enabled := IsOn;
        R.InvZ.Enabled := IsOn;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.ApplyColors
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Colorare il setup con la skin selezionata (anteprima immediata).
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.ApplyColors;
var
    T: TPresentedTextControl;
    B: THoloButton;
    Fr: THoloFrame;
    Cls: TSkinClass;
begin
    Cls := SkinByIndex(FSkin.ItemIndex);
    if Cls <> nil then
        FColors := Cls.Colors
    else
        FColors := DefaultSkinColors;
    Fill.Kind := TBrushKind.Solid;
    Fill.Color := WithAlpha(MixColors(FColors.PanelBack, TAlphaColors.Black, 0.35), $FF);
    for T in FTexts do
        T.TextSettings.FontColor := FColors.Text;
    for B in FButtons do
        B.SetColors(FColors);
    for Fr in FFrames do
        Fr.SetColors(FColors);
    if FDossier <> nil then
        FDossier.SetColors(FColors);
    if FInfoCard <> nil then
        FInfoCard.SetColors(FColors);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.SkinChange
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Applicare subito i colori della skin scelta alla finestra di Setup.
//** Data Ultima Modifica: 02/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.SkinChange(Sender: TObject);
begin
    ApplyColors;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.LangChange
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Cambiare la lingua dell'interfaccia dalla pagina Generale.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: raccoglie tutti i valori del setup nella configurazione di
//** lavoro (lingua compresa) e chiude con mrRetry: la finestra principale
//** carica la nuova lingua e riapre il setup, che mostra i testi tradotti
//** senza perdere le modifiche non ancora salvate.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.LangChange(Sender: TObject);
begin
    if FLoading or (FLang.ItemIndex < 0) then
        Exit;
    ReadValues;
    ModalResult := mrRetry;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.RowChange
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Aggiornare lo stato dei campi quando cambia una casella di spunta.
//** Data Ultima Modifica: 02/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.RowChange(Sender: TObject);
var
    K: TDeviceKind;
begin
    for K := Low(TDeviceKind) to High(TDeviceKind) do
        UpdateRowState(K);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.LayoutChange
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Cambiando layout, abilitare/disabilitare le coordinate X/Y.
//** Data Ultima Modifica: 22/10/2026
//***********************************************************************************************************
//** Funzionamento: le posizioni vere vengono ricalcolate quando si preme
//** Salva (layout predefiniti); con Personalizzato si parte dalle posizioni
//** attuali, modificabili nei campi X/Y.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.LayoutChange(Sender: TObject);
var
    K: TDeviceKind;
begin
    for K := Low(TDeviceKind) to High(TDeviceKind) do
        UpdateRowState(K);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.LegendsChange
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiedere conferma prima di attivare le legende sui tasti.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: solo quando la casella viene ATTIVATA dall'utente (non
//** durante il caricamento dei valori e non quando la si disattiva) mostra un
//** avviso con lo stile della skin scelta: Ok lascia l'opzione attiva,
//** Annulla la rimette disattiva. FInLegendsPrompt evita che il cambio di
//** stato fatto qui richiami di nuovo l'avviso.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.LegendsChange(Sender: TObject);
begin
    if FLoading or FInLegendsPrompt or not FLegends.IsChecked then
        Exit;
    FInLegendsPrompt := True;
    try
        if not HoloConfirm(Tr('setup.legends.title', 'Legende sui tasti'), Tr('setup.legends.text',
            'Le legende aggiungono molte scritte 3D ai widget (tastiera, gamepad, ' +
            'pulsantiere) e possono rallentare l''overlay, in particolare durante lo ' +
            'spostamento dei widget.' + sLineBreak + sLineBreak +
            'Vuoi attivarle comunque?'), FColors) then
            FLegends.IsChecked := False;
    finally
        FInLegendsPrompt := False;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.AutoHideChange
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Abilitare il campo dei secondi solo con "Nascondi i widget inattivi" attivo.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.AutoHideChange(Sender: TObject);
begin
    FAutoHideSecs.Enabled := FAutoHide.IsChecked;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.ModelChange
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Quando l'utente sceglie un altro modello, proporre la mappatura assi suggerita dal
//**        modello (es. joystick Virpil: "0,1,2"; senza suggerimento: "0,1,3").
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: ignorato durante il caricamento dei valori, per non
//** sovrascrivere la mappatura salvata nel .ini.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.ModelChange(Sender: TObject);
var
    K: TDeviceKind;
    C: TComboBox;
    Axes: string;
begin
    if FLoading then
        Exit;
    C := Sender as TComboBox;
    K := TDeviceKind(C.Tag);
    if (C.ItemIndex < 0) or (C.ItemIndex > High(FRows[K].Models)) then
        Exit;
    Axes := FRows[K].Models[C.ItemIndex].DefaultAxes;
    if Axes = '' then
        Axes := '0,1,3';
    if K in [dkJoyLeft, dkJoyRight, dkThrLeft, dkThrRight] then
        FRows[K].Axes.Text := Axes;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnSaveClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Confermare (la form principale applica e salva su .ini).
//** Data Ultima Modifica: 02/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnSaveClick(Sender: TObject);
begin
    ReadValues;
    ModalResult := mrOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnCloseClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiudere il Setup senza applicare le modifiche (pulsante "Chiudi").
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: con mrCancel la finestra principale scarta la copia della
//** configurazione su cui lavora il Setup: nulla viene applicato ne' salvato e
//** la lingua torna quella salvata.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnCloseClick(Sender: TObject);
begin
    ModalResult := mrCancel;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnDefaultsClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Ripristinare skin, layout, dimensioni e vista predefiniti (non salvati finche' non si
//**        preme Salva).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//** Funzionamento: prima raccoglie le altre modifiche fatte nel setup (per non
//** perderle), poi riporta la skin RSI (l'anteprima dei colori del setup si
//** aggiorna subito), lo stile dei widget a pannello con effetti di base,
//** layout Orizzontale (Basso), margine, spaziatura e
//** dimensioni iniziali di tutti i widget e la vista predefinita dei modelli
//** (annulla le rotazioni fatte con il tasto destro e lo zoom fatto con la
//** rotella), e aggiorna i campi.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnDefaultsClick(Sender: TObject);
begin
    ReadValues;
    FConfig.ResetLayoutDefaults;
    LoadValues;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnRangeDefaultsClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Riportare l'ampiezza del movimento dei due joystick e delle due manette ai valori
//**        predefiniti (non salvati finche' non si preme Salva).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: aggiorna solo i campi della pagina Ampiezza; il valore passa
//** alla configurazione con ReadValues, quando si preme Salva.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnRangeDefaultsClick(Sender: TObject);
var
    K: TDeviceKind;
begin
    for K in [dkJoyLeft, dkJoyRight] do
    begin
        FRows[K].RangeX.Value := DEF_RANGE_X;
        FRows[K].RangeY.Value := DEF_RANGE_Y;
        FRows[K].RangeZ.Value := DEF_RANGE_Z;
    end;
    for K in [dkThrLeft, dkThrRight] do
    begin
        FRows[K].RangeX.Value := DEF_THR_LEVER;
        FRows[K].RangeY.Value := DEF_THR_MINI;
        FRows[K].RangeZ.Value := DEF_THR_MINI;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.RangeChange
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Aggiornare il riepilogo delle ampiezze quando cambia un campo della pagina Ampiezza.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.RangeChange(Sender: TObject);
begin
    UpdateRangeInfo;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.UpdateRangeInfo
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Scrivere nella pagina Ampiezza le ampiezze (e le inversioni) attuali dei due joystick.
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: legge i campi della pagina Ampiezza (non ancora salvati) e
//** per ogni asse mostra l'ampiezza totale, l'angolo massimo a fine corsa (meta')
//** e se l'asse e' invertito.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.UpdateRangeInfo;
var
    K: TDeviceKind;
    Info: string;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: Axis
    //** Parametri di ingresso: AName: string; ABox: TNumberBox; AInv: TComboBox
    //** Parametri di uscita: Result: string
    //** Scopo: Testo dell'ampiezza di un asse per il riepilogo (es. "X 36 gradi (+/-18)", con
    //**        " invertito" se l'asse e' invertito).
    //** Data Ultima Modifica: 04/11/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function Axis(const AName: string; ABox: TNumberBox; AInv: TComboBox): string;
    var
        D: Integer;
    begin
        D := Round(ABox.Value);
        Result := Format('%s %d' + #$00B0 + ' (' + #$00B1 + '%s' + #$00B0 + ')',
            [AName, D, FormatFloat('0.#', D / 2)]);
        if AInv.ItemIndex = 1 then
            Result := Result + Tr('setup.amp.inverted', ' invertito');
    end;

begin
    if (FRangeInfo = nil) or (FRows[dkJoyLeft].RangeX = nil) or (FRows[dkJoyRight].RangeX = nil) then
        Exit;
    Info := '';
    for K in [dkJoyLeft, dkJoyRight] do
    begin
        if Info <> '' then
            Info := Info + sLineBreak;
        Info := Info + KindText(K) + ':   ' + Axis('X', FRows[K].RangeX, FRows[K].InvX) + '   ' +
            Axis('Y', FRows[K].RangeY, FRows[K].InvY) + '   ' + Axis('Z', FRows[K].RangeZ, FRows[K].InvZ);
    end;
    FRangeInfo.Text := Info;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnUpdateClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiudere il Setup e chiedere alla finestra principale di controllare gli aggiornamenti.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: come i pulsanti del servizio OBS, applica e salva le
//** modifiche fatte nel Setup (mrOk); il controllo, l'eventuale download con
//** la barra di progresso e il riavvio li esegue la finestra principale.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnUpdateClick(Sender: TObject);
begin
    ReadValues;
    FUpdateRequested := True;
    ModalResult := mrOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnDossierClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Aprire il Citizen Dossier dell'autore nel browser.
//** Data Ultima Modifica: 26/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnDossierClick(Sender: TObject);
begin
    OpenUrl(DOSSIER_URL);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.SetObsState
//** Parametri di ingresso: ARunning: Boolean; AStatus: string
//** Parametri di uscita: nessuno
//** Scopo: Mostrare nella pagina OBS lo stato del servizio (chiamata prima di ShowModal).
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: "Avvia il servizio" e' attivo solo con il servizio fermo,
//** "Ferma il servizio" solo con il servizio attivo (il pulsante non
//** disponibile e' attenuato); con il servizio attivo il Setup si apre
//** direttamente sulla pagina OBS. La cornice "Stato del servizio" e' verde tenue
//** con il servizio attivo e rosso sbiadito con il servizio fermo. Viene
//** richiamata anche dopo il riavvio per il cambio degli FPS (ObsFpsChange).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.SetObsState(ARunning: Boolean; const AStatus: string);
const
    OFF_OPACITY = 0.35;   // pulsante non disponibile
begin
    FObsRunning := ARunning;
    FObsStatus.Text := AStatus;
    if ARunning then
        FObsStateFrame.SetStateColor(OBS_ON_COLOR)
    else
        FObsStateFrame.SetStateColor(OBS_OFF_COLOR);
    FObsBtnStart.Enabled := not ARunning;
    FObsBtnStop.Enabled := ARunning;
    if ARunning then
    begin
        FObsBtnStart.Opacity := OFF_OPACITY;
        FObsBtnStop.Opacity := 1;
        ShowPage(5);
    end
    else
    begin
        FObsBtnStart.Opacity := 1;
        FObsBtnStop.Opacity := OFF_OPACITY;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.ObsFpsChange
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Con il servizio OBS attivo, fermarlo e riavviarlo subito con i nuovi fotogrammi al secondo.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: ignorato durante il caricamento dei valori, con il servizio
//** fermo (allora gli FPS valgono al prossimo avvio, dopo Salva) e se il valore
//** non cambia. Prima mostra un avviso (HoloConfirm) che dice che il servizio
//** verra' fermato e riavviato: con Annulla il menu torna agli FPS in uso
//** (FInFpsPrompt evita che il ripristino richiami l'avviso). Con Riavvia
//** aggiorna la copia della configurazione e chiede alla finestra principale
//** (OnObsFpsChange) di fermare e riavviare il servizio: il cambio e' applicato
//** e salvato subito, anche se poi il Setup si chiude con Chiudi. Lo stato
//** mostrato nella pagina OBS viene aggiornato dalla finestra principale
//** (SetObsState).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.ObsFpsChange(Sender: TObject);
var
    Fps, I: Integer;
begin
    if FLoading or FInFpsPrompt or not FObsRunning or (FObsFps.ItemIndex < 0) then
        Exit;
    Fps := OBS_FPS_CHOICES[FObsFps.ItemIndex];
    if Fps = FConfig.ObsFps then
        Exit;
    FInFpsPrompt := True;
    try
        if not HoloConfirm(Tr('setup.obs.fps.restart.title', 'Riavvio del servizio OBS'),
            Format(Tr('setup.obs.fps.restart.text', 'Il servizio OBS e'' attivo: per passare a %d fps ' +
            'verra'' fermato e riavviato subito (OBS si ricollega da solo). Imposta gli stessi fps ' +
            'nella fonte Browser di OBS.' + sLineBreak + sLineBreak + 'Riavviare il servizio?'), [Fps]),
            FColors,
            Tr('setup.obs.fps.restart.ok', 'Riavvia')) then
        begin
            // Annulla: il menu torna agli FPS in uso
            for I := 0 to High(OBS_FPS_CHOICES) do
                if OBS_FPS_CHOICES[I] = FConfig.ObsFps then
                    FObsFps.ItemIndex := I;
            Exit;
        end;
    finally
        FInFpsPrompt := False;
    end;
    FConfig.ObsFps := Fps;
    if Assigned(FOnObsFpsChange) then
        FOnObsFpsChange(Self, Fps);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.UpdateObsUrl
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Aggiornare l'indirizzo per OBS in base alla porta scelta.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.UpdateObsUrl;
begin
    FObsUrl.Text := ObsUrl(Round(FObsPort.Value));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.ObsPortChange
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Aggiornare l'indirizzo per OBS quando cambia la porta.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.ObsPortChange(Sender: TObject);
begin
    UpdateObsUrl;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.ObsHideChange
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Abilitare la scelta del monitor solo con "Sposta la finestra su un altro monitor".
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.ObsHideChange(Sender: TObject);
begin
    FObsMonitor.Enabled := (FObsHide.ItemIndex = OBS_HIDE_MONITOR) and (Length(FObsMonitors) > 0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnObsNativeClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Riportare la risoluzione del servizio OBS a quella nativa del monitor principale.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnObsNativeClick(Sender: TObject);
var
    S: TSize;
begin
    S := NativeScreenSize;
    FObsWidth.Value := S.cx;
    FObsHeight.Value := S.cy;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnObsCopyClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Copiare negli appunti l'indirizzo da inserire nel Browser Source di OBS.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnObsCopyClick(Sender: TObject);
var
    Svc: IFMXClipboardService;
begin
    if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Svc) then
        Svc.SetClipboard(TValue.From<string>(FObsUrl.Text));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnObsStartClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiedere alla finestra principale di avviare il servizio OBS (con i parametri del
//**        Setup, che vengono applicati e salvati).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnObsStartClick(Sender: TObject);
begin
    if not FObsBtnStart.Enabled then
        Exit;
    ReadValues;
    FObsAction := oaStart;
    ModalResult := mrOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnObsStopClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiedere alla finestra principale di fermare il servizio OBS (le modifiche del Setup
//**        vengono applicate e salvate).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnObsStopClick(Sender: TObject);
begin
    if not FObsBtnStop.Enabled then
        Exit;
    ReadValues;
    FObsAction := oaStop;
    ModalResult := mrOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnScanClick
//** Parametri di ingresso: Sender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Azzerare il log ed eseguire una nuova scansione dei dispositivi (pulsante "Esegui
//**        scansione" della pagina Log).
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//** Funzionamento: raccoglie prima le modifiche fatte nel setup (per non
//** perderle), svuota il log, esegue la scansione e aggiorna le combo dei
//** dispositivi con l'elenco appena letto.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnScanClick(Sender: TObject);
var
    K: TDeviceKind;
begin
    ReadValues;
    FLog.Lines.Clear;
    RunScan;
    FillDeviceCombos;
    for K := Low(TDeviceKind) to High(TDeviceKind) do
        UpdateRowState(K);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.LogLine
//** Parametri di ingresso: S: string
//** Parametri di uscita: nessuno
//** Scopo: Aggiungere una riga in fondo al log della pagina Log.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.LogLine(const S: string);
begin
    FLog.Lines.Add(S);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.RunScan
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Eseguire la scansione dei dispositivi e scriverne il resoconto nel log.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: legge i 16 id WinMM (joystick e pulsantiere, con nome, assi,
//** pulsanti e POV), interroga i 4 slot XInput (gamepad), ricorda che tastiera e
//** mouse sono di sistema, poi controlla i widget visibili: per ognuno indica il
//** dispositivo assegnato e segnala con ATTENZIONE quelli non collegati.
//** Aggiorna FJoys, usato dalle combo della pagina Dispositivi.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.RunScan;
var
    I, NJoy, NPad: Integer;
    K: TDeviceKind;
    W: TWidgetConfig;
    PadOn: array[0..MAX_PADS - 1] of Boolean;
    Pov, Res: string;
begin
    FLog.Lines.BeginUpdate;
    try
        LogLine(Format(Tr('log.start', '[%s] Avvio scansione dispositivi'), [FormatDateTime('hh:nn:ss', Now)]));
        LogLine('');

        // joystick e pulsantiere: id WinMM 0..15
        LogLine(Format(Tr('log.joy.header', 'JOYSTICK E PULSANTIERE (WinMM, ID 0-%d)'), [MAX_JOY - 1]));
        FJoys := FInput.EnumJoysticks;
        NJoy := 0;
        for I := 0 to High(FJoys) do
            if FJoys[I].Present then
            begin
                Inc(NJoy);
                if FJoys[I].HasPOV then
                    Pov := Tr('log.yes', 'si''')
                else
                    Pov := Tr('log.no', 'no');
                LogLine(Format(Tr('log.joy.item', '    ID %2d   %s  -  %d assi, %d pulsanti, POV %s'),
                    [I, FJoys[I].Name, FJoys[I].NumAxes, FJoys[I].NumButtons, Pov]));
                // lettura in background (Raw Input HID) e assi HID usati per X Y Z R U V
                if FJoys[I].Background then
                    LogLine(Format(Tr('log.joy.hid',
                        '             letto anche in background (HID)  -  assi X Y Z R U V = %s'),
                        [FJoys[I].BgAxes]))
                else
                    LogLine(Tr('log.joy.nohid',
                        '             nessun dispositivo HID abbinato: aggiornato solo con HoloInput in primo piano'));
            end
            else
                LogLine(Format(Tr('log.joy.none', '    ID %2d   non collegato'), [I]));
        LogLine(Format(Tr('log.joy.count', '    Rilevati: %d su %d'), [NJoy, MAX_JOY]));
        LogLine(Tr('log.joy.note', '    Nota: WinMM gestisce max 32 pulsanti e 6 assi per dispositivo.'));
        LogLine('');

        // gamepad: slot XInput 1..4
        LogLine(Tr('log.pad.header', 'GAMEPAD (XInput)'));
        NPad := 0;
        for I := 0 to MAX_PADS - 1 do
        begin
            PadOn[I] := FInput.PadConnected(I);
            if PadOn[I] then
                Inc(NPad);
        end;
        if FInput.XInputAvailable then
        begin
            LogLine(Tr('log.pad.lib', '    Libreria XInput: disponibile'));
            for I := 0 to MAX_PADS - 1 do
                if PadOn[I] then
                    LogLine(Format(Tr('log.pad.on', '    XInput %d   collegato'), [I + 1]))
                else
                    LogLine(Format(Tr('log.pad.off', '    XInput %d   non collegato'), [I + 1]));
        end
        else
            LogLine(Tr('log.pad.nolib', '    Libreria XInput: NON disponibile (i gamepad non possono essere letti)'));
        LogLine('');

        LogLine(Tr('log.kbm.header', 'TASTIERA E MOUSE'));
        LogLine(Tr('log.kbm.text', '    Sistema (Raw Input): sempre disponibili'));
        LogLine('');

        // widget visibili e dispositivo assegnato
        LogLine(Tr('log.widgets.header', 'WIDGET VISIBILI'));
        for K := Low(TDeviceKind) to High(TDeviceKind) do
        begin
            W := FConfig.Widgets[K];
            if not W.Visible then
                Continue;
            case K of
                dkKeyboard, dkMouse:
                    begin
                        Res := Tr('log.widgets.system', 'Sistema (Raw Input)  -  OK');
                        if (K = dkKeyboard) and FConfig.PrivacyMode then
                            Res := Res + Tr('log.widgets.privacy', ' (nascosta: modalita'' privacy attiva)');
                    end;
                dkGamepad:
                    begin
                        I := EnsureRange(W.DeviceIndex, 0, MAX_PADS - 1);
                        if not FInput.XInputAvailable then
                            Res := Format(Tr('log.widgets.pad.nolib', 'XInput %d  -  ATTENZIONE: XInput non disponibile'), [I + 1])
                        else if PadOn[I] then
                            Res := Format(Tr('log.widgets.pad.ok', 'XInput %d  -  OK'), [I + 1])
                        else
                            Res := Format(Tr('log.widgets.pad.none', 'XInput %d  -  ATTENZIONE: nessun gamepad collegato'), [I + 1]);
                    end;
            else
                I := EnsureRange(W.DeviceIndex, 0, MAX_JOY - 1);
                if FJoys[I].Present then
                    Res := Format(Tr('log.widgets.joy.ok', 'ID %d  %s  -  OK'), [I, FJoys[I].Name])
                else
                    Res := Format(Tr('log.widgets.joy.none', 'ID %d  -  ATTENZIONE: dispositivo non collegato'), [I]);
            end;
            LogLine(Format('    %-16s %s', [KindText(K), Res]));
        end;
        LogLine('');
        LogLine(Format(Tr('log.end', '[%s] Scansione completata: %d joystick/pulsantiere, %d gamepad.'),
            [FormatDateTime('hh:nn:ss', Now), NJoy, NPad]));
    finally
        FLog.Lines.EndUpdate;
    end;
end;

end.
