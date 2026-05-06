import sys

from compile_and_sim import list_binfiles
from compile_and_sim import run


def main(prj_name, dram_type):
    # 获取路径下所有bin文件
    all_bin_files = list_binfiles()

    # 成功失败计数器
    passCnt = 0
    failCnt = 0

    # 遍历所有文件一个一个执行
    for file_bin in all_bin_files:
        index = file_bin.index('-p-')
        print_name = file_bin[index + 3:-4]
        if (run(prj_name, file_bin, dram_type) == True):
            print('指令  ' + print_name.ljust(10, ' ') + '    PASS')
            passCnt += 1
        else:
            print('指令  ' + print_name.ljust(10, ' ') + '    !!!FAIL!!!')
            failCnt += 1
    
    print(f"共{passCnt}个成功，{failCnt}个失败")


if __name__ == '__main__':
    prj_name = sys.argv[1] if len(sys.argv) > 1 else '5_LEVEL_CPU_Cache'
    dram_type = sys.argv[2] if len(sys.argv) > 2 else "BRAM"

    sys.exit(main(prj_name, dram_type))


'''
使用方法：
在终端输入 python test_all.py prj_name dram_type

prj_name 为 rtl 代码所在的文件夹名称，默认为 5_LEVEL_CPU_Cache
dram_type 为 DRAM 类型，有 BRAM 和 LUTRAM 两种，默认为 BRAM
'''