@echo off
echo ========================================
echo   VERIFICACION DE LUMINA
echo ========================================
echo.

echo [1/4] Verificando archivos necesarios...
if not exist "cycles.ps1" (
    echo   X cycles.ps1 no encontrado
    goto :error
)
if not exist "lumina.vbs" (
    echo   X lumina.vbs no encontrado
    goto :error
)
if not exist "lib\Lumina.Native.ps1" (
    echo   X lib\Lumina.Native.ps1 no encontrado
    goto :error
)
if not exist "lib\Lumina.Wallpaper.ps1" (
    echo   X lib\Lumina.Wallpaper.ps1 no encontrado
    goto :error
)
echo   OK Todos los archivos estan presentes
echo.

echo [2/4] Verificando carpeta wallpapers...
if not exist "wallpapers" (
    echo   X carpeta wallpapers no encontrada
    goto :error
)
dir /b wallpapers\*.png 2>nul | find /c ".png" > temp_count.txt
set /p COUNT=<temp_count.txt
del temp_count.txt
if "%COUNT%"=="0" (
    echo   ! ADVERTENCIA: No hay wallpapers PNG en la carpeta
    echo     Agrega archivos PNG nombrados 1.png, 2.png, etc.
) else (
    echo   OK Encontrados %COUNT% wallpapers PNG
)
echo.

echo [3/4] Probando sintaxis de cycles.ps1...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$result = Get-Command -Syntax '%~dp0cycles.ps1' -ErrorAction SilentlyContinue; if ($result) { exit 0 } else { exit 1 }"
if %ERRORLEVEL% NEQ 0 (
    echo   X Error de sintaxis en cycles.ps1
    goto :error
)
echo   OK Sintaxis correcta
echo.

echo [4/4] Verificando acceso directo en Startup...
set STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
if exist "%STARTUP%\Lumina.lnk" (
    echo   OK Acceso directo encontrado en Startup
) else (
    echo   ! ADVERTENCIA: No se encontro acceso directo en Startup
    echo     Ubicacion esperada: %STARTUP%\Lumina.lnk
    echo.
    echo     Para crear el acceso directo:
    echo     1. Presiona Win+R
    echo     2. Escribe: shell:startup
    echo     3. Crea un acceso directo a lumina.vbs
)
echo.

echo ========================================
echo   VERIFICACION COMPLETADA
echo ========================================
echo.
echo Para probar Lumina manualmente ejecuta:
echo   wscript lumina.vbs
echo.
pause
exit /b 0

:error
echo.
echo ========================================
echo   ERROR EN VERIFICACION
echo ========================================
pause
exit /b 1
