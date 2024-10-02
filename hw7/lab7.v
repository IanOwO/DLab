`timescale 1ns / 1ps

module lab6(
  // General system I/O ports
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,
  input  uart_rx,
  output uart_tx,
  // 1602 LCD Module Interface
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D
);

localparam [2:0] S_MAIN_INIT = 3'b000, S_MAIN_READ = 3'b001,
                 S_CAL1 = 3'b010, S_CAL2 = 3'b011, S_CAL3 = 3'b100, S_CAL4 = 3'b101,
                 S_PRINT = 3'b110;
localparam [1:0] S_UART_IDLE = 0, S_UART_WAIT = 1,
                 S_UART_SEND = 2, S_UART_INCR = 3;
localparam INIT_DELAY = 100_000; // 1 msec @ 100 MHz
localparam STR1 = 0;
localparam LEN1 = 36;

localparam STR2 = 36;
localparam LEN2 = 32;

localparam STR3 = 68;
localparam LEN3 = 32;

localparam STR4 = 100;
localparam LEN4 = 32;

localparam STR5 = 132;
localparam LEN5 = 35;

localparam MEM_SIZE = 167;


wire enter_pressed;
wire print_enable, print_done;
reg [$clog2(MEM_SIZE):0] send_counter;
reg [2:0] P, P_next;
reg [1:0] Q, Q_next;
reg [$clog2(INIT_DELAY):0] init_counter;
reg [4:0] calc_counter;
reg [7:0] data[0:MEM_SIZE-1];
reg  [0:LEN1*8-1] msg1 = {"The matrix multiplication result is:"};
reg  [0:LEN2*8-1] msg2 = {"\015\012[ 00000, 00000, 00000, 00000 ]"};
reg  [0:LEN3*8-1] msg3 = {"\015\012[ 00000, 00000, 00000, 00000 ]"};
reg  [0:LEN4*8-1] msg4 = {"\015\012[ 00000, 00000, 00000, 00000 ]"};
reg  [0:LEN5*8-1] msg5 = {"\015\012[ 00000, 00000, 00000, 00000 ]\015\012",8'h00};

// declare UART signals
wire transmit;
wire received;
wire [7:0] rx_byte;
reg  [7:0] rx_temp;  // if recevied is true, rx_temp latches rx_byte for ONLY ONE CLOCK CYCLE!
wire [7:0] tx_byte;
wire [7:0] echo_key; // keystrokes to be echoed to the terminal
wire is_num_key;
wire is_receiving;
wire is_transmitting;
wire recv_error;

/* The UART device takes a 100MHz clock to handle I/O at 9600 baudrate */
uart uart(
  .clk(clk),
  .rst(~reset_n),
  .rx(uart_rx),
  .tx(uart_tx),
  .transmit(transmit),
  .tx_byte(tx_byte),
  .received(received),
  .rx_byte(rx_byte),
  .is_receiving(is_receiving),
  .is_transmitting(is_transmitting),
  .recv_error(recv_error)
);

// declare system variables
wire [1:0]  btn_level, btn_pressed;
reg  [1:0]  prev_btn_level;
reg  [11:0] user_addr;
reg  [7:0]  user_data;

reg  [7:0]  matrix_one [0:15];
reg  [7:0]  B [0:3];

reg  [18:0] ans [0:15];
reg  finish_cal = 0;
reg  finish_cal1 = 0;
reg  finish_cal2 = 0;
reg  finish_cal3 = 0;
reg  finish_cal4 = 0;

reg  readdone = 0;
reg  readdone1 = 0;
reg  readdone2 = 0;
reg  readdone3 = 0;
reg  readdone4 = 0;

reg  [127:0] row_A, row_B;

// declare SRAM control signals
wire [10:0] sram_addr;
wire [7:0]  data_in;
wire [7:0]  data_out;
wire        sram_we, sram_en;

assign usr_led = 4'h00;

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
  .btn_input(usr_btn[0]),
  .btn_output(btn_level[0])
);

debounce btn_db1(
  .clk(clk),
  .btn_input(usr_btn[1]),
  .btn_output(btn_level[1])
);

//
// Enable one cycle of btn_pressed per each button hit
//
always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 2'b00;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level & ~prev_btn_level);

// ------------------------------------------------------------------------
// The following code creates an initialized SRAM memory block that
// stores an 1024x8-bit unsigned numbers.
sram ram0(.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));

assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However,
                             // if you set 'we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = (P == S_MAIN_READ || P == S_CAL1 || P == S_CAL2 || P == S_CAL3); // Enable the SRAM block.
assign sram_addr = user_addr[11:0];
assign data_in = 8'b0; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the main controller
always @(posedge clk) begin
  if (~reset_n) begin
    P <= S_MAIN_INIT; // read samples at 000 first
  end
  else begin
    P <= P_next;
  end
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT:
      if (init_counter > INIT_DELAY && btn_pressed) P_next = S_MAIN_READ;
      else P_next = S_MAIN_INIT;
    S_MAIN_READ: // fetch the sample from the SRAM
      if(finish_cal)P_next = S_CAL1;
      else P_next = S_MAIN_READ;
    S_CAL1:
      if(finish_cal1)P_next = S_CAL2;
      else P_next = S_CAL1;
    S_CAL2:
      if(finish_cal2)P_next = S_CAL3;
      else P_next = S_CAL2;
    S_CAL3:
      if(finish_cal3)P_next = S_CAL4;
      else P_next = S_CAL3;
    S_CAL4:
      if(finish_cal4)P_next = S_PRINT;
      else P_next = S_CAL4;
    S_PRINT:
      if(print_done)P_next = S_MAIN_INIT;
      else P_next = S_PRINT;
  endcase
end

// FSM ouput logic: Fetch the data bus of sram[] for display
always @(posedge clk) begin
  if (~reset_n) user_data <= 8'b0;
  else if (sram_en && !sram_we) user_data <= data_out;
end
// End of the main controller
// ------------------------------------------------------------------------

always @(posedge clk)begin
  if(~reset_n || P == S_MAIN_INIT)begin
    user_addr = 0;
    readdone = 0;
    readdone1 = 0;
    readdone2 = 0;
    readdone3 = 0;
    readdone4 = 0;
    
    for(idx = 0;idx < 16;idx = idx + 1)matrix_one[idx] = 0;
    for(idx = 0;idx < 4;idx = idx + 1)B[idx] = 0;
  end
  else if(P == S_MAIN_READ)begin
    if(sram_en && !sram_we)begin
      case (user_addr - 1)
        0: matrix_one[0] = data_out;
        1: matrix_one[4] = data_out;
        2: matrix_one[8] = data_out;
        3: matrix_one[12] = data_out;
        4: matrix_one[1] = data_out;
        5: matrix_one[5] = data_out;
        6: matrix_one[9] = data_out;
        7: matrix_one[13] = data_out;
        8: matrix_one[2] = data_out;
        9: matrix_one[6] = data_out;
        10: matrix_one[10] = data_out;
        11: matrix_one[14] = data_out;
        12: matrix_one[3] = data_out;
        13: matrix_one[7] = data_out;
        14: matrix_one[11] = data_out;
        15: matrix_one[15] = data_out;
        16: B[0] = data_out;
        17: B[1] = data_out;
        18: B[2] = data_out;
        19: begin
            B[3] = data_out;
            readdone = 1;
            readdone1 = 1;
        end
      endcase
    end
    user_addr = (user_addr < 20)? user_addr + 1 : user_addr;
  end
  else if(P == S_CAL1)begin
    if(sram_en && !sram_we)begin
      case (user_addr - 1)
        20: B[0] = data_out;
        21: B[1] = data_out;
        22: B[2] = data_out;
        23: begin
            B[3] = data_out;
            readdone2 = 1;
        end
      endcase
    end
    user_addr = (user_addr < 24)? user_addr + 1 : user_addr;
  end
  else if(P == S_CAL2)begin
    if(sram_en && !sram_we)begin
      case (user_addr - 1)
        24: B[0] = data_out;
        25: B[1] = data_out;
        26: B[2] = data_out;
        27: begin
            B[3] = data_out;
            readdone3 = 1;
        end
      endcase
    end
    user_addr = (user_addr < 28)? user_addr + 1 : user_addr;
  end
  else if(P == S_CAL3)begin
    if(sram_en && !sram_we)begin
      case (user_addr - 1)
        28: B[0] = data_out;
        29: B[1] = data_out;
        30: B[2] = data_out;
        31: begin
            B[3] = data_out;
            readdone4 = 1;
        end
      endcase
    end
    user_addr = (user_addr < 32)? user_addr + 1 : user_addr;
  end
end

integer idx;
integer t;
always @(posedge clk) begin
  if (~reset_n) begin
    for (idx = 0; idx < LEN1; idx = idx + 1) data[idx+STR1] = msg1[idx*8 +: 8];
    for (idx = 0; idx < LEN2; idx = idx + 1) data[idx+STR2] = msg2[idx*8 +: 8];
    for (idx = 0; idx < LEN3; idx = idx + 1) data[idx+STR3] = msg3[idx*8 +: 8];
    for (idx = 0; idx < LEN4; idx = idx + 1) data[idx+STR4] = msg4[idx*8 +: 8];
    for (idx = 0; idx < LEN5; idx = idx + 1) data[idx+STR5] = msg5[idx*8 +: 8];
    t = 0;
  end
  else if (P == S_CAL1 && P_next == S_CAL2) begin
    data[STR2+4] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR2+5] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR2+6] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR2+7] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR2+8] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 1;
    data[STR3+4] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR3+5] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR3+6] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR3+7] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR3+8] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 2;
    data[STR4+4] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR4+5] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR4+6] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR4+7] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR4+8] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 3;
    data[STR5+4] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR5+5] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR5+6] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR5+7] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR5+8] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 4;
  end
  else if (P == S_CAL2 && P_next == S_CAL3) begin
    data[STR2+4 + 7] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR2+5 + 7] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR2+6 + 7] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR2+7 + 7] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR2+8 + 7] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 5;
    data[STR3+4 + 7] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR3+5 + 7] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR3+6 + 7] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR3+7 + 7] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR3+8 + 7] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 6;
    data[STR4+4 + 7] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR4+5 + 7] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR4+6 + 7] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR4+7 + 7] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR4+8 + 7] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 7;
    data[STR5+4 + 7] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR5+5 + 7] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR5+6 + 7] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR5+7 + 7] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR5+8 + 7] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 8;
  end
  else if (P == S_CAL3 && P_next == S_CAL4) begin
    data[STR2+4 + 14] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR2+5 + 14] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR2+6 + 14] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR2+7 + 14] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR2+8 + 14] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 9;
    data[STR3+4 + 14] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR3+5 + 14] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR3+6 + 14] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR3+7 + 14] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR3+8 + 14] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 10;
    data[STR4+4 + 14] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR4+5 + 14] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR4+6 + 14] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR4+7 + 14] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR4+8 + 14] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 11;
    data[STR5+4 + 14] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR5+5 + 14] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR5+6 + 14] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR5+7 + 14] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR5+8 + 14] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 12;
  end
  else if (P == S_CAL4 && P_next == S_PRINT) begin
    data[STR2+4 + 21] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR2+5 + 21] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR2+6 + 21] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR2+7 + 21] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR2+8 + 21] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 13;
    data[STR3+4 + 21] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR3+5 + 21] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR3+6 + 21] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR3+7 + 21] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR3+8 + 21] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 14;
    data[STR4+4 + 21] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR4+5 + 21] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR4+6 + 21] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR4+7 + 21] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR4+8 + 21] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 15;
    data[STR5+4 + 21] <= ((ans[t][18:16] > 9) ? "7" : "0") + ans[t][18:16];
    data[STR5+5 + 21] <= ((ans[t][15:12] > 9) ? "7" : "0") + ans[t][15:12];
    data[STR5+6 + 21] <= ((ans[t][11:08] > 9) ? "7" : "0") + ans[t][11:08];
    data[STR5+7 + 21] <= ((ans[t][07:04] > 9) ? "7" : "0") + ans[t][07:04];
    data[STR5+8 + 21] <= ((ans[t][03:00] > 9) ? "7" : "0") + ans[t][03:00];
    t = 16;
  end
end

always @(posedge clk) begin
  if (P == S_MAIN_INIT) init_counter <= init_counter + 1;
  else init_counter <= 0;
end

always @(posedge clk) begin
  if (~reset_n) Q <= S_UART_IDLE;
  else Q <= Q_next;
end

always @(*) begin // FSM next-state logic
  case (Q)
    S_UART_IDLE: // wait for the print_string flag
      if (print_enable) Q_next = S_UART_WAIT;
      else Q_next = S_UART_IDLE;
    S_UART_WAIT: // wait for the transmission of current data byte begins
      if (is_transmitting == 1) Q_next = S_UART_SEND;
      else Q_next = S_UART_WAIT;
    S_UART_SEND: // wait for the transmission of current data byte finishes
      if (is_transmitting == 0) Q_next = S_UART_INCR; // transmit next character
      else Q_next = S_UART_SEND;
    S_UART_INCR:
      if (tx_byte == 8'h0) Q_next = S_UART_IDLE; // string transmission ends
      else Q_next = S_UART_WAIT;
  endcase
end

// FSM output logics: UART transmission control signals
assign enter_pressed = (rx_temp == 8'h0D); // don't use rx_byte here!
assign print_enable = (P != S_PRINT && P_next == S_PRINT);
assign print_done = (tx_byte == 8'h0);
assign transmit = (Q_next == S_UART_WAIT || print_enable);
assign tx_byte  = data[send_counter];

// UART send_counter control circuit
always @(posedge clk) begin
  case (P_next)
    S_CAL4: send_counter = STR1;
    default: send_counter <= send_counter + (Q_next == S_UART_INCR);
  endcase
end
// End of the FSM of the print string controller
// ------------------------------------------------------------------------

integer i;
integer j;
integer c;
reg [18:0] pipe[0:15];

always @(posedge clk) begin
  if(~reset_n || P == S_MAIN_INIT)begin
    i = 0;
    j = 0;
    finish_cal = 0;
    finish_cal1 = 0;
    finish_cal2 = 0;
    finish_cal3 = 0;
    finish_cal4 = 0;
  end
  else if (P == S_MAIN_READ && !finish_cal && readdone1)begin
    for(j = 0;j < 16;j = j + 1)begin
      pipe[j] <= matrix_one[j] * B[j % 4];
    end
    finish_cal = 1;
  end
  else if (P == S_CAL1 && !finish_cal1 && readdone2) begin
    for(i = 0;i < 4;i = i + 1)begin
      ans[i] = 0;
      case (i)
        0:ans[i] = pipe[0] + pipe[1] + pipe[2] + pipe[3];
        1:ans[i] = pipe[4] + pipe[5] + pipe[6] + pipe[7];
        2:ans[i] = pipe[8] + pipe[9] + pipe[10] + pipe[11];
        3:ans[i] = pipe[12] + pipe[13] + pipe[14] + pipe[15];
      endcase
    end
    for(j = 0;j < 16;j = j + 1)begin
      pipe[j] <= matrix_one[j] * B[j % 4];
    end
    if(i == 4 && j == 16)finish_cal1 = 1;
  end
  else if (P == S_CAL2 && !finish_cal2 && readdone3) begin
    for(i = 4;i < 8;i = i + 1)begin
      ans[i] = 0;
      case (i)
        4:ans[i] = pipe[0] + pipe[1] + pipe[2] + pipe[3];
        5:ans[i] = pipe[4] + pipe[5] + pipe[6] + pipe[7];
        6:ans[i] = pipe[8] + pipe[9] + pipe[10] + pipe[11];
        7:ans[i] = pipe[12] + pipe[13] + pipe[14] + pipe[15];
      endcase
    end
    for(j = 0;j < 16;j = j + 1)begin
      pipe[j] <= matrix_one[j] * B[j % 4];
    end
    if(i == 8 && j == 16)finish_cal2 = 1;
  end
  else if (P == S_CAL3 && !finish_cal3 && readdone4) begin
    for(i = 8;i < 12;i = i + 1)begin
      ans[i] = 0;
      case (i)
        8:ans[i] = pipe[0] + pipe[1] + pipe[2] + pipe[3];
        9:ans[i] = pipe[4] + pipe[5] + pipe[6] + pipe[7];
        10:ans[i] = pipe[8] + pipe[9] + pipe[10] + pipe[11];
        11:ans[i] = pipe[12] + pipe[13] + pipe[14] + pipe[15];
      endcase
    end
    for(j = 0;j < 16;j = j + 1)begin
      pipe[j] <= matrix_one[j] * B[j % 4];
    end
    if(i == 12 && j == 16)finish_cal3 = 1;
  end
  else if (P == S_CAL4 && !finish_cal4) begin
    for(i = 12;i < 16;i = i + 1)begin
      ans[i] = 0;
      case (i)
        12:ans[i] = pipe[0] + pipe[1] + pipe[2] + pipe[3];
        13:ans[i] = pipe[4] + pipe[5] + pipe[6] + pipe[7];
        14:ans[i] = pipe[8] + pipe[9] + pipe[10] + pipe[11];
        15:ans[i] = pipe[12] + pipe[13] + pipe[14] + pipe[15];
      endcase
    end
    if(i == 16)finish_cal4 = 1;
  end
end

endmodule
