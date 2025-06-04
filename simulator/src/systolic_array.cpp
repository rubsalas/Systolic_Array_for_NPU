#include "systolic_array.h"
#include <iostream>
#include <stdexcept>

SystolicArray::SystolicArray(int n, const std::string &df) : size(n), dataflow(df)
{
    if (n <= 0)
    {
        throw std::invalid_argument("El tamaño del arreglo debe ser positivo");
    }

    // Inicializar la cuadrícula de PEs
    grid.resize(size, std::vector<ProcessingElement>(size));

    // Inicializar buffers
    input_buffer.resize(size, 0);
    weight_buffer.resize(size, 0);
    output_buffer.resize(size, 0);
}

void SystolicArray::setDataflow(const std::string &df)
{
    if (df != "WS" && df != "IS" && df != "OS")
    {
        throw std::invalid_argument("Flujo de datos no válido. Use WS, IS u OS");
    }
    dataflow = df;
}

void SystolicArray::enableAllReLU(bool enable)
{
    for (auto &row : grid)
    {
        for (auto &pe : row)
        {
            pe.set_relu(enable);
        }
    }
}

void SystolicArray::configure(const Matrix &weights)
{
    if (weights.getRows() != size || weights.getCols() != size)
    {
        throw std::invalid_argument("Las dimensiones de los pesos deben coincidir con el tamaño del arreglo");
    }

    // Cargar pesos según el flujo de datos
    if (dataflow == "WS")
    { // Weight Stationary
        for (int i = 0; i < size; ++i)
        {
            for (int j = 0; j < size; ++j)
            {
                // Los pesos se cargan en cada PE y permanecen allí
                grid[i][j].process(0, weights.getData()[i][j], 0);
            }
        }
    }
    else if (dataflow == "IS")
    { // Input Stationary
        // Implementación similar pero con diferente flujo
        // (simplificado para este ejemplo)
        weight_buffer.clear();
        for (int j = 0; j < size; ++j)
        {
            for (int i = 0; i < size; ++i)
            {
                weight_buffer.push_back(weights.getData()[i][j]);
            }
        }
    }
}

void SystolicArray::loadWeights(const std::vector<int> &weights)
{
    if (weights.size() != size * size)
    {
        throw std::invalid_argument("Número incorrecto de pesos");
    }
    weight_buffer = weights;
}

void SystolicArray::loadInputs(const std::vector<int> &inputs)
{
    if (inputs.size() != size)
    {
        throw std::invalid_argument("Número incorrecto de entradas");
    }
    input_buffer = inputs;
}

void SystolicArray::propagateData()
{
    // Propagación de datos según el flujo seleccionado
    if (dataflow == "WS")
    { // Weight Stationary
        // Propagamos inputs hacia abajo y outputs hacia la derecha
        for (int i = size - 1; i >= 0; --i)
        {
            for (int j = 0; j < size; ++j)
            {
                int a_in = (i == 0) ? input_buffer[j] : grid[i - 1][j].get_a_out();
                int b_in = (j == 0) ? 0 : grid[i][j - 1].get_b_out();
                int acc_in = (i == 0 || j == 0) ? 0 : grid[i - 1][j - 1].get_result();

                grid[i][j].process(a_in, b_in, acc_in);
            }
        }

        // Recoger outputs del borde derecho
        for (int i = 0; i < size; ++i)
        {
            output_buffer[i] = grid[i][size - 1].get_result();
        }
    }
    // Otros flujos de datos pueden implementarse aquí
}

void SystolicArray::collectOutputs()
{
    // Implementación específica según el flujo de datos
    if (dataflow == "WS")
    {
        for (int i = 0; i < size; ++i)
        {
            output_buffer[i] = grid[i][size - 1].get_result();
        }
    }
}

Matrix SystolicArray::multiply(const Matrix& input) {
    if (input.getRows() != size || input.getCols() != size) {
        throw std::invalid_argument("Las dimensiones de entrada deben coincidir con el tamaño del arreglo");
    }
    
    Matrix result(size, size);
    
    for (int col = 0; col < size; ++col) {
        // Cargar columna de entrada
        std::vector<int> input_col;
        for (int row = 0; row < size; ++row) {
            input_col.push_back(input.getData()[row][col]);
        }
        loadInputs(input_col);
        
        // Simular suficientes ciclos para propagar los datos
        for (int cycle = 0; cycle < 2*size-1; ++cycle) {
            propagateData();
            
            if (cycle >= size-1) {
                // Empezamos a obtener resultados
                collectOutputs();
                for (int row = 0; row < size; ++row) {
                    result.setValue(row, col, output_buffer[row]);
                }
            }
        }
    }
    
    return result;
}

void SystolicArray::simulateCycles(int cycles)
{
    for (int i = 0; i < cycles; ++i)
    {
        propagateData();
        std::cout << "Ciclo " << i + 1 << " completado." << std::endl;
        printState();
    }
}

void SystolicArray::printState() const
{
    std::cout << "\nEstado del arreglo sistólico (" << size << "x" << size << "):" << std::endl;
    std::cout << "Flujo de datos: " << dataflow << std::endl;

    for (int i = 0; i < size; ++i)
    {
        for (int j = 0; j < size; ++j)
        {
            std::cout << "PE[" << i << "][" << j << "]: ";
            std::cout << "A=" << grid[i][j].get_a_out() << ", ";
            std::cout << "B=" << grid[i][j].get_b_out() << ", ";
            std::cout << "R=" << grid[i][j].get_result();
            std::cout << "\t";
        }
        std::cout << std::endl;
    }

    std::cout << "Buffer de salida: ";
    for (int val : output_buffer)
    {
        std::cout << val << " ";
    }
    std::cout << std::endl;
}