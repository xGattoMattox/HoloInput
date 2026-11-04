@echo off
rem Rigenera HoloObj.res dopo aver cambiato i modelli 3D (cartella OBJ).
rem Usa brcc32 di RAD Studio: avviare dal "RAD Studio Command Prompt" oppure
rem con la cartella bin di RAD Studio nel PATH.
cd /d "%~dp0.."
where brcc32 >nul 2>nul || (
  echo brcc32 non trovato: avviare questo file dal RAD Studio Command Prompt.
  pause
  exit /b 1
)
brcc32 -foHoloObj.res HoloObj.rc || goto errore
echo Risorse aggiornate. Ricompilare il progetto.
pause
exit /b 0
:errore
echo Errore nella compilazione delle risorse.
pause
exit /b 1
