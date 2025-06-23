#ifndef PE_H
#define PE_H

// Clase que simula un Elemento de Procesamiento (PE)
// Esta clase NO se utiliza directamente en la solución con multithreading,
// pero está diseñada para representar un PE en un arreglo sistólico tradicional.
class PE {
public:
    int a = 0, b = 0; // Datos de entrada para el PE
    int sum = 0;      // Acumulador de resultados parciales

    // Realiza la operación de multiplicación y acumulación (MAC)
    void compute() {
        sum += a * b;
    }
};

#endif
