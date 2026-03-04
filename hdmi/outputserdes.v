`timescale 1ns / 1ps

module outputserdes#(
    parameter                  KPARALLELWIDTH = 10
)(
    input                      pixelclk,
    input                      serialclk,
    input                      rstn,
    
    input [KPARALLELWIDTH-1:0] pdataout,
    
    output                     sdataout_p,
    output                     sdataout_n 
);

wire SHIFTIN1;
wire SHIFTIN2;
wire sDataOut;   

OSERDESE2 #(
      .DATA_RATE_OQ("DDR"),   // DDR, SDR
      .DATA_RATE_TQ("DDR"),   // DDR, BUF, SDR
      .DATA_WIDTH(10),         // Parallel data width (2-8,10,14)
      .INIT_OQ(1'b0),         // Initial value of OQ output (1'b0,1'b1)
      .INIT_TQ(1'b0),         // Initial value of TQ output (1'b0,1'b1)
      .SERDES_MODE("MASTER"), // MASTER, SLAVE
      .SRVAL_OQ(1'b0),        // OQ output value when SR is used (1'b0,1'b1)
      .SRVAL_TQ(1'b0),        // TQ output value when SR is used (1'b0,1'b1)
      .TBYTE_CTL("FALSE"),    // Enable tristate byte operation (FALSE, TRUE)
      .TBYTE_SRC("FALSE"),    // Tristate byte source (FALSE, TRUE)
      .TRISTATE_WIDTH(1)      // 3-state converter width (1,4)
   )
OSERDESE2_inst_master (
   .OFB(),             // 1-bit output: Feedback path for data
   .OQ(sDataOut),               // 1-bit output: Data path output
   // SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
   .SHIFTOUT1(),
   .SHIFTOUT2(),
   .TBYTEOUT(),   // 1-bit output: Byte group tristate
   .TFB(),             // 1-bit output: 3-state control
   .TQ(),               // 1-bit output: 3-state control
   .CLK(serialclk),             // 1-bit input: High speed clock
   .CLKDIV(pixelclk),       // 1-bit input: Divided clock
   // D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
   .D1(pdataout[0]),
   .D2(pdataout[1]),
   .D3(pdataout[2]),
   .D4(pdataout[3]),
   .D5(pdataout[4]),
   .D6(pdataout[5]),
   .D7(pdataout[6]),
   .D8(pdataout[7]),
   .OCE(1'b1),             // 1-bit input: Output data clock enable
   .RST(~rstn),             // 1-bit input: Reset
   // SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
   .SHIFTIN1(SHIFTIN1),
   .SHIFTIN2(SHIFTIN2),
   // T1 - T4: 1-bit (each) input: Parallel 3-state inputs
   .T1(),
   .T2(),
   .T3(),
   .T4(),
   .TBYTEIN(),     // 1-bit input: Byte group tristate
   .TCE(1'b0)              // 1-bit input: 3-state clock enable
);

OSERDESE2 #(
      .DATA_RATE_OQ("DDR"),   // DDR, SDR
      .DATA_RATE_TQ("DDR"),   // DDR, BUF, SDR
      .DATA_WIDTH(10),         // Parallel data width (2-8,10,14)
      .INIT_OQ(1'b0),         // Initial value of OQ output (1'b0,1'b1)
      .INIT_TQ(1'b0),         // Initial value of TQ output (1'b0,1'b1)
      .SERDES_MODE("SLAVE"), // MASTER, SLAVE
      .SRVAL_OQ(1'b0),        // OQ output value when SR is used (1'b0,1'b1)
      .SRVAL_TQ(1'b0),        // TQ output value when SR is used (1'b0,1'b1)
      .TBYTE_CTL("FALSE"),    // Enable tristate byte operation (FALSE, TRUE)
      .TBYTE_SRC("FALSE"),    // Tristate byte source (FALSE, TRUE)
      .TRISTATE_WIDTH(1)      // 3-state converter width (1,4)
   )
OSERDESE2_inst_slave (
   .OFB(),             // 1-bit output: Feedback path for data
   .OQ(),               // 1-bit output: Data path output
   // SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
   .SHIFTOUT1(SHIFTIN1),
   .SHIFTOUT2(SHIFTIN2),
   .TBYTEOUT(),   // 1-bit output: Byte group tristate
   .TFB(),             // 1-bit output: 3-state control
   .TQ(),               // 1-bit output: 3-state control
   .CLK(serialclk),             // 1-bit input: High speed clock
   .CLKDIV(pixelclk),       // 1-bit input: Divided clock
   // D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
   .D1(),
   .D2(),
   .D3(pdataout[8]),
   .D4(pdataout[9]),
   .D5(),
   .D6(),
   .D7(),
   .D8(),
   .OCE(1'b1),             // 1-bit input: Output data clock enable
   .RST(~rstn),             // 1-bit input: Reset
   // SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
   .SHIFTIN1(),
   .SHIFTIN2(),
   // T1 - T4: 1-bit (each) input: Parallel 3-state inputs
   .T1(),
   .T2(),
   .T3(),
   .T4(),
   .TBYTEIN(),     // 1-bit input: Byte group tristate
   .TCE(1'b0)              // 1-bit input: 3-state clock enable
);    

OBUFDS #(
      .IOSTANDARD("TMDS33"), // Specify the output I/O standard
      .SLEW("SLOW")           // Specify the output slew rate
   ) OBUFDS_inst (
      .O(sdataout_p),     // Diff_p output (connect directly to top-level port)
      .OB(sdataout_n),   // Diff_n output (connect directly to top-level port)
      .I(sDataOut)      // Buffer input
   );

endmodule
