import subprocess
from pathlib import Path


'''全局变量'''
AutoSim_dir = Path.cwd()    # 当前文件夹


def list_binfiles():
    '''列出 generated 下所有 .bin 文件'''
    return [str(p) for p in Path(str(AutoSim_dir / 'generated')).rglob('*.bin')]


def bin_to_mem(infile):
    '''bin转为文本文件'''
    with open(infile, 'rb') as binfile:
        data = binfile.read()
    with open(str(AutoSim_dir / 'generated' / 'inst_data.txt'), 'w') as datafile:
        for b in range(0, len(data), 4):
            chunk = data[b:b + 4]

            # 不足4字节补0
            if len(chunk) < 4:
                chunk += b'\x00' * (4 - len(chunk))
            
            # 小端转换
            datafile.write(chunk[::-1].hex() + '\n')


def compile(prj_name, dram_type):
    '''编译 rtl 代码并输出到 out.vvp'''
    # 获取目标工程路径
    rtl_dir = AutoSim_dir.parent / f'{prj_name}'

    # iverilog 程序
    iverilog_cmd = ['iverilog',
                    '-o', 'out.vvp',                                                # 编译生成文件
                    '-y', str(rtl_dir),                                             # 添加 test_rtl 下的所有 .v 文件
                    '-I', str(rtl_dir),                                             # 添加头文件
                    str(AutoSim_dir / f'tb_{dram_type}.v'),                         # 测试平台 testbench 代码
                    str(AutoSim_dir / 'IP-sim' / 'irom.v'),                         # IROM
                    str(AutoSim_dir / 'IP-sim' / f'dram_{dram_type}.v')             # 选择使用 DRAM (LUTRAM / BRAM)
    ]

    # 编译
    try:
        result = subprocess.run(
            iverilog_cmd,
            capture_output=True,  # 捕获输出
            text=True,            # 以文本模式返回
            timeout=5
        )
        return 'error' not in result.stdout
    except subprocess.TimeoutExpired:
        print('!!!Fail, iverilog exec timeout!!!')
        return False


def sim():
    '''对 out.vvp 进行仿真'''
    try:
        result = subprocess.run(
            ['vvp', 'out.vvp'],
            capture_output=True,  # 捕获输出
            text=True,            # 以文本模式返回
            timeout=10
        )
        # print(result.stdout)
        return 'pass!!!' in result.stdout
    except subprocess.TimeoutExpired:
        print('!!!Fail, vvp exec timeout!!!')
        return False


def run(prj_name, file_bin, dram_type):
    bin_to_mem(file_bin)
    if(compile(prj_name, dram_type) == True):
        return sim()
    else:
        return False
