#ifndef PROCESSING_ELEMENT_H
#define PROCESSING_ELEMENT_H

class ProcessingElement {
private:
    int a_reg;      // Registro para valor A
    int b_reg;      // Registro para valor B
    int acc_reg;    // Registro de acumulación
    bool use_relu;  // Si aplica ReLU o no
    
public:
    // Constructor
    ProcessingElement(bool relu = false);
    
    // Procesamiento en un ciclo de reloj
    void process(int a_in, int b_in, int acc_in = 0);
    
    // Getters para los valores de salida
    int get_a_out() const;
    int get_b_out() const;
    int get_result() const;
    
    // Configurar ReLU
    void set_relu(bool enable);
};

#endif // PROCESSING_ELEMENT_H