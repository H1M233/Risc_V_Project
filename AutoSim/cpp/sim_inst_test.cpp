#include <verilated.h>
#include <verilated_fst_c.h>
#include "Vtb_verilator_inst_test.h"
#include <iostream>
#include <iomanip>
#include <cfloat>
#include <cstdio>
#include <cmath>
#include <chrono>
#include <string>

int main(int argc, char** argv) {
    // 宏变量传递: 
    // ENABLE_TRACE:        启用波形记录

    // 环境变量传递：
    // INST_NAME:           指令名称

    // 仿真配置
    const uint64_t CLK_CPU_HALF_PERIOD = 10; // 给定 50 MHz - 20 ns
    const uint64_t NS2MS = 1000000;
    const uint64_t SIM_TIME = 4 * NS2MS;
    uint64_t sim_time_ps = 0;
    const std::string INST_NAME = std::getenv("INST_NAME");

    // 初始化
    Verilated::commandArgs(argc, argv);
    
    // 创建上下文
    VerilatedContext* contextp = new VerilatedContext;
    contextp->timeunit(-9);        // ns
    contextp->timeprecision(-9);   // ns

    // 创建顶层模块
    Vtb_verilator_inst_test* top = new Vtb_verilator_inst_test{contextp, "TOP"};

    // 记录波形
    #ifdef ENABLE_TRACE
        Verilated::traceEverOn(true);
        VerilatedFstC* tfp = new VerilatedFstC;
        top->trace(tfp, 99);                    // 追踪99层深度
        std::string filename = "vcd/verilator_inst_" + INST_NAME + ".vcd";
        tfp->open(filename.c_str());   // 打开波形文件
    #endif

    // 记录函数
    auto step_and_advance = [&](uint64_t delta_time_ns) {
        if (delta_time_ns > 0) {
            contextp->time(sim_time_ps);
            top->eval();
            #ifdef ENABLE_TRACE
                tfp->dump(sim_time_ps);
            #endif
            sim_time_ps += delta_time_ns;
        }
    };
    
    // 试探脉冲
    const uint64_t rst_time = 20;
    top->rst = 0;
    top->clk_50MHz = 0;
    step_and_advance(rst_time);

    top->clk_50MHz = 1;
    step_and_advance(CLK_CPU_HALF_PERIOD);

    top->clk_50MHz = 0;
    step_and_advance(rst_time - CLK_CPU_HALF_PERIOD);

    top->rst = 1;
    
    // 时钟主循环
    while (!contextp->gotFinish() && sim_time_ps < SIM_TIME) {
        top->clk_50MHz = !top->clk_50MHz;
        step_and_advance(CLK_CPU_HALF_PERIOD);
    }

    bool isPass = top->x26 == 1 && top->x27 == 1;
    
    std::cout << ((isPass) ? "PASS!!!" : "FAIL!!!") << std::endl;

    #ifdef ENABLE_TRACE
        tfp->close();
        delete top;
        delete tfp;
    #else
        delete top;
    #endif

    delete contextp;
    return 0;
}