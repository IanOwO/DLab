`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/09/24 17:56:54
// Design Name: 
// Module Name: mmuli
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
`include "SeqMultiplier.v"

module mmult(
input wire [0:9*8-1] A_mat, input wire [0:9*8-1] B_mat, output wire [0:9*17-1] C_mat,
input wire clk, input wire reset_n, input wire enable,
output wire valid
    );
    reg [0:9*17-1] result;//change C_mat in always
    integer counter;//count whether there are three clock cycle
    reg valid_reg;//to change valid in always
    integer i = 0;//row of A
    integer j;//column of B
    integer k;//count that c add to which one =>A11 * B11 (k=0) + A12 * B 21 (k=1) + A13 * B31 (k=2) = C11
    wire [0:47] temp;//temp vector for SeqMultiplier to store
    
    assign C_mat = result;
    assign valid = valid_reg;
    
    always @(posedge clk) begin
        if(!reset_n) begin
            result <= 0;
            counter <= 0;
            valid_reg <= 0;
        end
        else if(enable)begin
        
            for(j = 0;j < 3;j = j + 1)begin
            /*
                SeqMultiplier (
                    .C(temp[0:15]),
                    .clk(clk),
                    .enable(enable),
                    .A(A_mat[0 + 24 * i +: 8]),
                    .B(B_mat[0 + 8 * j +: 8])
                ); 
                SeqMultiplier(
                    .C(temp[16:31]),
                    .clk(clk),
                    .enable(enable),
                    .A(A_mat[8 + 24 * i +: 8]),
                    .B(B_mat[24 + 8 * j +: 8])
                );
                SeqMultiplier(
                    .C(temp[32:47]),
                    .clk(clk),
                    .enable(enable),
                    .A(A_mat[16 + 24 * i +: 8]),
                    .B(B_mat[48 + 8 * j +: 8])
                );
                result[51*i + 17*j +: 17] = temp[0:15] + temp[16:31] + temp[32:47];*/ 
                //result[51*i + 17*j +: 17] = A_mat[0 + 24 * i +: 8] * B_mat[0 + 8 * j +: 8] + A_mat[8 + 24 * i +: 8] * B_mat[24 + 8 * j +: 8] + A_mat[16 + 24 * i +: 8] * B_mat[48 + 8 * j +: 8];
                for(k = 0;k < 3;k = k + 1)begin
                    result[51*i + 17*j +: 17] = result[51*i + 17*j +: 17] + (A_mat[8 * k + 24 * i +: 8] * B_mat[24 * k + 8 * j +: 8]);
                end
            end 
            
            counter <= counter + 1;
            i <= i + 1;
            if(counter == 2)begin
                valid_reg <= 1;
            end
        end        
    end
endmodule

/*
            //mult for row0 of A
            SeqMultiplier A11(
                .C(temp[0:15]),
                .clk(clk),
                .enable(enable),
                .A(A_mat[0 + 8 * row:7 + 8 * row]),
                .B(B_mat[0:7])
            );
            SeqMultiplier A12(
                .clk(clk),
                .enable(enable),
                .A(A_mat[8 + 8 * row:15 + 8 * row]),
                .B(B_mat[24:31]),
                .C(temp[16:31])
            );
            SeqMultiplier A13(
                .clk(clk),
                .enable(enable),
                .A(A_mat[16 + 8 * row:23 + 8 * row]),
                .B(B_mat[48:55]),
                .C(temp[32:47])
            );*/
