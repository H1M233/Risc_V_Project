@echo off

wsl bash -i -c "cd ~/RiscV-MySystem && make"

echo generated in /Vivado_Project/mem_init/MySystem.coe
bin2coe -i \\wsl.localhost\Ubuntu-26.04\home\h1m233\RiscV-MySystem\output\MySystem.bin -o ../Vivado_Project/mem_init/MySystem.coe -w 32

echo.
echo FINISHED!!!
pause