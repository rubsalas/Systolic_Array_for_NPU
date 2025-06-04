#ifndef MATRIX_H
#define MATRIX_H

#include <vector>
#include <string>
#include <stdexcept>

class Matrix {
private:
    std::vector<std::vector<int>> data;
    int rows;
    int cols;

public:
    Matrix();
    Matrix(int r, int c);
    
    void loadFromFile(const std::string& filename);
    void saveToFile(const std::string& filename) const;
    void print() const;
    
    Matrix multiply(const Matrix& other) const;
    void applyReLU();
    
    // Métodos inline en el header (solo declaración)
    int getRows() const { return rows; }
    int getCols() const { return cols; }
    const std::vector<std::vector<int>>& getData() const { return data; }
    
    // Setter
    void setValue(int row, int col, int value);
};

#endif // MATRIX_H