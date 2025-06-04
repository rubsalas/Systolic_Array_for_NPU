#ifndef SYSTOLIC_ARRAY_H
#define SYSTOLIC_ARRAY_H

#include "processing_element.h"
#include "matrix.h"
#include <vector>

class SystolicArray {
private:
    int size; // Tamaño NxN del arreglo
    std::vector<std::vector<ProcessingElement>> grid; // Matriz de PEs
    std::string dataflow; // Flujo de datos (WS, IS, OS)
    
    // Buffers para los datos
    std::vector<int> input_buffer;
    std::vector<int> weight_buffer;
    std::vector<int> output_buffer;
    
    // Métodos internos
    void loadWeights(const std::vector<int>& weights);
    void loadInputs(const std::vector<int>& inputs);
    void collectOutputs();
    void propagateData();
    
public:
    SystolicArray(int n, const std::string& df = "WS");
    
    // Configuración
    void setDataflow(const std::string& df);
    void enableAllReLU(bool enable);
    
    // Operaciones principales
    void configure(const Matrix& weights);
    Matrix multiply(const Matrix& input);
    
    // Simulación
    void simulateCycles(int cycles);
    void printState() const;
};

#endif // SYSTOLIC_ARRAY_H