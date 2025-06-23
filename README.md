# Systolic_Array_for_NPU
Este es el segundo proyecto del curso CE-4302 Arquitectura de Computadores II del Programa de Licenciatura en Ingeniería en Computadores del Instituto Tecnológico de Costa Rica para el Semestre I 2025. Se diseñará e implementará un arreglo sistólico para una Unidad de Procesamiento Neural (NPU).


Para la ejecución del JTAG deben hacerse cd a la carpeta JTAG/jtag_server una vez cargado el proyecto del jtag a la FPGA

Para ejecutar el servidor se debe correr el siguiente comando

quartus_stp -t jtag_server.tcl

En caso de que no sea posible ejecutarlo de esta manera, se debe ejecutar con el siguiente comando, modificando la ruta completa por el path donde este guardado el archivo

quartus_stp -t rutaCompletaDelArchivo/jtag_server.tcl

Para ejecutar el cliente en python se debe ejecutar el comando

python3 client.py