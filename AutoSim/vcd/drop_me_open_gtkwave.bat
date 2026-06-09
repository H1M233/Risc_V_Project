@echo off
chcp 65001 >nul

if "%~1"=="" (
    echo 请拖入.vcd文件
    pause
    exit /b
)

set "SAVED_GTKW=gtkw.gtkw"

if exist "%SAVED_GTKW%" (
    start "" gtkwave --dark "%~1" "%SAVED_GTKW%"
) else (
    start "" gtkwave --dark "%~1"
)

exit /b