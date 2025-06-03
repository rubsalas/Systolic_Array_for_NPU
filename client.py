import socket

def send_jtag_data(value_hex: str, host='localhost', port=5555):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.connect((host, port))
        s.sendall(f"SEND {value_hex}\\n".encode())
        data = s.recv(1024).decode()
        print("Respuesta del servidor:", data.strip())

if __name__ == "__main__":
    hex_val = input("Introduce byte en HEX (ej. A5): ").strip()
    send_jtag_data(hex_val)
