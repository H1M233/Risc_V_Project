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
    def_dir = rtl_dir / 'def'
    sim_cpp = AutoSim_dir / 'cpp' / f'sim_{sim_type}.cpp'

    # 批量添加编译文件
    foldersInRtl = ['core', 'mem_sim', 'peripheral', 'utils', 'wrapper']
    
    source_file = []
    source_file.append(rtl_dir / 'tb' / f'tb_verilator_{sim_type}.sv')

    for f in foldersInRtl:
        source_file.extend(Path(rtl_dir / f).rglob('*.sv'))

    # Verilator 程序
    verilator_cmd = ['verilator',
                    f'-DPROJECT_{prj_folder.upper()}',      # 传递宏给.v
                    '-cc', '-exe', '-build',
                    '-j', '0',
                    '-trace-fst',

                    # 启用多线程
                    '--threads', '1',

                    # Verilator 编译优化
                    '--x-assign', 'fast',                   # 加速未初始化变量的处理
                    '--x-initial', 'fast',                  # 加速初始区块的处理
                    '--no-assert',                          # 关闭断言检查

                    # C++ 编译优化
                    '-CFLAGS', f'-O3 -march=native', 
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
    verilator_cmd.append(f'-I{str(def_dir)}')
    verilator_cmd.append(str(sim_cpp))

    # 测试
    # print(verilator_cmd)

    # 编译
    try:
        result = subprocess.run(
            verilator_cmd,
            capture_output=True, 
            text=True,            # 以文本模式返回
        )
        if result.stderr:
            return False, result.stderr
        elif 'error' in result.stdout.lower():
            return False, result.stdout
        else:
            return True, '  '
    except subprocess.TimeoutExpired:
        return False, 'verilator exec timeout!'


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
                if key_num in prj_dict:
                    prj_ch = prj_dict[key_num]
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
    testSys = False
    
    mem_dict = dict(enumerate([key for key in json_file['mem_init']], start=1))
    while True:
        # 打印信息
        print('\r[i] Inst Test  [a] ALL  [s] System ', end='')
        for index, prj_name in mem_dict.items():
            print(f'[{index}] {prj_name}', end='', flush=True)
            print('  ' if index != len(mem_dict) else ': ', end='', flush=True)

        # 获取按键
        mem_name_ask = getch()
        if mem_name_ask == 'ESC':
            print("\033[2K\033[A\033[2K", end='')
            break
        elif mem_name_ask.lower() == 'a':
            mem_ret = json_file['mem_init']
            testAll = True
            print("\033[96mALL\033[0m")
            break
        elif mem_name_ask.lower() == 's':
            testSys = True
            print("\033[96mSystem\033[0m")
            break
        elif mem_name_ask.lower() == 'i':
            testInst = True
            print("\033[96mInst Test\033[0m")
            break
        else:
            try:
                key_num = int(mem_name_ask)
                if key_num in mem_dict:
                    mem_ch.append(mem_dict[key_num])
                    break
            except ValueError:
                pass

    # 打印结果
    for mem_name in mem_ch:
        print(f"\033[96m{mem_name}\033[0m")
        mem_ret[mem_name] = json_file['mem_init'][mem_name]
    return prj_ret, mem_ret, testInst, testAll, testSys


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


def softwareTest(prj_dict, mem_dict, enableTrace=False, traceRange=(-1, -1), Debugging=False):
    print()
    for mem_name, mem_file in mem_dict.items():
        irom_bin_dir = AutoSim_dir / 'mem_init' / mem_file['irom']
        dram_bin_dir = AutoSim_dir / 'mem_init' / mem_file['dram']
        print(f"[INFO] 加载 \033[96m{mem_name}\033[0m 至 IROM & DRAM......", end='', flush=True)
        bin_to_mem(irom_bin_dir, 'software_test_irom')
        bin_to_mem(dram_bin_dir, 'software_test_dram')
        print("加载成功", flush=True)

        # 宏定义
        print("[INFO] 编译仿真文件中......", end='', flush=True)
        macros = {}
        if enableTrace:
            macros['ENABLE_TRACE'] = 1
            traceStartTime, traceEndTime = traceRange
            macros['TRACE_START_TIME'] = '2147483647' if traceStartTime < 0 else str(traceStartTime)
            macros['TRACE_END_TIME'] = '0' if traceEndTime < 0 else str(traceEndTime)

        if Debugging:
            macros['DEBUGGING'] = 1

        success, error_msg = compile(prj_dict, 'software', macros)
        if success:
            print(f'编译成功\n')

            # 环境变量定义
            env = os.environ.copy()
            env['CLK_FREQ'] = str(prj_dict['clockFreq'])
            env['PREV_TIME'] = str(getPrevTimeJson(prj_dict['prj_name'], mem_name))
            sim('software', stdout=True, env=env)

            updateJson(prj_dict['prj_name'], sim_type='software', mem_name=mem_name)
        else:
            print('编译失败\n')
            print('=' * 40)
            print(error_msg, end='')
            print('=' * 40)


def instTest(prj_dict, testAll=False):
    inst_name = ''
    enableTrace = False

    while True:
        if not testAll:
            print('\r\033[2KINST Name (Press Enter for ALL, \'/\' for Folder): ', end='')
            print('\033[96m', end='')
            inst_name = input().lower()
            print('\033[0m', end='')

        # 获取路径下所有bin文件
        if inst_name == 'all' or inst_name == '' or testAll:
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
    
    updateJson(prj_dict['prj_name'], 'Inst Test', inst_result=(passCnt == len(sel_bin_files) and failCnt == 0))
    print(f"\033[2K指令集测试共 \033[92m{passCnt}个成功 \033[91m{failCnt}个失败\033[0m", end='\n\033[2K')


def systemTest(prj_dict, cmake=True, enableTrace=False, traceRange=(-1, -1)):
    print()
    json_filename = 'settings.json'
    
    if Path(AutoSim_dir / json_filename).exists():
        with open(json_filename, 'r', encoding='utf-8') as f:
            json_file = json.load(f)
    else:
        sys.exit("无法找到settings.json")

    # 交叉编译
    if cmake:
        print("[INFO] 交叉编译中...", end='', flush=True)
        cmakePath = Path(json_file['MySystem']['cmakePath']).expanduser()
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

    # IROM & DRAM 转格式
    irom_path_expand = Path(json_file['MySystem']['irom']).expanduser()
    dram_path_expand = Path(json_file['MySystem']['dram']).expanduser()

    print(f"[INFO] 加载 \033[96mMySystem\033[0m 至 IROM & DRAM...", end='', flush=True)
    bin_to_mem(irom_path_expand, 'MySystem_irom')
    bin_to_mem(dram_path_expand, 'MySystem_dram')
    print("加载完成", flush=True)

    # 宏定义
    print("[INFO] 编译仿真文件中...", end='', flush=True)
    macros = {}
    if enableTrace:
        macros['ENABLE_TRACE'] = 1
        traceStartTime, traceEndTime = traceRange
        macros['TRACE_START_TIME'] = '2147483647' if traceStartTime < 0 else str(traceStartTime)
        macros['TRACE_END_TIME'] = '0' if traceEndTime < 0 else str(traceEndTime)
    success, error_msg = compile(prj_dict, 'system', macros)

    if success:
        print(f'编译完成')

        # 环境变量定义
        env=os.environ.copy()
        env['CLK_FREQ'] = str(prj_dict['clockFreq'])
        sim('system', stdout=True, env=env)
    else:
        print('编译失败\n')
        print('=' * 40)
        print(error_msg, end='')
        print('=' * 40)


def main():
    while True:
        try:
            prj_dict, mem_dict, testInst, testAll, testSys = prj_mem_ch()
            if testInst:
                instTest(prj_dict, testAll=testAll)
            if mem_dict:
                softwareTest(
                    prj_dict, mem_dict, 
                    enableTrace=False, 
                    traceRange=(222, 223), 
                    Debugging=True
                )
            if testSys:
                systemTest(
                    prj_dict, 
                    cmake=True, 
                    enableTrace=False, 
                    traceRange=(0, 1)
                )
        except KeyboardInterrupt:
            print("\n\n仿真进程被Ctrl + C终止")



if __name__ == '__main__':
    main()
