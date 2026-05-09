#ifndef JSON_MANAGER_H
#define JSON_MANAGER_H

#include <string>
#include <map>
#include <cstdint>

// 简单的JSON处理类
class SimpleJSON {
private:
    std::map<std::string, std::string> data;
    
public:
    void set(const std::string& key, const std::string& value);
    std::string get(const std::string& key, const std::string& default_val = "");
    void saveToFile(const std::string& filename);
    void loadFromFile(const std::string& filename);
};

// 实例管理类
class InstanceManager {
private:
    struct InstanceInfo {
        double last_run_time_ms;
        double total_run_time_ms;
        uint32_t last_seg_value;
        int run_count;
        std::string instance_name;
    };
    
    std::map<std::string, InstanceInfo> instances;
    std::string json_filename;
    std::string current_instance;
    
public:
    InstanceManager(const std::string& filename = "instance_state.json");
    ~InstanceManager();
    
    void setCurrentInstance(const std::string& instance_name);
    void updateRun(double current_time_ms, uint32_t seg_value);
    void saveToJSON();
    void loadFromJSON();
    void printSummary();
    double getLastRunTime(const std::string& instance_name);
    uint32_t getLastSegValue(const std::string& instance_name);
    int getRunCount(const std::string& instance_name);
};

#endif // INSTANCE_MANAGER_H