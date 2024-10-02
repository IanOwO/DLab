`timescale 1ns / 1ps
module lab4(
  input  clk,            // System clock at 100 MHz
  input  reset_n,        // System reset signal, in negative logic
  input  [3:0] usr_btn,  // Four user pushbuttons
  output [3:0] usr_led   // Four yellow LEDs
);
//assign usr_led = usr_btn;

reg [27:0] pwm;
wire [3:0] btn;
reg [2:0] type;
reg [3:0] restrict;
reg signed [3:0] counter;
reg [3:0] led_reg;

debounce d3(usr_btn[3],clk,btn[3]);
debounce d2(usr_btn[2],clk,btn[2]);
debounce d1(usr_btn[1],clk,btn[1]);
debounce d0(usr_btn[0],clk,btn[0]);
//div_clk d(clk,_clk);
assign usr_led = led_reg;

always @(posedge clk or negedge reset_n)begin
    if(reset_n == 0)begin
        pwm <= 0;
        type <= 0;
        restrict <= 0;
        counter <= 0;
        led_reg <= 0;
    end
    else begin
        pwm <= (pwm < 1000000)?pwm + 1:0;
        
        if(btn[3] == 1 && restrict[3] == 0)begin
            type <= (type < 4)?type + 1 : 4;
            restrict[3] <= 1;
        end
        else if(btn[3] == 0 && restrict[3] == 1)begin
            restrict[3] <= 0;
        end
        
        if(btn[2] == 1 && restrict[2] == 0)begin
            type <= (type > 0)?type - 1 : 0;
            restrict[2] <= 1;
        end
        else if(btn[2] == 0 && restrict[2] == 1)begin
            restrict[2] <= 0;
        end
        
        if(btn[0] == 1 && restrict[0] == 0)begin
            counter <= (counter > -8)?counter - 1 : -8;
            restrict[0] <= 1;
        end
        else if(btn[0] == 0 && restrict[0] == 1)begin
            restrict[0] <= 0;
        end
        
        if(btn[1] == 1 && restrict[1] == 0)begin
            counter <= (counter < 7)?counter + 1 : 7;
            restrict[1] <= 1;
        end 
        else if(btn[1] == 0 && restrict[1] == 1)begin
            restrict[1] <= 0;
        end
        
        if(type == 3'b000)begin
            if(counter[3] == 1)led_reg[3] <= (pwm < 50000)?1 : 0;
            else led_reg[3] <= 0;
            if(counter[2] == 1)led_reg[2] <= (pwm < 50000)?1 : 0;
            else led_reg[2] <= 0;
            if(counter[1] == 1)led_reg[1] <= (pwm < 50000)?1 : 0;
            else led_reg[1] <= 0;
            if(counter[0] == 1)led_reg[0] <= (pwm < 50000)?1 : 0;
            else led_reg[0] <= 0;
        end 
        else if(type == 3'b001)begin
            if(counter[3] == 1)led_reg[3] <= (pwm < 250000)?1 : 0;
            else led_reg[3] <= 0;
            if(counter[2] == 1)led_reg[2] <= (pwm < 250000)?1 : 0;
            else led_reg[2] <= 0;
            if(counter[1] == 1)led_reg[1] <= (pwm < 250000)?1 : 0;
            else led_reg[1] <= 0;
            if(counter[0] == 1)led_reg[0] <= (pwm < 250000)?1 : 0;
            else led_reg[0] <= 0;
        end 
        else if(type == 3'b010)begin
            if(counter[3] == 1)led_reg[3] <= (pwm < 500000)?1 : 0;
            else led_reg[3] <= 0;
            if(counter[2] == 1)led_reg[2] <= (pwm < 500000)?1 : 0;
            else led_reg[2] <= 0;
            if(counter[1] == 1)led_reg[1] <= (pwm < 500000)?1 : 0;
            else led_reg[1] <= 0;
            if(counter[0] == 1)led_reg[0] <= (pwm < 500000)?1 : 0;
            else led_reg[0] <= 0;
        end 
        else if(type == 3'b011)begin
            if(counter[3] == 1)led_reg[3] <= (pwm < 750000)?1 : 0;
            else led_reg[3] <= 0;
            if(counter[2] == 1)led_reg[2] <= (pwm < 750000)?1 : 0;
            else led_reg[2] <= 0;
            if(counter[1] == 1)led_reg[1] <= (pwm < 750000)?1 : 0;
            else led_reg[1] <= 0;
            if(counter[0] == 1)led_reg[0] <= (pwm < 750000)?1 : 0;
            else led_reg[0] <= 0;
        end 
        else if(type == 3'b100)begin
            if(counter[3] == 1)led_reg[3] <= (pwm < 1000000)?1 : 0;
            else led_reg[3] <= 0;
            if(counter[2] == 1)led_reg[2] <= (pwm < 1000000)?1 : 0;
            else led_reg[2] <= 0;
            if(counter[1] == 1)led_reg[1] <= (pwm < 1000000)?1 : 0;
            else led_reg[1] <= 0;
            if(counter[0] == 1)led_reg[0] <= (pwm < 1000000)?1 : 0;
            else led_reg[0] <= 0;
        end
    end
end 

endmodule

module debounce(input in_1,input clk,output out);
wire de_clk;
wire q1,q2,q2_bar,q0;
div_clk c1(clk,de_clk);
d_flip_flop d0(de_clk,in_1,q0);
d_flip_flop d1(de_clk,q0,q1);
d_flip_flop d2(de_clk,q1,q2);
assign q2_bar = ~q2;
assign out = q1 & q2_bar;
endmodule

module div_clk(input clk_,output reg de_clk);
    reg [27:0] div = 0;
    always @(posedge clk_)begin
        div <= (div >= 1499999)?0:div + 1;
        de_clk <= (div < 750000)?1'b0:1'b1;
    end  
endmodule

module d_flip_flop(input dff_clk,input d,output reg q);
    always @(posedge dff_clk)begin
        q <= d;
    end 
endmodule