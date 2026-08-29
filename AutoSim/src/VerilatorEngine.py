import subprocess
import os
from pathlib import Path
from typing import Optional

class VerilatorEngine:
    def __init__(
        self, 
        AutoSim_dir: Path, 
        obj_dir: Path, 
        rtl_dir: Path,
        prj_name: str, 
        sim_type: str
    ):
        self.AutoSim_dir = AutoSim_dir
        self.obj_dir = obj_dir
        self.rtl_dir = rtl_dir
        self.prj_name = prj_name
        self.sim_type = sim_type


    def compile(self, macros: Optional[dict[str, str]] = None) -> tuple[bool, str]:
        '''编译 rtl 代码并输出到 obj_dir'''

        # 参数默认值
        macros = {} or macros
        
        # 获取目标工程路径
        rtl_dir = self.rtl_dir
        def_dir = rtl_dir / 'def'
        sim_cpp_path = self.AutoSim_dir / 'cpp' / f'sim_{self.sim_type}.cpp'

        # 批量添加编译文件
        rtl_files = [d for d in list(rtl_dir.iterdir()) if d.is_dir() and d.name != 'def' and d.name != 'tb']
        
        source_file = []
        source_file.append(rtl_dir / 'tb' / f'tb_verilator_{self.sim_type}.sv')

        for f in rtl_files:
            source_file.extend(Path(rtl_dir / f).rglob('*.sv'))

        # Verilator 程序
        verilator_cmd = ['verilator',
                        f'-DPROJECT_{self.prj_name.upper()}',      # 传递宏给.v
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
                        '-top-module', f'tb_verilator_{self.sim_type}',

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
        for f in source_file:
            verilator_cmd.append(str(f))

        # 添加 .vh 和 sim_cpp 文件
        verilator_cmd.append(f'-I{str(def_dir)}')
        verilator_cmd.append(str(sim_cpp_path))

        # 测试
        # print(verilator_cmd)

        # 检查 obj_dir 是否存在，不存在则创建
        if not os.path.exists(self.obj_dir):
            os.makedirs(self.obj_dir)

        # 编译
        try:
            result = subprocess.run(
                verilator_cmd,
                capture_output=True, 
                text=True,            # 以文本模式返回
                cwd=self.obj_dir
            )
            if result.stderr:                       # 返回错误信息
                return False, result.stderr
            elif 'error' in result.stdout.lower():  # 存在'error'关键字
                return False, result.stdout
            else:
                return True, '  '
        except subprocess.TimeoutExpired:
            return False, 'verilator exec timeout!'


    def simulation(self, stdout: bool = True, env: Optional[dict[str, str]] = None):
        '''运行仿真程序'''

        # 参数默认值
        env = env or os.environ.copy()

        result = subprocess.run(
            f'{self.obj_dir}/obj_dir/Vtb_verilator_{self.sim_type}',
            env=env,
            capture_output=not stdout,
            text=not stdout,
        )
        if not stdout:
            return result.stdout