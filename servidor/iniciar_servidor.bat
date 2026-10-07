@echo off
rem Arranca el servidor de salas en este PC (puerto 8910). Cierra la ventana para pararlo.
set GODOT=%~dp0..\..\Godot_v4.7.2-stable_win64_console.exe
if not exist "%GODOT%" (
  echo No encuentro Godot en %GODOT%
  echo Edita este archivo y pon la ruta de tu Godot_v4.7.2-stable_win64_console.exe
  pause
  exit /b 1
)
"%GODOT%" --headless --path "%~dp0.." -- --server --port=8910
pause
