import subprocess
from pathlib import Path
import sys
import json
import os


'''全局变量'''
AutoSim_dir = Path.cwd()    # 当前文件夹
clkFreqList = {}    # 时钟频率字典


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


def compile(prj_name, sim_type):
    '''编译 rtl 代码并输出到 obj_dir'''
    # 获取目标工程路径
    rtl_dir = AutoSim_dir.parent / prj_name
    new_dir = AutoSim_dir / 'new' / prj_name
    sim_cpp = AutoSim_dir / f'sim_{sim_type}.cpp'
    
    source_file = []
    source_file.extend(rtl_dir.glob('*.v'))
    source_file.extend(rtl_dir.glob('*.vh'))
    source_file.extend(new_dir.glob('*.sv'))
    source_file.append(AutoSim_dir / 'tb_verilator.v')

    # Verilator 程序
    verilator_cmd = ['verilator',
                    # f'-DCLK_FREQ={clkFreq[prj_name]}',
                    f'-DPROJECT_{prj_name.upper()}',    # 传递宏给.v
                    '-cc', '-exe', '-build',
                    # '-trace',
                    '-j', '0',
                    '-CFLAGS', '-O3 -march=native', 
                    '-top-module', f'tb_verilator_{sim_type}',
                    '-Wno-TIMESCALEMOD',     # 忽略timescale警告
                    '-Wno-WIDTHTRUNC',       # 忽略位宽截断警告
                    '-Wno-WIDTHEXPAND',      # 忽略位宽扩展警告
                    '-Wno-CASEINCOMPLETE',   # 忽略case不完全警告
                    '-Wno-UNOPTFLAT'         # 忽略组合逻辑环警告
    ]

    # 添加代码文件
    for file in source_file:
        verilator_cmd.append(str(file))

    # 添加 .vh 和 sim_cpp 文件
    verilator_cmd.append(f'-I{str(rtl_dir)}')
    verilator_cmd.append(str(sim_cpp))

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


def sim(clk_freq, sim_type, stdout=True):
    # 添加环境变量
    env = os.environ.copy()
    env['CLK_FREQ'] = str(clk_freq)

    if (stdout):
        result = subprocess.run(f"./obj_dir/Vtb_verilator_{sim_type}", env=env)
    else:
        result = subprocess.run(
            f"./obj_dir/Vtb_verilator_{sim_type}",
            env=env,
            capture_output=True,
            text=True,
        )
        return result.stdout


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
    isAll = False
    isInst = False
    while not ch and not isAll and not isInst:
        print("\r[i] 37 inst  [1] init  [2] src0  [3] src1  [4] src2  [a] ALL: ", end='', flush=True)
        mem_name_ask = getch()
        if mem_name_ask.lower() == 'i':
            isInst = True
        elif mem_name_ask == '1':
            ch = ['init']
        elif mem_name_ask == '2':
            ch = ['src0']
        elif mem_name_ask == '3':
            ch = ['src1']
        elif mem_name_ask == '4':
            ch = ['src2']
        elif mem_name_ask.lower() == 'a':
            ch = ['init', 'src0', 'src1', 'src2']
            isAll = True
    print('\033[96m', end='')
    if isInst:
        print('37 inst', end='')
    elif isAll:
        print('ALL', end='')
    else:
        print(ch[0], end='')
    print('\033[0m')
    return ch, isAll, isInst


def getch():
    """跨平台获取单个按键,无需回车"""
    if sys.platform.startswith('win'):
        # Windows
        import msvcrt
        key = msvcrt.getch()
        if key == b'\x1b':  # ESC 键
            print("\033[96mESC\033[0m\r")
            sys.exit()
        else:
            return key.decode('utf-8')
    else:
        # Linux/macOS
        import tty
        import termios
        
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            ch = sys.stdin.read(1)
            if ord(ch) == 27:
                print("\033[96mESC\033[0m\r")
                sys.exit()
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        return ch


