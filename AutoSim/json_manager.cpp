#include "json_manager.h"
#include <fstream>
#include <iostream>
#include <iomanip>

// SimpleJSON 实现
void SimpleJSON::set(const std::string& key, const std::string& value) {
    data[key] = value;
}

std::string SimpleJSON::get(const std::string& key, const std::string& default_val) {
    if (data.find(key) != data.end()) {
        return data[key];
    }
    return default_val;
}

void SimpleJSON::saveToFile(const std::string& filename) {
    std::ofstream file(filename);
    if (file.is_open()) {
        file << "{\n";
        size_t i = 0;
        for (auto& [key, value] : data) {
            file << "  \"" << key << "\": \"" << value << "\"";
            if (++i < data.size()) file << ",";
            file << "\n";
        }
        file << "}\n";
    }
}

void SimpleJSON::loadFromFile(const std::string& filename) {
    std::ifstream file(filename);
    if (!file.is_open()) return;
    
    std::string line;
    while (std::getline(file, line)) {
        size_t colon_pos = line.find(':');
        if (colon_pos != std::string::npos) {
            size_t key_start = line.find('"');
            size_t key_end = line.find('"', key_start + 1);
            size_t val_start = line.find('"', colon_pos + 1);
            size_t val_end = line.find('"', val_start + 1);
            
            if (key_start != std::string::npos && key_end != std::string::npos &&
                val_start != std::string::npos && val_end != std::string::npos) {
                std::string key = line.substr(key_start + 1, key_end - key_start - 1);
                std::string value = line.substr(val_start + 1, val_end - val_start - 1);
                data[key] = value;
            }
        }
    }
}

// InstanceManager 实现
InstanceManager::InstanceManager(const std::string& filename) 
    : json_filename(filename) {
    loadFromJSON();
}

InstanceManager::~InstanceManager() {
    saveToJSON();
}

void InstanceManager::setCurrentInstance(const std::string& instance_name) {
    current_instance = instance_name;
    if (instances.find(current_instance) == instances.end()) {
        instances[current_instance] = {
            0.0,    // last_run_time_ms
            0.0,    // total_run_time_ms
            0,      // last_seg_value
            0,      // run_count
            current_instance
        };
    }
}

void InstanceManager::updateRun(double current_time_ms, uint32_t seg_value) {
    if (current_instance.empty()) return;
    
    auto& inst = instances[current_instance];
    
    // 显示上次运行信息
    if (inst.run_count > 0) {
        std::cout << "\n[实例 " << current_instance << "] 上次运行:\n";
        std::cout << "  运行时间: " << inst.last_run_time_ms << " ms\n";
        std::cout << "  SEG值: 0x" << std::hex << inst.last_seg_value << std::dec << "\n";
        std::cout << "  总运行次数: " << inst.run_count << "\n";
        std::cout << "  累计运行时间: " << inst.total_run_time_ms << " ms\n\n";
    }
    
    // 更新当前运行信息
    inst.last_run_time_ms = current_time_ms;
    inst.last_seg_value = seg_value;
    inst.total_run_time_ms += current_time_ms;
    inst.run_count++;
    
    // 保存到文件
    saveToJSON();
}

void InstanceManager::saveToJSON() {
    SimpleJSON json;
    
    for (auto& [name, info] : instances) {
        std::string prefix = name + "_";
        json.set(prefix + "last_run_time_ms", std::to_string(info.last_run_time_ms));
        json.set(prefix + "total_run_time_ms", std::to_string(info.total_run_time_ms));
        json.set(prefix + "last_seg_value", std::to_string(info.last_seg_value));
        json.set(prefix + "run_count", std::to_string(info.run_count));
    }
    
    json.saveToFile(json_filename);
}

void InstanceManager::loadFromJSON() {
    SimpleJSON json;
    json.loadFromFile(json_filename);
    
    // 注：完整实现需要解析所有实例，这里简化处理
    // 实际使用时可以从JSON恢复数据
}

void InstanceManager::printSummary() {
    std::cout << "\n========== 实例运行摘要 ==========\n";
    for (auto& [name, info] : instances) {
        std::cout << "实例: " << name << "\n";
        std::cout << "  运行次数: " << info.run_count << "\n";
        std::cout << "  累计运行时间: " << info.total_run_time_ms << " ms\n";
        std::cout << "  上次运行时间: " << info.last_run_time_ms << " ms\n";
        std::cout << "  上次SEG值: 0x" << std::hex << info.last_seg_value << std::dec << "\n\n";
    }
}

double InstanceManager::getLastRunTime(const std::string& instance_name) {
    if (instances.find(instance_name) != instances.end()) {
        return instances[instance_name].last_run_time_ms;
    }
    return 0.0;
}

uint32_t InstanceManager::getLastSegValue(const std::string& instance_name) {
    if (instances.find(instance_name) != instances.end()) {
        return instances[instance_name].last_seg_value;
    }
    return 0;
}

int InstanceManager::getRunCount(const std::string& instance_name) {
    if (instances.find(instance_name) != instances.end()) {
        return instances[instance_name].run_count;
    }
    return 0;
}