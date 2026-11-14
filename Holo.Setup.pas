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
//**               stato e pulsanti "Avvia il servizio" / "Ferma il servizio" (eObsAction dice
//**               alla finestra principale cosa fare dopo la chiusura);
//**   INFO        Citizen Dossier dell'autore e informazioni sul software;
//**               pulsante "Controlla aggiornamenti" (bUpdateRequested) e casella
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
    TObsFpsChangeEvent = procedure(oSender: TObject; iAFps: Integer) of object;

    TWidgetRow = record
        oVisible: TCheckBox;
        oModel: TComboBox;
        oDevice: TComboBox;
        oX, oY, oW, oH: TNumberBox;
        oAxes: TEdit;
        oOffset: TNumberBox;
        oRangeX, oRangeY, oRangeZ: TNumberBox;  // solo joystick (pagina Ampiezza), altrimenti nil
        oInvX, oInvY, oInvZ: TComboBox;         // solo joystick (pagina Ampiezza): 0 = No, 1 = Si
        aModels: TArray<TDeviceModelClass>;
    end;

    TfrmSetup = class(TForm)
    private
        oFConfig: TAppConfig;
        oFInput: TInputManager;
        rFColors: TSkinColors;
        aFJoys: TArray<TJoyDeviceInfo>;
        oFSkin, oFLayout, oFLang: TComboBox;
        aFLangs: TArray<TLangInfo>;              // lingue elencate in oFLang (stesso ordine)
        oFMargin, oFSpacing, oFMouseRange: TNumberBox;
        oFOpacity: TTrackBar;
        oFLegends, oFOnTop, oFStartLocked, oFStreamer, oFPrivacy: TCheckBox;
        oFWidgetStyle: TComboBox;                 // stile dei widget (pannello / solo dispositivo)
        oFBaseEffects: TCheckBox;                 // effetti di base (anelli e scanline)
        oFAutoHide: TCheckBox;                    // nascondi i widget inattivi
        oFAutoHideSecs: TNumberBox;               // secondi di inattivita' prima di nasconderli
        oFCheckUpdates: TCheckBox;                // pagina Info: controlla gli aggiornamenti all'avvio
        bFUpdateRequested: Boolean;               // chiuso con "Controlla aggiornamenti"
        oFPage: TFmxObject;                       // contenitore dei controlli creati da Add*
        aFPages: array[0..6] of TLayout;
        aFPageBtns: array[0..6] of THoloButton;
        oFDossier: THoloDossierCard;
        oFInfoCard: THoloInfoCard;
        iFActivePage: Integer;
        aFRows: array[TDeviceKind] of TWidgetRow;
        oFTexts: TList<TPresentedTextControl>;
        oFButtons: TList<THoloButton>;
        oFFrames: TList<THoloFrame>;              // cornici dei riquadri (colori della skin)
        oFLog: TMemo;                             // log del rilevamento dispositivi (pagina Log)
        oFRangeInfo: TLabel;                      // riepilogo delle ampiezze nella pagina Ampiezza
        bFLoading: Boolean;
        bFInLegendsPrompt: Boolean;
        oFObsPort, oFObsWidth, oFObsHeight: TNumberBox;   // pagina OBS: parametri del servizio
        oFObsHide: TComboBox;                     // pagina OBS: occultamento della finestra
        oFObsFps: TComboBox;                      // pagina OBS: fotogrammi al secondo (OBS_FPS_CHOICES)
        oFObsMonitor: TComboBox;                  // pagina OBS: monitor di destinazione
        aFObsMonitors: TArray<TMonitorDesc>;      // monitor elencati in oFObsMonitor (stesso ordine)
        oFObsUrl, oFObsStatus: TLabel;             // pagina OBS: indirizzo e stato del servizio
        oFObsBtnStart, oFObsBtnStop: THoloButton;
        oFObsStateFrame: THoloFrame;              // pagina OBS: cornice "Stato del servizio" (colore = stato)
        oFObsAuto: TCheckBox;                     // pagina OBS: avvio automatico del servizio
        eFObsAction: TObsAction;                  // azione chiesta alla chiusura (vedi eObsAction)
        bFObsRunning: Boolean;                    // servizio OBS attivo (da SetObsState)
        bFInFpsPrompt: Boolean;                   // avviso di riavvio per il cambio degli FPS aperto
        mFOnObsFpsChange: TObsFpsChangeEvent;     // cambio degli FPS con il servizio attivo
        procedure BuildUI;
        procedure LoadValues;
        procedure ReadValues;
        procedure FillDeviceCombos;
        procedure ApplyColors;
        procedure UpdateRowState(eAKind: TDeviceKind);
        function oAddLabel(dAPosX, dAPosY, dAWidth: Single; const sAText: string; dASize: Single = 12;
            bABold: Boolean = False): TLabel;
        function oAddCheck(dAPosX, dAPosY, dAWidth: Single; const sAText: string): TCheckBox;
        function oAddCombo(dAPosX, dAPosY, dAWidth: Single): TComboBox;
        function oAddNumber(dAPosX, dAPosY, dAWidth: Single; iAMin, iAMax: Integer): TNumberBox;
        function oAddEdit(dAPosX, dAPosY, dAWidth: Single): TEdit;
        function oAddText(dAPosX, dAPosY, dAWidth, dAHeight: Single; const sAText: string): TLabel;
        function oAddFrame(dAPosX, dAPosY, dAWidth, dAHeight: Single): THoloFrame;
        function oAddButton(dAPosX, dAPosY, dAWidth: Single; const sAText: string;
            mAClick: TNotifyEvent): THoloButton;
        function oAddLockBadge(dAPosX, dAPosY: Single): THoloButton;
        procedure SkinChange(oSender: TObject);
        procedure LangChange(oSender: TObject);
        procedure RowChange(oSender: TObject);
        procedure LayoutChange(oSender: TObject);
        procedure LegendsChange(oSender: TObject);
        procedure AutoHideChange(oSender: TObject);
        procedure PageClick(oSender: TObject);
        procedure ShowPage(iAIndex: Integer);
        function oNewPage(iAIndex: Integer; const sACaption: string): TLayout;
        procedure ModelChange(oSender: TObject);
        procedure BtnSaveClick(oSender: TObject);
        procedure BtnCloseClick(oSender: TObject);
        procedure BtnDefaultsClick(oSender: TObject);
        procedure BtnRangeDefaultsClick(oSender: TObject);
        procedure RangeChange(oSender: TObject);
        procedure UpdateRangeInfo;
        procedure BtnScanClick(oSender: TObject);
        procedure DragBarMouseDown(oSender: TObject; eButton: TMouseButton; eShift: TShiftState;
            dAPosX, dAPosY: Single);
        procedure RunScan;
        procedure LogLine(const sAText: string);
        procedure BtnDossierClick(oSender: TObject);
        procedure BtnUpdateClick(oSender: TObject);
        procedure BtnObsNativeClick(oSender: TObject);
        procedure BtnObsCopyClick(oSender: TObject);
        procedure BtnObsStartClick(oSender: TObject);
        procedure BtnObsStopClick(oSender: TObject);
        procedure ObsPortChange(oSender: TObject);
        procedure ObsHideChange(oSender: TObject);
        procedure ObsFpsChange(oSender: TObject);
        procedure UpdateObsUrl;
    public
        constructor CreateSetup(oAOwner: TComponent; oAConfig: TAppConfig; oAInput: TInputManager);
        destructor Destroy; override;
        /// Mostra lo stato del servizio OBS (chiamata dalla finestra principale prima di ShowModal).
        procedure SetObsState(bARunning: Boolean; const sAStatus: string);
        /// Azione sul servizio OBS chiesta con i pulsanti della pagina OBS (oaNone se nessuna).
        property eObsAction: TObsAction read eFObsAction;
        /// True se il Setup e' stato chiuso con "Controlla aggiornamenti" (pagina Info).
        property bUpdateRequested: Boolean read bFUpdateRequested;
        /// Chiamato quando si cambiano gli FPS di OBS con il servizio attivo: la finestra
        /// principale ferma e riavvia subito il servizio con i nuovi FPS.
        property mOnObsFpsChange: TObsFpsChangeEvent read mFOnObsFpsChange write mFOnObsFpsChange;
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
//** Parametri di ingresso: oAOwner: TComponent; oAConfig: TAppConfig; oAInput: TInputManager
//** Parametri di uscita: nuova istanza della classe
//** Scopo: Creare il setup collegato alla copia della configurazione.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: carica il .fmx (form vuota), costruisce i controlli, esegue
//** la prima scansione dei dispositivi (scritta nella pagina Log) e popola i
//** campi con i valori correnti.
//***********************************************************************************************************
//***********************************************************************************************************
constructor TfrmSetup.CreateSetup(oAOwner: TComponent; oAConfig: TAppConfig;
    oAInput: TInputManager);
begin
    inherited Create(oAOwner);
    oFConfig := oAConfig;
    oFInput := oAInput;
    oFTexts := TList<TPresentedTextControl>.Create;
    oFButtons := TList<THoloButton>.Create;
    oFFrames := TList<THoloFrame>.Create;
    Caption := sTr('setup.caption', 'HoloInput - Setup');   // nome nella barra delle applicazioni
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
    oFTexts.Free;
    oFButtons.Free;
    oFFrames.Free;
    inherited;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.DragBarMouseDown
//** Parametri di ingresso: oSender: TObject; eButton: TMouseButton; eShift: TShiftState; dAPosX, dAPosY:
//**                        Single
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
procedure TfrmSetup.DragBarMouseDown(oSender: TObject; eButton: TMouseButton; eShift: TShiftState;
    dAPosX, dAPosY: Single);
begin
    if eButton = TMouseButton.mbLeft then
        StartWindowDrag;
end;

//** Costruttori di controlli *******************************************************************************

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.oAddLabel
//** Parametri di ingresso: dAPosX, dAPosY, dAWidth: Single; sAText: string; dASize: Single; bABold: Boolean
//** Parametri di uscita: Result: TLabel
//** Scopo: Creare un'etichetta con font e colore dell'app (non quelli dello stile).
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: i titoli (grassetto da 12 in su) usano il font olografico
//** HOLO_FONT; tutti gli altri testi usano SETUP_FONT (Segoe UI), piu'
//** leggibile, e non scendono sotto SETUP_MIN_SIZE.
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.oAddLabel(dAPosX, dAPosY, dAWidth: Single; const sAText: string; dASize: Single;
    bABold: Boolean): TLabel;
