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

    // 仿真配置
    const double CLK_CPU = 150.0;
    const double CLK_CPU_HALF_PERIOD = 500.0 / CLK_CPU;
    const double CLK_50MHz_HALF_PERIOD = 10.0;          // 50 MHz
    const double NS2MS = 1000000.0;
    const double SIM_TIME = 30.0 * 1000.0 * NS2MS;
    double sim_time_ns = 0.0;                           // 定义 sim_time_ns
    double time_ms = 0.0;
    double next_clk_50MHz_edge = 0.0;
    double next_clk_CPU_edge = 0.0;
    bool Finished = false;

    // 记录函数
    auto step_and_advance = [&](double delta_time_ns) {
        contextp->time(sim_time_ns * 1000);
        top->eval();
        sim_time_ns += delta_time_ns;
    };
    
    // 试探脉冲
    top->rst = 0;
    top->clk_50MHz = 0;
    top->clk_cpu = 0;
    step_and_advance(NS2MS / 2.0);

    top->clk_50MHz = 1;
    top->clk_cpu = 1;
    step_and_advance(CLK_50MHz_HALF_PERIOD);
    
    top->clk_50MHz = 0;
    step_and_advance(CLK_50MHz_HALF_PERIOD - CLK_CPU_HALF_PERIOD);

    top->clk_cpu = 0;
    step_and_advance(NS2MS / 2.0 - CLK_CPU_HALF_PERIOD);

    top->rst = 1;
    
    // 时钟主循环
    while (!contextp->gotFinish() && sim_time_ns < SIM_TIME && !Finished) {
        
        // 计算下一个时钟边沿的时间
        if (next_clk_50MHz_edge <= sim_time_ns) {
            next_clk_50MHz_edge = sim_time_ns + CLK_50MHz_HALF_PERIOD;
            top->clk_50MHz = !top->clk_50MHz;  // 翻转 50MHz 时钟
        }
        if (next_clk_CPU_edge <= sim_time_ns) {
            next_clk_CPU_edge = sim_time_ns + CLK_CPU_HALF_PERIOD;
            top->clk_cpu = !top->clk_cpu;  // 翻转 CPU 时钟
            totalCycle += 0.5;
        }
        
        // 找到下一个事件时间
        double next_event_time = DBL_MAX;
        next_event_time = std::min(next_clk_50MHz_edge, next_clk_CPU_edge);
        
        // 执行到下一个事件
        step_and_advance(next_event_time - sim_time_ns);
        static double prev_mem_inst = 0x0000'0013;
        if (top->x26 == 1) {
            Finished = 1;
            std::cout << (top->x27 == 1) ? 'PASS!!!' : 'FAIL!!!' << std::endl;
        }
    }

    delete top;
    delete contextp;
    return 0;
}