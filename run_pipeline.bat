@echo off
cd /d "%~dp0"

echo ============================================================
echo   Pipeline ETL - Dashboard Turismo Chile
echo ============================================================
echo.
echo   1) Ejecutar pipeline completo (Extract + Transform)
echo   2) Solo Extract (Python)
echo   3) Solo Transform (R)
echo   4) Lanzar Dashboard (Shiny)
echo   5) Desplegar en Shinyapps.io
echo   0) Salir
echo.
set /p opcion="Selecciona una opcion: "

if "%opcion%"=="1" goto :EXTRACT
if "%opcion%"=="2" goto :EXTRACT_ONLY
if "%opcion%"=="3" goto :TRANSFORM
if "%opcion%"=="4" goto :DASHBOARD
if "%opcion%"=="5" goto :DEPLOY
if "%opcion%"=="0" goto :EOF
echo [ERROR] Opcion invalida.
exit /b 1

:EXTRACT_ONLY
call :RUN_EXTRACT
if errorlevel 1 exit /b 1
goto :DONE

:EXTRACT
call :RUN_EXTRACT
if errorlevel 1 exit /b 1

:TRANSFORM
call :RUN_TRANSFORM
if errorlevel 1 exit /b 1
goto :DONE

:DASHBOARD
echo === DASHBOARD (Shiny) ===
echo Iniciando dashboard...
cd /d "%~dp0dashboard"
Rscript -e "shiny::runApp('.')"
exit /b 0

:DEPLOY
echo.
echo === DEPLOY (shinyapps.io) ===
echo Publicando el dashboard en la nube...
Rscript deploy.R
if errorlevel 1 (
    echo [ERROR] El despliegue fallo. Revisa tus credenciales.
    exit /b 1
)
goto :DONE

:DONE
echo.
echo ============================================================
echo   Pipeline completado exitosamente.
echo ============================================================
exit /b 0

:: ---------- Funciones ----------

:RUN_EXTRACT
echo.
echo === EXTRACT (Python) ===
echo Descargando datos desde URLs configuradas en config.yml...
python extract/main.py
if errorlevel 1 (
    echo [ERROR] La extraccion fallo. Revisa las URLs en config.yml.
    exit /b 1
)
exit /b 0

:RUN_TRANSFORM
echo.
echo === TRANSFORM (R) ===
echo Procesando datos: STL, ARIMA, SARIMAX, unificacion...
Rscript transform/main.R
if errorlevel 1 (
    echo [ERROR] La transformacion fallo.
    exit /b 1
)
exit /b 0
