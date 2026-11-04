//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome programma: HoloInput
//** Scopo: Overlay olografico delle periferiche di input (programma principale).
//** Data Ultima Modifica: 04/11/2026
//***********************************************************************************************************
//** Funzionamento: Delphi 13 CE - FireMonkey - Windows (Win64 / Win32).
//**
//** Struttura:
//**   root          core dell'app (schermo, input, configurazione, widget)
//**   MOUSE\        sketch 3D dei mouse
//**   KEYBOARD\     sketch 3D delle tastiere
//**   GAMEPAD\      gamepad da modelli 3D reali (+ base comune Pad.ObjBase)
//**   JOYSTICK.DX\  joystick destri da modelli 3D reali (+ base comune JoyDx.ObjBase)
//**   JOYSTICK.SX\  joystick sinistri (stessi modelli specchiati)
//**   PULSANTI.DX\  sketch 3D delle pulsantiere destre (+ base comune)
//**   PULSANTI.SX\  sketch 3D delle pulsantiere sinistre
//**   SKINS\        skin colore ispirate ai produttori di Star Citizen
//**   OBJ\          modelli 3D reali (OBJ preparati con TOOLS\holo_prep.py)
//**   TOOLS\        script di preparazione dei modelli 3D e dei file di lingua
//**
//** Per aggiungere un dispositivo o una skin basta aggiungere la unit qui sotto:
//** si registra da sola nella propria sezione initialization.
//***********************************************************************************************************
//***********************************************************************************************************
program HoloInput;

uses
    System.StartUpCopy,
    FMX.Forms,
    Holo.Main in 'Holo.Main.pas' {frmMain},
    Holo.Setup in 'Holo.Setup.pas' {frmSetup},
    Holo.Config in 'Holo.Config.pas',
    Holo.Input in 'Holo.Input.pas',
    Holo.Skins in 'Holo.Skins.pas',
    Holo.Prims in 'Holo.Prims.pas',
    Holo.Models in 'Holo.Models.pas',
    Holo.Widget in 'Holo.Widget.pas',
    Holo.UI in 'Holo.UI.pas',
    Holo.Dialog in 'Holo.Dialog.pas',
    Holo.About in 'Holo.About.pas',
    Holo.Obj in 'Holo.Obj.pas',
    Holo.Lang in 'Holo.Lang.pas',
    Holo.Disclaimer in 'Holo.Disclaimer.pas',
    Holo.WebOverlay in 'Holo.WebOverlay.pas',
    //** skin (l'ordine e' quello del menu nel setup) *******************************************************
    Skin.RSI in 'SKINS\Skin.RSI.pas',
    Skin.Origin in 'SKINS\Skin.Origin.pas',
    Skin.Drake in 'SKINS\Skin.Drake.pas',
    Skin.Anvil in 'SKINS\Skin.Anvil.pas',
    Skin.Aegis in 'SKINS\Skin.Aegis.pas',
    Skin.MISC in 'SKINS\Skin.MISC.pas',
    Skin.Crusader in 'SKINS\Skin.Crusader.pas',
    Skin.Argo in 'SKINS\Skin.Argo.pas',
    Skin.CNOU in 'SKINS\Skin.CNOU.pas',
    Skin.Tumbril in 'SKINS\Skin.Tumbril.pas',
    //** tastiere *******************************************************************************************
    Kbd.Base in 'KEYBOARD\Kbd.Base.pas',
    Kbd.Iso100 in 'KEYBOARD\Kbd.Iso100.pas',
    Kbd.Ansi100 in 'KEYBOARD\Kbd.Ansi100.pas',
    Kbd.TklIso in 'KEYBOARD\Kbd.TklIso.pas',
    Kbd.TklAnsi in 'KEYBOARD\Kbd.TklAnsi.pas',
    //** mouse **********************************************************************************************
    Mouse.Base in 'MOUSE\Mouse.Base.pas',
    Mouse.Gaming in 'MOUSE\Mouse.Gaming.pas',
    Mouse.Std in 'MOUSE\Mouse.Std.pas',
    //** gamepad ********************************************************************************************
    Pad.ObjBase in 'GAMEPAD\Pad.ObjBase.pas',
    Pad.XboxObj in 'GAMEPAD\Pad.XboxObj.pas',
    //** joystick destri / sinistri *************************************************************************
    JoyDx.ObjBase in 'JOYSTICK.DX\JoyDx.ObjBase.pas',
    JoyDx.VirpilObj in 'JOYSTICK.DX\JoyDx.VirpilObj.pas',
    JoySx.VirpilObj in 'JOYSTICK.SX\JoySx.VirpilObj.pas',
    JoySx.VirpilZObj in 'JOYSTICK.SX\JoySx.VirpilZObj.pas',
    //** pulsantiere destre / sinistre **********************************************************************
    BtnDx.Base in 'PULSANTI.DX\BtnDx.Base.pas',
    BtnDx.Grid16 in 'PULSANTI.DX\BtnDx.Grid16.pas',
    BtnDx.Panel in 'PULSANTI.DX\BtnDx.Panel.pas',
    BtnSx.Grid16 in 'PULSANTI.SX\BtnSx.Grid16.pas',
    BtnSx.Panel in 'PULSANTI.SX\BtnSx.Panel.pas';

{$R *.res}
{$R HoloObj.res}      // modelli 3D olografici (cartella OBJ)   - rigenerare con TOOLS\build_res.bat

begin
    Application.Initialize;
    Application.CreateForm(TfrmMain, frmMain);
    Application.Run;
end.
