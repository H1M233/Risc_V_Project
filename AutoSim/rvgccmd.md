# 交叉编译coremark.elf
riscv32-unknown-elf-gcc -O3 -static -mcmodel=medany -fvisibility=hidden -march=rv32imf_zicsr_zmmul -mabi=ilp32 core_main.c core_list_join.c core_matrix.c core_state.c core_util.c simple/core_portme.c -I. -Isimple -DITERATIONS=1000 -o output/coremark.elf

# 生成反汇编文件.dump
riscv32-unknown-elf-objdump --disassemble-all --disassemble-zeroes --section=.text --section=.text.startup --section=.text.init --section=.data output/coremark.elf > output/coremark.dump

# 生成比特文件.bin
riscv32-unknown-elf-objcopy -O binary output/coremark.elf output/coremark.bin

# 增加库
./configure --prefix=$RV32GC --with-arch=rv32im_zmmul --with-abi=ilp32 --with-multilib-generator="rv32im_zmmul-ilp32--;rv32imf_zicsr_zmmul-ilp32--;rv32imafdc_zicsr_zifencei_zmmul_zaamo_zalrsc_zca_zcd_zcf-ilp32f--"

# 查询库
riscv32-unknown-elf-gcc --print-multi-lib