//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome unit: Holo.SafeDll
//** Scopo: Limitare la ricerca delle DLL caricate dal programma alla cartella di sistema di Windows.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento: per un nome di DLL senza percorso Windows cerca di solito
//** prima nella cartella dell'exe; una DLL con lo stesso nome messa li'
//** verrebbe caricata al posto di quella di sistema ("DLL hijacking").
//** La sezione initialization di questa unit (prima nella lista uses di
//** HoloInput.dpr, quindi eseguita prima delle altre) chiama:
//**   - SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_SYSTEM32): da qui in poi
//**     LoadLibrary con un nome semplice cerca solo in System32 (le DLL
//**     caricate con il percorso completo non cambiano);
//**   - SetDllDirectory(''): toglie la cartella corrente dalla ricerca (utile
//**     anche se la funzione precedente non e' disponibile).
//** Le DLL importate in modo statico vengono caricate da Windows prima di
//** qualsiasi codice: per questo le DLL usate da HoloInput (hid.dll,
//** winmm.dll) sono dichiarate "delayed" (caricate al primo uso, quindi dopo
//** questa unit) e XInput e' caricato con LoadLibraryEx solo da System32.
//***********************************************************************************************************
//***********************************************************************************************************
unit Holo.SafeDll;

interface

const
    /// Flag di LoadLibraryEx / SetDefaultDllDirectories: cerca solo in System32.
    HOLO_LOAD_LIBRARY_SEARCH_SYSTEM32 = $00000800;

implementation

uses
    Winapi.Windows;

type
    TSetDefaultDllDirectoriesFn = function(DirectoryFlags: DWORD): BOOL; stdcall;

//***********************************************************************************************************
//***********************************************************************************************************
//** Autore: Citizen GattoMatto
//** Nome procedura: RestrictDllSearch
//** Parametri di ingresso: nessuno
//** Parametri di uscita: nessuno
//** Scopo: Togliere la cartella dell'exe e quella corrente dalla ricerca delle DLL.
//** Data Ultima Modifica: 11/11/2026
//***********************************************************************************************************
//** Funzionamento: SetDefaultDllDirectories e' letta da kernel32 a runtime
//** (presente da Windows 8; se manca si usa solo SetDllDirectory('')).
//***********************************************************************************************************
//***********************************************************************************************************
procedure RestrictDllSearch;
var
    mSetDllDirs: TSetDefaultDllDirectoriesFn;
begin
    SetDllDirectory('');
    @mSetDllDirs := GetProcAddress(GetModuleHandle(kernel32), 'SetDefaultDllDirectories');
    if Assigned(mSetDllDirs) then
        mSetDllDirs(HOLO_LOAD_LIBRARY_SEARCH_SYSTEM32);
end;

initialization
    RestrictDllSearch;

end.
