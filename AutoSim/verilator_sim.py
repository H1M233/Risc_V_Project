import subprocess
from pathlib import Path
import sys
import json
import os


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


def compile(prj_dict, sim_type, macros):
    '''编译 rtl 代码并输出到 obj_dir'''
    prj_folder = prj_dict['folder']
    # 获取目标工程路径
    rtl_dir = AutoSim_dir.parent / prj_folder
    new_dir = AutoSim_dir / 'new' / prj_folder
    sim_cpp = AutoSim_dir / f'sim_{sim_type}.cpp'
    
    source_file = []
    source_file.append(AutoSim_dir / f'tb_verilator_{sim_type}.v')
    source_file.extend(rtl_dir.glob('*.v'))
    source_file.extend(rtl_dir.glob('*.sv'))
    source_file.extend(rtl_dir.glob('*.vh'))
    source_file.extend(new_dir.glob('*.sv'))

    # Verilator 程序
    verilator_cmd = ['verilator',
                    f'-DPROJECT_{prj_folder.upper()}',      # 传递宏给.v
                    '-cc', '-exe', '-build',
                    '-j', '0',
                    '-trace',

                    # Verilator 转换优化
                    '-O3',
                    '--x-assign', 'fast',                   # 加速未初始化变量的处理
                    '--x-initial', 'fast',                  # 加速初始区块的处理
                    '--no-assert',                          # 关闭断言检查

                    # C++ 编译优化
                    '-CFLAGS', '-O3 -march=native', 
                    '-top-module', f'tb_verilator_{sim_type}',

                    # 警告控制
                    '-Wno-TIMESCALEMOD',                    # 忽略timescale警告
                    '-Wno-WIDTHTRUNC',                      # 忽略位宽截断警告
                    '-Wno-WIDTHEXPAND',                     # 忽略位宽扩展警告
                    '-Wno-CASEINCOMPLETE',                  # 忽略case不完全警告
                    '-Wno-UNSIGNED'                         # 忽略判断逻辑永远为真警告
    ]

    for macroName, macroValue in macros.items():
        verilator_cmd.extend(['-CFLAGS', f'-D{macroName}={macroValue}'])

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


def sim(sim_type, stdout=True, env=os.environ.copy()):
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


def getch():
    """跨平台获取单个按键,无需回车"""
    if sys.platform.startswith('win'):
        # Windows
        import msvcrt
        key = msvcrt.getch()
        if key == b'\x1b':  # ESC 键
            return 'ESC'
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
                return 'ESC'
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        return ch


def prj_mem_ch(prj_ch=None, mem_ch=None):
    json_filename = 'settings.json'

    if Path(AutoSim_dir / json_filename).exists():
        with open(json_filename, 'r', encoding='utf-8') as f:
            json_file = json.load(f)
    else:
        sys.exit("无法找到settings.json")
    
    '''选择工程'''
    if prj_ch == None:
        prj_ch = ''

    prj_dict = dict(enumerate([key for key in json_file['Project']], start=1))
    while True:
        # 打印信息
        print('\r', end='')
        for index, prj_name in prj_dict.items():
            print(f'[{index}] {prj_name}', end='', flush=True)
            print('  ' if index != len(prj_dict) else ': ', end='', flush=True)

        # 获取按键
        prj_name_ask = getch()
        if prj_name_ask == 'ESC':
            print("\033[96mESC\033[0m")
            sys.exit("程序被ESC终止")
        else:
            try:
                key_num = int(prj_name_ask)
                prj_ch = prj_dict[key_num] if key_num in prj_dict else ''
                break
            except ValueError:
                pass

    # 打印结果
    print(f"\033[96m{prj_ch} @{json_file['Project'][prj_ch]['clockFreq']} MHz\033[0m")
    prj_ret = json_file['Project'][prj_ch]
    prj_ret['prj_name'] = prj_ch

    '''选择 mem_init'''
    if mem_ch == None:
        mem_ch = []
    mem_ret = {}
    testInst = False
    testAll = False
    
    mem_dict = dict(enumerate([key for key in json_file['mem_init']], start=1))
    while True:
        # 打印信息
        print('\r[i] Inst Test  [a] ALL  ', end='')
        for index, prj_name in mem_dict.items():
            print(f'[{index}] {prj_name}', end='', flush=True)
            print('  ' if index != len(mem_dict) else ': ', end='', flush=True)

        # 获取按键
        mem_name_ask = getch()
        if mem_name_ask == 'ESC':
            print("\033[2K\033[A\033[2K", end='')
            break
        elif mem_name_ask == 'a':
            mem_ret = json_file['mem_init']
            testInst = True
            testAll = True
            print("\033[96mALL\033[0m")
            break
        elif mem_name_ask == 'i':
            testInst = True
            print("\033[96mInst Test\033[0m")
            break
        else:
            try:
                key_num = int(mem_name_ask)
                mem_ch.append(mem_dict[key_num] if key_num in mem_dict else '')
                break
            except ValueError:
                pass

    # 打印结果
    for mem_name in mem_ch:
        print(f"\033[96m{mem_name}\033[0m")
        mem_ret[mem_name] = json_file['mem_init'][mem_name]
    return prj_ret, mem_ret, testInst, testAll


