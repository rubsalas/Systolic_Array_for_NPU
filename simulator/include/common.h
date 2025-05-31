#pragma once
#include <cstdint>

// Configuración global
constexpr int ARRAY_ROWS = 4;
constexpr int ARRAY_COLS = 4;
constexpr int MEMORY_SIZE = 64 * 1024 * 1024; // 64 MB

// Tipo de dato configurable (16/32 bits)
#ifdef DATA_TYPE
using DataType = DATA_TYPE;
#else
using DataType = int32_t; // Default
#endif

// Enumeración de flujos de datos
enum DataFlowType { WS, IS, OS };