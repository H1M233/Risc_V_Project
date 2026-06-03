@echo off
chcp 65001 >nul

echo ========================================
echo VCD to Excel Converter (批量转换)
echo ========================================

if "%~1"=="" (
    echo 请将.vcd文件拖拽到此批处理文件上
    echo 支持同时拖拽多个文件
    pause
    exit /b
)

setlocal enabledelayedexpansion
set "count=0"
set "callPause=0"

:loop
if "%~1"=="" goto :end

set "FILE_NAME=%~n1"
set "FILE_EXT=%~x1"

REM 检查文件扩展名
if /i not "!FILE_EXT!"==".vcd" (
    echo 警告: %~nx1 不是.vcd文件
    shift
    goto :loop
)

echo.
echo [处理文件 !count!] %~nx1...

REM 运行Python脚本
wsl bash -c "source ../venv/bin/activate && python3 vcd_conversion.py '!FILE_NAME!'"

if !errorlevel! equ 0 (
    echo ✓ 成功: %~nx1
) else (
    echo ✗ 失败: %~nx1
    set "callPause=1"
)

set /a count+=1
shift
goto :loop

:end
echo.
echo ========================================
echo 处理完成！共处理 %count% 个文件
echo ========================================

if !callPause! EQU 1 (
    pause
)