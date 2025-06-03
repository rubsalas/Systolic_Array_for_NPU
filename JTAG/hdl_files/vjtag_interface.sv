module vjtag_interface (
                        input wire tck, tdi, aclr, ir_in,v_sdr, udr,
                        output logic [7:0] data,
                        output logic tdo
                       );
    
    logic DR0_bypass_reg; // Safeguard in case bad IR is sent through JTAG
    logic [7:0] DR1; // Date, time and revision DR. We could make separate Data Registers for each one, but
    
    wire select_DR0 = ~ir_in; // Default to 0, which is the bypass register
    wire select_DR1 = ir_in;  // Data Register 1 will collect the new LED Settings
    
    always_ff @ (posedge tck or negedge aclr) begin
        if (~aclr) begin
            DR0_bypass_reg <= 1'b0;
            DR1 <= 8'b000000;
        end
        else begin
            DR0_bypass_reg <= tdi; //Update the Bypass Register Just in case the incoming data is not sent to DR1
            if (v_sdr) begin// VJI is in Shift DR state
                if (select_DR1) begin //ir_in has been set to choose DR1
                    DR1 <= {tdi, DR1[7:1]}; // Shifting in (and out) the data
                end
            end
        end
    end

    //Maintain the TDO Continuity
    always_comb begin
        if (select_DR1) begin
            tdo = DR1[0];
        end
        else begin
            tdo = DR0_bypass_reg;
        end
    end
    
    //The udr signal will assert when the data has been transmitted and it's time to Update the DR
    // so copy it to the Output LED register.
    // Note that connecting the LED's to the DR1 register will cause an unwanted behavior as data is shifted through it
    always_ff @(udr) begin
        data <= DR1;
    end
    
endmodule