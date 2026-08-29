import sys
import os
import subprocess
from pathlib import Path
from typing import Optional

from utils import binToTxt
from JSONManager import getJson, updateRunData, getPrevRunTime
from VerilatorEngine import VerilatorEngine


def inst_test(
        AutoSim_dir: Path,
        json_settings: dict[str, any],
        prj_dict: dict[str, any],
        enableTrace: Optional[bool] = None
    ):
    # 参数默认值
    enableTrace = False or enableTrace
    inst_name = ''

    while True:
        print('\r\033[2KINST Name (Press Enter for ALL, \'/\' for Folder): ', end='')
        print('\033[96m', end='')
        inst_name = input().lower()
        print('\033[0m', end='')

        # 获取路径下所有bin文件
        if inst_name == 'all' or inst_name == '':
            sel_bin_files = [str(p) for p in Path(AutoSim_dir / 'generated').rglob(f'*.bin')]
            break
        elif inst_name:
            if inst_name[0] == '/':
                sel_bin_files = [str(p) for p in Path(AutoSim_dir / 'generated' / inst_name[1:]).rglob(f'*.bin')]
            else:
                sel_bin_files = [str(p) for p in Path(AutoSim_dir / 'generated').rglob(f'*{inst_name}.bin')]
            
            if sel_bin_files:
                enableTrace = True if len(sel_bin_files) == 1 else False
                break

    print("\n编译仿真文件中...", end='\r', flush=True)

    # 成功失败计数器
    passCnt, failCnt = 0, 0

    # 遍历所有文件
    for file_bin in sel_bin_files:
        print_name = Path(file_bin).name[:-4]

        binToTxt(file_bin, AutoSim_dir / 'mem_init' / 'inst_test.txt')

        # 宏定义
        macros = {}
        if enableTrace:
            macros['ENABLE_TRACE'] = '1'

        # 创建 VerilatorEngine 对象
        verilatorEngine = VerilatorEngine(
            AutoSim_dir = AutoSim_dir, 
            obj_dir = Path(json_settings['obj_dir']).expanduser(), 
            rtl_dir = prj_dict['path'],
            prj_name = prj_dict['name'], 
            sim_type = 'inst_test'
        )

        successFlag, error_msg = verilatorEngine.compile(macros)
        if successFlag:
            # 环境变量定义
            env=os.environ.copy()
            env['INST_NAME'] = print_name
            sim_stdout = verilatorEngine.simulation(stdout=False, env=env)
            # print(print_name + sim_stdout)

            findPass, findFail = "PASS!!!" in sim_stdout, "FAIL!!!" in sim_stdout
            passCnt += findPass
            failCnt += findFail

            # 进度条
            width = 50
            percent = (passCnt + failCnt) / len(sel_bin_files)
            filled = int(width * percent)
            bar = '█' * filled + '░' * (width - filled) + f'  {passCnt + failCnt} / {len(sel_bin_files)}'
            
            if findFail:
                print('\033[2K指令  ' + print_name.ljust(20, ' ') + '!!!FAIL!!!', flush=True)
                print(bar, end='\r', flush=True)
            elif findPass:
                print('\033[2K指令  ' + print_name.ljust(20, ' ') + 'PASS', flush=True)
                print(bar, end='\033[A\r', flush=True)
            else:
                print('\033[2K指令  ' + print_name.ljust(20, ' ') + 'NO ANSWER', flush=True)
                print(bar, end='\r', flush=True)
        else:
            print('编译失败:')
            print('\n')
            print('=' * 40)
            print(error_msg, end='')
            print('=' * 40)
    
    print(f"\033[2K指令集测试共 \033[92m{passCnt}个成功 \033[91m{failCnt}个失败\033[0m", end='\n\033[2K')


