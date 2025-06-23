module memory (
    input  logic         clk,
    input  logic         rst,

    // Control general
    input  logic         wr_en,         // 1 = escribir, 0 = leer
    input  logic         sel,           // 0 = memoria de 16 bits, 1 = memoria de 32 bits
    input  logic  [4:0]  addr,          // dirección (0–17 para 16-bit, 0–8 para 32-bit)
    input  logic  [31:0] data_in,       // datos de entrada (usar solo parte baja si sel=0)
    output logic  [31:0] data_out       // salida extendida a 32 bits
);

    // 18 posiciones de 16 bits para entradas
    logic [15:0] mem_in [0:17];

    // 9 posiciones de 32 bits para salidas
    logic [31:0] mem_out [0:8];

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            if (rst) begin
					 mem_in[0]  <= 0; mem_in[1]  <= 0; mem_in[2]  <= 0;
					 mem_in[3]  <= 0; mem_in[4]  <= 0; mem_in[5]  <= 0;
					 mem_in[6]  <= 0; mem_in[7]  <= 0; mem_in[8]  <= 0;
					 mem_in[9]  <= 0; mem_in[10] <= 0; mem_in[11] <= 0;
					 mem_in[12] <= 0; mem_in[13] <= 0; mem_in[14] <= 0;
					 mem_in[15] <= 0; mem_in[16] <= 0; mem_in[17] <= 0;

					 mem_out[0] <= 0; mem_out[1] <= 0; mem_out[2] <= 0;
					 mem_out[3] <= 0; mem_out[4] <= 0; mem_out[5] <= 0;
					 mem_out[6] <= 0; mem_out[7] <= 0; mem_out[8] <= 0;

        end else begin
            if (wr_en) begin
                if (sel == 1'b0 && addr < 18)
                    mem_in[addr] <= data_in[15:0];
                else if (sel == 1'b1 && addr < 9)
                    mem_out[addr] <= data_in;
            end
        end
  

    // Salida combinacional
    always @(*) begin
        if (sel == 1'b0 && addr < 18)
            data_out = {16'b0, mem_in[addr]};  // extiende 16 bits a 32
        else if (sel == 1'b1 && addr < 9)
            data_out = mem_out[addr];
        else
            data_out = 32'hDEAD_DEAD; // valor inválido
    end

endmodule
