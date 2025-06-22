# Systolic_Array_for_NPU
Este es el segundo proyecto del curso CE-4302 Arquitectura de Computadores II del Programa de Licenciatura en Ingeniería en Computadores del Instituto Tecnológico de Costa Rica para el Semestre I 2025. Se diseñará e implementará un arreglo sistólico para una Unidad de Procesamiento Neural (NPU).

Top Level reference model

Para ejecución del programa dereferencia de C++ se debe hacer cd hasta la carpeta Top_Level/src

Compilar el programa utilizando el comando

g++ main.cpp Systolic_Array.cpp -o systolic_array -pthread

Ejecutar el programa 

./systolic_array

Introducir la cantidad de filas y columnas que se desean en las matrices A y B.

Introducir la cantidad de PEs con los que se desea ejecutar el sistema.

Los resultados pueden ser observados en consola.