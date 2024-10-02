`timescale 1ns / 1ps
/////////////////////////////////////////////////////////
module lab9(
  input clk,
  input reset_n,
  input [3:0] usr_btn,
  output [3:0] usr_led,
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D
);

localparam [1:0] S_INIT = 2'b00, S_CALC = 2'b01, S_SHOW = 2'b10;
//localparam [3:0] S_INIT = 4'b0001, S_CALC = 4'b0001, S_COM = 4'b0100, S_SHOW = 4'b1000;
// turn off all the LEDs
assign usr_led = P;

reg  [1:0] P, P_next;

wire btn_level, btn_pressed;
reg prev_btn_level;
reg [127:0] row_A = "Press BTN3 to   "; // Initialize the text of the first row. 
reg [127:0] row_B = "show a message.."; // Initialize the text of the second row.

//variable for hash
reg  [127:0] passwd_hash = 128'hE8CD0953ABDFDE433DFEC7FAA70DF7F6;
reg [63: 0] txt;
wire [127: 0] hash;
wire [127: 0] out;
reg [63: 0] ans;

reg correct;

//variable for time count
reg [27:0] count_time;
reg [30:0] count = 0;

LCD_module lcd0(
  .clk(clk),
  .reset(~reset_n),
  .row_A(row_A),
  .row_B(row_B),
  .LCD_E(LCD_E),
  .LCD_RS(LCD_RS),
  .LCD_RW(LCD_RW),
  .LCD_D(LCD_D)
);
    
debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[3]),
  .btn_output(btn_level)
);
    
md5 m0(
  .clk(clk),
  .in_txt(txt),
  .hash(hash),
  .out_txt(out)
);
    
always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 1;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level == 1 && prev_btn_level == 0);

always @(posedge clk) begin
  if (~reset_n) P <= S_INIT;
  else P <= P_next;
end

always @(*)begin
    case (P)
        S_INIT:
          if (btn_pressed) P_next <= S_CALC;
          else P_next <= S_INIT;
        S_CALC:
          if (correct) P_next <= S_SHOW;
          else P_next <= S_CALC;
        S_SHOW:
          if (btn_pressed) P_next <= S_INIT;
          else P_next <= S_SHOW;
        default:
          P_next <= S_INIT;
    endcase
end

always @(posedge clk)begin
    if(~reset_n || P == S_INIT)begin
      count_time <= 0;
    end
    else if(P == S_CALC && count == 100000)begin
      if(count_time[3:0] == 4'h9)begin
        count_time[3:0] <= 0;
        if(count_time[7:4] == 4'h9)begin
          count_time[7:4] <= 0;
          if(count_time[11:8] == 4'h9)begin
            count_time[11:8] <= 0;
            if(count_time[15:12] == 4'h9)begin
              count_time[15:12] <= 0;
              if(count_time[19:16] == 4'h9)begin
                count_time[19:16] <= 0;
                if(count_time[23:20] == 4'h9)begin
                  count_time[23:20] <= 0;
                  if(count_time[27:24] == 4'h9)begin
                    count_time <= count_time;
                  end
                  else count_time[27:24] <= count_time[27:24] + 1;
                end
                else count_time[23:20] <= count_time[23:20] + 1;
              end
              else count_time[19:16] <= count_time[19:16] + 1;
            end
            else count_time[15:12] <= count_time[15:12] + 1;
          end
          else count_time[11:8] <= count_time[11:8] + 1;
        end
        else count_time[7:4] <= count_time[7:4] + 1;
      end
      else count_time[3:0] <= count_time[3:0] + 1;      
    end
end

always @(posedge clk)begin 
    if(~reset_n || P == S_INIT)begin
      count <= 0;
    end
    else if(P == S_CALC)begin
      count <= (count < 100000)?count + 1:0;
    end
end

always @(posedge clk)begin
  if(~reset_n || P == S_INIT)begin
    row_A <= "Press BTN3 to   ";
    row_B <= "show password...";
  end
  else if(P == S_CALC)begin
    row_A <= "calculating...  ";
    if(txt == "99999999")begin
        row_B <= "          failed";
    end
    else row_B <= "                ";
  end
  else if(P == S_SHOW)begin
    row_A <= {"Passwd: ", ans};
    row_B <= {"Time:    ", 
              "0" + count_time[27:24],"0" + count_time[23:20],"0" + count_time[19:16],"0" + count_time[15:12],
              "0" + count_time[11: 8],"0" + count_time[ 7: 4],"0" + count_time[ 3: 0],
              " ms"};
  end
end

always @(posedge clk)begin
  if(~reset_n)begin
    correct <= 0;
    txt <= "00000000";
  end
  else if(P == S_CALC)begin
    if(passwd_hash == hash)begin
        correct <= 1;
        ans <= out;
    end
    
    if(txt[3:0] == 4'h9)begin
      txt[3:0] <= 0;
      if(txt[11:8] == 4'h9)begin
        txt[11:8] <= 0;
        if(txt[19:16] == 4'h9)begin
          txt[19:16] <= 0;
          if(txt[27:24] == 4'h9)begin
            txt[27:24] <= 0;
            if(txt[35:32] == 4'h9)begin
              txt[35:32] <= 0;
              if(txt[43:40] == 4'h9)begin
                txt[43:40] <= 0;
                if(txt[51:48] == 4'h9)begin
                  txt[51:48] <= 0;
                  if(txt[59:56] == 4'h9)begin
                    txt <= txt;
                  end
                  else txt[59:56] <= txt[59:56] + 1;
                end
                else txt[51:48] <= txt[51:48] + 1;
              end
              else txt[43:40] <= txt[43:40] + 1;
            end
            else txt[35:32] <= txt[35:32] + 1;
          end
          else txt[27:24] <= txt[27:24] + 1;
        end
        else txt[19:16] <= txt[19:16] + 1;
      end
      else txt[11:8] <= txt[11:8] + 1;
    end
    else txt[3:0] <= txt[3:0] + 1;
  end
end

endmodule

module debounce(
    input clk,
    input btn_input,
    output btn_output
    );
    assign btn_output = btn_input;
endmodule