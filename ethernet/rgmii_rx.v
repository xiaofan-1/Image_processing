`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/13 17:44:45
// Design Name: 
// Module Name: rgmii_rx
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


module rgmii_rx(
	//以太网RGMII接口
    input	wire		rgmii_rxc   	,//RGMII接收时钟
    input	wire		rgmii_rx_ctl	,//RGMII接收数据控制信号
    input	wire [3:0]  rgmii_rxd   	,//RGMII接收数据
	//以太网GMII接口
    output	wire 		gmii_rx_clk 	,//GMII接收时钟
    output	wire 		gmii_rx_dv  	,//GMII接收数据有效信号
    output	wire [7:0]  gmii_rxd         //GMII接收数据   
    );
	
//wire define
wire         rgmii_rxc_bufg		; //全局时钟缓存
wire         rgmii_rxc_bufio	; //全局时钟IO缓存
wire  [1:0]  gmii_rxdv_t		; //两位GMII接收有效信号 

// 延迟后的信号线
wire         rgmii_rx_ctl_delay;
wire  [3:0]  rgmii_rxd_delay;

//*****************************************************
//**                    main code
//*****************************************************
assign gmii_rx_clk = rgmii_rxc_bufg;
assign gmii_rx_dv  = gmii_rxdv_t[0] & gmii_rxdv_t[1];

//全局时钟缓存
BUFG BUFG_inst (
  .I            (rgmii_rxc		),      // 1-bit input: Clock input
  .O            (rgmii_rxc_bufg	)  // 1-bit output: Clock output
);

//全局时钟IO缓存
BUFIO BUFIO_inst (
  .I            (rgmii_rxc),      // 1-bit input: Clock input
  .O            (rgmii_rxc_bufio) // 1-bit output: Clock output
);

IDELAYE2 #(
    .CINVCTRL_SEL("FALSE"),          
    .DELAY_SRC("IDATAIN"),           
    .HIGH_PERFORMANCE_MODE("FALSE"), 
    .IDELAY_TYPE("FIXED"),           
    .IDELAY_VALUE(0),                
                                      
    .PIPE_SEL("FALSE"),              
    .REFCLK_FREQUENCY(200.0),        
    .SIGNAL_PATTERN("DATA")          
) u_idelay_ctl (
    .CNTVALUEOUT(), 
    .DATAOUT(rgmii_rx_ctl_delay),    
    .C(1'b0),                     
    .CE(1'b0),                   
    .CINVCTRL(1'b0),       
    .CNTVALUEIN(5'd0),   
    .DATAIN(1'b0),           
    .IDATAIN(rgmii_rx_ctl),         
    .INC(1'b0),                 
    .LD(1'b0),                   
    .LDPIPEEN(1'b0),       
    .REGRST(1'b0)            
);
	
//输入双沿采样寄存器
IDDR #(
    .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),// "OPPOSITE_EDGE", "SAME_EDGE" 
                                        //    or "SAME_EDGE_PIPELINED" 
    .INIT_Q1  	(1'b0			),	// Initial value of Q1: 1'b0 or 1'b1
    .INIT_Q2  	(1'b0			),	// Initial value of Q2: 1'b0 or 1'b1
    .SRTYPE   	("SYNC"			)	// Set/Reset type: "SYNC" or "ASYNC" 
) u_iddr_rx_ctl (
    .Q1       	(gmii_rxdv_t[0]	),	// 1-bit output for positive edge of clock
    .Q2       	(gmii_rxdv_t[1]	),	// 1-bit output for negative edge of clock
    .C        	(rgmii_rxc_bufio),	// 1-bit clock input
    .CE       	(1'b1			),	// 1-bit clock enable input
    .D        	(rgmii_rx_ctl_delay	),	// 1-bit DDR data input
    .R        	(1'b0			),	// 1-bit reset
    .S        	(1'b0			)	// 1-bit set
);
 
genvar i;
generate for (i=0; i<4; i=i+1)
    begin : rxdata_bus
        IDELAYE2 #(
            .CINVCTRL_SEL("FALSE"),          
            .DELAY_SRC("IDATAIN"),           
            .HIGH_PERFORMANCE_MODE("FALSE"), 
            .IDELAY_TYPE("FIXED"),           
            .IDELAY_VALUE(0),                
            .PIPE_SEL("FALSE"),              
            .REFCLK_FREQUENCY(200.0),        
            .SIGNAL_PATTERN("DATA")          
        ) u_idelay_rxd (
            .CNTVALUEOUT(), 
            .DATAOUT(rgmii_rxd_delay[i]),  
            .C(1'b0),                     
            .CE(1'b0),                   
            .CINVCTRL(1'b0),       
            .CNTVALUEIN(5'd0),   
            .DATAIN(1'b0),           
            .IDATAIN(rgmii_rxd[i]),          
            .INC(1'b0),                 
            .LD(1'b0),                   
            .LDPIPEEN(1'b0),       
            .REGRST(1'b0)            
        );
		
		IDDR #(
            .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),// "OPPOSITE_EDGE", "SAME_EDGE" 
                                                //    or "SAME_EDGE_PIPELINED" 
            .INIT_Q1  (1'b0			),	// Initial value of Q1: 1'b0 or 1'b1
            .INIT_Q2  (1'b0			),	// Initial value of Q2: 1'b0 or 1'b1
            .SRTYPE   ("SYNC"		)	// Set/Reset type: "SYNC" or "ASYNC" 
        ) u_iddr_rxd (
            .Q1       (gmii_rxd[i]		),	// 1-bit output for positive edge of clock
            .Q2       (gmii_rxd[4+i]	),	// 1-bit output for negative edge of clock
            .C        (rgmii_rxc_bufio	),	// 1-bit clock input rgmii_rxc_bufio
            .CE       (1'b1				),	// 1-bit clock enable input
            .D        (rgmii_rxd_delay[i]),	// 1-bit DDR data input
            .R        (1'b0				),	// 1-bit reset
            .S        (1'b0				)	// 1-bit set
        );
    end
endgenerate


endmodule
