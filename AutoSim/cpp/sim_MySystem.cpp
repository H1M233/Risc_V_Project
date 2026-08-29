#include <verilated.h>
#include <verilated_fst_c.h>
#include "Vtb_verilator_MySystem.h"
#include <iostream>
#include <iomanip>
#include <cfloat>
#include <cstdio>   
#include <cmath>
#include <chrono>
#include <fstream>
#include <deque>
#include <string>
#include <cstring>
#include <cerrno>
#include <fcntl.h>
#include <thread>

#include <pty.h>
#include <termios.h>
#include <unistd.h>
#include <sys/select.h>

class VirtualUartBridge {
public:
    explicit VirtualUartBridge(const std::string& alias_path = "/tmp/RV_UART", int baud_rate = 1000000)
    : baud_rate_(baud_rate),
        bit_period_ns_(static_cast<int64_t>(1'000'000'000.0 / baud_rate + 0.5)),
        next_rx_bit_time_ns_(0.0),
        next_tx_bit_time_ns_(0.0),
        last_tx_bit_(true),
        rx_state_(RxState::Idle),
        tx_state_(TxState::Idle),
        rx_bit_index_(0),
        tx_bit_index_(0),
        current_rx_byte_(0),
        current_tx_byte_(0),
        master_fd_(-1) 
        {
            int master_fd = -1;
            int slave_fd = -1;
            if (openpty(&master_fd, &slave_fd, nullptr, nullptr, nullptr) == 0) {
                master_fd_ = master_fd;
                fcntl(master_fd_, F_SETFL, O_NONBLOCK);
                char* pty_name = ptsname(master_fd_);
                if (pty_name != nullptr) {
                    pty_path_ = pty_name;
                }
                
                // 创建符号链接
                unlink(alias_path.c_str());
                if (symlink(pty_name, alias_path.c_str()) != 0) {
                    perror("symlink");
                    close(master_fd_);
                }

                close(slave_fd);    // 关闭被控
                std::cout << "[UART] Virtual serial port ready: " << pty_path_ << " or " << alias_path << std::endl;

                // 通知 Python 端
                std::ofstream("/tmp/RV_UART_screen_ready") << "screen is now open";

                // 等待 PTY 启用
                std::cout << "[UART] waiting for terminal open..." << std::endl;
                while (true) {
                    char buf;
                    ssize_t n = read(master_fd_, &buf, 1);
                    if (n >= 0 || errno == EAGAIN || errno == EWOULDBLOCK) {
                        break;
                    }
                    if (errno == EIO) {
                        std::this_thread::sleep_for(std::chrono::milliseconds(100));
                        continue;
                    }
                    std::cerr << "[UART] unexpected PTY error: " << std::strerror(errno) << std::endl;
                    break;
                }
                std::cout << "[UART] terminal open, starting simulation in 1 second...\n\n";
                std::this_thread::sleep_for(std::chrono::seconds(1));

            } else {
                std::cerr << "[UART] openpty failed: " << std::strerror(errno) << std::endl;
        }
    }

    ~VirtualUartBridge() {
        if (master_fd_ >= 0) {
            close(master_fd_);
        }
    }

    void poll_io() {
        if (master_fd_ < 0) {
            return;
        }
        char buffer[256];
        ssize_t bytes_read = read(master_fd_, buffer, sizeof(buffer));
        if (bytes_read > 0) {
            for (ssize_t i = 0; i < bytes_read; ++i) {
                // printf("[UART] Received from PTY: 0x%02X (%c)\n", buffer[i], isprint(buffer[i]) ? buffer[i] : '.');
                rx_bytes_.push_back(static_cast<unsigned char>(buffer[i]));
            }
        } else if (bytes_read < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
            std::cerr << "[UART] read from PTY failed: " << std::strerror(errno) << std::endl;
            
        }
    }

    void drive_rx(double sim_time_ns, unsigned char& uart_rx_bit) {
        if (sim_time_ns < next_rx_bit_time_ns_) {
            return;
        }

        switch (rx_state_) {
            case RxState::Idle:
                if (!rx_bytes_.empty()) {
                    current_rx_byte_ = rx_bytes_.front();
                    rx_bytes_.pop_front();
                    rx_state_ = RxState::Start;
                    uart_rx_bit = 0;
                } else {
                    uart_rx_bit = 1;
                }
                break;
            case RxState::Start:
                rx_state_ = RxState::Data;
                rx_bit_index_ = 0;
                uart_rx_bit = static_cast<unsigned char>((current_rx_byte_ >> rx_bit_index_) & 0x1);
                break;
            case RxState::Data:
                if (rx_bit_index_ < 7) {
                    ++rx_bit_index_;
                    uart_rx_bit = static_cast<unsigned char>((current_rx_byte_ >> rx_bit_index_) & 0x1);
                } else {
                    rx_state_ = RxState::Stop;
                    uart_rx_bit = 1;
                }
                break;
            case RxState::Stop:
                rx_state_ = RxState::Idle;
                uart_rx_bit = 1;
                break;
        }

        next_rx_bit_time_ns_ = sim_time_ns + bit_period_ns_;
    }

    void observe_tx(double sim_time_ns, bool tx_bit) {
        int64_t sim_ns = static_cast<int64_t>(sim_time_ns);
        bool prev_bit = last_tx_bit_;
        last_tx_bit_ = tx_bit;
    
        switch (tx_state_) {
            case TxState::Idle:
                if (prev_bit && !tx_bit) {
                    // 检测到起始位，准备在半个周期后采样
                    tx_state_ = TxState::StartBit;
                    tx_bit_index_ = 0;
                    current_tx_byte_ = 0;
                    next_tx_bit_time_ns_ = sim_ns + bit_period_ns_ / 2;
                }
                break;
    
            case TxState::StartBit:
                if (sim_ns >= next_tx_bit_time_ns_) {
                    // 验证起始位（应为 0）
                    if (!tx_bit) {
                        tx_state_ = TxState::DataBit;
                        tx_bit_index_ = 0;
                        next_tx_bit_time_ns_ = sim_ns + bit_period_ns_;
                    } else {
                        tx_state_ = TxState::Idle;  // 起始位错误，复位
                    }
                }
                break;
    
            case TxState::DataBit:
                if (sim_ns >= next_tx_bit_time_ns_) {
                    // 采样数据位（在比特周期中间）
                    if (tx_bit) {
                        current_tx_byte_ |= (1u << tx_bit_index_);
                    }
                    tx_bit_index_++;
                    
                    if (tx_bit_index_ >= 8) {
                        // 所有数据位采样完成，准备采样停止位
                        tx_state_ = TxState::StopBit;
                        next_tx_bit_time_ns_ = sim_ns + bit_period_ns_ / 2;
                    } else {
                        next_tx_bit_time_ns_ = sim_ns + bit_period_ns_;
                    }
                }
                break;
    
            case TxState::StopBit:
                if (sim_ns >= next_tx_bit_time_ns_) {
                    // 验证停止位（应为 1）
                    if (tx_bit) {
                        emit_byte(static_cast<unsigned char>(current_tx_byte_));
                    }
                    tx_state_ = TxState::Idle;
                }
                break;
        }
    }

    const std::string& pty_path() const { return pty_path_; }

private:
    void emit_byte(unsigned char byte) {
        if (master_fd_ >= 0) {
            ssize_t written = write(master_fd_, &byte, 1);
            if (written < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
                std::cerr << "[UART] write to PTY failed: " << std::strerror(errno) << std::endl;
            }
        }
    }

    enum class RxState { Idle, Start, Data, Stop };
    // enum class TxState { Idle, Data, Stop };
    enum class TxState { Idle, StartBit, DataBit, StopBit };

    int baud_rate_;
    double bit_period_ns_;
    double next_rx_bit_time_ns_;
    double next_tx_bit_time_ns_;
    bool last_tx_bit_;
    RxState rx_state_;
    TxState tx_state_;
    int rx_bit_index_;
    int tx_bit_index_;
    unsigned char current_rx_byte_;
    unsigned char current_tx_byte_;
    std::deque<unsigned char> rx_bytes_;
    std::string pty_path_;
    int master_fd_;
};

int main(int argc, char** argv) {
    // 宏传递：
    // ENABLE_TRACE:        启用波形记录
    // TRACE_START_TIME:    波形记录起始时间
    // TRACE_END_TIME:      波形记录结束时间
    
    // 环境变量传递：
    // CLK_FREQ:            时钟频率

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

    // 初始化
    Verilated::commandArgs(argc, argv);
    
    // 创建上下文
    VerilatedContext* contextp = new VerilatedContext;
    contextp->timeunit(-9);         // ns
    contextp->timeprecision(-9);    // ns

    // 创建顶层模块
    Vtb_verilator_MySystem* top = new Vtb_verilator_MySystem{contextp, "TOP"};

    // 记录波形
    #ifdef ENABLE_TRACE
        Verilated::traceEverOn(true);
        VerilatedFstC* tfp = new VerilatedFstC;
        top->trace(tfp, 99);                    // 追踪99层深度
        tfp->open("vcd/verilator_system.vcd");        // 打开波形文件
    #endif

    // 创建虚拟串口
    VirtualUartBridge uart_bridge("/tmp/RV_UART", 1000000);

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

    // 打印更新频率 - 影响仿真性能
    const double tf = 1;  // 1 = 每仿真 1ms 更新一次

    // 统计数据
    double REAL_TIME, RUN_TIME;
    int SEG;
    int LED;
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
            sim_time_ns += delta_time_ns;

            #ifdef ENABLE_TRACE
                if (sim_time_ns > TRACE_START_TIME * NS2MS && sim_time_ns < TRACE_END_TIME * NS2MS) tfp->dump(sim_time_ns * NS2MS);
            #endif
        }
    };
    