def updateJson(prj_name, sim_type, inst_result=False, mem_name='init'):
    json_filename = 'verilatorRunData.json'
    json_file = {}

    if Path(AutoSim_dir / json_filename).exists():
        with open(json_filename, 'r', encoding='utf-8') as f:
            try:
                json_file = json.load(f)
            except json.decoder.JSONDecodeError:
                pass

    json_file.setdefault(prj_name, {})

    if sim_type == 'software':
        result_file = 'software_results.txt'
        with open(result_file, 'r', encoding='utf-8') as f:
            results = dict(line.strip().split('=') for line in f if '=' in line)
        os.remove(result_file)

        json_file[prj_name].setdefault('SOFTWARE TEST', {})
        json_file[prj_name]['SOFTWARE TEST'].setdefault(mem_name, {})

        json_file[prj_name]['SOFTWARE TEST'][mem_name].update(results)
    elif sim_type == 'Inst Test':
        json_file[prj_name]['INST TEST'] = 'PASS √' if inst_result else 'FAIL x'

    with open(json_filename, 'w', encoding='utf-8') as f:
        json.dump(json_file, f, indent=2, ensure_ascii=False)


def getPrevTimeJson(prj_name, mem_name):
    json_filename = 'verilatorRunData.json'

    try:
        with open(json_filename, 'r', encoding='utf-8') as f:
            json_file = json.load(f)
        return float(json_file[prj_name]['SOFTWARE TEST'][mem_name]['RUN TIME'])
    except:
        return 0
    


def softwareTest(prj_dict, mem_dict, enableTrace=False, traceRange=(-1, -1)):
    for mem_name, mem_file in mem_dict.items():
        irom_bin_dir = AutoSim_dir / 'mem_init' / mem_file['irom']
        dram_bin_dir = AutoSim_dir / 'mem_init' / mem_file['dram']
        bin_to_mem(irom_bin_dir, 'irom')
        bin_to_mem(dram_bin_dir, 'dram')
        print(f"\n加载 \033[96m{mem_name}\033[0m 至 IROM & DRAM...")

        # 宏定义
        macros = {}
        if enableTrace:
            macros['ENABLE_TRACE'] = 1
            traceStartTime, traceEndTime = traceRange
            macros['TRACE_START_TIME'] = '2147483647' if traceStartTime < 0 else str(traceStartTime)
            macros['TRACE_END_TIME'] = '0' if traceEndTime < 0 else str(traceEndTime)

        success, error_msg = compile(prj_dict, 'software', macros)
        if success:
            print(f'编译成功...')

            # 环境变量定义
            env = os.environ.copy()
            env['CLK_FREQ'] = str(prj_dict['clockFreq'])
            env['PREV_TIME'] = str(getPrevTimeJson(prj_dict['prj_name'], mem_name))
            sim('software', stdout=True, env=env)

            updateJson(prj_dict['prj_name'], sim_type='software', mem_name=mem_name)
        else:
            print('\n')
            print('=' * 40)
            print('编译失败:')
            print(error_msg)
            print('=' * 40)


def instTest(prj_dict, testAll=False):
    inst_name = ' '
    enableTrace = False
    while True:
        if not testAll:
            print('\r\033[2KINST Name (Press Enter or ALL): ', end='')
            inst_name = input().lower()

        # 获取路径下所有bin文件
        if inst_name == 'all' or inst_name == '' or testAll:
            all_bin_files = [str(p) for p in Path(AutoSim_dir / 'generated').rglob('*.bin')]
            break
        elif inst_name:
            all_bin_files = [str(p) for p in Path(AutoSim_dir / 'generated').rglob(f'*{inst_name}.bin')]
            if all_bin_files:
                enableTrace = True
                break

    print("\n编译中...", end='\r', flush=True)

    # 成功失败计数器
    passCnt, failCnt = 0, 0

    # 遍历所有文件
    for file_bin in all_bin_files:
        index = file_bin.index('rv')
        print_name = file_bin[index:-4]

        bin_to_mem(file_bin, 'inst_test')

        # 宏定义
        macros = {}
        if enableTrace:
            macros['ENABLE_TRACE'] = '1'
        success, error_msg = compile(prj_dict, 'inst', macros=macros)
        if success:
            # 环境变量定义
            env=os.environ.copy()
            env['INST_NAME'] = print_name
            sim_stdout = sim('inst', stdout=False, env=env)

            findPass, findFail = "PASS!!!" in sim_stdout, "FAIL!!!" in sim_stdout
            passCnt += findPass
            failCnt += findFail

            # 进度条
            width = 50
            percent = (passCnt + failCnt) / len(all_bin_files)
            filled = int(width * percent)
            bar = '█' * filled + '░' * (width - filled) + f'  {passCnt + failCnt} / {len(all_bin_files)}'
            
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
            print('\n')
            print('=' * 40)
            print('编译失败:')
            print(error_msg)
            print('=' * 40)
    
    updateJson(prj_dict['prj_name'], 'Inst Test', inst_result=(passCnt == len(all_bin_files) and failCnt == 0))
    print(f"\033[2K指令集测试共 \033[92m{passCnt}个成功 \033[91m{failCnt}个失败\033[0m", end='\n\033[2K')

def main():
    while True:
        try:
            prj_dict, mem_dict, testInst, testAll = prj_mem_ch()
            if testInst:
                instTest(prj_dict, testAll=testAll)
            if mem_dict:
                softwareTest(prj_dict, mem_dict, enableTrace=False, traceRange=(0, 200))
        except KeyboardInterrupt:
            print("\n\n仿真进程被Ctrl + C终止")



if __name__ == '__main__':
    main()
