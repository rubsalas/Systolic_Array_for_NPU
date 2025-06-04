#include <iostream>
#include <string>
#include <stdexcept>
#include "config.h"
#include "matrix.h"
#include "processing_element.h"
#include "systolic_array.h"

void testSinglePE() {
    ProcessingElement pe;
    int a, b, acc;
    char relu_choice;
    
    std::cout << "\n--- Prueba de Processing Element ---" << std::endl;
    std::cout << "Ingrese valor A: ";
    std::cin >> a;
    std::cout << "Ingrese valor B: ";
    std::cin >> b;
    std::cout << "Ingrese valor acumulador (opcional, default 0): ";
    std::cin.ignore(); // Limpiar buffer
    std::string acc_str;
    std::getline(std::cin, acc_str);
    acc = acc_str.empty() ? 0 : std::stoi(acc_str);
    
    std::cout << "¿Aplicar ReLU? (s/n): ";
    std::cin >> relu_choice;
    pe.set_relu(relu_choice == 's' || relu_choice == 'S');
    
    pe.process(a, b, acc);
    
    std::cout << "\nResultados del PE:" << std::endl;
    std::cout << "A out: " << pe.get_a_out() << std::endl;
    std::cout << "B out: " << pe.get_b_out() << std::endl;
    std::cout << "Resultado: " << pe.get_result() << std::endl;
}

void testSystolicArray() {
    int size;
    std::cout << "\n--- Prueba de Arreglo Sistólico ---" << std::endl;
    std::cout << "Ingrese tamaño del arreglo sistólico (ej. 4): ";
    std::cin >> size;
    
    std::string dataflow;
    std::cout << "Ingrese flujo de datos (WS/IS/OS): ";
    std::cin >> dataflow;
    
    SystolicArray sa(size, dataflow);
    
    char relu;
    std::cout << "¿Habilitar ReLU en todos los PEs? (s/n): ";
    std::cin >> relu;
    sa.enableAllReLU(relu == 's' || relu == 'S');
    
    Matrix weights(size, size);
    Matrix inputs(size, size);
    
    try {
        std::string weights_file, inputs_file;
        std::cout << "Archivo de pesos (matriz " << size << "x" << size << "): ";
        std::cin >> weights_file;
        weights.loadFromFile(weights_file);
        
        std::cout << "Archivo de entradas (matriz " << size << "x" << size << "): ";
        std::cin >> inputs_file;
        inputs.loadFromFile(inputs_file);
        
        // Mostrar matrices cargadas
        std::cout << "\nMatriz de pesos:" << std::endl;
        weights.print();
        std::cout << "\nMatriz de entrada:" << std::endl;
        inputs.print();
        
        // Configurar pesos
        sa.configure(weights);
        
        // Realizar multiplicación
        std::cout << "\nRealizando multiplicación..." << std::endl;
        Matrix result = sa.multiply(inputs);
        
        std::cout << "\nResultado de la multiplicación:" << std::endl;
        result.print();
        
        // Opción para guardar resultado
        char save;
        std::cout << "\n¿Desea guardar el resultado? (s/n): ";
        std::cin >> save;
        if (save == 's' || save == 'S') {
            std::string filename;
            std::cout << "Nombre del archivo: ";
            std::cin >> filename;
            result.saveToFile(filename);
            std::cout << "Resultado guardado en " << filename << std::endl;
        }
        
        // Mostrar estado final
        std::cout << "\nEstado final del arreglo sistólico:" << std::endl;
        sa.printState();
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
    }
}

