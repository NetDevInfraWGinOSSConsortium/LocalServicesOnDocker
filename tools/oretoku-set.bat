@echo off
rem ===========================================================================
rem  Start a hand-picked subset of the LocalServicesOnDocker containers
rem  with Rancher Desktop's Docker.
rem
rem  Edit SERVICES below to choose what to start. Valid names are the
rem  docker-compose.yml service names: redis mongo mysql postgres sqlserver
rem  oracle (or "all"). Run "Start-Services.ps1 help" for the full list.
rem
rem  NOTE: "::" is a comment only at the START of a line. Written in the
rem  middle of a command it is passed through as a literal argument
rem  (e.g. ::"oracle" arrives as ::oracle) and the script rejects it as an
rem  unknown service name. Comment out a whole SERVICES line instead.
rem
rem  ASCII-only on purpose: cmd.exe mis-parses multibyte batch files at chcp 65001.
rem ===========================================================================
setlocal

rem Oracle takes the longest to boot, so it is left out by default.
set "SERVICES=sqlserver"
rem set "SERVICES=sqlserver oracle postgres mysql"
rem set "SERVICES=all"

if not defined SERVICES (
    echo SERVICES is empty. Edit this file and set the services to start.
    goto :errexit
)

rem %~dp0 keeps this working no matter which folder it is launched from.
powershell -ExecutionPolicy RemoteSigned -File "%~dp0Start-Services.ps1" %SERVICES%
if errorlevel 1 goto :errexit

endlocal
exit /b 0

:errexit
endlocal
pause
exit /b 1
