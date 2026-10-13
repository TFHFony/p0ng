@echo off
cd /d "%~dp0"
"%~dp0sjasmplus.exe" src/main.asm --raw=p0ng.rom
if errorlevel 1 (
    echo BUILD FAILED
    exit /b 1
)
echo Build OK: p0ng.rom
