package require comm
package require struct

set port 5555
comm::comm new $port

puts "JTAG server listening on port $port..."

set paths [get_service_paths master]
if {[llength $paths] == 0} {
    puts "No JTAG service paths found!"
    exit
}

set jtag_path [lindex $paths 0]
puts "Connecting to JTAG path: $jtag_path"
open_service master $jtag_path

proc handle_request {socket data} {
    set data [string trim $data]
    if {[regexp {SEND ([0-9a-fA-F]+)} $data -> hexval]} {
        set value [scan $hexval %x]
        set ir [create_ir_shift -instance_index 0 -ir_value 0 -ir_length 2]
        execute_ir_shift $ir
        set dr [create_dr_shift -instance_index 0 -dr_value $value -dr_length 8]
        set result [execute_dr_shift $dr]
        puts "DR sent: 0x$hexval, response: $result"
        comm::comm send $socket "RECV [format %02X $result]\n"
    } else {
        comm::comm send $socket "ERR Unknown command\n"
    }
}

comm::comm hook handle handle_request
vwait forever
