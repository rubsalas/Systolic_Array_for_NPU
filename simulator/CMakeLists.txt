cmake_minimum_required(VERSION 3.10)
project(SystolicArraySimulator)

# Configuración del tipo de dato (16/32 bits)
option(INT_WIDTH "Ancho del entero (16 o 32)" 16)

# Definir tipo de dato según configuración
if(INT_WIDTH EQUAL 16)
    add_compile_definitions(DATA_TYPE=int16_t)
elseif(INT_WIDTH EQUAL 32)
    add_compile_definitions(DATA_TYPE=int32_t)
else()
    message(FATAL_ERROR "INT_WIDTH debe ser 16 o 32")
endif()

# Configuración estándar
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Directorios de inclusión
include_directories(include)

# --- EJECUTABLE PRINCIPAL ---
add_executable(simulator
    src/main.cpp
    src/systolic_array.cpp
    src/activation.cpp
    src/memory_interface.cpp
    src/dataflow.cpp
    model/reference_model.cpp
)

# --- APLICACIÓN DE CONTROL ---
add_executable(control_app
    app/control_app.cpp
    app/pc_interface.cpp
    src/memory_interface.cpp
)

# --- PRUEBAS UNITARIAS ---
enable_testing()
add_executable(tests
    test/test_main.cpp
    test/test_systolic.cpp
    test/test_activation.cpp
    src/systolic_array.cpp
    src/activation.cpp
    model/reference_model.cpp
)

# Enlazar librerías para pruebas (ej: Catch2)
find_package(Catch2 REQUIRED)
target_link_libraries(tests PRIVATE Catch2::Catch2)
add_test(NAME UnitTests COMMAND tests)