void matrixTests(Matrix& matA, Matrix& matB) {
    int choice;
    while (true) {
        std::cout << "\n--- Operaciones con Matrices ---" << std::endl;
        std::cout << "1. Cargar matriz A" << std::endl;
        std::cout << "2. Cargar matriz B" << std::endl;
        std::cout << "3. Mostrar matrices" << std::endl;
        std::cout << "4. Multiplicar matrices (software)" << std::endl;
        std::cout << "5. Aplicar ReLU a matriz" << std::endl;
        std::cout << "6. Volver al menú principal" << std::endl;
        std::cout << "Seleccione una opción: ";
        std::cin >> choice;

        try {
            switch (choice) {
                case 1: {
                    std::string filename;
                    std::cout << "Ingrese nombre del archivo para matriz A: ";
                    std::cin >> filename;
                    matA.loadFromFile(filename);
                    std::cout << "Matriz A cargada exitosamente (" 
                             << matA.getRows() << "x" << matA.getCols() << ")" << std::endl;
                    break;
                }
                case 2: {
                    std::string filename;
                    std::cout << "Ingrese nombre del archivo para matriz B: ";
                    std::cin >> filename;
                    matB.loadFromFile(filename);
                    std::cout << "Matriz B cargada exitosamente (" 
                             << matB.getRows() << "x" << matB.getCols() << ")" << std::endl;
                    break;
                }
                case 3: {
                    std::cout << "\nMatriz A:" << std::endl;
                    matA.print();
                    std::cout << "\nMatriz B:" << std::endl;
                    matB.print();
                    break;
                }
                case 4: {
                    Matrix result = matA.multiply(matB);
                    std::cout << "\nResultado de multiplicación:" << std::endl;
                    result.print();
                    
                    char save;
                    std::cout << "\n¿Desea guardar el resultado? (s/n): ";
                    std::cin >> save;
                    if (save == 's' || save == 'S') {
                        std::string filename;
                        std::cout << "Ingrese nombre del archivo: ";
                        std::cin >> filename;
                        result.saveToFile(filename);
                        std::cout << "Resultado guardado en " << filename << std::endl;
                    }
                    break;
                }
                case 5: {
                    char which;
                    std::cout << "Aplicar ReLU a (A/B): ";
                    std::cin >> which;
                    if (which == 'A' || which == 'a') {
                        matA.applyReLU();
                        std::cout << "ReLU aplicado a matriz A" << std::endl;
                    } else {
                        matB.applyReLU();
                        std::cout << "ReLU aplicado a matriz B" << std::endl;
                    }
                    break;
                }
                case 6:
                    return;
                default:
                    std::cout << "Opción inválida. Intente nuevamente." << std::endl;
            }
        } catch (const std::exception& e) {
            std::cerr << "Error: " << e.what() << std::endl;
        }
    }
}

void configurationMenu(Config& config) {
    int choice;
    while (true) {
        std::cout << "\n--- Configuración del Simulador ---" << std::endl;
        std::cout << "1. Tamaño de palabra: " << config.word_size << " bits" << std::endl;
        std::cout << "2. Flujo de datos predeterminado: " << config.data_flow << std::endl;
        std::cout << "3. Modo depuración: " << (config.debug_mode ? "ON" : "OFF") << std::endl;
        std::cout << "4. Volver al menú principal" << std::endl;
        std::cout << "Seleccione opción a cambiar: ";
        std::cin >> choice;

        try {
            switch (choice) {
                case 1: {
                    std::cout << "Nuevo tamaño de palabra (8, 16, 32): ";
                    std::cin >> config.word_size;
                    break;
                }
                case 2: {
                    std::cout << "Nuevo flujo de datos predeterminado (WS/IS/OS): ";
                    std::cin >> config.data_flow;
                    break;
                }
                case 3: {
                    config.debug_mode = !config.debug_mode;
                    std::cout << "Modo depuración " << (config.debug_mode ? "activado" : "desactivado") << std::endl;
                    break;
                }
                case 4:
                    return;
                default:
                    std::cout << "Opción inválida. Intente nuevamente." << std::endl;
            }
        } catch (const std::exception& e) {
            std::cerr << "Error: " << e.what() << std::endl;
        }
    }
}

void showMenu(Config& config) {
    Matrix matA, matB;
    int choice;
    
    while (true) {
        std::cout << "\n=== Simulador de Arreglo Sistólico ===" << std::endl;
        std::cout << "1. Operaciones con matrices" << std::endl;
        std::cout << "2. Probar Processing Element (PE) individual" << std::endl;
        std::cout << "3. Probar Arreglo Sistólico completo" << std::endl;
        std::cout << "4. Configuración" << std::endl;
        std::cout << "5. Salir" << std::endl;
        std::cout << "Seleccione una opción: ";
        std::cin >> choice;

        try {
            switch (choice) {
                case 1:
                    matrixTests(matA, matB);
                    break;
                case 2:
                    testSinglePE();
                    break;
                case 3:
                    testSystolicArray();
                    break;
                case 4:
                    configurationMenu(config);
                    break;
                case 5:
                    std::cout << "Saliendo del simulador..." << std::endl;
                    return;
                default:
                    std::cout << "Opción inválida. Intente nuevamente." << std::endl;
            }
        } catch (const std::exception& e) {
            std::cerr << "Error: " << e.what() << std::endl;
        }
    }
}

int main() {
    Config config;
    
    std::cout << "==============================================" << std::endl;
    std::cout << "  Simulador de Arreglo Sistólico para NPU" << std::endl;
    std::cout << "  Fase 3: Arreglo Sistólico (4x4 mínimo)" << std::endl;
    std::cout << "==============================================" << std::endl;
    
    showMenu(config);
    
    return 0;
}