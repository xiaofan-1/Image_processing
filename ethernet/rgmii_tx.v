`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/13 17:50:22
// Design Name: 
// Module Name: rgmii_tx
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


module rgmii_tx(
	//GMII发送端口
    input              gmii_tx_clk , //GMII发送时钟    
    input              gmii_tx_en  , //GMII输出数据有效信号
    input       [7:0]  gmii_txd    , //GMII输出数据        
    
    //RGMII发送端口
    output             rgmii_txc   , //RGMII发送数据时钟    
    output             rgmii_tx_ctl, //RGMII输出数据有效信号
    output      [3:0]  rgmii_txd     //RGMII输出数据     
    );
	
//*****************************************************
//**                    main code
//*****************************************************

assign rgmii_txc = gmii_tx_clk;

//输出双沿采样寄存器 (rgmii_tx_ctl)
/* ODDRE1 #(
      .IS_C_INVERTED     (1'b0),            // Optional inversion for C
      .IS_D1_INVERTED    (1'b0),            // Unsupported, do not use
      .IS_D2_INVERTED    (1'b0),            // Unsupported, do not use
      .SIM_DEVICE        ("ULTRASCALE"),    // Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1,ULTRASCALE_PLUS_ES2)
      .SRVAL(1'b0)                          // Initializes the ODDRE1 Flip-Flops to the specified value (1'b0, 1'b1)
   )
   ODDRE1_tx_ctl (
      .Q     (rgmii_tx_ctl),    // 1-bit output: Data output to IOB
      .C     (gmii_tx_clk),     // 1-bit input: High-speed clock input
      .D1    (gmii_tx_en),      // 1-bit input: Parallel data input 1
      .D2    (gmii_tx_en),      // 1-bit input: Parallel data input 2
      .SR    (1'b0)             // 1-bit input: Active High Async Reset
   ); */
   
ODDR #(
    .DDR_CLK_EDGE  ("SAME_EDGE"	),	// "OPPOSITE_EDGE" or "SAME_EDGE" 
    .INIT          (1'b0		),	// Initial value of Q: 1'b0 or 1'b1
    .SRTYPE        ("SYNC"		)	// Set/Reset type: "SYNC" or "ASYNC" 
) ODDR_inst (
    .Q             (rgmii_tx_ctl), // 1-bit DDR output
    .C             (gmii_tx_clk	),  // 1-bit clock input
    .CE            (1'b1		),	// 1-bit clock enable input
    .D1            (gmii_tx_en	),	// 1-bit data input (positive edge)
    .D2            (gmii_tx_en	),	// 1-bit data input (negative edge)
    .R             (1'b0		),	// 1-bit reset
    .S             (1'b0		)	// 1-bit set
); 


genvar i;
generate for (i=0; i<4; i=i+1)
    begin : txdata_bus
      /* ODDRE1 #(
      .IS_C_INVERTED(1'b0),      // Optional inversion for C
      .IS_D1_INVERTED(1'b0),     // Unsupported, do not use
      .IS_D2_INVERTED(1'b0),     // Unsupported, do not use
      .SIM_DEVICE("ULTRASCALE"), // Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1,ULTRASCALE_PLUS_ES2)
      .SRVAL(1'b0)               // Initializes the ODDRE1 Flip-Flops to the specified value (1'b0, 1'b1)
   )
   ODDRE1_inst (
      .Q     (rgmii_txd[i]),      // 1-bit output: Data output to IOB
      .C     (gmii_tx_clk),       // 1-bit input: High-speed clock input
      .D1    (gmii_txd[i]),       // 1-bit input: Parallel data input 1
      .D2    (gmii_txd[4+i]),     // 1-bit input: Parallel data input 2
      .SR    (1'b0)               // 1-bit input: Active High Async Reset
   );       */ 
//输出双沿采样寄存器 (rgmii_txd)
	ODDR #(
		.DDR_CLK_EDGE  ("SAME_EDGE"	),  // "OPPOSITE_EDGE" or "SAME_EDGE" 
		.INIT          (1'b0		),	// Initial value of Q: 1'b0 or 1'b1
		.SRTYPE        ("SYNC"		)	// Set/Reset type: "SYNC" or "ASYNC" 
        ) ODDR_inst (
            .Q             (rgmii_txd[i]	), // 1-bit DDR output
            .C             (gmii_tx_clk		),	// 1-bit clock input
            .CE            (1'b1			),	// 1-bit clock enable input
            .D1            (gmii_txd[i]		),  // 1-bit data input (positive edge)
            .D2            (gmii_txd[4+i]	),// 1-bit data input (negative edge)
            .R             (1'b0			),         // 1-bit reset
            .S             (1'b0			)          // 1-bit set
        );           
    end
endgenerate



endmodule
