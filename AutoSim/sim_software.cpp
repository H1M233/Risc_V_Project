#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtb_verilator_software.h"
#include <iostream>
#include <iomanip>
#include <cfloat>
#include <cstdio>
#include <cmath>
#include <chrono>
#include <fstream>

int main(int argc, char** argv) {
    // 初始化
    Verilated::commandArgs(argc, argv);
    
    // 创建上下文
    VerilatedContext* contextp = new VerilatedContext;
    contextp->timeunit(-9);         // ns
    contextp->timeprecision(-12);   // ps

    // 创建顶层模块
    Vtb_verilator_software* top = new Vtb_verilator_software{contextp, "TOP"};

    // // 记录波形
    // Verilated::traceEverOn(true);
    // VerilatedVcdC* tfp = new VerilatedVcdC;
    // top->trace(tfp, 99);                    // 追踪99层深度
    // tfp->open("wave_verilator.vcd");        // 打开波形文件

    // 仿真配置
    const double CLK_CPU = std::stoi(std::getenv("CLK_FREQ"));
    const double CLK_CPU_HALF_PERIOD = 500.0 / CLK_CPU;
    const double CLK_50MHz_HALF_PERIOD = 10.0;          // 50 MHz
    const double NS2MS = 1000000.0;
    const double SIM_TIME = 30.0 * 1000.0 * NS2MS;
    double sim_time_ns = 0.0;                           // 定义 sim_time_ns
    double time_ms = 0.0;
    double next_clk_50MHz_edge = 0.0;
    double next_clk_CPU_edge = 0.0;
    int SEG_getTime = 0;

    // 计算 IPC
    double totalCycle = 0.0;
    double commitCycle = 0.0;

    // 计算预测准确率
    double predTotal = 0.0;
    double predMiss = 0.0;
    double predMissB = 0.0;
    double predMissJr = 0.0;
    double predTotalB = 0.0;
    double predTotalJr = 0.0;

    // 记录函数
    auto step_and_advance = [&](double delta_time_ns) {
        contextp->time(sim_time_ns * 1000);
        top->eval();
        // tfp->dump(sim_time_ns * 1000);
        sim_time_ns += delta_time_ns;
    };
    
    std::cout << "=================================== Simulation Started ===================================\n\n\n\n\n\n";

    // 计时器
    const double PREV_TIME = std::stof(std::getenv("PREV_TIME"));
    std::chrono::steady_clock::time_point start_time = std::chrono::steady_clock::now();;
    double current_time;
    auto get_elapsed_ms = [&]() -> double {
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(now - start_time);
        return elapsed.count() / 1000.0;
    };
    
    // 试探脉冲
    top->rst = 0;
    top->clk_50MHz = 0;
    top->clk_cpu = 0;
    step_and_advance(20.0);

    top->clk_50MHz = 1;
    top->clk_cpu = 1;
    step_and_advance(CLK_50MHz_HALF_PERIOD);
    
    top->clk_50MHz = 0;
    step_and_advance(CLK_50MHz_HALF_PERIOD - CLK_CPU_HALF_PERIOD);

    top->clk_cpu = 0;
    step_and_advance(20.0 - CLK_CPU_HALF_PERIOD);

    top->rst = 1;
    
    // 时钟主循环
    while (!contextp->gotFinish() && sim_time_ns < SIM_TIME && !SEG_getTime) {
        
        // 计算下一个时钟边沿的时间
        if (next_clk_50MHz_edge <= sim_time_ns) {
            next_clk_50MHz_edge = sim_time_ns + CLK_50MHz_HALF_PERIOD;
            top->clk_50MHz = !top->clk_50MHz;  // 翻转 50MHz 时钟
        }
        if (next_clk_CPU_edge <= sim_time_ns) {
            next_clk_CPU_edge = sim_time_ns + CLK_CPU_HALF_PERIOD;
            top->clk_cpu = !top->clk_cpu;  // 翻转 CPU 时钟
            totalCycle += 0.5;

            // 在上升沿统计
            if (top->clk_cpu == 1) {
                if (top->commit == 1) {
                    commitCycle++;
                }
                if (top->pred_total == 1) {
                    predTotal++;
                    if (top->pred_miss == 1) predMiss++;
                    if (top->pred_total_b) predTotalB++;
                    if (top->pred_total_jr) predTotalJr++;
                    if (top->pred_miss_b) predMissB++;
                    if (top->pred_miss_jr) predMissJr++;
                }
            }
        }
        
        // 找到下一个事件时间
        double next_event_time = DBL_MAX;
        next_event_time = std::min(next_clk_50MHz_edge, next_clk_CPU_edge);
        
        // 执行到下一个事件
        step_and_advance(next_event_time - sim_time_ns);
        
        // 每 1s 打印一次
        static double last_print_time = 0.0;
        current_time = get_elapsed_ms();
        if (current_time - last_print_time >= 100) {
            last_print_time = current_time;
            if (top->seg != 0x3700'0000 || top->seg != 0x0000'0000) {
                SEG_getTime = top->seg & 0x000F'FFFF;
            }
            
            // 打印进度条
            std::cout << "\r" << "\033[6A" << "\033[2K" << "\033[96m";
            double barWidth = 70.0;
            double percentage = (PREV_TIME) ? sim_time_ns / NS2MS / PREV_TIME : 0.0;
            for (double cnt = 0.0; cnt <= barWidth; ++cnt){
                if (cnt / barWidth > percentage && !SEG_getTime) std::cout << "\033[0m=";
                else std::cout << "=";
                if (cnt == barWidth / 2) std::cout << " Simulation Started ";
            }
            if (!SEG_getTime) std::cout << "\033[0m";
            std::cout << "\n\n";

            std::cout << "RUN TIME:"
                      << std::right << std::setw(9) << std::fixed << std::setprecision(1) << current_time / 1000.0
                      << std::left << std::setw(10) << " s"
                      << "SIM TIME:"
                      << std::right << std::setw(13) << std::fixed << std::setprecision(2) << sim_time_ns / NS2MS
                      << std::left << std::setw(11) << " ms"
                      << "SEG:"
                      << std::right << std::setw(19) << std::hex << top->seg << std::dec
                      << std::left << std::setw(13) << " " << std::endl << std::endl << "\033[2K"
                      << "IPC:" 
                      << std::right << std::setw(16) << std::fixed << std::setprecision(4) << commitCycle / totalCycle
                      << std::left << std::setw(8) << " "
                      << "BPU accuracy:"
                      << std::right << std::setw(10) << (predTotal - predMiss) / predTotal
                      << std::left << std::setw(8) << " %" 
                      << "Branch:  " << (predTotal - predMissB) / predTotal << " %  "
                      << "JALR:  " << (predTotal - predMissJr) / predTotal << " %  "
                      << std::endl << std::endl << "\033[2K"
                      << "PC:" 
                      << std::right << std::setw(10) << std::hex << top->func_block_addr << " -> " 
                      << std::right << std::setw(8) << top->pc << std::dec 

                      << std::flush;
        }
    }
    std::cout << "\n\n=================================== Simulation Finished ===================================\033[0m\n";
    // 输出 LED 内容
    bool isTick = (top->LED == 0x0122'1c08);
    for (int row = 0; row < 4; ++row){
        uint8_t byte = (top->LED >> (24 - 8 * row)) & 0xFF;
        std::cout << std::endl;
        std::cout << std::setw(10);

        for(int col = 0; col < 8; ++col){
            bool lit;
            lit = (byte >> (7 - col)) & 1;
            if (lit){
                std::cout << "\033[93m" << "██" << "\033[0m";
            }
            else {
                std::cout << "  ";
            }
        }
    }

    std::cout << std::setw(16) << (isTick ? "\033[92mPASS!!!" : "\033[91mFAIL!!!") 
        << std::setw(12) << "Run time: " << std::hex << SEG_getTime << std::dec << " ms  " << "\033[0m\n\n";

    // 写回文件 传输给python
    std::ofstream f("software_results.txt");
    f << "IPC=" << commitCycle / totalCycle << std::endl
      << "REAL TIME=" << current_time / 1000.0 << std::endl
      << "RUN TIME=" << std::hex << SEG_getTime << std::dec << std::endl
      << "BPU ACCURACY=" << (predTotal - predMiss) / predTotal << std::endl
      << "LED=" << (isTick ? "PASS √" : "FAIL x");
    f.close();

    // tfp->close();
    delete top;
    // delete tfp;
    delete contextp;
    return 0;
}