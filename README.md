# Systolic_Array_for_NPU

Este es el segundo proyecto del curso CE-4302 Arquitectura de Computadores II del Programa de Licenciatura en Ingeniería en Computadores del Instituto Tecnológico de Costa Rica para el Semestre I 2025. Se diseñará e implementará un arreglo sistólico para una Unidad de Procesamiento Neural (NPU).

## Modelo de Referencia

## Proyecto Quartus

Este proyecto se encuentra en la carpeta NPU/.

### Requisitos

- Intel Quartus Prime (versión 22.1 o superior)
- Modelo de dispositivo FPGA: DE1-SoC
- Librerías/síntesis adicionales : Altera JTAG

### Compilación y Síntesis

1. Abrir Inter Quartus Prime.

2. File -> Open Project... y seleccionar dentro de la carpeta NPU/ el archivo NPU.qpf.

3. Revisar en "Project Navigator" que estén todos los .sv dentro de la carpeta NPU/hdl_files/

4. Ajustar el dispositivo FPGA en Assignments -> Device...

5. Configura los pines de entrada en el “Pin Planner” según el board.

6. En la ventana de Tasks, seleccionar "Compilation" del dropdown y hacer click en "Compile Design". Esperar que finalice la síntesis y el fit.

### Simulación

Usando la herramienta de Modelsim se procederá a configurar la simulación de los modulos.

1. En la ventana de Tasks, seleccionar "RTL Simulation" del dropdown y hacer click en "Edit Settings".Ahí se podrá escoger el modulo de test bench necesario según el Plan de Pruebas. Todos los test benches se encuentran en sus respectivas carpetas tb/ dentro de las carpetas de los modulos dentro de la carpeta NPU/hdl_files/.

2. Luego hacer click en el botón de "RTL Simulation", donde se aplicará también el "Analysis & Elavoration."

3. Esperar que abra Modelsim y revisar los resultados del test bench.

### Generación de bitsstream y programación

1. Tras la compilación exitosa en Quartus, ir a “Programmer”. Seleccionar el archivo .sof generado en NPU/output_files/.

2. Conectar la FPGA y darle click en “Start”.

## JTAG
Top Level reference model

Para ejecución del programa dereferencia de C++ se debe hacer cd hasta la carpeta Top_Level/src

Compilar el programa utilizando el comando

g++ main.cpp Systolic_Array.cpp -o systolic_array -pthread

Ejecutar el programa 

./systolic_array

Introducir la cantidad de filas y columnas que se desean en las matrices A y B.

Introducir la cantidad de PEs con los que se desea ejecutar el sistema.

Los resultados pueden ser observados en consola.
