@echo off
rem ===========================================================================
rem  Start / stop the LocalServicesOnDocker containers with Rancher Desktop's Docker.
rem
rem  With Rancher Desktop the "docker" command runs natively on Windows, so the
rem  old WSL wrapping, path conversion, VM keep-alive and localhost-forwarding
rem  workarounds are all unnecessary. This just follows the README steps:
rem  create the common_link network, then docker compose up -d / down.
rem
rem  ASCII-only on purpose: cmd.exe mis-parses multibyte batch files at chcp 65001.
rem
rem  Usage:
rem    Start-Services.bat          start containers (default)
rem    Start-Services.bat up       same as above
rem    Start-Services.bat down     stop containers
rem    Start-Services.bat ps       show status
rem    Start-Services.bat logs     tail logs (Ctrl+C to quit)
rem ===========================================================================
setlocal

rem Run from this batch file's folder (where docker-compose.yml lives).
cd /d "%~dp0"

set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=up"

if /i "%ACTION%"=="up"   goto :up
if /i "%ACTION%"=="down" goto :down
if /i "%ACTION%"=="ps"   goto :ps
if /i "%ACTION%"=="logs" goto :logs

echo Unknown action: %ACTION%
echo Usage: Start-Services.bat [up^|down^|ps^|logs]
goto :errexit

:up
rem Create the common_link network if it does not exist (idempotent).
docker network inspect common_link >nul 2>&1
if errorlevel 1 (
    echo Creating network 'common_link'...
    docker network create --driver bridge common_link || goto :fail
)
echo Starting containers (docker compose up -d)...
docker compose up -d || goto :fail
echo.
echo Started. Status:
docker compose ps
goto :end

:down
echo Stopping containers (docker compose down)...
docker compose down || goto :fail
echo Stopped.
goto :end

:ps
docker compose ps
goto :end

:logs
docker compose logs -f
goto :end

:fail
echo.
echo Error: the operation failed. Make sure Rancher Desktop is running.
goto :errexit

:end
endlocal
pause
exit /b 0

:errexit
endlocal
pause
exit /b 1

