package pkg_systolic;

  //--------------------
  // Parámetros globales
  //--------------------
  parameter int DATA_W = 16;      // palabra de datos  (signed 16-bit)
  parameter int ACC_W  = 32;      // acumulador        (signed 32-bit)

  //--------------------
  // Tipos con signo
  //--------------------
  typedef  logic signed [DATA_W-1:0] s16_t;
  typedef  logic signed [ACC_W-1 :0] s32_t;

endpackage : pkg_systolic