def update_json(prj_name, sim_type, inst_result=False, mem_name='init'):
    json_filename = 'verilatorRunData.json'

    if Path(AutoSim_dir / json_filename).exists():
        with open(json_filename, 'r', encoding='utf-8') as f:
            json_file = json.load(f)
    else:
        json_file = {}

    json_file.setdefault(prj_name, {})

    if sim_type == 'software':
        with open('software_results.txt', 'r', encoding='utf-8') as f:
            results = dict(line.strip().split('=') for line in f if '=' in line)

        if prj_name == '5_LEVEL_CPU_improved':
            del results['DCACHE HIT']
            del results['ICACHE HIT']
        json_file[prj_name].setdefault('SOFTWARE TEST', {})
        json_file[prj_name]['SOFTWARE TEST'].setdefault(mem_name, {})

        json_file[prj_name]['SOFTWARE TEST'][mem_name].update(results)
    elif sim_type == 'inst':
        json_file[prj_name]['37 INST TEST'] = 'PASS √' if inst_result else 'FAIL x'

    with open(json_filename, 'w', encoding='utf-8') as f:
        json.dump(json_file, f, indent=2, ensure_ascii=False)


def softwareTest(prj_name, mem_list):
    for mem_name in mem_list:
        irom_bin_dir = AutoSim_dir / 'mem_init' / f'irom_{mem_name}.bin'
        dram_bin_dir = AutoSim_dir / 'mem_init' / f'dram_{mem_name}.bin'
        bin_to_mem(irom_bin_dir, 'irom')
        bin_to_mem(dram_bin_dir, 'dram')
        print(f"\n加载 \033[96m{mem_name}\033[0m 至 IROM & DRAM...")

        success, error_msg = compile(prj_name, 'software')
        if(success):
            print(f'编译成功...')
            sim(clkFreqList[prj_name], 'software', stdout=True)
            update_json(prj_name, sim_type='software', mem_name=mem_name)
        else:
            print('\n')
            print('=' * 40)
            print('编译失败:')
            print(error_msg)
            print('=' * 40)


def instTest(prj_name):
    print("\n编译中...", end='\r')
    # 获取路径下所有bin文件
    all_bin_files = [str(p) for p in Path(AutoSim_dir / 'generated').rglob('*.bin')]

    # 成功失败计数器
    passCnt, failCnt = 0, 0

    # 遍历所有文件
    for file_bin in all_bin_files:
        index = file_bin.index('-p-')
        print_name = file_bin[index + 3:-4]

        bin_to_mem(file_bin, 'inst_test')

        success, error_msg = compile(prj_name, 'inst')
        if(success):
            sim_stdout = sim(50, 'inst', stdout=False)
            findPass, findFail = "PASS!!!" in sim_stdout, "FAIL!!!" in sim_stdout
            if (findFail):
                print('\033[2K指令  ' + print_name.ljust(10, ' ') + '    !!!FAIL!!!')
                failCnt += 1
            elif (findPass):
                print('\033[2K指令  ' + print_name.ljust(10, ' ') + '    PASS', end='\r')
                passCnt += 1
            else:
                print('\033[2K指令  ' + print_name.ljust(10, ' ') + '    NO ANSWER')
        else:
            print('\n')
            print('=' * 40)
            print('编译失败:')
            print(error_msg)
            print('=' * 40)
    
    update_json(prj_name, 'inst', inst_result=(passCnt == 37 and failCnt == 0))
    print(f"\033[2K指令集测试共 \033[92m{passCnt}个成功 \033[91m{failCnt}个失败\033[0m")


if __name__ == '__main__':
    clkFreqList['5_LEVEL_CPU_Cache'] = 250
    clkFreqList['5_LEVEL_CPU_improved'] = 150

    prj_name = prj_ch()
    print(f"时钟频率: {clkFreqList[prj_name]} MHz")
    mem_list, isAll, isInst = mem_ch()

    if isInst:
        instTest(prj_name)
    elif isAll:
        instTest(prj_name)
        softwareTest(prj_name, mem_list)
    else:
        softwareTest(prj_name, mem_list)
