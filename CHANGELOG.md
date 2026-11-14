# Changelog

All notable changes to HoloInput are listed here, newest first.
Versions follow the exe's version info (`Major.Year.Month.Day`).

## [0.2026.11.13] - 2026-11-13

### Added

- **Throttles.** Two new widgets, *Left throttle* and *Right throttle* (hidden by default, turn them on in *Setup → Devices*), with a generic 3D throttle: the lever moves forward and back with the main axis, the mini-stick tilts with its two axes, the hat lights up in the pressed direction and 6 buttons press and light up. In *XYZ axes* the first number is the lever and the other two the mini-stick (default `2,0,1`); *Setup → Range* has a new *Throttles* box for the lever and mini-stick ranges and their *Invert* options.

### Changed

- **Code: unified naming style.** Internal clean-up of the source code: names across the whole project now follow a single, consistent convention. Nothing changes in how HoloInput works.

### Security

- **OBS service: only OBS can connect.** The local OBS server now answers only requests addressed to `127.0.0.1` or `localhost` on its own port, and accepts a WebSocket connection only from its own overlay page. Before, any website open in your browser while the service was running could connect to it and receive the overlay frames (and so see which keys you were pressing). Nothing changes in OBS: keep using the Browser source URL shown in *Setup → OBS*.
- **OBS service: one connection only.** The service now accepts a single overlay connection at a time (the one from OBS); any other is refused until it closes, and the page retries on its own every second. To allow a second connection (for example to check the overlay in a browser while OBS is connected) start HoloInput with the `SecondConnection` option, e.g. `HoloInput.exe -o SecondConnection`. Opening `/frame.png` in a browser is not affected by this limit.
- **Updates: official downloads only.** The updater now downloads only files whose address starts with `https://github.com/xGattoMattox/HoloInput/releases/download/`, opens only release pages of the official repository, and saves the downloaded zip under a fixed name in the temporary folder instead of the name given by GitHub.
- **Updates: size limits.** A release zip larger than 200 MB, or a checksum file larger than 64 KB, cancels the update instead of being downloaded.
- **OBS service: stricter message checks.** Malformed WebSocket messages (unmasked, with an invalid length, or control messages longer than the protocol allows) now close the connection.
- **System DLLs only.** HoloInput now loads XInput, `hid.dll` and `winmm.dll` only from the Windows system folder, and no longer looks for DLLs next to the executable or in the current folder first, so a DLL with the same name placed there is not loaded.
- **Safer file names.** The language name read from `HoloInput.ini` and the names of the 3D model files can no longer point outside the `LANG` and `OBJ` folders (a name containing a path falls back to the default language or to the built-in model).
- **Links and controller data.** HoloInput opens only `https://` web addresses, and ignores a controller data packet whose declared size does not match the data actually received.

## [0.2026.11.8] - 2026-11-08

### Added

- **Automatic updates.** At startup HoloInput checks the official GitHub releases. When a newer version is available it asks you (*Update* / *Later*) in a window that shows what's new (the sections of this changelog for the versions after yours), downloads it with a progress bar, verifies it against the release's SHA-256 file, replaces its executable and restarts on the new version. Your settings are kept. *Setup → Info* has a *Check for updates* button and a *Check at startup* box. The automatic check never interrupts you while the Setup is open or the OBS service is running.
- **Auto hide for idle widgets.** New option in *Setup → General → Options*: *Hide idle widgets after N seconds* (5 seconds by default, from 1 to 600). When it is on, the widget of a device fades out after that time without input from that device and comes back as soon as you use it again. A held key or button, a moving axis, a deflected gamepad stick or a mouse movement all count as input; a joystick axis that stays still (for example a throttle left in position) does not. With the layout unlocked the widgets always stay visible, and hidden widgets are left out of the OBS frames.
- **Move the model up or down inside a widget.** Hold **Shift** and the **right mouse button** on a widget, then move the mouse forward to move the model up or back to move it down. Useful when a tall model (for example a joystick) doesn't sit where you want in its frame. The position is saved with the other view settings, and *Setup → Default* resets it.

### Changed

- **OBS: changing the frame rate restarts the service right away.** If you change *Frames per second* in *Setup → OBS* while the service is running, HoloInput stops and restarts it immediately with the new value, without waiting for *Save*. A confirmation window warns you first that the service will be restarted: choose *Restart* to go ahead, or *Cancel* to keep the current frame rate. OBS reconnects on its own. The new value is saved even if you then close the Setup with *Close*. Remember to set the same fps in the OBS Browser source.
- **Setup: the device drop-down is always visible.** *Setup → Devices* now always shows the *Source device* column, so you can pick the hardware device of each widget (joysticks, button boxes, gamepads) without any start option. The `-o DebugDevices` start option has been removed.
- **Ctrl+Alt+F11 brings the command bar back.** Opening the Setup with `Ctrl+Alt+F11` now also turns streamer mode off, so when you close the Setup the command bar and the label below it are visible again.
- **Setup: "Locked only" tags.** Options that work only with the layout locked (*Hide idle widgets*, the OBS service) now carry a **LOCKED ONLY** tag, explained by a legend at the bottom of the Setup. Everything without the tag works both locked and unlocked.

### Fixed

- **Setup: numbers typed in a field are saved.** A value typed in a numeric field (margin, spacing, mouse range, OBS port and resolution, widget positions and sizes, joystick ranges, the *Hide idle widgets* seconds…) is now saved even if you press *Save* right away, without pressing Enter or leaving the field first.
- **Virpil joysticks: correct twist axis.** When you choose a Virpil model in *Setup → Devices* (right stick, left stick and left stick with the Z-axis extension), the *XYZ axes* field is now set to `0,1,2`, because on Virpil grips the twist is the Windows **Z** axis. New configurations use the same mapping. If you already use a Virpil stick, enter `0,1,2` in the *XYZ axes* field once (or pick another model and then the Virpil one again).

## [0.2026.11.4] - 2026-11-05

- First public release.
