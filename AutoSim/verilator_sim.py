import subprocess
from pathlib import Path
import shutil
import sys
import json


'''全局变量'''
AutoSim_dir = Path.cwd()    # 当前文件夹

def bin_to_mem(infile, mem_type):
    '''bin转为文本文件'''
    with open(infile, 'rb') as binfile:
        data = binfile.read()
    with open(str(AutoSim_dir / 'mem_init' / f'{mem_type}.txt'), 'w') as datafile:
        for b in range(0, len(data), 4):
            chunk = data[b:b + 4]

            # 不足4字节补0
            if len(chunk) < 4:
                chunk += b'\x00' * (4 - len(chunk))
            
            # 小端转换
            datafile.write(chunk[::-1].hex() + '\n')


def compile(prj_name):
    '''编译 rtl 代码并输出到 obj_dir'''
    # 获取目标工程路径
    rtl_dir = AutoSim_dir.parent / prj_name
    new_dir = AutoSim_dir / 'new' / prj_name
    sim_cpp = AutoSim_dir / 'tb_verilator.cpp'
    
    source_file = []
    source_file.extend(rtl_dir.glob('*.v'))
    source_file.extend(rtl_dir.glob('*.vh'))
    source_file.extend(new_dir.glob('*.sv'))
    source_file.append(AutoSim_dir / 'tb_verilator.v')

    # Verilator 程序
    verilator_cmd = ['verilator',
                    '-cc', '-exe', '-build',
                    # '-trace',
                    '-j', '0',
                    '-CFLAGS', '-O3 -march=native', 
                    '-top-module', 'tb_verilator',
                    '-Wno-TIMESCALEMOD',     # 忽略timescale警告
                    '-Wno-WIDTHTRUNC',       # 忽略位宽截断警告
                    '-Wno-WIDTHEXPAND',      # 忽略位宽扩展警告
                    '-Wno-CASEINCOMPLETE',   # 忽略case不完全警告
                    '-Wno-UNOPTFLAT',        # 忽略组合逻辑环警告
                    f'-I{str(rtl_dir)}',
                    str(sim_cpp)
    ]

    # 添加代码文件
    for file in source_file:
        verilator_cmd.append(str(file))

    # 编译
    try:
        result = subprocess.run(
            verilator_cmd,
            capture_output=True, 
            text=True             # 以文本模式返回
        )
        if result.stderr:
            return False, result.stderr
        elif 'error' in result.stdout.lower():
            return False, result.stdout
        else:
            return True, '  '
    except subprocess.TimeoutExpired:
        return False, 'iverilog exec timeout!'


def sim():
    result = subprocess.run(["./obj_dir/Vtb_verilator"])


def prj_ch():
    ch = None
    while(ch == None):
        print("\r[1] 5_LEVEL_CPU_Cache  [2] 5_LEVEL_CPU_improved: ", end='', flush=True)
        prj_name_ask = getch()
        if prj_name_ask == '1':
            ch = '5_LEVEL_CPU_Cache'
        elif prj_name_ask == '2':
            ch = '5_LEVEL_CPU_improved'
    print(f"\033[96m{ch}\033[0m")
    return ch


def mem_ch():
    ch = []
    while not ch:
        print("\r[1] init  [2] src0  [3] src1  [4] src2  [5] ALL: ", end='', flush=True)
        mem_name_ask = getch()
        if mem_name_ask == '1':
            ch = ['init']
        elif mem_name_ask == '2':
            ch = ['src0']
        elif mem_name_ask == '3':
            ch = ['src1']
        elif mem_name_ask == '4':
            ch = ['src2']
        elif mem_name_ask == '5':
            ch = ['init', 'src0', 'src1', 'src2']
        if len(ch) == 1:
            print(f"\033[96m{ch[0]}\033[0m")
        else:
            print("\033[96mALL\033[0m")
    return ch


def getch():
    """跨平台获取单个按键,无需回车"""
    if sys.platform.startswith('win'):
        # Windows
        import msvcrt
        return msvcrt.getch().decode('utf-8')
    else:
        # Linux/macOS
        import tty
        import termios
        
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            ch = sys.stdin.read(1)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        return ch
    
def save_current_mem_name(mem_name):
    json_filename = 'verilatorRunTime.json'

    if Path(AutoSim_dir / json_filename).exists():
        with open(json_filename, 'r', encoding='utf-8') as f:
            json_file = json.load(f)
    else:
        json_file = {}

    json_file['now_run'] = mem_name

    with open(json_filename, 'w', encoding='utf-8') as f:
        json.dump(json_file, f, indent=2, ensure_ascii=False)

if __name__ == '__main__':
    prj_name = prj_ch()
    mem_list = mem_ch()

    for mem_name in mem_list:
        irom_bin_dir = AutoSim_dir / 'mem_init' / f'irom_{mem_name}.bin'
        dram_bin_dir = AutoSim_dir / 'mem_init' / f'dram_{mem_name}.bin'
        bin_to_mem(irom_bin_dir, 'irom')
        bin_to_mem(dram_bin_dir, 'dram')
        print(f"成功加载 {mem_name} 至 IROM & DRAM...")
        save_current_mem_name(mem_name)

        success, error_msg = compile(prj_name)
        if(success):
            print(f'编译成功...')
            sim()
        else:
            print('\n')
            print('=' * 40)
            print('编译失败:')
            print(error_msg)
            print('=' * 40)
