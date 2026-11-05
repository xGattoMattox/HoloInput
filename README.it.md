# HoloInput — overlay olografico delle periferiche

*English: [README.md](README.md)*

Applicazione FireMonkey (Delphi 13 CE) che mostra in 3D, con look da ologramma, tastiera, mouse, gamepad, joystick e pulsantiere mentre si gioca.

> Per ora commenti del codice, intestazioni delle routine e documentazione tecnica sono **solo in italiano**; l'interfaccia è localizzata (italiano e inglese).

## Compilazione

1. Aprire `HoloInput.dproj` in RAD Studio 13 CE (serve Indy, incluso nell'IDE).
2. Selezionare la piattaforma **Windows 64-bit**.
3. Compilare ed eseguire. Il gioco deve essere in **finestra senza bordi** (borderless): in fullscreen esclusivo nessun overlay è visibile.

## Struttura

| Cartella | Contenuto |
|---|---|
| root | `HoloInput.dpr`, `Holo.Main` (overlay), `Holo.Setup`, `Holo.Config` (.ini), `Holo.Input` (Raw Input / Raw Input HID / XInput / WinMM), `Holo.Prims` (primitive olografiche), `Holo.Widget`, `Holo.Models` (registro modelli), `Holo.Skins`, `Holo.UI`, `Holo.Lang` (lingue), `Holo.Disclaimer` (avviso del primo avvio), `Holo.WebOverlay` (servizio Browser Source per OBS) |
| `MOUSE\` | `Mouse.Base`, `Mouse.Gaming`, `Mouse.Std` |
| `KEYBOARD\` | `Kbd.Base`, `Kbd.Iso100`, `Kbd.Ansi100`, `Kbd.TklIso`, `Kbd.TklAnsi` |
| `GAMEPAD\` | `Pad.ObjBase` (base comune dei gamepad 3D), `Pad.XboxObj` |
| `JOYSTICK.DX\` | `JoyDx.ObjBase` (base comune dei joystick 3D), `JoyDx.VirpilObj` |
| `JOYSTICK.SX\` | `JoySx.VirpilObj` (base del destro specchiata, impugnatura sinistra dedicata), `JoySx.VirpilZObj` (con prolunga asse Z) |
| `PULSANTI.DX\` | `BtnDx.Base`, `BtnDx.Grid16`, `BtnDx.Panel` |
| `PULSANTI.SX\` | `BtnSx.Grid16`, `BtnSx.Panel` |
| `SKINS\` | RSI, Origin, Drake, Anvil, Aegis, MISC, Crusader, Argo, CNOU, Tumbril |
| `OBJ\` | modelli 3D reali in stile ologramma (`.obj`) e posizione dei comandi (`.ini`) |
| `TOOLS\` | `holo_prep.py` per preparare i modelli 3D generati da una foto (il workflow ComfyUI resta privato, escluso dal repository); `lang_extract.py` per i file di lingua |
| `ARTWORK\` | avatar dell'autore (`avatar.png`, incorporato come risorsa `AVATAR_PNG`; non sostituibile: la pagina Info usa solo la risorsa incorporata; escluso dalla licenza GPL, tutti i diritti riservati) |
| `LANG\` | lingue dell'interfaccia: `italiano.ini`, `english.ini` (incorporate anche come risorse `LANG_ITALIANO` / `LANG_ENGLISH`) |

## Avvisi di sicurezza di Windows (exe non firmato)

`HoloInput.exe` **non è firmato digitalmente** (i certificati di firma del codice sono costosi per un progetto amatoriale gratuito), quindi al primo avvio Windows può mostrare un avviso:

- **SmartScreen** ("Windows ha protetto il PC"): fare clic su **Ulteriori informazioni → Esegui comunque**.
- **Smart App Control** (Windows 11) può bloccare le app non firmate senza l'opzione "Esegui comunque": per usare HoloInput va disattivato in *Sicurezza di Windows → Controllo app e browser → Smart App Control*. Prima di farlo leggere le note di Microsoft: a seconda della versione di Windows, riattivarlo può non essere immediato.
- **Falsi positivi degli antivirus**: HoloInput legge tastiera, mouse e controller in background (è così che l'overlay continua a funzionare mentre il gioco è in primo piano) e alcune euristiche degli antivirus lo trattano come un keylogger. HoloInput **mostra soltanto** gli input: non li registra, non li salva e non li invia da nessuna parte; l'unico servizio di rete è la pagina opzionale per OBS su `127.0.0.1` (il proprio PC).

**Verifica del download**: ogni release riporta lo **SHA-256** dello zip. Si controlla con `certutil -hashfile HoloInput-v<versione>-win64.zip SHA256` (oppure `Get-FileHash` in PowerShell): il valore deve coincidere con quello della pagina della release. In alternativa si può compilare l'exe dal codice sorgente (vedi *Compilazione*).

## Uso

- **Primo avvio**: compare l'**avviso legale** (software amatoriale fornito "così com'è", marchi di terzi, possibile impatto sulle prestazioni del gioco, software in continuo sviluppo) con la scelta di **lingua** e **skin**, che si applicano subito all'avviso. Con **Accetto** l'accettazione, la lingua e la skin si salvano nel `.ini` (`AvvisoAccettato`, `Lingua`, `Skin`) e l'avviso non viene più mostrato; con **Rifiuto** l'applicazione termina. Per rivederlo basta togliere `AvvisoAccettato=1` dal `.ini`.
- **Setup / Blocca layout / Esci**: barra comandi sempre in basso al centro del monitor principale, con l'etichetta sotto (da bloccato il pulsante diventa **Sblocca layout**). Nel layout Orizzontale (Basso) i widget si appoggiano sopra la barra.
- **Layout** (Setup): Orizzontale (Basso), Orizzontale (Alto), Verticale (Destra), Verticale (Sinistra), Personalizzato. I primi quattro dispongono automaticamente i widget sul monitor principale (centrati; se non ci stanno vanno a capo); è predefinito Orizzontale (Basso). Scegliendo un layout le posizioni vengono ricalcolate.
- **Sbloccato**: i widget si trascinano col mouse; basta spostarne uno perché il layout diventi **Personalizzato** (le posizioni si salvano nel .ini).
  Durante lo spostamento dall'angolo inferiore sinistro del widget partono due **linee guida verdi** (verticale e orizzontale) da bordo a bordo: arrivando a meno di 10 px da un lato di un altro widget si **agganciano** (diventano piene) e il widget si allinea esattamente a quel lato; le coordinate agganciate non vengono arrotondate alla griglia di 4 px.
- **Rotazione della vista**: tenendo premuto il **tasto destro** su un widget e muovendo il mouse a destra/sinistra il modello ruota attorno all'asse verticale (asse Z, come il twist), muovendolo avanti/indietro si inclina (asse Y, come il pitch). - **Zoom**: con la **rotella** su un widget il modello si ingrandisce (rotella in avanti) o si rimpicciolisce (indietro), da 0,3x a 3x.
- La vista si salva nel .ini (`VistaInclinazione`, `VistaRotazione`, `VistaZoom`) e il pulsante **Default** del Setup la riporta a quella predefinita.
  Afferrando bordi o angoli di un widget (maniglie colorate) lo si ridimensiona: le nuove misure compaiono anche nel Setup. Il tasto **Default** del Setup riporta la skin predefinita (RSI), il layout Orizzontale (Basso), margine, spaziatura e dimensioni iniziali dei widget, senza toccare le altre impostazioni.
- **Bloccato**: l'overlay è trasparente ai click (click-through) e non ruba il fuoco al gioco; solo la barra comandi resta cliccabile (Sblocca layout, Setup, Esci).
- Hotkey globali: `Ctrl+Alt+F12` blocca/sblocca · `Ctrl+Alt+F11` setup · `Ctrl+Alt+F10` mostra/nasconde · `Ctrl+Alt+F9` modalità streamer.
- Il Setup è diviso in pagine: **Generale**, **Dispositivi**, **Ampiezza**, **Modalità**, **Log**, **OBS**, **Info**.
- **Log** (Setup): resoconto del rilevamento dispositivi (joystick e pulsantiere WinMM ID 0–15 con nome, assi, pulsanti e POV, e per ognuno se è letto anche in background tramite HID e con quali assi; slot XInput 1–4; tastiera e mouse di sistema; widget visibili con il dispositivo assegnato, segnalando con ATTENZIONE quelli non collegati). Il pulsante **Esegui scansione** azzera il log ed esegue una nuova scansione; una prima scansione parte all'apertura del Setup.
- Nella pagina **Dispositivi** la colonna del dispositivo sorgente è nascosta: resta valido l'ID salvato in `HoloInput.ini` (chiave `Dispositivo`), e la pagina **Log** mostra quale dispositivo usa ogni widget.
  Per il debug, avviando con `HoloInput.exe -o DebugDevices` la colonna **Dispositivo sorgente** ricompare e si può scegliere a mano il dispositivo di ogni widget (il titolo del Setup mostra `[DEBUG DEVICES]`). In Delphi: *Run > Parameters*, campo *Parameters* = `-o DebugDevices`.
- **Ampiezza del movimento dei joystick** (Setup, pagina **Ampiezza**): per ogni joystick e per ogni asse si imposta l'angolo totale di escursione in gradi (0–180). Con 60° l'asse a fine corsa va da −30° a +30° rispetto al centro. X = inclinazione sinistra/destra, Y = avanti/indietro, Z = rotazione dell'impugnatura (twist); predefiniti X 36°, Y 36°, Z 50°. Accanto a ogni asse il menu **Inverti** (Si/No) ne rovescia il verso. Si salva nel .ini (`AmpiezzaX`, `AmpiezzaY`, `AmpiezzaZ`, `InvertiX`, `InvertiY`, `InvertiZ`).
- **Stile dei widget** (Setup, pagina **Generale**, riquadro *Stile dei widget*): **Pannello** (sfondo, cornice, titolo e stato) oppure **Solo dispositivo**: resta visibile solo il modello 3D su sfondo completamente trasparente (anche nel fotogramma per OBS). In questo stile titolo, cornice tratteggiata e maniglie compaiono solo con il layout sbloccato e solo quando il mouse è sopra il widget; per poterlo afferrare anche nelle zone vuote il widget ha una velatura invisibile (sui pixel del tutto trasparenti i click passerebbero sotto). L'avviso compare solo se il dispositivo non è collegato. La casella **Effetti di base** mostra o nasconde gli anelli del proiettore e la linea di scansione. Si salvano nel .ini (`StileWidget` = `Pannello` / `SoloDispositivo`, `EffettiBase`); il pulsante **Default** li riporta a Pannello con effetti di base.
- **Modalità streamer**: nasconde i pulsanti della barra comandi; resta solo l'etichetta con il tasto rapido (`Ctrl+Alt+F9`) per farli ricomparire.
- **Modalità privacy**: il widget della tastiera non viene mai mostrato (per non far vedere password in diretta); ricompare solo disattivando la modalità.
- **Servizio OBS** (Setup, pagina **OBS**): HoloInput fa da *Browser Source* per OBS, così l'overlay compare nella diretta senza stare sullo schermo.
  - Parametri: **porta** (predefinita 8765), **fotogrammi al secondo** (15, 30 o 60; predefinito 30), **risoluzione** della pagina (inizialmente quella **nativa del monitor principale**, ripristinabile col pulsante *Risoluzione nativa*), modo di **occultamento** della finestra: nascosta, spostata fuori dallo schermo oppure **spostata su un altro monitor**, scelto da un elenco dei monitor collegati che esclude il principale (dove gira l'overlay); la finestra viene allineata al bordo del monitor lontano dal principale, così l'eventuale parte in eccesso non ricade sul principale. Se il monitor scelto non è più collegato la finestra va fuori dallo schermo. Si salvano nel .ini, sezione `[OBS]` (`Porta`, `FPS`, `Larghezza`, `Altezza`, `Occultamento`, `Monitor` = nome del dispositivo, es. `\\.\DISPLAY2`).
  - **Avvia il servizio** (applica e salva anche le modifiche del Setup): il layout viene bloccato, parte un server HTTP/WebSocket **solo locale** (`http://127.0.0.1:<porta>/`) e HoloInput scompare dallo schermo. Al ritmo scelto i widget visibili vengono fotografati e composti nell'area che occupano, ognuno nella **stessa posizione che ha sullo schermo** (con un'altra risoluzione la disposizione viene scalata in proporzione); compressione PNG e invio avvengono in thread separati e la pagina riceve i fotogrammi da una connessione **WebSocket** continua (`/ws`), disegnandoli su un canvas trasparente grande quanto la risoluzione del servizio. Se la connessione cade la pagina si ricollega da sola; `/frame.png` mostra l'ultimo fotogramma per verifica.
  - In OBS: *Fonti > + > Browser*, URL = l'indirizzo mostrato nella pagina (*Copia indirizzo*), larghezza/altezza = la risoluzione impostata, *Usa frequenza fotogrammi personalizzata* = gli stessi fps, *Spegni la fonte quando non visibile* disattivato. Se il canvas di OBS è più piccolo del monitor, impostare nel Setup la sua risoluzione di base.
  - `Ctrl+Alt+F11` riapre il Setup sulla pagina OBS, con lo **stato** del servizio: fotogrammi preparati (e al secondo effettivi), inviati a OBS, connessioni aperte, tempo di cattura (thread principale) e di codifica, pixel visibili dell'ultimo fotogramma (se sono 0 la finestra occultata non viene disegnata: provare un altro modo di occultamento). Da lì **Ferma il servizio** (attivo solo con il servizio avviato, come *Avvia il servizio* solo con il servizio fermo); premendo *Salva* con il servizio attivo il servizio si riavvia con i nuovi parametri. Con il servizio attivo le altre hotkey sono ignorate.
  - **Avvia il servizio all'avvio di HoloInput** (casella nella pagina OBS, chiave `AvvioAutomatico` in `[OBS]`): all'avvio HoloInput avvia subito il servizio e si occulta come scelto (dopo l'eventuale avviso del primo avvio).
- La configurazione è in `HoloInput.ini` accanto all'eseguibile; viene letta all'avvio se esiste.
  Solo da .ini: `VistaInclinazione`, `VistaRotazione`, `VistaZoom` per ogni widget e `Animazioni` in `[Generale]` (anelli rotanti, scansione e sfarfallio olografico; predefinito `1`).

## Lingue

- Ogni scritta mostrata a video passa da `Tr('chiave', 'testo predefinito')` (unit `Holo.Lang`): il testo predefinito è l'italiano scritto nel codice.
- Ogni lingua ha il suo file nella cartella `LANG\` accanto all'eseguibile: `italiano.ini`, `english.ini`, … Formato (UTF-8):
  ```
  [Lingua]
  Nome=English
  [Testi]
  setup.gen.language=Language
  setup.legends.text=Prima riga\n\nSeconda riga
  ```
  `\n` = a capo, `\\` = barra rovescia; un testo che inizia o finisce con spazi va tra virgolette; i segnaposto `%d` / `%s` vanno mantenuti nello stesso ordine. Una chiave mancante usa il testo predefinito.
- I testi della pagina **Info** (Citizen Dossier dell'autore e informazioni sul software) passano da `TrBuiltin`: valgono solo quelli incorporati nell'exe (lingua corrente se incorporata, altrimenti inglese) e non si possono modificare dai file di `LANG\`; nei file sono segnalati da un commento.
- Italiano e inglese sono incorporati nell'exe (`HoloObj.rc`); un file in `LANG\` ha la precedenza, quindi si possono correggere i testi senza ricompilare. Per una nuova lingua basta copiare `english.ini` con un altro nome (es. `deutsch.ini`), cambiare `Nome=` e tradurre: compare da sola nel Setup.
- La lingua si sceglie nel Setup, pagina **Generale** (riquadro Aspetto): il Setup si riapre subito nella nuova lingua; si salva nel `.ini` come `Lingua=`.
- `python TOOLS/lang_extract.py` rigenera `LANG/italiano.ini` dalle chiamate `Tr` / `TrBuiltin` del codice; `python TOOLS/lang_extract.py --check LANG/english.ini` elenca le chiavi mancanti in una traduzione.

## Licenza

GNU GPL v3 con termini aggiuntivi della sezione 7 (file [LICENSE](LICENSE)): obbligo di mantenere inalterate la menzione dell'autore e la pagina **Info** in ogni copia o versione modificata (7b); le versioni modificate vanno indicate come tali e non possono presentarsi come l'originale (7c); nessun diritto su nome HoloInput, pseudonimo e avatar dell'autore, le versioni modificate ridistribuite devono usare un altro nome (7e). L'avatar è escluso dalla GPL: tutti i diritti riservati.

## Aggiungere un dispositivo o una skin

1. Creare la unit nella cartella giusta, derivando da `TKeyboardModel`, `TMouseModel`, `TObjPadModel` (vedi "Gamepad 3D da file OBJ"), `TObjStickModel` (vedi "Joystick 3D da file OBJ"), `TButtonBoxModel` (o da `TSkin`).
2. Registrarla nella `initialization` con `RegisterModel(...)` / `RegisterSkin(...)`.
3. Aggiungerla alla clausola `uses` di `HoloInput.dpr`. Compare da sola nel Setup.

## Note tecniche

- Tastiera identificata per **scan code** (posizione fisica): funziona con qualunque lingua di Windows.
- Joystick/pulsantiere: identificati dall'ID WinMM (0–15), max 6 assi, 32 pulsanti, 1 POV per dispositivo. WinMM aggiorna i dati solo quando HoloInput è in primo piano, quindi ogni ID viene abbinato al dispositivo **Raw Input HID** con lo stesso VID/PID (a parità di VID/PID in ordine di nome) e letto da lì, anche in background (mentre si gioca o si clicca altrove). Assi HID → assi WinMM: X, Y, Z (o Slider/Dial), R = Rz (o Ry/Slider/Dial), U = Rx, V = Ry (o Slider/Dial). Senza abbinamento HID resta la lettura WinMM.
- Se il gioco gira come amministratore, avviare anche HoloInput come amministratore.
- Se le rotazioni 3D risultassero invertite nella propria versione di FMX, impostare `ROT_SIGN = -1` in `Holo.Models.pas`.

## Geometria ad alta definizione

- `THoloLoft` (in `Holo.Prims`) costruisce superfici curve da una serie di sezioni (superellissi) lungo X, Y o Z: scocche dei mouse, tasti.
- `THoloKit.RBox` crea parallelepipedi arrotondati e smussati (copritasti rastremati, piastre, pulsanti).
- Cilindri e sfere sono a 32 lati.

## Mesh 3D da immagine (TOOLS\)

I modelli di `OBJ\` sono stati generati con **IA generativa locale** (pipeline image-to-3D eseguita interamente sul PC, senza servizi cloud): workflow ComfyUI personalizzato (privato, non incluso nel repository: `TOOLS\holo_trellis2_ologramma.json` è escluso dal `.gitignore`) con il modello **Pixal3D** (`pixal3d_int8_convrot`, diffusion transformer quantizzato INT8), condizionamento DINOv3, stima di geometria/FOV MoGe-2, rimozione dello sfondo BiRefNet e VAE di forma TRELLIS.2; uno switch del workflow permette di usare **TRELLIS.2** come generatore alternativo. Non è un requisito: va bene qualunque mesh nel formato OBJ descritto sotto (altri modelli image-to-3D, fotogrammetria, CAD, Blender, modellazione a mano), ognuno può usare il metodo che preferisce.

1. `holo_trellis2_ologramma.json` (solo nella copia locale): workflow ComfyUI (Pixal3D / TRELLIS.2) solo geometria: niente texture, remesh e decimazione a 20.000 facce, spigoli netti. Salva `output/3d/holo_XXXXX.glb`.
2. `python holo_prep.py holo_00001.glb --pivot top --largest`: raddrizza, imposta il pivot e ricava le linee dell'ologramma.
   Esce `holo_00001_holo.obj` con `o holo_fill` (triangoli del riempimento traslucido) e `o holo_lines` (polilinee `l` degli spigoli), Y in alto.
   Impugnature: `--align stick --pivot bottom --scale 0.66` (asse del connettore in verticale, grilletto verso +Z). In alternativa `--align none --rot X Y Z` con i valori del pannello N di Blender.
3. Copiare i due `.obj` nella cartella `OBJ\` (vedi sotto).

## Joystick 3D da file OBJ

- `JoyDx.VirpilObj` (destro) e `JoySx.VirpilObj` (sinistro), predefiniti per i due widget, usano `OBJ\warbrd_holo.obj` (base fissa, specchiata per il sinistro) e l'impugnatura `OBJ\vpap_r_holo.obj` (destra) o `OBJ\vpap_l_holo.obj` (sinistra, modello dedicato non specchiato, allineato all'immagine speculare della destra).
- Il codice comune è in `JOYSTICK.DX\JoyDx.ObjBase`; il lettore OBJ e la mesh olografica in `Holo.Obj`.
- Disegno: riempimento traslucido, spigoli vivi del file (`o holo_lines`) e **contorno ricalcolato quando l'impugnatura ruota**.
- L'impugnatura ruota sui tre assi attorno al gimbal (`GimbalDepth`, poco sotto la cima della torretta).
- I file sono incorporati nell'exe (`HoloObj.res`, generato da `HoloObj.rc` con `TOOLS\build_res.bat`); un file con lo stesso nome in `OBJ\` accanto all'exe ha la precedenza.
- `OBJ\vpap_r_holo.ini` / `OBJ\vpap_l_holo.ini`: posizione dei pulsanti e dell'hat, in coordinate di Blender (vedi commenti nel file). Senza questo file l'impugnatura si muove ma i comandi non si accendono.
- `JoySx.VirpilZObj` (sinistro con **prolunga asse Z**, Flightstick Z-Extension): base `warbrd_holo`, prolunga `OBJ\zaxis_holo.obj` innestata sulla torretta, impugnatura sinistra (`vpap_l_holo`) montata sul collare superiore della prolunga e allineata al suo asse. Punto e asse di montaggio (e rollio) in `OBJ\zaxis_holo.ini`, modificabili senza ricompilare. La prolunga non viene specchiata (la scritta VPC resta leggibile) e si muove con il gimbal: pitch e roll (assi X e Y) ruotano sulla base, mentre il twist (asse Z) ruota l'impugnatura attorno al proprio asse sul collare terminale della prolunga, dove si innesta.
- Preparazione della prolunga: `python prep_prolunga.py zaxis.obj --yaw 30 --scale 0.456` (raddrizza il pezzo sul collare inferiore e stampa Punto/Asse per il file `.ini`), poi `python holo_prep.py zaxis_up.obj -o zaxis_holo.obj --align none --pivot none --scale 0.456 --angle 30 --region 0.2 --min-len 1.5`.
- Per aggiungere un altro joystick: generare base e impugnatura, prepararle con `holo_prep.py`, copiarle in `OBJ\`, aggiungerle a `HoloObj.rc` e creare una unit come `JoyDx.VirpilObj` con i nuovi nomi in `ObjStickSpec`.

## Gamepad 3D da file OBJ

- `Pad.XboxObj` usa `OBJ\xbox_holo.obj` (corpo) e `OBJ\xbox_holo.ini` (posizione dei comandi); il codice comune è in `GAMEPAD\Pad.ObjBase`.
- Preparazione del modello: `python holo_prep.py xbox.obj --align pad --pivot center --angle 30 --region 0.1 --min-len 1`.
- Il corpo è fisso; le levette sono cappucci olografici che seguono l'input, pulsanti e croce sono luci che compaiono quando premuti, i grilletti si illuminano in proporzione alla pressione.
- Le posizioni nel file `.ini` sono in coordinate di Blender (vedi commenti nel file) e si possono correggere senza ricompilare mettendo il file in `OBJ\` accanto all'exe.
