@echo off
rem Stop the LocalServicesOnDocker containers (shortcut for Start-Services.bat down).
rem Uses %~dp0 so it works no matter which folder it is launched from.
call "%~dp0Start-Services.bat" down
