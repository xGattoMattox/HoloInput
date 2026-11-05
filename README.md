# HoloInput — holographic input overlay

**HoloInput** shows your input devices — keyboard, mouse, gamepad, joysticks and button boxes — as live **3D holograms** while you play. It was built for *Star Citizen* pilots and streamers, but it works with any game running in a borderless window.

*Italiano: [README.it.md](README.it.md)*

---

## Features

- **Real-time 3D widgets** for keyboard (ISO/ANSI, full size and TKL), mouse, Xbox-style gamepad, joysticks (including the left-hand stick with a Z-axis extension) and button boxes. Keys, buttons, axes, hats and twist move as you use them.
- **10 skins** inspired by the *Star Citizen* manufacturers: RSI (default), Origin, Drake, Anvil, Aegis, MISC, Crusader, ARGO, CNOU and Tumbril.
- **Two widget styles**:
  - **Panel**: background, frame, title and device status.
  - **Device only**: just the 3D model on a fully transparent background.
- **Layouts**: horizontal (bottom or top), vertical (left or right), or **custom**, where you drag widgets freely. Green alignment guides snap them to each other.
- **Per-widget view**:
  - **Rotate:** hold the right mouse button and drag.
  - **Zoom:** use the mouse wheel.
  - **Resize:** drag the edges or corners.
- **Joystick movement range**: set the total travel angle of each axis (X, Y, twist) to match your real sticks, and invert any axis (Yes/No).
- **Click-through overlay**: when locked, the overlay never steals focus from the game.
- **All input is read in the background**, so the overlay keeps working while the game (or any other window) has focus:
  - keyboard and mouse: Raw Input;
  - gamepads: XInput;
  - joysticks and button boxes: Raw Input HID.
- **Streamer mode** hides the command bar. **Privacy mode** always hides the keyboard, so you never show a password on stream.
- **OBS Browser Source service**: HoloInput streams the overlay to OBS through a local WebSocket page, with transparency, at 15, 30 or 60 fps. It can then hide itself from the screen:
  - hidden window;
  - moved off-screen;
  - moved to another monitor.
- **Localization**: Italian and English are included. Every on-screen text can be translated with a simple `.ini` file.

## Requirements