begin
    Result := TLabel.Create(Self);
    Result.Parent := oFPage;
    Result.SetBounds(dAPosX, dAPosY, dAWidth, 22);
    Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Family,
        TStyledSetting.Size, TStyledSetting.Style, TStyledSetting.FontColor];
    if bABold and (dASize >= 12) then
    begin
        Result.TextSettings.Font.Family := HOLO_FONT;
        Result.TextSettings.Font.Size := dASize;
    end
    else
    begin
        Result.TextSettings.Font.Family := SETUP_FONT;
        Result.TextSettings.Font.Size := Max(dASize, SETUP_MIN_SIZE);
    end;
    if bABold then
        Result.TextSettings.Font.Style := [TFontStyle.fsBold];
    Result.Text := sAText;
    oFTexts.Add(Result);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.oAddCheck
//** Parametri di ingresso: dAPosX, dAPosY, dAWidth: Single; sAText: string
//** Parametri di uscita: Result: TCheckBox
//** Scopo: Creare una casella di spunta con testo (Segoe UI) nel colore dell'app.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.oAddCheck(dAPosX, dAPosY, dAWidth: Single; const sAText: string): TCheckBox;
begin
    Result := TCheckBox.Create(Self);
    Result.Parent := oFPage;
    Result.SetBounds(dAPosX, dAPosY, dAWidth, 22);
    Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Family,
        TStyledSetting.Size, TStyledSetting.FontColor];
    Result.TextSettings.Font.Family := SETUP_FONT;
    Result.TextSettings.Font.Size := 12;
    Result.Text := sAText;
    oFTexts.Add(Result);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.oAddCombo
//** Parametri di ingresso: dAPosX, dAPosY, dAWidth: Single
//** Parametri di uscita: Result: TComboBox
//** Scopo: Creare una combo box.
//** Data Ultima Modifica: 01/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.oAddCombo(dAPosX, dAPosY, dAWidth: Single): TComboBox;
begin
    Result := TComboBox.Create(Self);
    Result.Parent := oFPage;
    Result.SetBounds(dAPosX, dAPosY, dAWidth, 24);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.oAddNumber
//** Parametri di ingresso: dAPosX, dAPosY, dAWidth: Single; iAMin, iAMax: Integer
//** Parametri di uscita: Result: TNumberBox
//** Scopo: Creare un campo numerico intero con limiti.
//** Data Ultima Modifica: 01/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.oAddNumber(dAPosX, dAPosY, dAWidth: Single; iAMin, iAMax: Integer): TNumberBox;
begin
    Result := TNumberBox.Create(Self);
    Result.Parent := oFPage;
    Result.SetBounds(dAPosX, dAPosY, dAWidth, 24);
    Result.DecimalDigits := 0;
    Result.Min := iAMin;
    Result.Max := iAMax;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.oAddEdit
//** Parametri di ingresso: dAPosX, dAPosY, dAWidth: Single
//** Parametri di uscita: Result: TEdit
//** Scopo: Creare un campo di testo.
//** Data Ultima Modifica: 01/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.oAddEdit(dAPosX, dAPosY, dAWidth: Single): TEdit;
begin
    Result := TEdit.Create(Self);
    Result.Parent := oFPage;
    Result.SetBounds(dAPosX, dAPosY, dAWidth, 24);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.oAddText
//** Parametri di ingresso: dAPosX, dAPosY, dAWidth, dAHeight: Single; sAText: string
//** Parametri di uscita: Result: TLabel
//** Scopo: Creare un testo su piu' righe, allineato in alto e a capo automatico.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//** Funzionamento: parte da oAddLabel (font e colore dell'app) e toglie anche
//** l'allineamento dello stile, cosi' il testo comincia subito sotto il titolo
//** invece di essere centrato in verticale nell'area.
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.oAddText(dAPosX, dAPosY, dAWidth, dAHeight: Single; const sAText: string): TLabel;
begin
    Result := oAddLabel(dAPosX, dAPosY, dAWidth, sAText, 10);
    Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Other];
    Result.TextSettings.VertAlign := TTextAlign.Leading;
    Result.TextSettings.HorzAlign := TTextAlign.Leading;
    Result.TextSettings.WordWrap := True;
    Result.Height := dAHeight;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.oAddFrame
//** Parametri di ingresso: dAPosX, dAPosY, dAWidth, dAHeight: Single
//** Parametri di uscita: Result: THoloFrame
//** Scopo: Creare una cornice sottile nei colori della skin attorno a un gruppo di controlli.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.oAddFrame(dAPosX, dAPosY, dAWidth, dAHeight: Single): THoloFrame;
begin
    Result := THoloFrame.Create(Self);
    Result.Parent := oFPage;
    Result.SetBounds(dAPosX, dAPosY, dAWidth, dAHeight);
    oFFrames.Add(Result);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.oAddButton
//** Parametri di ingresso: dAPosX, dAPosY, dAWidth: Single; sAText: string; mAClick: TNotifyEvent
//** Parametri di uscita: Result: THoloButton
//** Scopo: Creare un pulsante con lo stesso stile della barra dell'overlay.
//** Data Ultima Modifica: 01/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.oAddButton(dAPosX, dAPosY, dAWidth: Single; const sAText: string;
    mAClick: TNotifyEvent): THoloButton;
begin
    Result := THoloButton.Create(Self);
    Result.Parent := oFPage;
    Result.SetBounds(dAPosX, dAPosY, dAWidth, 34);
    Result.sText := sAText;
    Result.OnClick := mAClick;
    oFButtons.Add(Result);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.oAddLockBadge
//** Parametri di ingresso: dAPosX, dAPosY: Single
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
function TfrmSetup.oAddLockBadge(dAPosX, dAPosY: Single): THoloButton;
begin
    Result := oAddButton(dAPosX, dAPosY, 118, sTr('setup.badge.locked', 'Solo bloccato'), nil);
    Result.Height := 20;
    Result.bPassive := True;
    Result.bHighlight := True;
    Result.dFontSize := 9;
    Result.HitTest := False;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: TfrmSetup.oNewPage
//** Parametri di ingresso: iAIndex: Integer; sACaption: string
//** Parametri di uscita: Result: TLayout
//** Scopo: Creare una pagina (area che occupa la parte centrale della finestra) e il pulsante che
//**        la seleziona.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
function TfrmSetup.oNewPage(iAIndex: Integer; const sACaption: string): TLayout;
begin
    oFPage := Self;
    aFPageBtns[iAIndex] := oAddButton(20 + iAIndex * PAGE_BTN_STEP, PAGE_BTN_Y, PAGE_BTN_W, sACaption,
        PageClick);
    aFPageBtns[iAIndex].Tag := iAIndex;
    Result := TLayout.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(0, PAGE_TOP, ClientWidth, ClientHeight - PAGE_TOP - 64);
    Result.Visible := False;
    aFPages[iAIndex] := Result;
    oFPage := Result;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.ShowPage
//** Parametri di ingresso: iAIndex: Integer
//** Parametri di uscita: nessuno
//** Scopo: Mostrare una pagina ed evidenziarne il pulsante.
//** Data Ultima Modifica: 24/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.ShowPage(iAIndex: Integer);
var
    iPage: Integer;
begin
    iFActivePage := iAIndex;
    for iPage := 0 to High(aFPages) do
    begin
        aFPages[iPage].Visible := iPage = iAIndex;
        aFPageBtns[iPage].bHighlight := iPage = iAIndex;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.PageClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Mostrare la pagina del Setup associata al pulsante cliccato (Tag).
//** Data Ultima Modifica: 24/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.PageClick(oSender: TObject);
begin
    ShowPage((oSender as THoloButton).Tag);
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
//** contrassegno "SOLO BLOCCATO" (oAddLockBadge), spiegato dalla legenda in basso.
//** I controlli sono creati dentro la pagina corrente (oFPage).
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
    eDevice: TDeviceKind;
    eMode: TLayoutMode;
    iSkin: Integer;
    dPosY, dFormWidth: Single;
    rRow: TWidgetRow;
    aBoxes: array[0..2] of TNumberBox;
    aInvs: array[0..2] of TComboBox;
    oDragBar: TLayout;
