##############################################################################################
######################### JTAG SERVER PARA DE-SoC [USB-1] ####################################
##############################################################################################

global usbblaster_name
global test_device

# Escapar los corchetes en el nombre del hardware
set usbblaster_name "DE-SoC \[USB-1\]"

# Validar que el hardware existe
set found 0
foreach name [get_hardware_names] {
    if { $name eq $usbblaster_name } {
        set found 1
    }
}
if { !$found } {
    puts "ERROR: Hardware $usbblaster_name no encontrado en get_hardware_names"
    return
}

# Mostrar lista de dispositivos JTAG para depuración
puts "Lista completa de dispositivos JTAG:"
foreach d [get_device_names -hardware_name $usbblaster_name] {
    puts " -> $d"
}

# Seleccionar el segundo dispositivo en la cadena JTAG (el FPGA en DE1-SoC)
foreach device_name [get_device_names -hardware_name $usbblaster_name] {
    if { [string match "@2*" $device_name] } {
        puts "|DEBUG| device name = $device_name|"
        set test_device $device_name
    }
}
puts "Selected device: $test_device"

##############################################################################################
################################## FUNCIONES JTAG ############################################
##############################################################################################

proc openport {} {
    global usbblaster_name
    global test_device
    open_device -hardware_name $usbblaster_name -device_name $test_device
}

proc closeport {} {
    catch {device_unlock}
    catch {close_device}
}

proc transmit {send_data} {
    openport
    device_lock -timeout 10000
    puts "|INFO| Sending Value $send_data to FPGA"
    device_virtual_ir_shift -instance_index 0 -ir_value 1 -no_captured_ir_value
    device_virtual_dr_shift -dr_value $send_data -instance_index 0 -length 8 -no_captured_dr_value
    device_virtual_ir_shift -instance_index 0 -ir_value 0 -no_captured_ir_value
    closeport
}

##############################################################################################
################################# SERVIDOR TCP/IP ############################################
##############################################################################################

proc Start_Server {port} {
    set s [socket -server ConnAccept $port]
    puts "Started Socket Server on port - $port"
    vwait forever
}

proc ConnAccept {sock addr port} {
    global conn
    puts "Accept $sock from $addr port $port"
    set conn(addr,$sock) [list $addr $port]
    fconfigure $sock -buffering line
    fileevent $sock readable [list IncomingData $sock]
}

proc IncomingData {sock} {
    global conn
    if {[eof $sock] || [catch {gets $sock line}]} {
        close $sock
        puts "Close $conn(addr,$sock)"
        unset conn(addr,$sock)
    } else {
        set data_len [string length $line]
        if {$data_len != "0"} {
            set line [string range $line 0 7]
            transmit $line
        }
    }
}

# Iniciar servidor en el puerto 2540
Start_Server 2540
