# Autosim - 使用 verilator 进行仿真
### 目录结构

```bash
RV_Baseline/
├──cpp/                     # 仿真所需的 C++ 测试文件
├──generated/               # 指令测试的 .bin 文件及反汇编文件
├──mem_init/                # 软件/系统测试的 .bin 文件
├──run.bat                  # Windows 平台自动化运行脚本
├──settings.json            # 工程索引和内存索引配置
├──verilator_sim.py         # 自动化仿真主程序
└──verilatorRunData.json    # 软件测试结果记录
```
<br>


# 一些常用指令

### 交叉编译coremark.elf
```bash
riscv32-unknown-elf-gcc -O3 -static -mcmodel=medany -fvisibility=hidden -march=rv32imf_zicsr_zmmul -mabi=ilp32 core_main.c core_list_join.c core_matrix.c core_state.c core_util.c simple/core_portme.c -I. -Isimple -DITERATIONS=1000 -o output/coremark.elf
```

### 生成反汇编文件.dump
```bash
riscv32-unknown-elf-objdump --disassemble-all --disassemble-zeroes --section=.text --section=.text.startup --section=.text.init --section=.data output/coremark.elf > output/coremark.dump
```

### 生成比特文件.bin
```bash
riscv32-unknown-elf-objcopy -O binary output/coremark.elf output/coremark.bin
```

### 增加库
```bash
./configure --prefix=$RV32GC --with-arch=rv32im_zmmul --with-abi=ilp32 --with-multilib-generator="rv32im_zmmul-ilp32--;rv32imf_zicsr_zmmul-ilp32--;rv32imafdc_zicsr_zifencei_zmmul_zaamo_zalrsc_zca_zcd_zcf-ilp32f--"
```

### 查询库
```bash
riscv32-unknown-elf-gcc --print-multi-lib
```