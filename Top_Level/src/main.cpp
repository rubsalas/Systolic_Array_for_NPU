#include <iostream>
#include <vector>
#include <cstdlib>
#include <ctime>
#include "Systolic_Array.h"

// Genera una matriz de enteros aleatorios entre -9 y 9 de tamaño [rows x cols]
std::vector<std::vector<int>> generateMatrix(int rows, int cols) {
    std::vector<std::vector<int>> matrix(rows, std::vector<int>(cols));
    for (int i = 0; i < rows; ++i)
        for (int j = 0; j < cols; ++j)
            matrix[i][j] = (rand() % 19) - 9;
    return matrix;
}

// Imprime una matriz con su nombre
void printMatrix(const std::vector<std::vector<int>>& matrix, const std::string& name) {
    std::cout << name << ":\n";
    for (const auto& row : matrix) {
        for (int val : row)
            std::cout << (val >= 0 ? " " : "") << val << " ";
        std::cout << "\n";
    }
    std::cout << std::endl;
}

int main() {
    int rowsA, colsA, rowsB, colsB, numPEs;

    // Entrada del usuario para tamaños de las matrices A y B
    std::cout << "Ingrese filas de la matriz A: ";
    std::cin >> rowsA;
    std::cout << "Ingrese columnas de la matriz A (y filas de B): ";
    std::cin >> colsA;
    std::cout << "Ingrese columnas de la matriz B: ";
    std::cin >> colsB;

    // Validación básica de dimensiones
    if (rowsA < 1 || colsA < 1 || colsB < 1) {
        std::cerr << "Las dimensiones deben ser mayores a 0.\n";
        return 1;
    }

    // Entrada del usuario para cantidad de PEs a simular
    std::cout << "Ingrese la cantidad de Processing Elements (PEs): ";
    std::cin >> numPEs;
    if (numPEs < 1) {
        std::cerr << "Debe haber al menos 1 PE.\n";
        return 1;
    }

    // Inicialización de la semilla aleatoria
    srand(static_cast<unsigned>(time(0)));

    // Generación aleatoria de matrices A y B
    auto A = generateMatrix(rowsA, colsA);
    auto B = generateMatrix(colsA, colsB);

    printMatrix(A, "Matriz A");
    printMatrix(B, "Matriz B");

    // Creación y ejecución del arreglo sistólico con hilos (multithreaded)
    SystolicArray systolic(rowsA, colsB, colsA, numPEs);
    systolic.loadMatrices(A, B);
    systolic.run();

    // Muestra del resultado antes y después de aplicar ReLU
    printMatrix(systolic.getPreActivationOutput(), "Resultado antes de activacion");
    printMatrix(systolic.getOutput(), "Resultado después de activacion");

    return 0;
}
