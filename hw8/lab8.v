`timescale 1ns / 1ps

module lab8(
  // General system I/O ports
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,

  // SD card specific I/O ports
  output spi_ss,
  output spi_sck,
  output spi_mosi,
  input  spi_miso,

  // 1602 LCD Module Interface
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D
);

localparam [2:0] S_MAIN_INIT = 3'b000, S_MAIN_IDLE = 3'b001,
                 S_MAIN_WAIT = 3'b010, S_MAIN_READ = 3'b011,
                 S_MAIN_WAIT2 = 3'b100, S_MAIN_SHOW = 3'b101,
                 S_FINAL = 3'b110;

// Declare system variables
wire btn_level, btn_pressed;
reg  prev_btn_level;
reg  [5:0] send_counter;
reg  [2:0] P, P_next;
reg  [9:0] sd_counter;
reg  [7:0] data_byte;
reg  [31:0] blk_addr;

reg  finished = 0;
reg  [7:0] next = 0;
reg  [7:0] ending = 0;
reg  [3:0] counter = 0;
reg  [15:0] count = 0;

reg  [127:0] row_A = "SD card cannot  ";
reg  [127:0] row_B = "be initialized! ";
reg  done_flag; // Signals the completion of reading one SD sector.

// Declare SD card interface signals
wire clk_sel;
wire clk_500k;
reg  rd_req;
reg  [31:0] rd_addr;
wire init_finished;
wire [7:0] sd_dout;
wire sd_valid;

// Declare the control/data signals of an SRAM memory block
wire [7:0] data_in;
wire [7:0] data_out;
wire [8:0] sram_addr;
wire       sram_we, sram_en;

assign clk_sel = (init_finished)? clk : clk_500k; // clock for the SD controller
assign usr_led = P;

clk_divider#(200) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(clk_500k)
);

debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[2]),
  .btn_output(btn_level)
);

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

sd_card sd_card0(
  .cs(spi_ss),
  .sclk(spi_sck),
  .mosi(spi_mosi),
  .miso(spi_miso),

  .clk(clk_sel),
  .rst(~reset_n),
  .rd_req(rd_req),
  .block_addr(rd_addr),
  .init_finished(init_finished),
  .dout(sd_dout),
  .sd_valid(sd_valid)
);

sram ram0(
  .clk(clk),
  .we(sram_we),
  .en(sram_en),
  .addr(sram_addr),
  .data_i(data_in),
  .data_o(data_out)
);

//
// Enable one cycle of btn_pressed per each button hit
//
always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 0;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level == 1 && prev_btn_level == 0)? 1 : 0;

// ------------------------------------------------------------------------
// The following code sets the control signals of an SRAM memory block
// that is connected to the data output port of the SD controller.
// Once the read request is made to the SD controller, 512 bytes of data
// will be sequentially read into the SRAM memory block, one byte per
// clock cycle (as long as the sd_valid signal is high).
assign sram_we = sd_valid;          // Write data into SRAM when sd_valid is high.
assign sram_en = 1;                 // Always enable the SRAM block.
assign data_in = sd_dout;           // Input data always comes from the SD controller.
assign sram_addr = sd_counter[8:0]; // Set the driver of the SRAM address signal.
// End of the SRAM memory block
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the SD card reader that reads the super block (512 bytes)
always @(posedge clk) begin
  if (~reset_n) begin
    P <= S_MAIN_INIT;
    done_flag <= 0;
  end
  else begin
    P <= P_next;
    if (P_next == S_MAIN_WAIT)
      done_flag <= 1;
    else
      done_flag <= 0;
  end
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT: // wait for SD card initialization
      if (init_finished == 1) P_next = S_MAIN_IDLE;
      else P_next = S_MAIN_INIT;
    S_MAIN_IDLE: // wait for button click
      if (btn_pressed == 1) P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_IDLE;
    S_MAIN_WAIT: // issue a rd_req to the SD controller until it's ready
      P_next = S_MAIN_READ;
    S_MAIN_READ: // wait for the input data to enter the SRAM buffer
      if(next == 8'b11111111)P_next = S_MAIN_WAIT2;
      else if (sd_counter == 512) P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_READ;
    S_MAIN_WAIT2: // read byte 0 of the superblock from sram[]
      P_next = S_MAIN_SHOW;
    S_MAIN_SHOW:
      if(finished)P_next = S_FINAL;
      else if (sd_counter == 512) P_next = S_MAIN_WAIT2;
      else P_next = S_MAIN_SHOW;
    S_FINAL:
      P_next = S_FINAL;
    default:
      P_next = S_MAIN_IDLE;
  endcase
end

// FSM output logic: controls the 'rd_req' and 'rd_addr' signals.
always @(*) begin
  rd_req <= (P == S_MAIN_WAIT || P == S_MAIN_WAIT2);
end

// FSM output logic: controls the 'sd_counter' signal.
// SD card read address incrementer
always @(posedge clk) begin
  if (~reset_n)begin
    rd_addr <= 32'h2000;
  end
  else if( P == S_MAIN_WAIT || P == S_MAIN_WAIT2) begin
    rd_addr <= rd_addr + 1; // In lab 6, change this line to scan all blocks
  end
  
  if (~reset_n)begin
    sd_counter <= 0;
  end
  else if(P == S_MAIN_WAIT || P == S_MAIN_WAIT2)begin
    sd_counter <= 0;
  end
  else if (sd_valid)
    sd_counter <= sd_counter + 1;
end

// FSM ouput logic: Retrieves the content of sram[] for display

// End of the FSM of the SD card reader
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// LCD Display function.
always @(posedge clk) begin
  if (~reset_n) begin
    row_A = "SD card cannot  ";
    row_B = "be initialized! ";
  end
  else if(P == S_FINAL)begin
    row_A <= {"Found ",
                 ((count[15:12] > 9)? "7" : "0") + count[15:12],
                 ((count[11:08] > 9)? "7" : "0") + count[11:08],
                 ((count[07:04] > 9)? "7" : "0") + count[07:04],
                 ((count[03:00] > 9)? "7" : "0") + count[03:00],
                  " words"};
        row_B <= "in the text file";
  end
  else if (done_flag) begin
    row_A <= "Wait...         ";
    row_B <= "                ";
  end
  else if (P == S_MAIN_IDLE) begin
    row_A <= "Hit BTN2 to read";
    row_B <= "the SD card ... ";
  end
end
// End of the LCD display function
// ------------------------------------------------------------------------

always @(posedge clk)begin
  if(~reset_n)begin
    next <= 0;
  end
  else if(P == S_MAIN_READ && sd_valid && next[7] == 0)begin
    if(sd_dout == "D")next[7] <= 1;
    else next <= 0;
  end
  else if(P == S_MAIN_READ && sd_valid && next[6] == 0)begin
    if(sd_dout == "L")next[6] <= 1;
    else next <= 0;
  end
  else if(P == S_MAIN_READ && sd_valid && next[5] == 0)begin
    if(sd_dout == "A")next[5] <= 1;
    else next <= 0;
  end
  else if(P == S_MAIN_READ && sd_valid && next[4] == 0)begin
    if(sd_dout == "B")next[4] <= 1;
    else next <= 0;
  end
  else if(P == S_MAIN_READ && sd_valid && next[3] == 0)begin
    if(sd_dout == "_")next[3] <= 1;
    else next <= 0;
  end
  else if(P == S_MAIN_READ && sd_valid && next[2] == 0)begin
    if(sd_dout == "T")next[2] <= 1;
    else next <= 0;
  end
  else if(P == S_MAIN_READ && sd_valid && next[1] == 0)begin
    if(sd_dout == "A")next[1] <= 1;
    else next <= 0;
  end
  else if(P == S_MAIN_READ && sd_valid && next[0] == 0)begin
    if(sd_dout == "G")next[0] <= 1;
    else next <= 0;
  end
end

always @(posedge clk)begin
  if(~reset_n)begin
    counter <= 0;
  end
  else if(next == 8'b11111111 && ending != 8'b11111111)begin
    if(P == S_MAIN_SHOW && sd_valid && counter[3] == 0)begin
      if((sd_dout >= "A" && sd_dout <= "Z") || (sd_dout >= "a" && sd_dout <= "z"))counter[3] <= 1;
      else counter <= 4'b0000;
    end
    else if(P == S_MAIN_SHOW && sd_valid && counter[2] == 0)begin
      if((sd_dout >= "A" && sd_dout <= "Z") || (sd_dout >= "a" && sd_dout <= "z"))counter[2] <= 1;
      else counter <= 4'b0000;
    end
    else if(P == S_MAIN_SHOW && sd_valid && counter[1] == 0)begin
      if((sd_dout >= "A" && sd_dout <= "Z") || (sd_dout >= "a" && sd_dout <= "z"))counter[1] <= 1;
      else counter <= 4'b0000;
    end
    else if(P == S_MAIN_SHOW && sd_valid && counter[0] == 0)begin
      if( !((sd_dout >= "A" && sd_dout <= "Z") || (sd_dout >= "a" && sd_dout <= "z")) )begin
        counter <= 4'b0000;
        count <= count + 1;
      end
      else counter <= 4'b1111;
    end
    else if(P == S_MAIN_SHOW && sd_valid && counter[0] == 1)begin
      if( !((sd_dout >= "A" && sd_dout <= "Z") || (sd_dout >= "a" && sd_dout <= "z")) )begin
        counter <= 4'b0000;
      end
      else counter <= 4'b1111;
    end
  end
end

always @(posedge clk)begin
  if(~reset_n)begin
    ending <= 0;
    finished <= 0;
  end
  else if(next == 8'b11111111)begin
    if(P == S_MAIN_SHOW && sd_valid && ending[7] == 0)begin
      if(sd_dout == "D")ending[7] <= 1;
      else ending <= 0;
    end
    else if(P == S_MAIN_SHOW && sd_valid && ending[6] == 0)begin
      if(sd_dout == "L")ending[6] <= 1;
      else ending <= 0;
    end
    else if(P == S_MAIN_SHOW && sd_valid && ending[5] == 0)begin
      if(sd_dout == "A")ending[5] <= 1;
      else ending <= 0;
    end
    else if(P == S_MAIN_SHOW && sd_valid && ending[4] == 0)begin
      if(sd_dout == "B")ending[4] <= 1;
      else ending <= 0;
    end
    else if(P == S_MAIN_SHOW && sd_valid && ending[3] == 0)begin
      if(sd_dout == "_")ending[3] <= 1;
      else ending <= 0;
    end
    else if(P == S_MAIN_SHOW && sd_valid && ending[2] == 0)begin
      if(sd_dout == "E")ending[2] <= 1;
      else ending <= 0;
    end
    else if(P == S_MAIN_SHOW && sd_valid && ending[1] == 0)begin
      if(sd_dout == "N")ending[1] <= 1;
      else ending <= 0;
    end
    else if(P == S_MAIN_SHOW && sd_valid && ending[0] == 0)begin
      if(sd_dout == "D")begin
        ending[0] <= 1;
        finished <= 1;
      end
      else ending <= 0;
    end
  end
end

endmodule