@echo off
:loop
wsl python3 verilator_sim.py
goto loop
pause