//
// This module show you how to infer an initialized SRAM block
// in your circuit using the standard Verilog code.  The initial
// values of the SRAM cells is defined in the text file "image.dat"
// Each line defines a cell value. The number of data in image.dat
// must match the size of the sram block exactly.

module sram
#(parameter DATA_WIDTH = 1, ADDR_WIDTH = 2, RAM_SIZE = 65536, FILE = "images.mem")
 (input clk, input we, input en,
  input  [ADDR_WIDTH-1 : 0] addr,
  input  [DATA_WIDTH-1 : 0] data_i,
  output reg [DATA_WIDTH-1 : 0] data_o,
  input  [ADDR_WIDTH-1 : 0] addr_bg,
  input  [DATA_WIDTH-1 : 0] data_i_bg,
  output reg [DATA_WIDTH-1 : 0] data_o_bg);

// Declareation of the memory cells
(* ram_style = "block" *) reg [DATA_WIDTH-1 : 0] RAM [RAM_SIZE - 1:0];

integer idx;

// ------------------------------------
// SRAM cell initialization
// ------------------------------------
// Initialize the sram cells with the values defined in "image.dat."
initial begin
    $readmemh(FILE, RAM);
end

// ------------------------------------
// SRAM read operation
// ------------------------------------
always@(posedge clk)
begin
  if (en & we)
    data_o <= data_i;
  else
    data_o <= RAM[addr];
end

// ------------------------------------
// SRAM write operation
// ------------------------------------
always@(posedge clk)
begin
  if (en & we)
    RAM[addr] <= data_i;
end

// ------------------------------------
// SRAM read operation
// ------------------------------------
always@(posedge clk)
begin
  if (en & we)
    data_o_bg <= data_i_bg;
  else
    data_o_bg <= RAM[addr_bg];
end

// ------------------------------------
// SRAM write operation
// ------------------------------------
always@(posedge clk)
begin
  if (en & we)
    RAM[addr_bg] <= data_i_bg;
end

endmodule


