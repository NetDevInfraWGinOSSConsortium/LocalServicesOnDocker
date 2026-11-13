@echo off
rem ===========================================================================
rem  Start a hand-picked subset of the LocalServicesOnDocker containers
rem  with the Docker daemon running inside WSL2.
rem
rem  Edit SERVICES below to choose what to start. Valid names are the
rem  docker-compose.yml service names: redis mongo mysql postgres sqlserver
rem  oracle (or "all"). Run "Start-Services_wsl2.ps1 help" for the full list.
rem
rem  NOTE: "::" is a comment only at the START of a line. Written in the
rem  middle of a command it is passed through as a literal argument
rem  (e.g. ::"oracle" arrives as ::oracle) and the script rejects it as an
rem  unknown service name. Comment out a whole SERVICES line instead.
rem
rem  NOTE: this uses the dockerd inside WSL2, which publishes the same host
rem  ports as the Rancher Desktop one. Stop the other side first.
rem
rem  ASCII-only on purpose: cmd.exe mis-parses multibyte batch files at chcp 65001.
rem ===========================================================================
setlocal

rem Oracle takes the longest to boot, so it is left out by default.
set "SERVICES=sqlserver"
rem set "SERVICES=sqlserver oracle postgres mysql"
rem set "SERVICES=all"

rem Set DISTRO to pick a specific WSL distribution (empty = the default one).
set "DISTRO="

if not defined SERVICES (
    echo SERVICES is empty. Edit this file and set the services to start.
    goto :errexit
)

set "DISTRO_ARG="
if defined DISTRO set "DISTRO_ARG=-Distro %DISTRO%"

rem %~dp0 keeps this working no matter which folder it is launched from.
powershell -ExecutionPolicy RemoteSigned -File "%~dp0Start-Services_wsl2.ps1" %SERVICES% %DISTRO_ARG%
if errorlevel 1 goto :errexit

endlocal
exit /b 0

:errexit
endlocal
pause
exit /b 1
