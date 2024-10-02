`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/10/13 15:31:09
// Design Name: 
// Module Name: alu
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


module alu(
input wire [7:0] accum, input wire [7:0] data, input wire clk,
input wire reset, input wire [2:0] opcode,
output wire [7:0] alu_out, output wire zero
    );
    reg [7:0] out; //the reg for output
    reg [7:0] after_cal; //the reg to store sum or subtraction or multiplication
    reg [7:0] temp; //the reg to store 2's complement
    
    assign alu_out = out;
    assign zero = (accum == 0) ? 1'b1:
                                 1'b0;
    
    always @(posedge clk) begin
        if(!reset)begin
            case (opcode)
                3'b000: begin
                    out <= accum;
                end
                3'b001: begin
                    if(accum[7] == 0 && data[7] == 0 && accum + data > 8'b01111111)begin
                        out <= 8'b01111111;
                    end
                    else if(accum[7] == 1 && data[7] == 1 && accum + data < 8'b10000000)begin
                        out <= 8'b10000000;
                    end
                    else begin
                        out <= accum + data;
                    end
                end
                3'b010: begin
                    if(accum[7] == 0 && data[7] == 0)begin
                        if(accum >= data)begin
                            out <= (accum + (~data + 1)) & 8'b01111111; //just want [6:0]
                        end
                        else begin
                            out <= accum + (~data + 1); //take data's 2's complement and add together
                        end
                    end
                    else if(accum[7] == 0 && data[7] == 1)begin
                        out <= (accum + (~data + 1)) & 8'b01111111; //just want [6:0] and let out is positive
                    end
                    else if(accum[7] == 1 && data[7] == 0)begin
                            out <= (accum + (~data + 1)) | 8'b10000000; //just want [6:0] and let out is negetive
                    end
                    else if(accum[7] == 1 && data[7] == 1)begin
                        if(accum >= data)begin
                            out <= accum + (~data + 1); //take data's 2's complement and add together
                        end
                        else begin
                            out <= (accum + (~data + 1)) & 8'b10000000; //just want [6:0]
                        end
                    end
                    
                end
                3'b011: begin
                    out <= accum & data;
                end
                3'b100: begin
                    out <= accum ^ data;
                end
                3'b101: begin
                    if(accum[7] == 0)begin
                        out <= accum;
                    end
                    else begin
                        out <= (~accum + 1);
                    end
                end
                3'b110: begin
                    if(accum[3] == 0 && data[3] == 0)begin
                        out <= accum[3:0] * data[3:0];
                    end
                    else if(accum[3] == 1 && data[3] == 0)begin
                        out <= ((~(accum[3:0]) + 1) * data[3:0] ) | 8'b10000000; 
                    end
                    else if(accum[3] == 0 && data[3] == 1)begin
                        out <= accum[3:0] * (~(data[3:0]) + 1) | 8'b10000000; 
                    end
                    else if(accum[3] == 1 && data[3] == 1)begin
                        out <= (~(accum[3:0]) + 1) * (~(data[3:0]) + 1);
                    end
                    else begin
                        out <= 0;
                    end
                end
                3'b111: begin
                    out <= data;
                end
                default begin
                    out <= 0;
                end
            endcase
        end
        else begin
            out <= 8'b00000000;
        end
    end

endmodule

/*

*/