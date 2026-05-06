import sys

from compile_and_sim import list_binfiles
from compile_and_sim import run


def main(prj_name, op_name, dram_type):
    # 获取路径下所有bin文件
    all_bin_files = list_binfiles()

    for file_bin in all_bin_files:
        if file_bin.find(op_name + '.bin') != -1:
            index = file_bin.index('-p-')
            print_name = file_bin[index + 3:-4]
            if (run(prj_name, file_bin, dram_type) == True):
                print('指令  ' + print_name.ljust(10, ' ') + '    PASS')
            else:
                print('指令  ' + print_name.ljust(10, ' ') + '    !!!FAIL!!!')


if __name__ == '__main__':
    prj_name = sys.argv[1] if len(sys.argv) > 1 else '5_LEVEL_CPU_Cache'
    op_name = sys.argv[2] if len(sys.argv) > 2 else 'addi'
    dram_type = sys.argv[3] if len(sys.argv) > 3 else 'BRAM'

    sys.exit(main(prj_name, op_name, dram_type))

'''
使用方法：
在终端输入 python test_one_inst.py prj_name op_name dram_type

prj_name 为 rtl 代码所在的文件夹名称，默认为 5_LEVEL_CPU_Cache
op_name 为操作名称，输入 generated 文件夹下 rv32ui-p-xxx.bin 中的 xxx 即可
dram_type 为 DRAM 类型，有 BRAM 和 LUTRAM 两种，默认为 BRAM
'''