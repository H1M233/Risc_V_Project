@echo off
setlocal enabledelayedexpansion
set generated_dir=D:\FPGA_Project\Risc_V_Project\AutoSim\wsllink-riscv-tests\mytest\generated
set mytest_dir=D:\FPGA_Project\Risc_V_Project\AutoSim\generated\mytest

wsl bash -lc "cd ~/gitLib/riscv-tests/mytest && make clean && make all"

move "%generated_dir%\*.bin" "%mytest_dir%\"
move "%generated_dir%\*.dump" "%mytest_dir%\"

pause