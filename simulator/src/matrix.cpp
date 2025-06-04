#include "matrix.h"
#include <fstream>
#include <algorithm>
#include <iostream>

Matrix::Matrix() : rows(0), cols(0) {}

Matrix::Matrix(int r, int c) : rows(r), cols(c), data(r, std::vector<int>(c, 0)) {}

void Matrix::loadFromFile(const std::string& filename) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        throw std::runtime_error("No se pudo abrir el archivo: " + filename);
    }

    file >> rows >> cols;
    data.resize(rows, std::vector<int>(cols));

    for (int i = 0; i < rows; ++i) {
        for (int j = 0; j < cols; ++j) {
            if (!(file >> data[i][j])) {
                throw std::runtime_error("Error leyendo datos del archivo: " + filename);
            }
        }
    }
}

void Matrix::saveToFile(const std::string& filename) const {
    std::ofstream file(filename);
    if (!file.is_open()) {
        throw std::runtime_error("No se pudo crear el archivo: " + filename);
    }

    file << rows << " " << cols << std::endl;
    for (const auto& row : data) {
        for (int val : row) {
            file << val << " ";
        }
        file << std::endl;
    }
}

void Matrix::print() const {
    for (const auto& row : data) {
        for (int val : row) {
            std::cout << val << "\t";
        }
        std::cout << std::endl;
    }
}

Matrix Matrix::multiply(const Matrix& other) const {
    if (cols != other.rows) {
        throw std::runtime_error("Dimensiones incompatibles para multiplicación");
    }

    Matrix result(rows, other.cols);
    for (int i = 0; i < rows; ++i) {
        for (int j = 0; j < other.cols; ++j) {
            for (int k = 0; k < cols; ++k) {
                result.data[i][j] += data[i][k] * other.data[k][j];
            }
        }
    }
    return result;
}

void Matrix::applyReLU() {
    for (auto& row : data) {
        for (int& val : row) {
            val = std::max(0, val);
        }
    }
}

void Matrix::setValue(int row, int col, int value) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) {
        throw std::out_of_range("Índices de matriz fuera de rango");
    }
    data[row][col] = value;
}