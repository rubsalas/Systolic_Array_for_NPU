#ifndef CONFIG_H
#define CONFIG_H

#include <string>

struct Config {
    int word_size = 16;       // Tamaño de palabra por defecto (16 bits)
    std::string data_flow = "WS";  // Flujo de datos por defecto (Weight Stationary)
    bool debug_mode = false;  // Modo depuración
};

#endif // CONFIG_H