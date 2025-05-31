#include <iostream>
#include <vector>
#include <algorithm> // Para std::max

using namespace std;

// Tipo de dato entero con signo de 16 bits
using Int = int16_t;

// Función de activación ReLU
Int relu(Int x)
{
    return max((Int)0, x);
}

// Multiplicación de matrices con activación ReLU y validación de dimensiones
bool systolicMultiplyAndActivate(const vector<vector<Int>> &A,
                                 const vector<vector<Int>> &B,
                                 vector<vector<Int>> &C)
{
    size_t N = A.size();
    size_t K = A[0].size();
    size_t Kb = B.size();
    size_t M = B[0].size();

    // Validar dimensiones compatibles
    for (const auto &row : A)
    {
        if (row.size() != K)
        {
            cerr << "Error: A tiene filas de diferente tamaño." << endl;
            return false;
        }
    }

    for (const auto &row : B)
    {
        if (row.size() != M)
        {
            cerr << "Error: B tiene filas de diferente tamaño." << endl;
            return false;
        }
    }

    if (K != Kb)
    {
        cerr << "Error: Las columnas de A no coinciden con las filas de B." << endl;
        return false;
    }

    // Crear C con el tamaño adecuado: NxM
    C.assign(N, vector<Int>(M, 0));

    // Multiplicación y activación
    for (size_t i = 0; i < N; ++i)
        for (size_t j = 0; j < M; ++j)
        {
            Int sum = 0;
            for (size_t k = 0; k < K; ++k)
            {
                sum += A[i][k] * B[k][j];
            }
            C[i][j] = sum;
        }

    return true;
}

int main()
{
    vector<vector<Int>> A = {
        {1, -2},
        {3, 4}};

    vector<vector<Int>> B = {
        {5, -1},
        {-1, 2}};

    vector<vector<Int>> C;

    // Ejecutar y validar
    if (systolicMultiplyAndActivate(A, B, C))
    {
        cout << "Resultado (C = ReLU(A x B)):" << endl;
        for (const auto &row : C)
        {
            for (auto val : row)
            {
                cout << val << "\t";
            }
            cout << endl;
        }
    }
    else
    {
        cerr << "No se pudo realizar la multiplicación por error en las dimensiones." << endl;
    }

    return 0;
}
