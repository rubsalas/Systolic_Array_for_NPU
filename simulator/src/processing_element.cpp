#include "processing_element.h"
#include <algorithm> // Para std::max

ProcessingElement::ProcessingElement(bool relu) : 
    a_reg(0), b_reg(0), acc_reg(0), use_relu(relu) {}

void ProcessingElement::process(int a_in, int b_in, int acc_in) {
    // Propagamos los valores a los registros de salida
    a_reg = a_in;
    b_reg = b_in;
    
    // Realizamos la operación MAC
    acc_reg = acc_in + (a_in * b_in);
    
    // Aplicamos ReLU si está configurado
    if (use_relu) {
        acc_reg = std::max(0, acc_reg);
    }
}

int ProcessingElement::get_a_out() const { return a_reg; }
int ProcessingElement::get_b_out() const { return b_reg; }
int ProcessingElement::get_result() const { return acc_reg; }

void ProcessingElement::set_relu(bool enable) { use_relu = enable; }