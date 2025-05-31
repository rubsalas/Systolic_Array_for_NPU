#pragma once
#include "common.h"

class ProcessingElement {
public:
    void reset();
    void execute(DataType input, DataType weight, DataType partial_in);
    DataType get_output() const;

private:
    DataType partial_sum = 0;
};

class SystolicArray {
public:
    void configure(DataFlowType dataflow);
    void load_weights(const DataType* weights);
    void process(const DataType* inputs);
    void get_results(DataType* outputs);
    void step(); // Para modo depuración
    
private:
    ProcessingElement pes[ARRAY_ROWS][ARRAY_COLS];
    DataFlowType current_dataflow;
};