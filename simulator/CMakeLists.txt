cmake_minimum_required(VERSION 3.10)
project(p2_arqui2)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Agrega los archivos fuente con ruta relativa
add_executable(programa
    src/main.cpp
    src/systolic_array.cpp
)


# Opcional, si usás encabezados fuera de src/
# target_include_directories(programa PRIVATE include)
