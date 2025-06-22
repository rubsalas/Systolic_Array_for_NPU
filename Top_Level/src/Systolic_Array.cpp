#include "Systolic_Array.h"
#include <algorithm>  // std::min

// Constructor del arreglo sistólico
SystolicArray::SystolicArray(int rows, int cols, int sharedDim, int peCount)
    : M(rows), K(cols), N(sharedDim), numPEs(peCount) {
    output.resize(M, std::vector<int>(K, 0));
    pre_activation_output.resize(M, std::vector<int>(K, 0));
}

// Carga las matrices A y B a multiplicar
void SystolicArray::loadMatrices(const std::vector<std::vector<int>>& matA,
                                 const std::vector<std::vector<int>>& matB) {
    A = matA;
    B = matB;
}

// Ejecuta la multiplicación A x B distribuyendo el trabajo entre hilos
void SystolicArray::run() {
    std::vector<std::thread> threads;
    int rows_per_pe = (M + numPEs - 1) / numPEs;  // Distribución equilibrada

    for (int pe = 0; pe < numPEs; ++pe) {
        int start_row = pe * rows_per_pe;
        int end_row = std::min(start_row + rows_per_pe, M);

        // Cada hilo ejecuta computeBlock sobre un subconjunto de filas
        threads.emplace_back(&SystolicArray::computeBlock, this, start_row, end_row);
    }

    // Espera a que todos los hilos finalicen
    for (auto& t : threads)
        t.join();

    // Aplica activación ReLU sobre el resultado
    applyActivation();
}

// Función que ejecuta cada hilo: procesa un bloque de filas de A contra B
void SystolicArray::computeBlock(int start_row, int end_row) {
    for (int i = start_row; i < end_row; ++i) {
        for (int j = 0; j < K; ++j) {
            int sum = 0;
            for (int k = 0; k < N; ++k)
                sum += A[i][k] * B[k][j];
            output[i][j] = sum;
            pre_activation_output[i][j] = sum;
        }
    }
}

// ReLU: convierte valores negativos a cero
void SystolicArray::applyActivation() {
    for (int i = 0; i < M; ++i)
        for (int j = 0; j < K; ++j)
            if (output[i][j] < 0)
                output[i][j] = 0;
}

// Getters
std::vector<std::vector<int>> SystolicArray::getOutput() {
    return output;
}

std::vector<std::vector<int>> SystolicArray::getPreActivationOutput() {
    return pre_activation_output;
}
