import sys
from typing import Optional
from pathlib import Path
import threading

import TestRunner
from utils import removeScreenFlag, waitForScreen


def getKey():
        '''跨平台获取单个按键,无需回车'''

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

class Console:
    def __init__(
        self, 
        AutoSim_dir: Path,
        RTL_dir_parent: Path,
        json_settings: dict[str, any],
        project_choice: Optional[str] = None,
        memory_choice: Optional[list[str]] = None
    ):
        self.AutoSim_dir = AutoSim_dir
        self.RTL_dir_parent = RTL_dir_parent
        self.json_settings = json_settings
        self.project_choice = project_choice or ''
        self.memory_choice = memory_choice or []


    def selectProject(self) -> dict[str, any]:
        '''选择工程'''

        # 参数默认值
        prj_ch = self.project_choice
        skip_choice = prj_ch and prj_ch in self.json_settings['Project']

        prj_dict = dict(enumerate([key for key in self.json_settings['Project']], start=1))
        while not skip_choice:
            # 打印信息
            print('\r', end='')
            for index, prj_name in prj_dict.items():
                print(f'[{index}] {prj_name}', end='', flush=True)
                print('  ' if index != len(prj_dict) else ': ', end='', flush=True)

            # 获取按键
            key_get = getKey()
            if key_get == 'ESC':
                print("\033[96mESC\033[0m")
                sys.exit("程序被ESC终止")
            else:
                prj_ch = prj_dict.get(int(key_get)) if key_get.isdecimal() else None
                if prj_ch is not None:
                    break

        # 打印结果
        prj_dict_ret = self.json_settings['Project'][prj_ch]
        prj_dict_ret['name'] = prj_ch
        prj_dict_ret['path'] = self.RTL_dir_parent / prj_dict_ret['folder']
        print(f"\033[96m{prj_ch} @{prj_dict_ret['clockFreq']} MHz\033[0m")
        return prj_dict_ret


    def selectMemoryInitialization(self) -> tuple[dict[str, any], bool, bool, bool]:
        '''选择内存初始化'''

        # 参数默认值
        mem_ch = self.memory_choice
        skip_choice = mem_ch and mem_ch in self.json_settings['mem_init']
        mem_dict_ret: dict[str, any] = {}
        test_inst = False
        test_all = False
        test_sys = False

        mem_dict = dict(enumerate([key for key in self.json_settings['mem_init']], start=1))
        while not skip_choice:
            # 打印信息
            print('\r[I] Inst Test  [A] ALL  [S] System ', end='')
            for index, prj_name in mem_dict.items():
                print(f'[{index}] {prj_name}', end='', flush=True)
                print('  ' if index != len(mem_dict) else ': ', end='', flush=True)

            # 获取按键
            key_get = getKey()
            if key_get == 'ESC':
                print("\033[2K\033[A\033[2K", end='')
                break
            elif key_get.upper() == 'A':
                mem_dict_ret = self.json_settings['mem_init']
                test_all = True
                print("\033[96mALL\033[0m")
                break
            elif key_get.upper() == 'S':
                test_sys = True
                print("\033[96mSystem\033[0m")
                break
            elif key_get.upper() == 'I':
                test_inst = True
                print("\033[96mInst Test\033[0m")
                break
            else:
                mem_ch.append(mem_dict.get(int(key_get)) if key_get.isdecimal() else None)
                if mem_ch[-1] is not None:
                    break

        # 打印结果
        for mem_name in mem_ch:
            mem_dict_ret[mem_name] = {}
            mem_dict_ret[mem_name]['irom'] = self.AutoSim_dir / 'mem_init' / self.json_settings['mem_init'][mem_name]['irom']
            mem_dict_ret[mem_name]['dram'] = self.AutoSim_dir / 'mem_init' / self.json_settings['mem_init'][mem_name]['dram']
            print(f"\033[96m{mem_name}\033[0m")

        return mem_dict_ret, test_inst, test_all, test_sys


    def main(self):
        prj_dict = self.selectProject()
        mem_dict, test_inst, test_all, test_sys = self.selectMemoryInitialization()

        if test_inst:
            TestRunner.inst_test(
                AutoSim_dir = self.AutoSim_dir, 
                json_settings = self.json_settings,
                prj_dict = prj_dict,
                enableTrace = False
            )

        if mem_dict:
            TestRunner.software_test(
                AutoSim_dir = self.AutoSim_dir,
                json_settings = self.json_settings,
                prj_dict = prj_dict,
                mem_dict = mem_dict,
                debugging = True,
                enableTrace = False,
                traceRange = (-1, -1)
            )

        if test_sys:
            # 打开 screen
            flag = '/tmp/RV_UART_screen_ready'
            removeScreenFlag(flag)
            screenT = threading.Thread(target=waitForScreen, args=(flag,), daemon=True)
            screenT.start()

            TestRunner.system_test(
                AutoSim_dir = self.AutoSim_dir,
                json_settings = self.json_settings,
                prj_dict = prj_dict,
                cmake = False,
                debugging = True,
                enableTrace = False,
                traceRange = (-1, -1)
            )

