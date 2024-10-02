`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/09/24 17:43:53
// Design Name: 
// Module Name: SeqMultiplier
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module SeqMultiplier(
input wire clk, input wire enable, input wire [7:0] A, input wire[7:0] B,
output wire [15:0] C
    );
    reg [15:0] product;
    reg [7:0] mult;
    reg [7:0] counter;
    wire shift;
    assign C = product;
    assign shift = |(counter ^ 7);
    
    always @(posedge clk) begin
        if (!enable) begin
            mult <= B;
            product <= 0;
            counter = 0;
        end
        else begin
            mult <= mult << 1;
            product <= (product + (A & {8{mult[7]}}) ) << shift ;
            counter <= counter + shift;
        end
    end      
endmodule
