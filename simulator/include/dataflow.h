#pragma once
#include "common.h"

class DataFlowManager {
public:
    void configure(DataFlowType type);
    void execute_ws(); // Weight Stationary
    void execute_is(); // Input Stationary
    void execute_os(); // Output Stationary
    
private:
    DataFlowType current_flow;
};