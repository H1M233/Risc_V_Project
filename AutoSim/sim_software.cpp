#include <verilated.h>
#include <verilated_fst_c.h>
#include "Vtb_verilator_software.h"
#include <iostream>
#include <iomanip>
#include <cfloat>
#include <cstdio>
#include <cmath>
#include <chrono>
#include <fstream>

int main(int argc, char** argv) {
    // 宏传递：
    // ENABLE_TRACE:        启用波形记录
    // TRACE_START_TIME:    波形记录起始时间
    // TRACE_END_TIME:      波形记录结束时间
    
    // 环境变量传递：
    // CLK_FREQ:            时钟频率
    // PREV_TIME:           上次仿真的计时器结果

    // 仿真配置
    const double CLK_FREQ = std::stoi(std::getenv("CLK_FREQ"));
    const double CLK_CPU_HALF_PERIOD = 500.0 / CLK_FREQ;
    const double CLK_50MHz_HALF_PERIOD = 10.0;          // 50 MHz
    const double NS2MS = 1000000.0;
    const double SIM_TIME = 30.0 * 1000.0 * NS2MS;
    double sim_time_ns = 0.0;                           // 定义 sim_time_ns
    double time_ms = 0.0;
    double next_clk_50MHz_edge = 0.0;
    double next_clk_CPU_edge = 0.0;
    int SEG_getTime = 0;
    double waitTime = 0.0;
    const double PREV_TIME = std::stoi(std::getenv("PREV_TIME")) * NS2MS;

    // 初始化
    Verilated::commandArgs(argc, argv);
    
    // 创建上下文
    VerilatedContext* contextp = new VerilatedContext;
    contextp->timeunit(-9);         // ns
    contextp->timeprecision(-9);    // ns

    // 创建顶层模块
    Vtb_verilator_software* top = new Vtb_verilator_software{contextp, "TOP"};

    // 记录波形
    #ifdef ENABLE_TRACE
        Verilated::traceEverOn(true);
        VerilatedFstC* tfp = new VerilatedFstC;
        top->trace(tfp, 99);                    // 追踪99层深度
        tfp->open("vcd/verilator_software.vcd");        // 打开波形文件
    #endif

    // 计算 IPC
    uint64_t totalCycle = 0;
    uint64_t commitCycle = 0;

    // 计算预测准确率
    uint64_t predTotal = 0;
    uint64_t predMiss = 0;
    uint64_t predMissB = 0;
    uint64_t predMissJr = 0;
    uint64_t predTotalB = 0;
    uint64_t predTotalJr = 0;

    // 剩余时间计算
    double lastRunTime = 0.0;
    double lastSimTime = 0.0;
    double speed_ns = 0.0;
    int speedRef = 100;
    int validRef = 0;
    
    // 进度条设置
    const double barWidth = 70.0;

    // 打印更新频率 - 影响仿真性能
    const double tf = 1;  // 1 = 每仿真 1ms 更新一次

    // 统计数据
    double REAL_TIME, RUN_TIME;
    int SEG;
    double IPC, BPU_ACCURACY, BRANCH, JALR;
    int PC0, PC1;
    int FUNC_BLOCK_PC0, FUNC_BLOCK_PC1;

    // 跑飞分析
    const int PC_RANGE_START = 0x8000'0000;
    const int PC_RANGE_END = 0x8000'3FFF;
    bool isPC0_OutOfRange = false;
    double PC0_firstTime_OutOfRange = 0.0;
    int PC0_OutOfRange = 0x0;
    bool isPC1_OutOfRange = false;
    double PC1_firstTime_OutOfRange = 0.0;
    int PC1_OutOfRange = 0x0;

    // 记录函数
    auto step_and_advance = [&](double delta_time_ns) {
        if (delta_time_ns > 0.0) {
            contextp->time(sim_time_ns * 1000);
            top->eval();
            #ifdef ENABLE_TRACE
                if (sim_time_ns > TRACE_START_TIME * NS2MS && sim_time_ns < TRACE_END_TIME * NS2MS) tfp->dump(sim_time_ns * 1000);
            #endif
            sim_time_ns += delta_time_ns;
        }
    };
    
    #ifdef DEBUGGING
    std::cout << "=================================== Simulation Started ===================================";
    std::cout << "\n\n\n\n\n\n\n\n\n";
    #endif
    std::cout << "\n\n";

    // 计时器
    std::chrono::steady_clock::time_point start_time = std::chrono::steady_clock::now();;
    double current_time;
    auto get_elapsed_ms = [&]() -> double {
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(now - start_time);
        return elapsed.count() / 1000.0;
    };
    
    // 试探脉冲
    const double rst_time = 20.0;
    top->rst = 0;
    top->clk_50MHz = 0;
    top->clk_cpu = 0;
    step_and_advance(rst_time);

    top->clk_50MHz = 1;
    top->clk_cpu = 1;
    step_and_advance(CLK_50MHz_HALF_PERIOD);
    
    top->clk_50MHz = 0;
    step_and_advance(CLK_50MHz_HALF_PERIOD - CLK_CPU_HALF_PERIOD);

    top->clk_cpu = 0;
    step_and_advance(rst_time - CLK_CPU_HALF_PERIOD);

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

            // 在 clk_cpu 上升沿统计
            if (top->clk_cpu) {
                totalCycle++;
                commitCycle += top->commit;
                predTotal   += top->pred_total;
                predMiss    += top->pred_miss;
                #ifdef DEBUGGING
                predTotalB  += top->pred_total_b;
                predTotalJr += top->pred_total_jr;
                predMissB   += top->pred_miss_b;
                predMissJr  += top->pred_miss_jr;

                PC0 = top->pc0;
                PC1 = top->pc1;
                if (((PC0 < PC_RANGE_START || PC0 > PC_RANGE_END) && PC0 != 0) && !isPC0_OutOfRange) {
                    isPC0_OutOfRange = true;
                    PC0_firstTime_OutOfRange = sim_time_ns / NS2MS;
                    PC0_OutOfRange = PC0;
                }
                if (((PC1 < PC_RANGE_START || PC1 > PC_RANGE_END) && PC1 != 0) && !isPC1_OutOfRange) {
                    isPC1_OutOfRange = true;
                    PC1_firstTime_OutOfRange = sim_time_ns / NS2MS;
                    PC1_OutOfRange = PC1;
                }
                #endif
            }
        }
        
        // 找到下一个事件时间
        double next_event_time = std::min(next_clk_50MHz_edge, next_clk_CPU_edge);
        
        // 执行到下一个事件
        step_and_advance(next_event_time - sim_time_ns);
        
        // 每仿真时 1 ms 打印一次
        #ifdef DEBUGGING
        static double last_print_sim_time = 0.0;
        if (sim_time_ns - last_print_sim_time >= NS2MS / tf) {
            current_time = get_elapsed_ms();
            last_print_sim_time = sim_time_ns;
            SEG = top->SEG;
            if (SEG != 0x3700'0000 && SEG != 0x0000'0000) {
                SEG_getTime = SEG & 0x000F'FFFF;
            }
            
            // 计算剩余时间
            if (lastSimTime != 0.0) {
                speed_ns = (speed_ns * (validRef - 1) + (sim_time_ns - lastSimTime) / (current_time - lastRunTime) * 100) / validRef;
            }
            if (validRef <= speedRef) validRef++;
            lastSimTime = sim_time_ns;
            lastRunTime = current_time;
            int ETATime_s_total = (PREV_TIME) ? (PREV_TIME - sim_time_ns) / speed_ns / 10 : -1;
            int ETATime_s = ETATime_s_total % 60;
            int ETATime_m = ETATime_s_total / 60; 

            // 统计数据
            REAL_TIME = current_time / 1000.0;
            RUN_TIME = sim_time_ns / NS2MS;
            IPC = commitCycle / static_cast<float>(totalCycle);
            BPU_ACCURACY = (predTotal - predMiss) / static_cast<float>(predTotal);
            BRANCH = (predTotalB - predMissB) / static_cast<float>(predTotalB);
            JALR = (predTotalJr - predMissJr) / static_cast<float>(predTotalJr);
            FUNC_BLOCK_PC0 = top->func_block_pc0;
            FUNC_BLOCK_PC1 = top->func_block_pc1;

            // 打印进度条
            std::cout << "\r" << "\033[11A" << "\033[2K" << "\033[96m";
            double percentage = (PREV_TIME) ? sim_time_ns / PREV_TIME : 0.0;
            int filled = (int)(percentage * barWidth);
            for (int cnt = 0.0; cnt <= barWidth; ++cnt){
                if (cnt > filled && !SEG_getTime) std::cout << "\033[0m=";
                else std::cout << "=";
                if (cnt == barWidth / 2) std::cout << " Simulation Started ";
            }
            if (!SEG_getTime) std::cout << "\033[0m";
            std::cout << "\n\n";

            std::cout << "REAL TIME:"
                      << std::right << std::setw(14) << std::fixed << std::setprecision(2) << REAL_TIME << " s"
                      << std::setw(12) << "RUN TIME:"
                      << std::right << std::setw(13) << std::fixed << std::setprecision(0) << RUN_TIME << " ms"
                      << std::setw(8) << "SEG:"
                      << std::right << std::setw(11) << std::hex << SEG << std::dec
                      << std::endl << std::endl << "\033[2K"

                      << "IPC:" 
                      << std::right << std::setw(21) << std::fixed << std::setprecision(4) << IPC
                      << std::setw(17) << "BPU ACCURACY:"
                      << std::right << std::setw(12) << BPU_ACCURACY
                      << std::setw(13) << "BRANCH:  " << BRANCH
                      << std::setw(10) << "JALR:  " << JALR
                      << std::endl << std::endl << "\033[2K"

                      << "PC0:" 
                      << std::right << std::setw(10) << std::hex << FUNC_BLOCK_PC0 << " -> " 
                      << std::right << std::setw(8) << PC0 << std::dec
                      << std::setw(13) << "IN RANGE: "
                      << ((isPC1_OutOfRange) ? "x | " : "√ | ") << PC0_firstTime_OutOfRange << " ms | " << PC0_OutOfRange
                      << "  stuck: " << ((top->hold_signal) ? "√" : "x") << "    flush: " << ((top->flush_signal) ? "√" : "x")
                      << std::endl << std::endl << "\033[2K"

                      << "PC1:"
                      << std::right << std::setw(10) << std::hex << FUNC_BLOCK_PC1 << " -> " 
                      << std::right << std::setw(8) << PC1 << std::dec
                      << std::setw(13) << "IN RANGE: "
                      << ((isPC1_OutOfRange) ? "x | " : "√ | ") << PC1_firstTime_OutOfRange << " ms | " << PC1_OutOfRange
                      << "  QUERY_VALUE: " << top->branch1 << " / " << top->branch2
                      << std::endl << std::endl << "\033[2K"

                      << "ETA: "
                      << std::right << std::setw(13) << ETATime_m << " m"
                      << std::right << std::setw(3) << ETATime_s << " s"

                      << std::endl << std::flush;
        }
        #else
        static double last_print_sim_time = 0.0;
        if (sim_time_ns - last_print_sim_time >= NS2MS / tf) {
            current_time = get_elapsed_ms();
            last_print_sim_time = sim_time_ns;
            SEG = top->SEG;
            if (SEG != 0x3700'0000 && SEG != 0x0000'0000) {
                SEG_getTime = SEG & 0x000F'FFFF;
            }

            // 计算剩余时间
            if (lastSimTime != 0.0) {
                speed_ns = (speed_ns * (validRef - 1) + (sim_time_ns - lastSimTime) / (current_time - lastRunTime) * 100) / validRef;
            }
            if (validRef <= speedRef) validRef++;
            lastSimTime = sim_time_ns;
            lastRunTime = current_time;
            int ETATime_s_total = (PREV_TIME) ? (PREV_TIME - sim_time_ns) / speed_ns / 10 : -1;
            int ETATime_s = ETATime_s_total % 60;
            int ETATime_m = ETATime_s_total / 60; 

            // 基础数据统计
            REAL_TIME = current_time / 1000.0;
            RUN_TIME = sim_time_ns / NS2MS;
            IPC = commitCycle / static_cast<float>(totalCycle);
            BPU_ACCURACY = (predTotal - predMiss) / static_cast<float>(predTotal);

            // 打印进度条
            std::cout << "\r" << "\033[A" << "\033[2K" << "\033[96m";
            double percentage = (PREV_TIME) ? sim_time_ns / PREV_TIME : 0.0;
            int filled = (int)(percentage * barWidth);
            for (int cnt = 0.0; cnt <= barWidth; ++cnt){
                if (cnt > filled && !SEG_getTime) std::cout << "\033[0m░";
                else std::cout << "█";
            }
            if (!SEG_getTime) std::cout << "\033[0m";
            std::cout << " " << std::right << std::setw(3) << int(percentage * 100) << " %";
            std::cout << "\n ETA: " << std::right << std::setw(2) << ETATime_m << " m" << std::right << std::setw(4) << ETATime_s << " s        ";
        }
        #endif
    }
    #ifdef DEBUGGING
    std::cout << "\n=================================== Simulation Finished ===================================\033[0m\n";
    #endif
    // 输出 LED 内容
    bool isTick = (top->LED == 0x0122'1c08 | top->LED == 0x078b'7323);
    for (int row = 0; row < 4; ++row){
        uint8_t byte = (top->LED >> (24 - 8 * row)) & 0xFF;
        std::cout << std::endl;
        for(int col = 0; col < 8; ++col){
            bool lit;
            std::cout << std::setw(2);
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
        << std::setw(12) << "Run time: " << std::hex << SEG_getTime << std::dec << " ms  LED: 0x" << std::hex << top->LED << std::dec <<"\033[0m\n\n";

    // 写回文件 传输给python
    std::ofstream f("software_results.txt");
    f << "IPC=" << IPC << std::endl
      << "REAL TIME=" << REAL_TIME << std::endl
      << "RUN TIME=" << RUN_TIME << std::endl
      << "SEG TIME=" << std::hex << SEG_getTime << std::dec << std::endl
      << "BPU ACCURACY=" << BPU_ACCURACY << std::endl
      << "LED=" << (isTick ? "PASS √" : "FAIL x");
    f.close();

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