def software_test(
        AutoSim_dir: Path,
        json_settings: dict[str, any],
        prj_dict : dict[str, any],
        mem_dict: dict[str, Path],
        debugging: Optional[bool] = None, 
        enableTrace: Optional[bool] = None, 
        traceRange: Optional[tuple[int, int]] = None
    ):
    # 参数默认值
    debugging = False or debugging
    enableTrace = False or enableTrace
    traceRange = (-1, -1) if traceRange is None else traceRange

    print()
    for mem_name, mem_path in mem_dict.items():
        # bin -> txt
        print(f"[INFO] 加载 \033[96m{mem_name}\033[0m 至 IROM & DRAM......", end='', flush=True)
        irom_bin_dir: Path = mem_path['irom']
        dram_bin_dir: Path = mem_path['dram']
        binToTxt(irom_bin_dir, AutoSim_dir / 'mem_init' / 'software_test_irom.txt')
        binToTxt(dram_bin_dir, AutoSim_dir / 'mem_init' / 'software_test_dram.txt')
        print("加载成功", flush=True)

        # 宏定义
        print("[INFO] 编译仿真文件中......", end='', flush=True)
        macros = {}
        if enableTrace:
            macros['ENABLE_TRACE'] = 1
            traceStartTime, traceEndTime = traceRange
            macros['TRACE_START_TIME'] = '2147483647' if traceStartTime < 0 else str(traceStartTime)
            macros['TRACE_END_TIME'] = '0' if traceEndTime < 0 else str(traceEndTime)

        if debugging:
            macros['DEBUGGING'] = 1

        # 创建 VerilatorEngine 对象
        verilatorEngine = VerilatorEngine(
            AutoSim_dir = AutoSim_dir, 
            obj_dir = Path(json_settings['obj_dir']).expanduser(), 
            rtl_dir = prj_dict['path'],
            prj_name = prj_dict['name'], 
            sim_type = 'software_test'
        )

        # 编译
        successFlag, error_msg = verilatorEngine.compile(macros)
        if successFlag:
            print(f'编译完成\n')

            # 获取上次运行时长
            prevTime = getPrevRunTime(prj_dict['name'], sim_type='SOFTWARE TEST', mem_name=mem_name)

            # 环境变量定义
            env = os.environ.copy()
            env['CLK_FREQ'] = str(prj_dict['clockFreq'])
            env['PREV_TIME'] = str(prevTime)
            verilatorEngine.simulation(stdout=True, env=env)

            updateRunData(prj_dict['name'], mem_name)
        else:
            print('编译失败\n')
            print('=' * 40)
            print(error_msg, end='')
            print('=' * 40)


def system_test(
        AutoSim_dir: Path,
        json_settings: dict[str, any],
        prj_dict : dict[str, any],
        cmake: Optional[bool] = None,
        debugging: Optional[bool] = None, 
        enableTrace: Optional[bool] = None, 
        traceRange: Optional[tuple[int, int]] = None
    ):
    # 参数默认值
    cmake = False or cmake
    debugging = False or debugging
    enableTrace = False or enableTrace
    traceRange = (-1, -1) if traceRange is None else traceRange

    print()

    # 交叉编译
    if cmake:
        print("[INFO] 交叉编译中...", end='', flush=True)
        cmakePath = Path(json_settings['MySystem']['cmakePath']).expanduser()
        cmakeErr = False
        cmakeStd = ''
        try:
            result = subprocess.run(
                'make',
                capture_output=True, 
                text=True,            # 以文本模式返回
                cwd=str(cmakePath)
            )
            if result.stderr:
                cmakeErr = True
                cmakeStd = result.stderr
            elif 'error' in result.stdout.lower():
                cmakeErr = True
                cmakeStd = result.stdout
        except subprocess.TimeoutExpired:
            cmakeErr = True
            cmakeStd = 'cmake exec timeout!'
        if cmakeErr:
            print('交叉编译失败\n')
            print('=' * 40)
            print(cmakeStd, end='')
            print('=' * 40)
            return 0
        else:
            print("交叉编译完成", flush=True)

    # bin -> txt
    print(f"[INFO] 加载 \033[96mMySystem\033[0m 至 IROM & DRAM...", end='', flush=True)
    irom_path_expand = Path(json_settings['MySystem']['irom']).expanduser()
    dram_path_expand = Path(json_settings['MySystem']['dram']).expanduser()
    binToTxt(irom_path_expand, AutoSim_dir / 'mem_init' / 'MySystem_irom.txt')
    binToTxt(dram_path_expand, AutoSim_dir / 'mem_init' / 'MySystem_dram.txt')
    print("加载完成", flush=True)

    # 宏定义
    print("[INFO] 编译仿真文件中...", end='', flush=True)
    macros = {}
    if enableTrace:
        macros['ENABLE_TRACE'] = 1
        traceStartTime, traceEndTime = traceRange
        macros['TRACE_START_TIME'] = '2147483647' if traceStartTime < 0 else str(traceStartTime)
        macros['TRACE_END_TIME'] = '0' if traceEndTime < 0 else str(traceEndTime)

    if debugging:
        macros['DEBUGGING'] = 1

    # 创建 VerilatorEngine 对象
    verilatorEngine = VerilatorEngine(
        AutoSim_dir = AutoSim_dir, 
        obj_dir = Path(json_settings['obj_dir']).expanduser(), 
        rtl_dir = prj_dict['path'],
        prj_name = prj_dict['name'], 
        sim_type = 'MySystem'
    )

    successFlag, error_msg = verilatorEngine.compile(macros)

    if successFlag:
        print(f'编译完成\n', flush=True )

        # 环境变量定义
        env=os.environ.copy()
        env['CLK_FREQ'] = str(prj_dict['clockFreq'])
        verilatorEngine.simulation(stdout=True, env=env)
    else:
        print('编译失败\n')
        print('=' * 40)
        print(error_msg, end='')
        print('=' * 40)