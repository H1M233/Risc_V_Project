#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtb_verilator_inst.h"
#include <iostream>
#include <iomanip>
#include <cfloat>
#include <cstdio>
#include <cmath>
#include <chrono>

int main(int argc, char** argv) {
    // 初始化
    Verilated::commandArgs(argc, argv);
    
    // 创建上下文
    VerilatedContext* contextp = new VerilatedContext;
    contextp->timeunit(-9);         // ns
    contextp->timeprecision(-12);   // ps

    // 创建顶层模块
    Vtb_verilator_inst* top = new Vtb_verilator_inst{contextp, "TOP"};

    // 记录波形
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);                    // 追踪99层深度
    tfp->open("wave_verilator.vcd");        // 打开波形文件

    // 仿真配置
    const double CLK_CPU = std::stoi(std::getenv("CLK_FREQ"));
    const double CLK_CPU_HALF_PERIOD = 500.0 / CLK_CPU;
    const double NS2MS = 1000000.0;
    const double SIM_TIME = 4.0 * NS2MS;
    double sim_time_ns = 0.0;                           // 定义 sim_time_ns
    double next_clk_50MHz_edge = 0.0;
    double next_clk_CPU_edge = 0.0;

    // 验证成功 / 失败
    bool x26_isTrue = false;
    bool Finished = false;
    double wait_time = 0.0;

    // 记录函数
    auto step_and_advance = [&](double delta_time_ns) {
        contextp->time(sim_time_ns * 1000);
        top->eval();
        tfp->dump(sim_time_ns * 1000);
        sim_time_ns += delta_time_ns;
    };
    
    // 试探脉冲
    top->rst = 0;
    top->clk_cpu = 0;
    step_and_advance(20.0);

    top->clk_cpu = 1;
    step_and_advance(CLK_CPU_HALF_PERIOD);

    top->clk_cpu = 0;
    step_and_advance(20.0 - CLK_CPU_HALF_PERIOD);

    top->rst = 1;
    
    // 时钟主循环
    while (!contextp->gotFinish() && sim_time_ns < SIM_TIME && !Finished) {
        
        top->clk_cpu = !top->clk_cpu;
        step_and_advance(CLK_CPU_HALF_PERIOD);
        
        if (top->x26 == 1) {
            x26_isTrue = true;
        }
        if (x26_isTrue){
            wait_time += CLK_CPU_HALF_PERIOD ;
            if (wait_time >= 100) {   // 等待 100 ns
                Finished = true;
                std::cout << ((top->x27 == 1) ? "PASS!!!" : "FAIL!!!") << std::endl;
            }
        }
    }

    if (!Finished) std::cout << "FAIL!!!" << std::endl;

    tfp->close();
    delete top;
    delete tfp;
    delete contextp;
    return 0;
}