    std::cout << "=================================== Simulation Started ===================================\n\n\n\n\n\n\n\n\n";

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
    while (sim_time_ns < SIM_TIME) {
        // 计算下一个时钟边沿的时间
        if (next_clk_50MHz_edge <= sim_time_ns) {
            next_clk_50MHz_edge = sim_time_ns + CLK_50MHz_HALF_PERIOD;
            top->clk_50MHz = !top->clk_50MHz;  // 翻转 50MHz 时钟
            if (top->clk_50MHz) {
                // uart -> 虚拟串口
                uart_bridge.poll_io();
                uart_bridge.drive_rx(sim_time_ns, top->uart_rx);
                uart_bridge.observe_tx(sim_time_ns, top->uart_tx);
            }
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
            }
        }
        
        // 找到下一个事件时间
        double next_event_time = std::min(next_clk_50MHz_edge, next_clk_CPU_edge);
        
        // 执行到下一个事件
        step_and_advance(next_event_time - sim_time_ns);
        
        // 每仿真时 1 ms 打印一次
        static double last_print_sim_time = 0.0;
        if (sim_time_ns - last_print_sim_time >= NS2MS / tf) {
            current_time = get_elapsed_ms();
            last_print_sim_time = sim_time_ns;

            // 统计数据
            REAL_TIME = current_time / 1000.0;
            RUN_TIME = sim_time_ns / NS2MS;
            SEG = top->SEG;
            LED = top->LED & 0xF;
            IPC = commitCycle / static_cast<float>(totalCycle);
            BPU_ACCURACY = (predTotal - predMiss) / static_cast<float>(predTotal);
            BRANCH = (predTotalB - predMissB) / static_cast<float>(predTotalB);
            JALR = (predTotalJr - predMissJr) / static_cast<float>(predTotalJr);
            FUNC_BLOCK_PC0 = top->func_block_pc0;
            FUNC_BLOCK_PC1 = top->func_block_pc1;

            std::cout << "\r" << "\033[7A" << "\033[2K";

            std::cout << "REAL TIME:"
                      << std::right << std::setw(14) << std::fixed << std::setprecision(2) << REAL_TIME << " s"
                      << std::setw(12) << "RUN TIME:"
                      << std::right << std::setw(13) << std::fixed << std::setprecision(0) << RUN_TIME << " ms"
                      << std::setw(8) << "SEG:"
                      << std::right << std::setw(11) << std::hex << SEG << std::dec
                      << std::setw(7) << "LED:"
                      << std::right << std::setw(9) << std::bitset<4>(LED)
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
                      << "  QUERY_VALUE: " << top->branch1 << " / " << std::hex << top->branch2 << std::dec
                      << std::endl << std::flush;
        }
    }
    std::cout << "\n=================================== Simulation Finished ===================================\033[0m\n";

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