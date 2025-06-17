# jtag_fpga.py
# ---------------------------------------------------------
# Cliente TCP/IP que se conecta a un servidor Tcl (ejecutado con quartus_stp)
# para enviar datos al módulo sld_virtual_jtag en una FPGA (ej. DE1-SoC).
# Permite escribir valores (en binario) y opcionalmente leer respuestas.
# ---------------------------------------------------------

# python .\jtag_fpga.py

import socket       # Para la conexión TCP/IP
import time         # (Reservado para posibles retardos o timeouts)
import argparse     # Para aceptar argumentos desde la línea de comandos
import os           # Para operaciones del sistema como rutas de archivos
from pyreadline3 import Readline     # Para guardar y recuperar historial de comandos
import atexit       # Para ejecutar funciones al cerrar el programa

# ----------------- CONFIGURACIÓN GLOBAL -----------------

# Niveles de verbosidad
VERBOSE_LEVEL_QUIET = 0    # Solo errores
VERBOSE_LEVEL_NORMAL = 1   # Información esencial
VERBOSE_LEVEL_DEBUG = 2    # Todo (incluso detalles técnicos)

# Parámetros ajustables desde línea de comandos
DATA_WIDTH = 8                     # Cantidad de bits por transacción
MAX_VAL = (1 << DATA_WIDTH) - 1    # Valor máximo que se puede enviar
HEX_PADDING = DATA_WIDTH // 4      # Cuántos dígitos hex necesita cada valor
VERBOSITY_LEVEL = VERBOSE_LEVEL_NORMAL

# Conexión al servidor Tcl
HOST = 'localhost'
PORT = 2540
SOCKET_TIMEOUT = 10.0

# Archivo para guardar el historial de comandos
HISTORY_FILE = os.path.expanduser("~/.jtag_fpga_history")

# ------------- HISTORIAL INTERACTIVO (solo UNIX) -------------

readline = Readline()

def load_history():
    """Carga el historial de comandos previos."""
    if hasattr(readline, "read_history_file"):
        try:
            readline.read_history_file(HISTORY_FILE)
        except FileNotFoundError:
            pass
        except Exception:
            pass

def save_history():
    """Guarda el historial al salir del programa."""
    if hasattr(readline, "write_history_file"):
        try:
            readline.write_history_file(HISTORY_FILE)
        except Exception:
            pass

# Registrar función de guardado al salir
atexit.register(save_history)

# ---------------------- VERBOSIDAD ----------------------

def print_message(level, message):
    """Imprime mensajes solo si el nivel de verbosidad lo permite."""
    global VERBOSITY_LEVEL
    if level <= VERBOSITY_LEVEL:
        print(message)

# ------------- CONEXIÓN CON EL SERVIDOR TCL -------------