begin
    oFPage := Self;
    // finestra senza barra del titolo: cornice attorno a tutta la form
    oAddFrame(0, 0, ClientWidth, ClientHeight);
    oAddLabel(20, 12, 700, sTr('setup.title', 'HOLOINPUT  ' + #$00B7 + '  SETUP'), 20, True).Height := 32;
    // fascia del titolo trasparente: trascinandola si sposta la finestra
    oDragBar := TLayout.Create(Self);
    oDragBar.Parent := Self;
    oDragBar.SetBounds(0, 0, ClientWidth, PAGE_BTN_Y - 4);
    oDragBar.HitTest := True;
    oDragBar.Cursor := crSizeAll;
    oDragBar.OnMouseDown := DragBarMouseDown;

    //** pagina GENERALE ************************************************************************************
    // ogni gruppo di impostazioni sta in un riquadro (cornice creata prima dei controlli)
    oNewPage(0, sTr('setup.page.general', 'Generale'));
    dFormWidth := ClientWidth - 16;
    oAddFrame(8, 0, dFormWidth, 76);
    oAddLabel(20, 10, 300, sTr('setup.gen.look', 'ASPETTO'), 13, True);
    oAddLabel(20, 42, 60, sTr('setup.gen.skin', 'Skin'));
    oFSkin := oAddCombo(70, 40, 210);
    for iSkin := 0 to iSkinCount - 1 do
        oFSkin.Items.Add(oSkinByIndex(iSkin).sDisplayName);
    oFSkin.OnChange := SkinChange;
    oAddLabel(300, 42, 70, sTr('setup.gen.opacity', 'Opacita'''));
    oFOpacity := TTrackBar.Create(Self);
    oFOpacity.Parent := oFPage;
    oFOpacity.SetBounds(370, 42, 250, 22);
    oFOpacity.Min := 20;
    oFOpacity.Max := 100;
    // lingua dell'interfaccia: cambiandola il setup si riapre nella nuova lingua
    oAddLabel(650, 42, 70, sTr('setup.gen.language', 'Lingua'));
    oFLang := oAddCombo(720, 40, 210);
    aFLangs := aAvailableLanguages;
    for iSkin := 0 to High(aFLangs) do
        oFLang.Items.Add(aFLangs[iSkin].sName);
    oFLang.OnChange := LangChange;

    oAddFrame(8, 88, dFormWidth, 76);
    oAddLabel(20, 98, 300, sTr('setup.gen.arrangement', 'DISPOSIZIONE'), 13, True);
    oAddLabel(20, 130, 70, sTr('setup.gen.layout', 'Layout'));
    oFLayout := oAddCombo(80, 128, 200);
    for eMode := Low(TLayoutMode) to High(TLayoutMode) do
        oFLayout.Items.Add(sLayoutText(eMode));
    oFLayout.OnChange := LayoutChange;
    oAddLabel(300, 130, 70, sTr('setup.gen.margin', 'Margine'));
    oFMargin := oAddNumber(370, 128, 65, 0, 500);
    oAddLabel(455, 130, 80, sTr('setup.gen.spacing', 'Spaziatura'));
    oFSpacing := oAddNumber(535, 128, 60, 0, 200);

    oAddFrame(8, 176, dFormWidth, 112);
    oAddLabel(20, 186, 300, sTr('setup.gen.options', 'OPZIONI'), 13, True);
    // le animazioni non si scelgono piu' dal Setup: resta il valore del .ini (Animazioni)
    oFLegends := oAddCheck(20, 216, 160, sTr('setup.gen.legends', 'Legende sui tasti'));
    oFLegends.OnChange := LegendsChange;
    oFOnTop := oAddCheck(185, 216, 200, sTr('setup.gen.ontop', 'Sempre in primo piano'));
    oFStartLocked := oAddCheck(390, 216, 240, sTr('setup.gen.startlocked',
        'Avvia bloccato (click-through)'));
    // nascondi i widget dei dispositivi inattivi dopo N secondi (da bloccato)
    oFAutoHide := oAddCheck(650, 254, 250, sTr('setup.gen.autohide', 'Nascondi i widget inattivi dopo'));
    oFAutoHide.OnChange := AutoHideChange;
    oFAutoHideSecs := oAddNumber(905, 252, 60, AUTOHIDE_MIN, AUTOHIDE_MAX);
    oAddLabel(972, 254, 140, sTr('setup.gen.autohide.secs', 'secondi'));
    // prima riga: contrassegno "solo bloccato"; seconda riga: la casella con i secondi
    oAddLockBadge(650, 214);
    oAddLabel(778, 216, 340, sTr('setup.gen.autohide.hint', 'ricompaiono al primo input'), 10);
    oAddLabel(20, 254, 100, sTr('setup.gen.mouserange', 'Corsa mouse'));
    oFMouseRange := oAddNumber(120, 252, 85, 200, 50000);
    oAddLabel(215, 254, 420, sTr('setup.gen.mouserange.hint', 'count del mouse per percorrere tutto il tappetino'), 10);

    // stile dei widget: subito dopo le opzioni
    oAddFrame(8, 300, dFormWidth, 100);
    oAddLabel(20, 310, 400, sTr('setup.gen.style', 'STILE DEI WIDGET'), 13, True);
    oAddLabel(20, 342, 60, sTr('setup.gen.style.label', 'Stile'));
    oFWidgetStyle := oAddCombo(80, 340, 340);
    oFWidgetStyle.Items.Add(sTr('setup.gen.style.panel', 'Pannello (sfondo, cornice e titolo)'));
    oFWidgetStyle.Items.Add(sTr('setup.gen.style.deviceonly', 'Solo dispositivo (sfondo trasparente)'));
    oFBaseEffects := oAddCheck(445, 341, 420, sTr('setup.gen.baseeffects',
        'Effetti di base (anelli del proiettore e scansione)'));
    oAddLabel(20, 372, 1100, sTr('setup.gen.style.hint',
        'Solo dispositivo: con il layout sbloccato titolo e cornice compaiono passando con il mouse ' +
        'sul widget; lo stato compare solo se il dispositivo non e'' collegato.'), 10);

    oAddFrame(8, 412, dFormWidth, 70);
    oAddLabel(20, 422, 300, sTr('setup.gen.hotkeys', 'HOTKEY'), 13, True);
    oAddLabel(20, 450, 1100,
        sTr('setup.gen.hotkeys.text', 'Ctrl+Alt+F12 blocca/sblocca  ' + #$00B7 + '  Ctrl+Alt+F11 setup  ' +
        #$00B7 + '  Ctrl+Alt+F10 mostra/nasconde  ' + #$00B7 + '  Ctrl+Alt+F9 modalita'' streamer.'), 10);

    //** pagina DISPOSITIVI *********************************************************************************
    oNewPage(1, sTr('setup.page.devices', 'Dispositivi'));
    // tabella dei widget in un riquadro
    oAddFrame(8, 0, dFormWidth, ROW_Y0 + DEV_ROWS * ROW_DY + 8);
    dPosY := 10;
    oAddLabel(20, dPosY, 170, sTr('setup.dev.col.visible', 'Visibile / tipo'), 10);
    oAddLabel(200, dPosY, 240, sTr('setup.dev.col.model', 'Modello 3D'), 10);
    oAddLabel(450, dPosY, 230, sTr('setup.dev.col.device', 'Dispositivo sorgente'), 10);
    oAddLabel(690, dPosY, 60, 'X', 10);
    oAddLabel(755, dPosY, 60, 'Y', 10);
    oAddLabel(820, dPosY, 60, sTr('setup.dev.col.width', 'Largh.'), 10);
    oAddLabel(885, dPosY, 60, sTr('setup.dev.col.height', 'Alt.'), 10);
    oAddLabel(950, dPosY, 60, sTr('setup.dev.col.axes', 'Assi XYZ'), 10);
    oAddLabel(1015, dPosY, 60, sTr('setup.dev.col.firstbutton', '1' + #$00B0 + ' puls.'), 10);

    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        dPosY := ROW_Y0 + Ord(eDevice) * ROW_DY;
        rRow := Default(TWidgetRow);
        rRow.oVisible := oAddCheck(20, dPosY + 1, 175, sKindText(eDevice));
        rRow.oVisible.OnChange := RowChange;
        rRow.oModel := oAddCombo(200, dPosY, 240);
        rRow.aModels := aModelsOfKind(eDevice);
        for iSkin := 0 to High(rRow.aModels) do
            rRow.oModel.Items.Add(rRow.aModels[iSkin].sDisplayName);
        rRow.oModel.Tag := Ord(eDevice);
        rRow.oModel.OnChange := ModelChange;
        // dispositivo sorgente: scelto tra quelli rilevati dall'ultima scansione
        rRow.oDevice := oAddCombo(450, dPosY, 230);
        rRow.oX := oAddNumber(690, dPosY, 60, -20000, 20000);
        rRow.oY := oAddNumber(755, dPosY, 60, -20000, 20000);
        rRow.oW := oAddNumber(820, dPosY, 60, 80, 4000);
        rRow.oH := oAddNumber(885, dPosY, 60, 80, 4000);
        rRow.oAxes := oAddEdit(950, dPosY, 60);
        rRow.oOffset := oAddNumber(1015, dPosY, 55, 1, 32);
        aFRows[eDevice] := rRow;
    end;

    // spiegazione della colonna "Assi XYZ" (cornice creata prima dei testi)
    dPosY := ROW_Y0 + DEV_ROWS * ROW_DY + 20;
    oAddFrame(8, dPosY, dFormWidth, 146);
    oAddLabel(20, dPosY + 10, 520, sTr('setup.dev.axes.title', 'ASSI XYZ'), 12, True);
    oAddText(20, dPosY + 34, 1100, 108, sTr('setup.dev.axes.text',
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
    dPosY := dPosY + 154;
    oAddFrame(8, dPosY, dFormWidth, 90);
    oAddLabel(20, dPosY + 8, 520, sTr('setup.dev.cols.title', 'ALTRE COLONNE'), 12, True);
    oAddText(20, dPosY + 32, 1100, 54, sTr('setup.dev.cols.text',
        '1' + #$00B0 + ' puls. (pulsantiere e manette): numero del pulsante del dispositivo da cui il ' +
        'modello comincia a leggere. Con 1 il primo tasto del modello 3D e'' il pulsante 1; con 17 ' +
        'una pulsantiera da 16 tasti mostra i pulsanti 17-32 (per dividere tra due pulsantiere un ' +
        'dispositivo con 32 pulsanti, o per mostrare i pulsanti della base di un joystick).' + sLineBreak +
        'X / Y (posizione sullo schermo): modificabili solo con il layout Personalizzato.'));

    //** pagina AMPIEZZA ************************************************************************************
    oNewPage(2, sTr('setup.page.range', 'Ampiezza'));
    // riquadro con la spiegazione dell'ampiezza degli angoli e i valori risultanti
    oAddFrame(8, 0, dFormWidth, 160);
    oAddLabel(20, 10, 520, sTr('setup.amp.angles.title', 'AMPIEZZA DEGLI ANGOLI'), 12, True);
    oAddText(20, 34, 1100, 48, Format(sTr('setup.amp.angles.text',
        'Angolo totale di escursione di ogni movimento (X, Y, Z), in gradi da %d a %d, impostato qui ' +
        'sotto: con 60' + #$00B0 + ' l''asse a fine corsa va da -30' + #$00B0 + ' a +30' + #$00B0 +
        ' rispetto al centro.' + sLineBreak + 'Gli assi X, Y e Z sono quelli assegnati nella pagina ' +
        'Dispositivi (colonna "Assi XYZ"); con Inverti = Si il movimento va nel verso opposto.'),
        [JOY_RANGE_MIN, JOY_RANGE_MAX]));
    oAddText(20, 88, 1100, 22, sTr('setup.amp.current', 'Valori attuali:'));
    oFRangeInfo := oAddText(36, 110, 1080, 44, '');
    oFRangeInfo.TextSettings.Font.Style := [TFontStyle.fsBold];

    // riquadro con le impostazioni dei due joystick
    oAddFrame(8, 172, dFormWidth, 202);
    oAddLabel(20, 182, 400, sTr('setup.amp.move.title', 'AMPIEZZA DEL MOVIMENTO'), 13, True);
    oAddLabel(20, 212, 170, sTr('setup.amp.col.joystick', 'Joystick'), 10);
    oAddLabel(RANGE_COL[0], 212, 125, sTr('setup.amp.col.x', 'X  sinistra / destra'), 10);
    oAddLabel(RANGE_COL[1], 212, 125, sTr('setup.amp.col.y', 'Y  avanti / indietro'), 10);
    oAddLabel(RANGE_COL[2], 212, 125, sTr('setup.amp.col.z', 'Z  rotazione (twist)'), 10);
    for iSkin := 0 to 2 do
        oAddLabel(RANGE_COL[iSkin] + INV_DX, 212, 80, sTr('setup.amp.col.invert', 'Inverti'), 10);
    dPosY := 238;
    for eDevice in [dkJoyLeft, dkJoyRight] do
    begin
        oAddLabel(20, dPosY + 2, 170, sKindText(eDevice));
        for iSkin := 0 to 2 do
        begin
            aBoxes[iSkin] := oAddNumber(RANGE_COL[iSkin], dPosY, 80, JOY_RANGE_MIN, JOY_RANGE_MAX);
            aBoxes[iSkin].OnChange := RangeChange;
            oAddLabel(RANGE_COL[iSkin] + 84, dPosY + 2, 20, #$00B0);
            aInvs[iSkin] := oAddCombo(RANGE_COL[iSkin] + INV_DX, dPosY, 64);
            aInvs[iSkin].Items.Add(sTr('setup.amp.invert.no', 'No'));
            aInvs[iSkin].Items.Add(sTr('setup.amp.invert.yes', 'Si'));
            aInvs[iSkin].ItemIndex := 0;
            aInvs[iSkin].OnChange := RangeChange;
        end;
        aFRows[eDevice].oRangeX := aBoxes[0];
        aFRows[eDevice].oRangeY := aBoxes[1];
        aFRows[eDevice].oRangeZ := aBoxes[2];
        aFRows[eDevice].oInvX := aInvs[0];
        aFRows[eDevice].oInvY := aInvs[1];
        aFRows[eDevice].oInvZ := aInvs[2];
        dPosY := dPosY + ROW_DY;
    end;
    oAddButton(20, dPosY + 16, 240, sTr('setup.amp.btn.defaults', 'Ampiezze predefinite'),
        BtnRangeDefaultsClick);
    oAddLabel(280, dPosY + 24, 800,
        Format(sTr('setup.amp.defaults.hint', 'X %d' + #$00B0 + '   Y %d' + #$00B0 + '   Z %d' + #$00B0 +
        '   (non salvate finche'' non si preme Salva)'), [DEF_RANGE_X, DEF_RANGE_Y, DEF_RANGE_Z]), 10);

    // riquadro con le impostazioni delle due manette (leva e mini-stick)
    oAddFrame(8, 386, dFormWidth, 150);
    oAddLabel(20, 396, 400, sTr('setup.amp.thr.title', 'MANETTE'), 13, True);
    oAddLabel(560, 400, 560, Format(sTr('setup.amp.thr.defaults', 'predefinite: leva %d' + #$00B0 +
        ', mini-stick %d' + #$00B0), [DEF_THR_LEVER, DEF_THR_MINI]), 10);
    oAddLabel(20, 426, 170, sTr('setup.amp.col.throttle', 'Manetta'), 10);
    oAddLabel(RANGE_COL[0], 426, 125, sTr('setup.amp.col.lever', 'Leva  avanti / indietro'), 10);
    oAddLabel(RANGE_COL[1], 426, 125, sTr('setup.amp.col.ministickx', 'Mini-stick  sx / dx'), 10);
    oAddLabel(RANGE_COL[2], 426, 125, sTr('setup.amp.col.ministicky', 'Mini-stick  su / giu'''), 10);
    for iSkin := 0 to 2 do
        oAddLabel(RANGE_COL[iSkin] + INV_DX, 426, 80, sTr('setup.amp.col.invert', 'Inverti'), 10);
    dPosY := 452;
    for eDevice in [dkThrLeft, dkThrRight] do
    begin
        oAddLabel(20, dPosY + 2, 170, sKindText(eDevice));
        for iSkin := 0 to 2 do
        begin
            aBoxes[iSkin] := oAddNumber(RANGE_COL[iSkin], dPosY, 80, JOY_RANGE_MIN, JOY_RANGE_MAX);
            oAddLabel(RANGE_COL[iSkin] + 84, dPosY + 2, 20, #$00B0);
            aInvs[iSkin] := oAddCombo(RANGE_COL[iSkin] + INV_DX, dPosY, 64);
            aInvs[iSkin].Items.Add(sTr('setup.amp.invert.no', 'No'));
            aInvs[iSkin].Items.Add(sTr('setup.amp.invert.yes', 'Si'));
            aInvs[iSkin].ItemIndex := 0;
        end;
        aFRows[eDevice].oRangeX := aBoxes[0];
        aFRows[eDevice].oRangeY := aBoxes[1];
        aFRows[eDevice].oRangeZ := aBoxes[2];
        aFRows[eDevice].oInvX := aInvs[0];
        aFRows[eDevice].oInvY := aInvs[1];
        aFRows[eDevice].oInvZ := aInvs[2];
        dPosY := dPosY + ROW_DY;
    end;

    //** pagina MODALITA' ***********************************************************************************
    oNewPage(3, sTr('setup.page.modes', 'Modalita'''));
    // per ogni modalita': titolo, descrizione e poi la casella per attivarla
    oAddFrame(8, 0, dFormWidth, 116);
    oAddLabel(20, 10, 400, sTr('setup.modes.streamer.title', 'MODALITA'' STREAMER'), 13, True);
    oAddText(20, 36, 1100, 40, sTr('setup.modes.streamer.text',
        'Nasconde i pulsanti della barra comandi (Setup, Blocca layout, Esci): resta solo ' +
        'l''etichetta, che mostra il tasto rapido per farli ricomparire: Ctrl+Alt+F9.' + sLineBreak +
        'Se Ctrl+Alt+F9 e'' gia'' usato da un''altra applicazione i pulsanti restano visibili.'))
        .TextSettings.Font.Size := 11;
    oFStreamer := oAddCheck(20, 82, 400, sTr('setup.modes.streamer.check', 'Attiva modalita'' streamer'));

    oAddFrame(8, 128, dFormWidth, 116);
    oAddLabel(20, 138, 400, sTr('setup.modes.privacy.title', 'MODALITA'' PRIVACY'), 13, True);
    oAddText(20, 164, 1100, 40, sTr('setup.modes.privacy.text',
        'Nasconde sempre il widget della tastiera, anche se e'' attivo tra i dispositivi, ' +
        'per non mostrare cio'' che si digita (ad esempio una password).' + sLineBreak +
        'Il widget della tastiera ricompare solo disattivando questa modalita''.'))
        .TextSettings.Font.Size := 11;
    oFPrivacy := oAddCheck(20, 210, 400, sTr('setup.modes.privacy.check', 'Attiva modalita'' privacy'));
    oFPrivacy.OnChange := RowChange;

    //** pagina LOG *****************************************************************************************
    oNewPage(4, sTr('setup.page.log', 'Log'));
    oAddFrame(8, 0, dFormWidth, TControl(oFPage).Height - 4);
    oAddLabel(20, 10, 600, sTr('setup.log.title', 'LOG DEL RILEVAMENTO DISPOSITIVI'), 13, True);
    oAddButton(ClientWidth - 260, 6, 240, sTr('setup.log.btn.scan', 'Esegui scansione'), BtnScanClick);
    oFLog := TMemo.Create(Self);
    oFLog.Parent := oFPage;
    oFLog.SetBounds(20, 48, ClientWidth - 40, TControl(oFPage).Height - 66);
    oFLog.ReadOnly := True;
    oFLog.WordWrap := False;
    oFLog.StyledSettings := oFLog.StyledSettings - [TStyledSetting.Family, TStyledSetting.Size];
    oFLog.TextSettings.Font.Family := 'Consolas';
    oFLog.TextSettings.Font.Size := 12;

    //** pagina OBS *****************************************************************************************
    oNewPage(5, sTr('setup.page.obs', 'OBS'));
    // parametri del servizio Browser Source
    oAddFrame(8, 0, dFormWidth, 176);
    oAddLabel(20, 10, 340, sTr('setup.obs.service.title', 'SERVIZIO BROWSER SOURCE PER OBS'), 13, True);
    // il servizio funziona solo con il layout bloccato (all'avvio lo blocca da solo)
    oAddLockBadge(370, 10);
    oAddLabel(20, 46, 60, sTr('setup.obs.port', 'Porta'));
    oFObsPort := oAddNumber(80, 44, 90, OBS_PORT_MIN, OBS_PORT_MAX);
    oFObsPort.OnChange := ObsPortChange;
    oAddLabel(200, 46, 100, sTr('setup.obs.resolution', 'Risoluzione'));
    oFObsWidth := oAddNumber(300, 44, 80, OBS_SIZE_MIN, OBS_SIZE_MAX);
    oAddLabel(386, 46, 14, 'x');
    oFObsHeight := oAddNumber(402, 44, 80, OBS_SIZE_MIN, OBS_SIZE_MAX);
    oAddButton(500, 39, 220, sTr('setup.obs.btn.native', 'Risoluzione nativa'), BtnObsNativeClick);
    oAddLabel(735, 46, 380, Format(sTr('setup.obs.native.hint', 'monitor principale: %d x %d pixel'),
        [rNativeScreenSize.cx, rNativeScreenSize.cy]), 10);
    oAddLabel(20, 90, 175, sTr('setup.obs.hide', 'Con il servizio attivo'));
    oFObsHide := oAddCombo(200, 88, 300);
    oFObsHide.Items.Add(sTr('setup.obs.hide.window', 'Nascondi la finestra'));
    oFObsHide.Items.Add(sTr('setup.obs.hide.offscreen', 'Sposta la finestra fuori dallo schermo'));
    oFObsHide.Items.Add(sTr('setup.obs.hide.monitor', 'Sposta la finestra su un altro monitor'));
    oFObsHide.OnChange := ObsHideChange;
    // monitor di destinazione: tutti quelli collegati tranne il principale (dove gira l'overlay)
    oFObsMonitor := oAddCombo(515, 88, 600);
    aFObsMonitors := aOtherMonitors;
    for iSkin := 0 to High(aFObsMonitors) do
        oFObsMonitor.Items.Add(sMonitorText(aFObsMonitors[iSkin]));
    if Length(aFObsMonitors) = 0 then
        oFObsMonitor.Items.Add(sTr('setup.obs.monitor.none', 'Nessun altro monitor collegato'));
    oAddLabel(20, 134, 175, sTr('setup.obs.url', 'Indirizzo per OBS'));
    oFObsUrl := oAddLabel(200, 134, 290, '', 12);
    oFObsUrl.TextSettings.Font.Style := [TFontStyle.fsBold];
    oAddButton(500, 127, 220, sTr('setup.obs.btn.copy', 'Copia indirizzo'), BtnObsCopyClick);
    // fotogrammi al secondo inviati a OBS
    oAddLabel(740, 134, 150, sTr('setup.obs.fps', 'Fotogrammi al secondo'));
    oFObsFps := oAddCombo(895, 132, 120);
    for iSkin := 0 to High(OBS_FPS_CHOICES) do
        oFObsFps.Items.Add(Format('%d fps', [OBS_FPS_CHOICES[iSkin]]));
    oFObsFps.OnChange := ObsFpsChange;

    // stato del servizio e comandi
    oFObsStateFrame := oAddFrame(8, 188, dFormWidth, 138);
    oFObsStateFrame.SetStateColor(OBS_OFF_COLOR);
    oAddLabel(20, 198, 600, sTr('setup.obs.status.title', 'STATO DEL SERVIZIO'), 13, True);
    oFObsStatus := oAddText(20, 224, 1100, 56, '');
    oFObsBtnStart := oAddButton(20, 284, 240, sTr('setup.obs.btn.start', 'Avvia il servizio'), BtnObsStartClick);
    oFObsBtnStop := oAddButton(280, 284, 240, sTr('setup.obs.btn.stop', 'Ferma il servizio'),
        BtnObsStopClick);
    oFObsAuto := oAddCheck(550, 290, 560, sTr('setup.obs.autostart', 'Avvia il servizio all''avvio di HoloInput'));

    // istruzioni
    oAddFrame(8, 338, dFormWidth, 210);
    oAddLabel(20, 348, 600, sTr('setup.obs.howto.title', 'COME USARLO IN OBS'), 13, True);
    oAddText(20, 374, 1100, 168, sTr('setup.obs.howto.text',
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
    oNewPage(6, sTr('setup.page.info', 'Info'));
    oFDossier := THoloDossierCard.Create(Self);
    oFDossier.Parent := oFPage;
    oFDossier.SetBounds(20, 10, 600, 340);
    oFInfoCard := THoloInfoCard.Create(Self);
    oFInfoCard.Parent := oFPage;
    oFInfoCard.SetBounds(640, 10, 480, 340);
    oAddButton(20, 364, 300, sTr('setup.info.btn.dossier', 'Apri il Citizen Dossier su RSI'),
        BtnDossierClick);
    // aggiornamenti dalla pagina delle release su GitHub
    oAddButton(640, 364, 260, sTr('setup.info.btn.update', 'Controlla aggiornamenti'), BtnUpdateClick);
    oFCheckUpdates := oAddCheck(915, 370, 210, sTr('setup.info.checkupdates', 'Controlla all''avvio'));

    //** comandi in basso ***********************************************************************************
    oFPage := Self;
    dPosY := ClientHeight - 52;
    oAddButton(20, dPosY, 130, sTr('setup.btn.default', 'Default'), BtnDefaultsClick);
    // legenda del contrassegno "SOLO BLOCCATO"
    oAddLockBadge(170, dPosY + 7);
    oAddLabel(296, dPosY + 8, ClientWidth - 296 - 300, sTr('setup.badge.legend',
        'funziona solo con il layout ' +
        'bloccato (Ctrl+Alt+F12); tutto il resto vale sia bloccato sia sbloccato'), 10);
    oAddButton(ClientWidth - 290, dPosY, 130, sTr('setup.btn.save', 'Salva'), BtnSaveClick);
    oAddButton(ClientWidth - 150, dPosY, 130, sTr('setup.btn.close', 'Chiudi'), BtnCloseClick);

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
    eDevice: TDeviceKind;
    iPad: Integer;
    oCombo: TComboBox;
begin
    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        oCombo := aFRows[eDevice].oDevice;
        oCombo.Items.BeginUpdate;
        try
            oCombo.Items.Clear;
            case eDevice of
                dkKeyboard, dkMouse:
                    oCombo.Items.Add(sTr('setup.dev.system', 'Sistema (Raw Input)'));
                dkGamepad:
                    for iPad := 0 to MAX_PADS - 1 do
                        if oFInput.bXInputAvailable then
                            oCombo.Items.Add(Format(sTr('setup.dev.xinput', 'XInput %d'), [iPad + 1]))
                        else
                            oCombo.Items.Add(Format(sTr('setup.dev.xinput.na', 'XInput %d (XInput non disponibile)'), [iPad + 1]));
            else
                for iPad := 0 to MAX_JOY - 1 do
                    if aFJoys[iPad].bPresent then
                        oCombo.Items.Add(Format(sTr('setup.dev.joy', 'ID %d - %s (%d assi, %d puls.)'),
                            [iPad, aFJoys[iPad].sName, aFJoys[iPad].iNumAxes, aFJoys[iPad].iNumButtons]))
                    else
                        oCombo.Items.Add(Format(sTr('setup.dev.joy.none', 'ID %d - non collegato'), [iPad]));
            end;
        finally
            oCombo.Items.EndUpdate;
        end;
        oCombo.ItemIndex := EnsureRange(oFConfig.aWidgets[eDevice].iDeviceIndex, 0, oCombo.Items.Count - 1);
        oCombo.Enabled := not (eDevice in [dkKeyboard, dkMouse]);
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
    eDevice: TDeviceKind;
    iLang: Integer;
    rWidget: TWidgetConfig;
begin
    bFLoading := True;
    try
    oFSkin.ItemIndex := Max(0, iSkinIndexOf(oFConfig.sSkinId));
    oFLang.ItemIndex := -1;
    for iLang := 0 to High(aFLangs) do
        if SameText(aFLangs[iLang].sId, oFConfig.sLanguage) then
            oFLang.ItemIndex := iLang;
    oFLayout.ItemIndex := Ord(oFConfig.eLayout);
    oFMargin.Value := oFConfig.iMargin;
    oFSpacing.Value := oFConfig.iSpacing;
    oFMouseRange.Value := oFConfig.iMouseRange;
    oFWidgetStyle.ItemIndex := Ord(oFConfig.eWidgetStyle);
    oFBaseEffects.IsChecked := oFConfig.bBaseEffects;
    oFAutoHide.IsChecked := oFConfig.bAutoHide;
    oFAutoHideSecs.Value := oFConfig.iAutoHideSecs;
    oFCheckUpdates.IsChecked := oFConfig.bCheckUpdates;
    AutoHideChange(nil);
    oFLegends.IsChecked := oFConfig.bShowLegends;
    oFOnTop.IsChecked := oFConfig.bStayOnTop;
    oFStartLocked.IsChecked := oFConfig.bStartLocked;
    oFStreamer.IsChecked := oFConfig.bStreamerMode;
    oFPrivacy.IsChecked := oFConfig.bPrivacyMode;
    oFOpacity.Value := Round(oFConfig.dOpacity * 100);
    oFObsPort.Value := oFConfig.iObsPort;
    oFObsWidth.Value := oFConfig.iObsWidth;
    oFObsHeight.Value := oFConfig.iObsHeight;
    oFObsHide.ItemIndex := EnsureRange(oFConfig.iObsHideMode, OBS_HIDE_WINDOW, OBS_HIDE_MONITOR);
    oFObsAuto.IsChecked := oFConfig.bObsAutoStart;
    oFObsFps.ItemIndex := High(OBS_FPS_CHOICES);
    for iLang := High(OBS_FPS_CHOICES) downto 0 do
        if oFConfig.iObsFps <= OBS_FPS_CHOICES[iLang] then
            oFObsFps.ItemIndex := iLang;
    oFObsMonitor.ItemIndex := 0;
    for iLang := 0 to High(aFObsMonitors) do
        if SameText(aFObsMonitors[iLang].sDevice, oFConfig.sObsMonitor) then
            oFObsMonitor.ItemIndex := iLang;
    ObsHideChange(nil);
    UpdateObsUrl;

    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        rWidget := oFConfig.aWidgets[eDevice];
        aFRows[eDevice].oVisible.IsChecked := rWidget.bVisible;
        aFRows[eDevice].oModel.ItemIndex := -1;
        for iLang := 0 to High(aFRows[eDevice].aModels) do
            if SameText(aFRows[eDevice].aModels[iLang].sModelId, rWidget.sModelId) then
                aFRows[eDevice].oModel.ItemIndex := iLang;
        if (aFRows[eDevice].oModel.ItemIndex < 0) and (aFRows[eDevice].oModel.Items.Count > 0) then
            aFRows[eDevice].oModel.ItemIndex := 0;
        aFRows[eDevice].oX.Value := rWidget.iX;
        aFRows[eDevice].oY.Value := rWidget.iY;
        aFRows[eDevice].oW.Value := rWidget.iW;
        aFRows[eDevice].oH.Value := rWidget.iH;
        aFRows[eDevice].oAxes.Text := Format('%d,%d,%d', [rWidget.iAxisX, rWidget.iAxisY, rWidget.iAxisZ]);
        aFRows[eDevice].oOffset.Value := rWidget.iButtonOffset + 1;
        if aFRows[eDevice].oRangeX <> nil then
        begin
            aFRows[eDevice].oRangeX.Value := rWidget.iRangeX;
            aFRows[eDevice].oRangeY.Value := rWidget.iRangeY;
            aFRows[eDevice].oRangeZ.Value := rWidget.iRangeZ;
            aFRows[eDevice].oInvX.ItemIndex := Ord(rWidget.bInvertX);
            aFRows[eDevice].oInvY.ItemIndex := Ord(rWidget.bInvertY);
            aFRows[eDevice].oInvZ.ItemIndex := Ord(rWidget.bInvertZ);
        end;
    end;
    FillDeviceCombos;
    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
        UpdateRowState(eDevice);
    UpdateRangeInfo;
    ApplyColors;
    finally
        bFLoading := False;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: dNumValue
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Copiare i valori dei controlli nella configurazione.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: converte il campo testuale degli assi ("0,1,3") ignorando
//** i valori non validi; l'inversione viene dai dropdown della pagina Ampiezza.
//** I campi numerici si leggono con dNumValue (testo scritto, anche se non
//** ancora confermato con Invio).
//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome funzione: dNumValue
//** Parametri di ingresso: oABox: TNumberBox
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
function dNumValue(oABox: TNumberBox): Single;
var
    dNumber: Double;
begin
    if TryStrToFloat(Trim(oABox.Text), dNumber) then
        Result := EnsureRange(dNumber, oABox.Min, oABox.Max)
    else
        Result := oABox.Value;
end;

//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.ReadValues;
var
    eDevice: TDeviceKind;
    rWidget: TWidgetConfig;
    aParts: TArray<string>;
begin
    if oFSkin.ItemIndex >= 0 then
        oFConfig.sSkinId := oSkinByIndex(oFSkin.ItemIndex).sId;
    if oFLang.ItemIndex >= 0 then
        oFConfig.sLanguage := aFLangs[oFLang.ItemIndex].sId;
    // con un layout predefinito le posizioni vengono ricalcolate all'applicazione
    oFConfig.SetLayout(TLayoutMode(EnsureRange(oFLayout.ItemIndex, 0, Ord(High(TLayoutMode)))));
    oFConfig.iMargin := Round(dNumValue(oFMargin));
    oFConfig.iSpacing := Round(dNumValue(oFSpacing));
    oFConfig.iMouseRange := Round(dNumValue(oFMouseRange));
    if oFWidgetStyle.ItemIndex >= 0 then
        oFConfig.eWidgetStyle := TWidgetStyle(EnsureRange(oFWidgetStyle.ItemIndex, 0,
            Ord(High(TWidgetStyle))));
    oFConfig.bBaseEffects := oFBaseEffects.IsChecked;
    oFConfig.bAutoHide := oFAutoHide.IsChecked;
    oFConfig.iAutoHideSecs := EnsureRange(Round(dNumValue(oFAutoHideSecs)), AUTOHIDE_MIN, AUTOHIDE_MAX);
    oFConfig.bCheckUpdates := oFCheckUpdates.IsChecked;
    oFConfig.bShowLegends := oFLegends.IsChecked;
    oFConfig.bStayOnTop := oFOnTop.IsChecked;
    oFConfig.bStartLocked := oFStartLocked.IsChecked;
    oFConfig.bStreamerMode := oFStreamer.IsChecked;
    oFConfig.bPrivacyMode := oFPrivacy.IsChecked;
    oFConfig.dOpacity := oFOpacity.Value / 100;
    oFConfig.iObsPort := EnsureRange(Round(dNumValue(oFObsPort)), OBS_PORT_MIN, OBS_PORT_MAX);
    oFConfig.iObsWidth := EnsureRange(Round(dNumValue(oFObsWidth)), OBS_SIZE_MIN, OBS_SIZE_MAX);
    oFConfig.iObsHeight := EnsureRange(Round(dNumValue(oFObsHeight)), OBS_SIZE_MIN, OBS_SIZE_MAX);
    if oFObsHide.ItemIndex >= 0 then
        oFConfig.iObsHideMode := oFObsHide.ItemIndex;
    if oFObsFps.ItemIndex >= 0 then
        oFConfig.iObsFps := OBS_FPS_CHOICES[oFObsFps.ItemIndex];
    oFConfig.bObsAutoStart := oFObsAuto.IsChecked;
    // senza altri monitor la finestra va fuori dallo schermo
    if (oFConfig.iObsHideMode = OBS_HIDE_MONITOR) and (Length(aFObsMonitors) = 0) then
        oFConfig.iObsHideMode := OBS_HIDE_OFFSCREEN;
    if (oFObsMonitor.ItemIndex >= 0) and (oFObsMonitor.ItemIndex <= High(aFObsMonitors)) then
        oFConfig.sObsMonitor := aFObsMonitors[oFObsMonitor.ItemIndex].sDevice;

    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
    begin
        rWidget := oFConfig.aWidgets[eDevice];
        rWidget.bVisible := aFRows[eDevice].oVisible.IsChecked;
        if aFRows[eDevice].oModel.ItemIndex >= 0 then
            rWidget.sModelId := aFRows[eDevice].aModels[aFRows[eDevice].oModel.ItemIndex].sModelId;
        if aFRows[eDevice].oDevice.Enabled and (aFRows[eDevice].oDevice.ItemIndex >= 0) then
            rWidget.iDeviceIndex := aFRows[eDevice].oDevice.ItemIndex;
        rWidget.iX := Round(dNumValue(aFRows[eDevice].oX));
        rWidget.iY := Round(dNumValue(aFRows[eDevice].oY));
        rWidget.iW := Round(dNumValue(aFRows[eDevice].oW));
        rWidget.iH := Round(dNumValue(aFRows[eDevice].oH));
        aParts := aFRows[eDevice].oAxes.Text.Split([',', ';', ' '], TStringSplitOptions.ExcludeEmpty);
        if Length(aParts) >= 3 then
        begin
            rWidget.iAxisX := EnsureRange(StrToIntDef(aParts[0], rWidget.iAxisX), 0, 5);
            rWidget.iAxisY := EnsureRange(StrToIntDef(aParts[1], rWidget.iAxisY), 0, 5);
            rWidget.iAxisZ := EnsureRange(StrToIntDef(aParts[2], rWidget.iAxisZ), 0, 5);
        end;
        rWidget.iButtonOffset := EnsureRange(Round(dNumValue(aFRows[eDevice].oOffset)) - 1, 0, 31);
        if aFRows[eDevice].oRangeX <> nil then
        begin
            rWidget.iRangeX := EnsureRange(Round(dNumValue(aFRows[eDevice].oRangeX)), JOY_RANGE_MIN,
                JOY_RANGE_MAX);
            rWidget.iRangeY := EnsureRange(Round(dNumValue(aFRows[eDevice].oRangeY)), JOY_RANGE_MIN,
                JOY_RANGE_MAX);
            rWidget.iRangeZ := EnsureRange(Round(dNumValue(aFRows[eDevice].oRangeZ)), JOY_RANGE_MIN,
                JOY_RANGE_MAX);
            rWidget.bInvertX := aFRows[eDevice].oInvX.ItemIndex = 1;
            rWidget.bInvertY := aFRows[eDevice].oInvY.ItemIndex = 1;
            rWidget.bInvertZ := aFRows[eDevice].oInvZ.ItemIndex = 1;
        end;
        oFConfig.aWidgets[eDevice] := rWidget;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.UpdateRowState
//** Parametri di ingresso: eAKind: TDeviceKind
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
procedure TfrmSetup.UpdateRowState(eAKind: TDeviceKind);
var
    rRow: TWidgetRow;
    bIsOn, bLocked: Boolean;
begin
    rRow := aFRows[eAKind];
    bLocked := (eAKind = dkKeyboard) and oFPrivacy.IsChecked;
    rRow.oVisible.Enabled := not bLocked;
    if bLocked then
        rRow.oVisible.Text := sKindText(eAKind) + sTr('setup.dev.privacysuffix', ' (PRIVACY)')
    else
        rRow.oVisible.Text := sKindText(eAKind);
    bIsOn := rRow.oVisible.IsChecked and not bLocked;
    rRow.oModel.Enabled := bIsOn;
    rRow.oDevice.Enabled := bIsOn and not (eAKind in [dkKeyboard, dkMouse]);
    rRow.oX.Enabled := bIsOn and (oFLayout.ItemIndex = Ord(lmCustom));
    rRow.oY.Enabled := bIsOn and (oFLayout.ItemIndex = Ord(lmCustom));
    rRow.oW.Enabled := bIsOn;
    rRow.oH.Enabled := bIsOn;
    rRow.oAxes.Enabled := bIsOn and (eAKind in [dkJoyLeft, dkJoyRight, dkThrLeft, dkThrRight]);
    rRow.oOffset.Enabled := bIsOn and (eAKind in [dkBoxLeft, dkBoxRight, dkThrLeft, dkThrRight]);
    if rRow.oRangeX <> nil then
    begin
        rRow.oRangeX.Enabled := bIsOn;
        rRow.oRangeY.Enabled := bIsOn;
        rRow.oRangeZ.Enabled := bIsOn;
        rRow.oInvX.Enabled := bIsOn;
        rRow.oInvY.Enabled := bIsOn;
        rRow.oInvZ.Enabled := bIsOn;
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
    oTextControl: TPresentedTextControl;
    oButton: THoloButton;
    oFrame: THoloFrame;
    oCls: TSkinClass;
begin
    oCls := oSkinByIndex(oFSkin.ItemIndex);
    if oCls <> nil then
        rFColors := oCls.rColors
    else
        rFColors := rDefaultSkinColors;
    Fill.Kind := TBrushKind.Solid;
    Fill.Color := iWithAlpha(iMixColors(rFColors.iPanelBack, TAlphaColors.Black, 0.35), $FF);
    for oTextControl in oFTexts do
        oTextControl.TextSettings.FontColor := rFColors.iText;
    for oButton in oFButtons do
        oButton.SetColors(rFColors);
    for oFrame in oFFrames do
        oFrame.SetColors(rFColors);
    if oFDossier <> nil then
        oFDossier.SetColors(rFColors);
    if oFInfoCard <> nil then
        oFInfoCard.SetColors(rFColors);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.SkinChange
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Applicare subito i colori della skin scelta alla finestra di Setup.
//** Data Ultima Modifica: 02/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.SkinChange(oSender: TObject);
begin
    ApplyColors;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.LangChange
//** Parametri di ingresso: oSender: TObject
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
procedure TfrmSetup.LangChange(oSender: TObject);
begin
    if bFLoading or (oFLang.ItemIndex < 0) then
        Exit;
    ReadValues;
    ModalResult := mrRetry;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.RowChange
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Aggiornare lo stato dei campi quando cambia una casella di spunta.
//** Data Ultima Modifica: 02/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.RowChange(oSender: TObject);
var
    eDevice: TDeviceKind;
begin
    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
        UpdateRowState(eDevice);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.LayoutChange
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Cambiando layout, abilitare/disabilitare le coordinate X/Y.
//** Data Ultima Modifica: 22/10/2026
//***********************************************************************************************************
//** Funzionamento: le posizioni vere vengono ricalcolate quando si preme
//** Salva (layout predefiniti); con Personalizzato si parte dalle posizioni
//** attuali, modificabili nei campi X/Y.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.LayoutChange(oSender: TObject);
var
    eDevice: TDeviceKind;
begin
    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
        UpdateRowState(eDevice);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.LegendsChange
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiedere conferma prima di attivare le legende sui tasti.
//** Data Ultima Modifica: 30/10/2026
//***********************************************************************************************************
//** Funzionamento: solo quando la casella viene ATTIVATA dall'utente (non
//** durante il caricamento dei valori e non quando la si disattiva) mostra un
//** avviso con lo stile della skin scelta: Ok lascia l'opzione attiva,
//** Annulla la rimette disattiva. bFInLegendsPrompt evita che il cambio di
//** stato fatto qui richiami di nuovo l'avviso.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.LegendsChange(oSender: TObject);
begin
    if bFLoading or bFInLegendsPrompt or not oFLegends.IsChecked then
        Exit;
    bFInLegendsPrompt := True;
    try
        if not bHoloConfirm(sTr('setup.legends.title', 'Legende sui tasti'), sTr('setup.legends.text',
            'Le legende aggiungono molte scritte 3D ai widget (tastiera, gamepad, ' +
            'pulsantiere) e possono rallentare l''overlay, in particolare durante lo ' +
            'spostamento dei widget.' + sLineBreak + sLineBreak +
            'Vuoi attivarle comunque?'), rFColors) then
            oFLegends.IsChecked := False;
    finally
        bFInLegendsPrompt := False;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.AutoHideChange
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Abilitare il campo dei secondi solo con "Nascondi i widget inattivi" attivo.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.AutoHideChange(oSender: TObject);
begin
    oFAutoHideSecs.Enabled := oFAutoHide.IsChecked;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.ModelChange
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Quando l'utente sceglie un altro modello, proporre la mappatura assi suggerita dal
//**        modello (es. joystick Virpil: "0,1,2"; senza suggerimento: "0,1,3").
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: ignorato durante il caricamento dei valori, per non
//** sovrascrivere la mappatura salvata nel .ini.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.ModelChange(oSender: TObject);
var
    eDevice: TDeviceKind;
    oCombo: TComboBox;
    sAxes: string;
begin
    if bFLoading then
        Exit;
    oCombo := oSender as TComboBox;
    eDevice := TDeviceKind(oCombo.Tag);
    if (oCombo.ItemIndex < 0) or (oCombo.ItemIndex > High(aFRows[eDevice].aModels)) then
        Exit;
    sAxes := aFRows[eDevice].aModels[oCombo.ItemIndex].sDefaultAxes;
    if sAxes = '' then
        sAxes := '0,1,3';
    if eDevice in [dkJoyLeft, dkJoyRight, dkThrLeft, dkThrRight] then
        aFRows[eDevice].oAxes.Text := sAxes;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnSaveClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Confermare (la form principale applica e salva su .ini).
//** Data Ultima Modifica: 02/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnSaveClick(oSender: TObject);
begin
    ReadValues;
    ModalResult := mrOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnCloseClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiudere il Setup senza applicare le modifiche (pulsante "Chiudi").
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: con mrCancel la finestra principale scarta la copia della
//** configurazione su cui lavora il Setup: nulla viene applicato ne' salvato e
//** la lingua torna quella salvata.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnCloseClick(oSender: TObject);
begin
    ModalResult := mrCancel;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnDefaultsClick
//** Parametri di ingresso: oSender: TObject
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
procedure TfrmSetup.BtnDefaultsClick(oSender: TObject);
begin
    ReadValues;
    oFConfig.ResetLayoutDefaults;
    LoadValues;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnRangeDefaultsClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Riportare l'ampiezza del movimento dei due joystick e delle due manette ai valori
//**        predefiniti (non salvati finche' non si preme Salva).
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: aggiorna solo i campi della pagina Ampiezza; il valore passa
//** alla configurazione con ReadValues, quando si preme Salva.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnRangeDefaultsClick(oSender: TObject);
var
    eDevice: TDeviceKind;
begin
    for eDevice in [dkJoyLeft, dkJoyRight] do
    begin
        aFRows[eDevice].oRangeX.Value := DEF_RANGE_X;
        aFRows[eDevice].oRangeY.Value := DEF_RANGE_Y;
        aFRows[eDevice].oRangeZ.Value := DEF_RANGE_Z;
    end;
    for eDevice in [dkThrLeft, dkThrRight] do
    begin
        aFRows[eDevice].oRangeX.Value := DEF_THR_LEVER;
        aFRows[eDevice].oRangeY.Value := DEF_THR_MINI;
        aFRows[eDevice].oRangeZ.Value := DEF_THR_MINI;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.RangeChange
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Aggiornare il riepilogo delle ampiezze quando cambia un campo della pagina Ampiezza.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.RangeChange(oSender: TObject);
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
    eDevice: TDeviceKind;
    sInfo: string;

    //***********************************************************************************************************
    //***********************************************************************************************************
    //** Autore: Citizen GattoMatto
    //** Nome funzione: sAxis
    //** Parametri di ingresso: sAName: string; oABox: TNumberBox; oAInv: TComboBox
    //** Parametri di uscita: Result: string
    //** Scopo: Testo dell'ampiezza di un asse per il riepilogo (es. "X 36 gradi (+/-18)", con
    //**        " invertito" se l'asse e' invertito).
    //** Data Ultima Modifica: 04/11/2026
    //***********************************************************************************************************
    //***********************************************************************************************************
    function sAxis(const sAName: string; oABox: TNumberBox; oAInv: TComboBox): string;
    var
        iDegrees: Integer;
    begin
        iDegrees := Round(oABox.Value);
        Result := Format('%s %d' + #$00B0 + ' (' + #$00B1 + '%s' + #$00B0 + ')',
            [sAName, iDegrees, FormatFloat('0.#', iDegrees / 2)]);
        if oAInv.ItemIndex = 1 then
            Result := Result + sTr('setup.amp.inverted', ' invertito');
    end;

begin
    if (oFRangeInfo = nil) or (aFRows[dkJoyLeft].oRangeX = nil) or (aFRows[dkJoyRight].oRangeX = nil) then
        Exit;
    sInfo := '';
    for eDevice in [dkJoyLeft, dkJoyRight] do
    begin
        if sInfo <> '' then
            sInfo := sInfo + sLineBreak;
        sInfo := sInfo + sKindText(eDevice) + ':   ' + sAxis('X', aFRows[eDevice].oRangeX,
            aFRows[eDevice].oInvX) + '   ' +
            sAxis('Y', aFRows[eDevice].oRangeY, aFRows[eDevice].oInvY) + '   ' + sAxis('Z',
                aFRows[eDevice].oRangeZ, aFRows[eDevice].oInvZ);
    end;
    oFRangeInfo.Text := sInfo;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnUpdateClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiudere il Setup e chiedere alla finestra principale di controllare gli aggiornamenti.
//** Data Ultima Modifica: 06/11/2026
//***********************************************************************************************************
//** Funzionamento: come i pulsanti del servizio OBS, applica e salva le
//** modifiche fatte nel Setup (mrOk); il controllo, l'eventuale download con
//** la barra di progresso e il riavvio li esegue la finestra principale.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnUpdateClick(oSender: TObject);
begin
    ReadValues;
    bFUpdateRequested := True;
    ModalResult := mrOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnDossierClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Aprire il Citizen Dossier dell'autore nel browser.
//** Data Ultima Modifica: 26/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnDossierClick(oSender: TObject);
begin
    OpenUrl(DOSSIER_URL);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.SetObsState
//** Parametri di ingresso: bARunning: Boolean; sAStatus: string
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
procedure TfrmSetup.SetObsState(bARunning: Boolean; const sAStatus: string);
const
    OFF_OPACITY = 0.35;   // pulsante non disponibile
begin
    bFObsRunning := bARunning;
    oFObsStatus.Text := sAStatus;
    if bARunning then
        oFObsStateFrame.SetStateColor(OBS_ON_COLOR)
    else
        oFObsStateFrame.SetStateColor(OBS_OFF_COLOR);
    oFObsBtnStart.Enabled := not bARunning;
    oFObsBtnStop.Enabled := bARunning;
    if bARunning then
    begin
        oFObsBtnStart.Opacity := OFF_OPACITY;
        oFObsBtnStop.Opacity := 1;
        ShowPage(5);
    end
    else
    begin
        oFObsBtnStart.Opacity := 1;
        oFObsBtnStop.Opacity := OFF_OPACITY;
    end;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.ObsFpsChange
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Con il servizio OBS attivo, fermarlo e riavviarlo subito con i nuovi fotogrammi al secondo.
//** Data Ultima Modifica: 05/11/2026
//***********************************************************************************************************
//** Funzionamento: ignorato durante il caricamento dei valori, con il servizio
//** fermo (allora gli FPS valgono al prossimo avvio, dopo Salva) e se il valore
//** non cambia. Prima mostra un avviso (bHoloConfirm) che dice che il servizio
//** verra' fermato e riavviato: con Annulla il menu torna agli FPS in uso
//** (bFInFpsPrompt evita che il ripristino richiami l'avviso). Con Riavvia
//** aggiorna la copia della configurazione e chiede alla finestra principale
//** (mOnObsFpsChange) di fermare e riavviare il servizio: il cambio e' applicato
//** e salvato subito, anche se poi il Setup si chiude con Chiudi. Lo stato
//** mostrato nella pagina OBS viene aggiornato dalla finestra principale
//** (SetObsState).
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.ObsFpsChange(oSender: TObject);
var
    iFps, iChoice: Integer;
begin
    if bFLoading or bFInFpsPrompt or not bFObsRunning or (oFObsFps.ItemIndex < 0) then
        Exit;
    iFps := OBS_FPS_CHOICES[oFObsFps.ItemIndex];
    if iFps = oFConfig.iObsFps then
        Exit;
    bFInFpsPrompt := True;
    try
        if not bHoloConfirm(sTr('setup.obs.fps.restart.title', 'Riavvio del servizio OBS'),
            Format(sTr('setup.obs.fps.restart.text', 'Il servizio OBS e'' attivo: per passare a %d fps ' +
            'verra'' fermato e riavviato subito (OBS si ricollega da solo). Imposta gli stessi fps ' +
            'nella fonte Browser di OBS.' + sLineBreak + sLineBreak + 'Riavviare il servizio?'), [iFps]),
            rFColors,
            sTr('setup.obs.fps.restart.ok', 'Riavvia')) then
        begin
            // Annulla: il menu torna agli FPS in uso
            for iChoice := 0 to High(OBS_FPS_CHOICES) do
                if OBS_FPS_CHOICES[iChoice] = oFConfig.iObsFps then
                    oFObsFps.ItemIndex := iChoice;
            Exit;
        end;
    finally
        bFInFpsPrompt := False;
    end;
    oFConfig.iObsFps := iFps;
    if Assigned(mFOnObsFpsChange) then
        mFOnObsFpsChange(Self, iFps);
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
    oFObsUrl.Text := sObsUrl(Round(oFObsPort.Value));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.ObsPortChange
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Aggiornare l'indirizzo per OBS quando cambia la porta.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.ObsPortChange(oSender: TObject);
begin
    UpdateObsUrl;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.ObsHideChange
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Abilitare la scelta del monitor solo con "Sposta la finestra su un altro monitor".
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.ObsHideChange(oSender: TObject);
begin
    oFObsMonitor.Enabled := (oFObsHide.ItemIndex = OBS_HIDE_MONITOR) and (Length(aFObsMonitors) > 0);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnObsNativeClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Riportare la risoluzione del servizio OBS a quella nativa del monitor principale.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnObsNativeClick(oSender: TObject);
var
    rScreenSize: TSize;
begin
    rScreenSize := rNativeScreenSize;
    oFObsWidth.Value := rScreenSize.cx;
    oFObsHeight.Value := rScreenSize.cy;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnObsCopyClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Copiare negli appunti l'indirizzo da inserire nel Browser Source di OBS.
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnObsCopyClick(oSender: TObject);
var
    xSvc: IFMXClipboardService;
begin
    if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, xSvc) then
        xSvc.SetClipboard(TValue.From<string>(oFObsUrl.Text));
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnObsStartClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiedere alla finestra principale di avviare il servizio OBS (con i parametri del
//**        Setup, che vengono applicati e salvati).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnObsStartClick(oSender: TObject);
begin
    if not oFObsBtnStart.Enabled then
        Exit;
    ReadValues;
    eFObsAction := oaStart;
    ModalResult := mrOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnObsStopClick
//** Parametri di ingresso: oSender: TObject
//** Parametri di uscita: nessuno
//** Scopo: Chiedere alla finestra principale di fermare il servizio OBS (le modifiche del Setup
//**        vengono applicate e salvate).
//** Data Ultima Modifica: 31/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.BtnObsStopClick(oSender: TObject);
begin
    if not oFObsBtnStop.Enabled then
        Exit;
    ReadValues;
    eFObsAction := oaStop;
    ModalResult := mrOk;
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.BtnScanClick
//** Parametri di ingresso: oSender: TObject
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
procedure TfrmSetup.BtnScanClick(oSender: TObject);
var
    eDevice: TDeviceKind;
begin
    ReadValues;
    oFLog.Lines.Clear;
    RunScan;
    FillDeviceCombos;
    for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
        UpdateRowState(eDevice);
end;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: TfrmSetup.LogLine
//** Parametri di ingresso: sAText: string
//** Parametri di uscita: nessuno
//** Scopo: Aggiungere una riga in fondo al log della pagina Log.
//** Data Ultima Modifica: 27/10/2026
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.LogLine(const sAText: string);
begin
    oFLog.Lines.Add(sAText);
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
//** Aggiorna aFJoys, usato dalle combo della pagina Dispositivi.
//***********************************************************************************************************
//***********************************************************************************************************
procedure TfrmSetup.RunScan;
var
    iJoy, iNJoy, iNPad: Integer;
    eDevice: TDeviceKind;
    rWidget: TWidgetConfig;
    aPadOn: array[0..MAX_PADS - 1] of Boolean;
    sPov, sRes: string;
begin
    oFLog.Lines.BeginUpdate;
    try
        LogLine(Format(sTr('log.start', '[%s] Avvio scansione dispositivi'), [FormatDateTime('hh:nn:ss', Now)]));
        LogLine('');

        // joystick e pulsantiere: id WinMM 0..15
        LogLine(Format(sTr('log.joy.header', 'JOYSTICK E PULSANTIERE (WinMM, ID 0-%d)'), [MAX_JOY - 1]));
        aFJoys := oFInput.aEnumJoysticks;
        iNJoy := 0;
        for iJoy := 0 to High(aFJoys) do
            if aFJoys[iJoy].bPresent then
            begin
                Inc(iNJoy);
                if aFJoys[iJoy].bHasPOV then
                    sPov := sTr('log.yes', 'si''')
                else
                    sPov := sTr('log.no', 'no');
                LogLine(Format(sTr('log.joy.item', '    ID %2d   %s  -  %d assi, %d pulsanti, POV %s'),
                    [iJoy, aFJoys[iJoy].sName, aFJoys[iJoy].iNumAxes, aFJoys[iJoy].iNumButtons, sPov]));
                // lettura in background (Raw Input HID) e assi HID usati per X Y Z R U V
                if aFJoys[iJoy].bBackground then
                    LogLine(Format(sTr('log.joy.hid',
                        '             letto anche in background (HID)  -  assi X Y Z R U V = %s'),
                        [aFJoys[iJoy].sBgAxes]))
                else
                    LogLine(sTr('log.joy.nohid',
                        '             nessun dispositivo HID abbinato: aggiornato solo con HoloInput in primo piano'));
            end
            else
                LogLine(Format(sTr('log.joy.none', '    ID %2d   non collegato'), [iJoy]));
        LogLine(Format(sTr('log.joy.count', '    Rilevati: %d su %d'), [iNJoy, MAX_JOY]));
        LogLine(sTr('log.joy.note', '    Nota: WinMM gestisce max 32 pulsanti e 6 assi per dispositivo.'));
        LogLine('');

        // gamepad: slot XInput 1..4
        LogLine(sTr('log.pad.header', 'GAMEPAD (XInput)'));
        iNPad := 0;
        for iJoy := 0 to MAX_PADS - 1 do
        begin
            aPadOn[iJoy] := oFInput.bPadConnected(iJoy);
            if aPadOn[iJoy] then
                Inc(iNPad);
        end;
        if oFInput.bXInputAvailable then
        begin
            LogLine(sTr('log.pad.lib', '    Libreria XInput: disponibile'));
            for iJoy := 0 to MAX_PADS - 1 do
                if aPadOn[iJoy] then
                    LogLine(Format(sTr('log.pad.on', '    XInput %d   collegato'), [iJoy + 1]))
                else
                    LogLine(Format(sTr('log.pad.off', '    XInput %d   non collegato'), [iJoy + 1]));
        end
        else
            LogLine(sTr('log.pad.nolib', '    Libreria XInput: NON disponibile (i gamepad non possono essere letti)'));
        LogLine('');

        LogLine(sTr('log.kbm.header', 'TASTIERA E MOUSE'));
        LogLine(sTr('log.kbm.text', '    Sistema (Raw Input): sempre disponibili'));
        LogLine('');

        // widget visibili e dispositivo assegnato
        LogLine(sTr('log.widgets.header', 'WIDGET VISIBILI'));
        for eDevice := Low(TDeviceKind) to High(TDeviceKind) do
        begin
            rWidget := oFConfig.aWidgets[eDevice];
            if not rWidget.bVisible then
                Continue;
            case eDevice of
                dkKeyboard, dkMouse:
                    begin
                        sRes := sTr('log.widgets.system', 'Sistema (Raw Input)  -  OK');
                        if (eDevice = dkKeyboard) and oFConfig.bPrivacyMode then
                            sRes := sRes + sTr('log.widgets.privacy',
                                ' (nascosta: modalita'' privacy attiva)');
                    end;
                dkGamepad:
                    begin
                        iJoy := EnsureRange(rWidget.iDeviceIndex, 0, MAX_PADS - 1);
                        if not oFInput.bXInputAvailable then
                            sRes := Format(sTr('log.widgets.pad.nolib', 'XInput %d  -  ATTENZIONE: XInput non disponibile'), [iJoy + 1])
                        else if aPadOn[iJoy] then
                            sRes := Format(sTr('log.widgets.pad.ok', 'XInput %d  -  OK'), [iJoy + 1])
                        else
                            sRes := Format(sTr('log.widgets.pad.none', 'XInput %d  -  ATTENZIONE: nessun gamepad collegato'), [iJoy + 1]);
                    end;
            else
                iJoy := EnsureRange(rWidget.iDeviceIndex, 0, MAX_JOY - 1);
                if aFJoys[iJoy].bPresent then
                    sRes := Format(sTr('log.widgets.joy.ok', 'ID %d  %s  -  OK'), [iJoy, aFJoys[iJoy].sName])
                else
                    sRes := Format(sTr('log.widgets.joy.none', 'ID %d  -  ATTENZIONE: dispositivo non collegato'), [iJoy]);
            end;
            LogLine(Format('    %-16s %s', [sKindText(eDevice), sRes]));
        end;
        LogLine('');
        LogLine(Format(sTr('log.end', '[%s] Scansione completata: %d joystick/pulsantiere, %d gamepad.'),
            [FormatDateTime('hh:nn:ss', Now), iNJoy, iNPad]));
    finally
        oFLog.Lines.EndUpdate;
    end;
end;

end.
