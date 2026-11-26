@echo off
rem Arranca el servidor de salas en este PC (puerto 8910). Cierra la ventana para pararlo.
set GODOT=%~dp0..\..\Godot_v4.7.2-stable_win64_console.exe
if not exist "%GODOT%" (
  echo No encuentro Godot en %GODOT%
  echo Edita este archivo y pon la ruta de tu Godot_v4.7.2-stable_win64_console.exe
  pause
  exit /b 1
)
rem Claves de Supabase para el ranked, si existe servidor\supabase.env (ver SUPABASE.md).
if exist "%~dp0supabase.env" (
  for /f "usebackq tokens=1,* delims==" %%a in ("%~dp0supabase.env") do set "%%a=%%b"
)
"%GODOT%" --headless --path "%~dp0.." -- --server --port=8910
pause