def open_connection(host_addr, server_port):
    """Establece la conexión con el servidor."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(SOCKET_TIMEOUT)
        s.connect((host_addr, server_port))
        print_message(VERBOSE_LEVEL_NORMAL, f"|INFO| Connected to server {host_addr}:{server_port}")
        return s
    except socket.timeout:
        print_message(VERBOSE_LEVEL_QUIET, f"|ERROR| Connection to {host_addr}:{server_port} timed out.")
        return None
    except ConnectionRefusedError:
        print_message(VERBOSE_LEVEL_QUIET, f"|ERROR| Connection to {host_addr}:{server_port} refused.")
        return None
    except Exception as e:
        print_message(VERBOSE_LEVEL_QUIET, f"|ERROR| Could not connect: {e}")
        return None

# ------------- ESCRITURA A LA FPGA ----------------------

def write_value_to_fpga(conn, int_value_to_write):
    """Envía un valor a la FPGA vía JTAG (convertido a binario)."""
    if conn is None:
        print_message(VERBOSE_LEVEL_QUIET, "|ERROR| No connection to server.")
        return
    try:
        # Convierte a cadena binaria con ceros a la izquierda
        binary_string = format(int_value_to_write, f'0{DATA_WIDTH}b')
        request = binary_string + '\n'

        print_message(VERBOSE_LEVEL_DEBUG, f"|DEBUG| Sending: {request.strip()}")
        conn.sendall(request.encode())

        print_message(VERBOSE_LEVEL_NORMAL, f"|INFO| Sent value {int_value_to_write} (0x{int_value_to_write:0{HEX_PADDING}x})")
    except Exception as e:
        print_message(VERBOSE_LEVEL_QUIET, f"|ERROR| Send failed: {e}")

# ------------- LECTURA OPCIONAL DE FPGA ----------------------

def read_value_from_fpga(conn):
    """Solicita un valor a la FPGA. (Debe estar soportado por el servidor)"""
    if conn is None:
        print_message(VERBOSE_LEVEL_QUIET, "|ERROR| No connection to server.")
        return None
    try:
        request = "READ\n"
        conn.sendall(request.encode())

        response_bytes = b''
        conn.settimeout(SOCKET_TIMEOUT)

        while True:
            chunk = conn.recv(1)
            if not chunk:
                print_message(VERBOSE_LEVEL_QUIET, "|ERROR| Server closed connection.")
                return None
            response_bytes += chunk
            if chunk == b'\n':
                break

        response_hex = response_bytes.decode().strip()
        print_message(VERBOSE_LEVEL_NORMAL, f"|INFO| Received: '{response_hex}'")
        return int(response_hex, 16)
    except Exception as e:
        print_message(VERBOSE_LEVEL_QUIET, f"|ERROR| Read failed: {e}")
        return None

# ------------------- UTILIDAD -------------------

def parse_integer_argument(arg_str, arg_name="argument"):
    """Convierte una cadena como '0xA5' o '165' a entero."""
    if arg_str is None:
        return None
    try:
        return int(arg_str, 0)
    except ValueError:
        print_message(VERBOSE_LEVEL_QUIET, f"|ERROR| Invalid {arg_name}: '{arg_str}'")
        return None

# ------------------- MODO INTERACTIVO -------------------

def main_loop(conn):
    """Bucle interactivo donde el usuario introduce comandos."""
    global VERBOSITY_LEVEL

    print_message(VERBOSE_LEVEL_NORMAL, f"JTAG Command Processor ({DATA_WIDTH}-bit)")
    print_message(VERBOSE_LEVEL_NORMAL, "Available commands: write <value>, read, verbose <0|1|2>, history, exit")

    while True:
        try:
            user_input = input(f"JTAG-{DATA_WIDTH}bit> ").strip()
        except EOFError:
            break

        parts = user_input.split()
        if not parts:
            continue

        command = parts[0].lower()

        if command == 'exit':
            break
        elif command == 'verbose':
            if len(parts) == 2:
                level = parse_integer_argument(parts[1], "verbosity level")
                if level is not None and level in [0, 1, 2]:
                    VERBOSITY_LEVEL = level
                    print_message(VERBOSE_LEVEL_NORMAL, f"|INFO| Verbosity set to {level}")
                else:
                    print("|ERROR| Verbosity must be 0, 1, or 2")
            else:
                print(f"Current verbosity level: {VERBOSITY_LEVEL}")
        elif command == 'write':
            if len(parts) >= 2:
                value = parse_integer_argument(parts[1], "write value")
                if value is not None:
                    write_value_to_fpga(conn, value)
            else:
                print("|ERROR| Usage: write <value>")
        elif command == 'read':
            value = read_value_from_fpga(conn)
            if value is not None:
                print(f"|RESULT| Received: {value} (0x{value:0{HEX_PADDING}x})")
        elif command == 'history':
            for i in range(readline.get_current_history_length()):
                print(readline.get_history_item(i + 1))
        else:
            print(f"|ERROR| Unknown command: '{command}'")

# ------------------- EJECUCIÓN PRINCIPAL -------------------

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Cliente JTAG para FPGA vía socket TCP/IP")
    parser.add_argument("-dw", "--data_width", type=int, default=8, choices=[8, 16, 32, 64],
                        help="Tamaño de palabra en bits (8, 16, 32, 64)")
    parser.add_argument("-q", "--quiet", action="store_const", const=VERBOSE_LEVEL_QUIET, dest="verbosity")
    parser.add_argument("-v", "--verbose", action="store_const", const=VERBOSE_LEVEL_DEBUG, dest="verbosity")
    parser.set_defaults(verbosity=VERBOSE_LEVEL_NORMAL)

    args = parser.parse_args()

    # Configuración inicial según argumentos
    DATA_WIDTH = args.data_width
    VERBOSITY_LEVEL = args.verbosity
    MAX_VAL = (1 << DATA_WIDTH) - 1
    HEX_PADDING = DATA_WIDTH // 4

    # Cargar historial solo si no estamos en Windows
    if os.name != 'nt':
        load_history()
    else:
        print_message(VERBOSE_LEVEL_NORMAL, "Tip: instala 'pyreadline3' en Windows para historial de comandos.")

    # Iniciar conexión
    conn = open_connection(HOST, PORT)
    if conn is None:
        exit(1)

    # Ejecutar interfaz interactiva
    main_loop(conn)