- Windows 10 or 11, 64-bit.
- A graphics card with Direct3D 11 support.
- The game must run in **borderless window** mode. No overlay can be drawn over a game in exclusive fullscreen.
- Optional: [OBS Studio](https://obsproject.com/) for the Browser Source service.

## Installation

1. Download the latest zip from the [Releases](https://github.com/xGattoMattox/HoloInput/releases) page.
2. Extract it to a folder **where you have write permission**, such as `Documents\HoloInput`. Avoid `Program Files`: HoloInput saves its settings in `HoloInput.ini` next to the executable.
3. Run `HoloInput.exe`. On the first launch you accept the notice and choose language and skin.

Nothing is installed in the system and there is no registry entry. To uninstall, delete the folder.

### Windows security warnings

`HoloInput.exe` is **not digitally signed** (code-signing certificates are expensive for a free hobby project), so Windows may warn you the first time you run it:

- **SmartScreen** ("Windows protected your PC"): click **More info → Run anyway**.
- **Smart App Control** (Windows 11) may block unsigned apps with no "Run anyway" option. To use HoloInput you have to turn it off in *Windows Security → App & browser control → Smart App Control*. Read Microsoft's notes before you do: depending on your Windows version, turning it back on may not be immediate.
- **Antivirus false positives**: HoloInput reads keyboard, mouse and controllers in the background (that is how the overlay keeps working while the game has focus). Some antivirus heuristics treat this like a keylogger. HoloInput **only displays** your inputs: it never records, saves or sends them anywhere, and the only network service is the optional OBS page on `127.0.0.1` (your own PC).

**Verify your download:** every release lists the **SHA-256** of the zip. Check it with `certutil -hashfile HoloInput-v<version>-win64.zip SHA256` (or `Get-FileHash` in PowerShell): the value must match the one on the release page. If you prefer, build the exe yourself from the source code (see *Building from source*).

## Quick start

| Hotkey | Action |
|---|---|
| `Ctrl+Alt+F12` | Lock / unlock the layout (locked = click-through) |
| `Ctrl+Alt+F11` | Open the Setup |
| `Ctrl+Alt+F10` | Show / hide the overlay |
| `Ctrl+Alt+F9` | Streamer mode (hide the command bar) |

- **Unlocked**: drag widgets with the left button, resize them from the edges, rotate the view with the right button and zoom with the wheel.
- **Setup** pages:
  - **General**: skin, language, layout, options, widget style.
  - **Devices**: which widgets to show and the 3D model of each.
  - **Range**: joystick travel angles and axis inversion.
  - **Modes**: streamer and privacy modes.
  - **Log**: device detection.
  - **OBS**: the Browser Source service.
  - **Info**: about HoloInput and its author.
- **Device assignment**: devices are assigned automatically. To pick the source device of each widget by hand, start HoloInput with `HoloInput.exe -o DebugDevices`.

## Using HoloInput with OBS

1. In HoloInput open **Setup → OBS**. Check the port (default `8765`) and the resolution. The default is your monitor's native resolution, so widgets appear in OBS exactly where they are on screen. If your OBS canvas is smaller, enter the canvas size here.
2. Press **Start the service**. HoloInput disappears from the screen and keeps running.
3. In OBS add **Sources → + → Browser**:
   - **URL**: `http://127.0.0.1:8765/` (the *Copy address* button copies it);
   - **Width / Height**: the resolution set in HoloInput;
   - tick **Use custom frame rate** and set the same fps as in HoloInput;
   - untick **Shutdown source when not visible**.
4. Press `Ctrl+Alt+F11` to bring the Setup back and **Stop the service**.

Tick **Start the service when HoloInput launches** if you want it to start automatically.

The service listens on `127.0.0.1` only, so it is not reachable from other computers and does not trigger the firewall.

## Translations

The interface texts are in `LANG\<language>.ini`, for example `english.ini`. To add a language, copy `english.ini` to a new name such as `deutsch.ini`, change `Nome=`, translate the values and restart: the language appears in **Setup → General**. In the values, `\n` is a line break. Keep placeholders such as `%d` and `%s` in the same order.

The texts of the **Info** page (author's Citizen Dossier and program information) and the author's avatar are embedded in the executable and cannot be changed through these files.

## Building from source

1. Install **RAD Studio / Delphi 13** (the Community Edition works). The Indy components it ships with are required.
2. Open `HoloInput.dproj`, select the **Windows 64-bit** platform and build.
3. The 3D models (`OBJ\`), the avatar and the built-in languages are embedded through `HoloObj.rc` → `HoloObj.res`. After changing them, run `TOOLS\build_res.bat` from the *RAD Studio Command Prompt*.
4. `python TOOLS/lang_extract.py` regenerates `LANG/italiano.ini` from the code. `--check LANG/english.ini` lists missing translations.

The Italian README ([README.it.md](README.it.md)) documents the source layout, the `.ini` keys and the internals in detail.

### Development notes

- **Language of the sources:** for now all code comments, routine headers and the technical documentation (README.it.md, comments in `TOOLS\`) are in **Italian only**. The user interface is localized (Italian and English).
- **How the 3D models were made:** the hologram meshes in `OBJ\` were generated with **local generative AI**, an image-to-3D pipeline running entirely on the author's PC with no cloud service. The author's custom [ComfyUI](https://github.com/comfyanonymous/ComfyUI) workflow is private and not included in the repository:
  - **Generation:** model **Pixal3D** (`pixal3d_int8_convrot`, INT8-quantized diffusion transformer), with DINOv3 image conditioning, MoGe-2 geometry/FOV estimation, BiRefNet background removal and the TRELLIS.2 shape VAE. A switch in the workflow selects **TRELLIS.2** as the alternative generator.
  - **Mesh processing:** geometry only, without the texture branch. The mesh is remeshed and decimated to about 20k faces and exported as `.glb`.
  - **Conversion for HoloInput:** `TOOLS\holo_prep.py` (Python + NumPy) aligns the mesh, sets the pivot, extracts the sharp edges and writes the OBJ format the app expects: object `holo_fill` (translucent triangles) plus `holo_lines` (`l` polylines of the edges).
- **Use the pipeline you prefer:** none of this is required. Any mesh in that OBJ layout works, whatever tool produced it: other image-to-3D models (such as Hunyuan3D or TripoSR), photogrammetry, CAD or Blender, or modelling by hand. See the "Joystick 3D da file OBJ" and "Gamepad 3D da file OBJ" sections of README.it.md for the `.ini` that places the controls on the model.

## Notice

HoloInput is a **hobby project**, developed in my spare time:
- **Free version:** this version is distributed free of charge, "as is", without warranty of any kind.
- **Game performance:** the overlay renders in 3D on top of the game and may affect game performance to some degree.
- **Trademarks:** *Star Citizen®*, *Roberts Space Industries®* and *Cloud Imperium Games* are trademarks of Cloud Imperium Rights LLC. The manufacturer names used for the skins, Virpil Controls and Xbox® belong to their respective owners. HoloInput is not affiliated with, sponsored or endorsed by any of them.

## License

HoloInput is released under the **GNU General Public License v3** with additional terms (section 7) — see [LICENSE](LICENSE). In short:

- You may use, study, modify and redistribute it, also commercially, as long as the source of your version is published under the same license.
- Every copy or modified version must keep the author attribution and the **Info** page (Citizen Dossier and information card) unaltered.
- Modified versions must be marked as such, must not be presented as the original and must use a different name while keeping the credit (e.g. "StarOverlay - Based on HoloInput by Citizen GattoMatto").
- The author's **avatar** is not covered by the GPL: all rights reserved, redistributable only unchanged in the Info page.

## Author

**Citizen GattoMatto**: [RSI Citizen Dossier](https://robertsspaceindustries.com/en/citizens/GattoMatto)
