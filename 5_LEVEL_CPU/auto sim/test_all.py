import os
import subprocess
import sys

from compile_and_sim import compile
from compile_and_sim import list_binfiles
from compile_and_sim import sim
from compile_and_sim import bin_to_mem


def main():
    # 获取上一级路径
    rtl_dir = os.path.abspath(os.path.join(os.getcwd(), ".."))
    # 获取路径下所有bin文件
    all_bin_files = list_binfiles(rtl_dir + r'/auto sim/generated/')
    # print(all_bin_files)

    passCnt = 0
    failCnt = 0
    # 遍历所有文件一个一个执行
    for file_bin in all_bin_files:
        cmd = f'python compile_and_sim.py "{file_bin}"'
        f = os.popen(cmd)
        r = f.read()

        index = file_bin.index('-p-')
        print_name = file_bin[index + 3:-4]

        if r.find('pass') != -1:
            print('指令  ' + print_name.ljust(10, ' ') + '    PASS')
            passCnt += 1
        else:
            print('指令  ' + print_name.ljust(10, ' ') + '    !!!FAIL!!!')
            failCnt += 1
        f.close()
    
    print(f"共{passCnt}个成功，{failCnt}个失败")


if __name__ == '__main__':
    main()
