#ifndef SYSTOLIC_ARRAY_H
#define SYSTOLIC_ARRAY_H

#include <vector>
#include <thread>

// Clase que simula un arreglo sistólico ejecutado sobre múltiples hilos (PEs)
class SystolicArray {
public:
    /*
     * Constructor
     * 
     * rows: filas de la matriz A
     * cols: columnas de la matriz B
     * sharedDim: dimensión compartida entre A y B (columnas A = filas B)
     * peCount: cantidad de hilos (PEs simulados)
     */
    SystolicArray(int rows, int cols, int sharedDim, int peCount);

    // Carga las matrices A y B que se van a multiplicar
    void loadMatrices(const std::vector<std::vector<int>>& A,
                      const std::vector<std::vector<int>>& B);

    // Ejecuta la multiplicación en paralelo y aplica activación
    void run();

    // Obtiene el resultado con activación ReLU aplicada
    std::vector<std::vector<int>> getOutput();

    // Obtiene el resultado crudo sin aplicar ReLU (útil para depuración)
    std::vector<std::vector<int>> getPreActivationOutput();

private:
    int M, K, N;       // M: filas A, K: columnas B, N: columnas A / filas B
    int numPEs;        // Número de hilos (PEs) simulados

    std::vector<std::vector<int>> A, B;                     // Matrices de entrada
    std::vector<std::vector<int>> output;                   // Resultado final con activación
    std::vector<std::vector<int>> pre_activation_output;    // Resultado sin activación

    // Aplica ReLU: si el valor es negativo, lo convierte en 0
    void applyActivation();

    // Función ejecutada por cada hilo (PE), recibe el rango de filas a procesar
    void computeBlock(int start_row, int end_row);
};

#endif
