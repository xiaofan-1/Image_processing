
module top_eth(
    input   wire            sys_clk      ,
    input   wire            sys_rst_n    ,
    output	wire			phy_rstn	 ,
    input   wire            key          ,
    output 	reg   			led			 ,

    //ddr3
    output  wire    [14:0]  ddr3_addr           ,
    output  wire    [2:0]   ddr3_ba             ,
    output  wire            ddr3_cas_n          ,
    output  wire    [0:0]   ddr3_ck_n           ,
    output  wire    [0:0]   ddr3_ck_p           ,
    output  wire    [0:0]   ddr3_cke            ,
    output  wire            ddr3_ras_n          ,
    output  wire            ddr3_reset_n        ,
    output  wire            ddr3_we_n           ,
    inout   wire    [31:0]  ddr3_dq             ,
    inout   wire    [3:0]   ddr3_dqs_n          ,
    inout   wire    [3:0]   ddr3_dqs_p          ,
    output  wire            init_calib_complete ,
    output  wire    [0:0]   ddr3_cs_n           ,
    output  wire    [3:0]   ddr3_dm             ,
    output  wire    [0:0]   ddr3_odt            ,

    input	wire			rgmii_rxc	 ,
    input	wire			rgmii_rx_ctl ,
    input	wire	[3:0]  	rgmii_rxd	 ,	
                         
    output	wire			rgmii_txc	 ,
    output	wire			rgmii_tx_ctl ,
    output	wire	[3:0] 	rgmii_txd    
);

wire    rgmii_clk;  
wire    clk_200m;   

wire    pixclk_out;
wire    rst_n;
wire    locked;

clk_pic clk_pic_inst (
    // Clock out ports
    .clk_out1(pixclk_out),     // output clk_out1
    .clk_out2(clk_200m),     // output clk_out2
    .clk_out3(clk_out3),     // output clk_out3
    // Status and control signals
    .resetn(sys_rst_n), // input resetn
    .locked(locked),       // output locked
   // Clock in ports
    .clk_in1(sys_clk)      // input clk_in1
);

assign rst_n = sys_rst_n & locked;
assign phy_rstn = rst_n;

reg [7:0] dly_cnt;
reg       idelay_rst;

always @(posedge clk_200m or negedge rst_n) begin
    if (!rst_n) begin
        dly_cnt <= 0;
        idelay_rst <= 1'b1; 
    end else begin
        if (dly_cnt < 8'hFF) 
            dly_cnt <= dly_cnt + 1;
        else 
            idelay_rst <= 1'b0; 
    end
end

IDELAYCTRL IDELAYCTRL_inst (
    .RDY(),
    .REFCLK(clk_200m),
    .RST(idelay_rst) // 使用延时后的复位
);

//===========================================================================
// color_bar
//===========================================================================
localparam  X_BITS   = 4'd13   ;
localparam  Y_BITS   = 4'd13   ;
localparam  V_TOTAL  = 12'd750 ;
localparam  V_FP     = 12'd5   ;
localparam  V_BP     = 12'd20  ;
localparam  V_SYNC   = 12'd5   ;
localparam  V_ACT    = 12'd720 ;
localparam  H_TOTAL  = 12'd1650;
localparam  H_FP     = 12'd110 ;
localparam  H_BP     = 12'd220 ;
localparam  H_SYNC   = 12'd40  ;
localparam  H_ACT    = 12'd1280;

wire   [X_BITS-1:0] x_act      ;
wire   [Y_BITS-1:0] y_act      ;

wire                vs_in_w      ;
wire                hs_in_w      ;
wire                de_in_w      ;

wire            ch0_read_req    ;
wire            ch0_read_req_ack;
wire            ch0_read_en;
wire    [15:0]  ch0_read_data;

wire             bar_vs     ;
wire             bar_hs     ;
wire             bar_de     ;
wire    [7:0]    bar_r      ;
wire    [7:0]    bar_g      ;
wire    [7:0]    bar_b      ;

wire    [23:0]  rgb_data   ;
assign rgb_data = {bar_r,bar_g,bar_b};

sync_vg # (
    .X_BITS  ( X_BITS  ) ,
    .Y_BITS  ( Y_BITS  ) ,
    .V_TOTAL ( V_TOTAL ) ,
    .V_FP    ( V_FP    ) ,
    .V_BP    ( V_BP    ) ,
    .V_SYNC  ( V_SYNC  ) ,
    .V_ACT   ( V_ACT   ) ,
    .H_TOTAL ( H_TOTAL ) ,
    .H_FP    ( H_FP    ) ,
    .H_BP    ( H_BP    ) ,
    .H_SYNC  ( H_SYNC  ) ,
    .H_ACT   ( H_ACT   )
) sync_vg_inst (
    /*input   wire                    */.clk     ( pixclk_out ) , 
    /*input   wire                    */.rst_n   ( rst_n      ) ,
    /*output  reg                     */.vs_out  ( vs_in_w    ) ,
    /*output  reg                     */.hs_out  ( hs_in_w    ) ,
    /*output  reg                     */.de_out  ( de_in_w    ) ,
    /*output  reg     [X_BITS-1:0]    */.x_act   ( x_act      ) ,
    /*output  reg     [Y_BITS-1:0]    */.y_act   ( y_act      )  
);

pattern_vg # (
    .COCLOR_DEPP    ( 8        ) , // number of bits per channel
    .X_BITS         ( X_BITS   ) ,
    .Y_BITS         ( Y_BITS   ) ,
    .H_ACT          ( H_ACT    ) ,
    .V_ACT          ( V_ACT    )
) pattern_vg_inst (                                       
    /*input   wire                        */.pix_clk ( pixclk_out ) ,
    /*input   wire                        */.rst_n   ( rst_n & init_calib_complete     ) , 
    /*input   wire                        */.vs_in   ( vs_in_w    ) , 
    /*input   wire                        */.hs_in   ( hs_in_w    ) , 
    /*input   wire                        */.de_in   ( de_in_w    ) ,
    /*input   wire    [X_BITS-1:0]        */.x_act   ( x_act      ) ,
    /*input   wire    [Y_BITS-1:0]        */.y_act   ( y_act      ) ,
       
    /*output  reg                         */.vs_out  ( bar_vs     ) , 
    /*output  reg                         */.hs_out  ( bar_hs     ) , 
    /*output  reg                         */.de_out  ( bar_de     ) ,
    /*output  reg     [COCLOR_DEPP-1:0]   */.r_out   ( bar_r      ) , 
    /*output  reg     [COCLOR_DEPP-1:0]   */.g_out   ( bar_g      ) , 
    /*output  reg     [COCLOR_DEPP-1:0]   */.b_out   ( bar_b      )
);


wire    [15:0]  ch0_write_data;
wire            ch0_write_en;

assign ch0_write_data = {bar_r[7:3],bar_g[7:2],bar_b[7:3]};
assign ch0_write_en = bar_de;

//===========================================================================
// cmos_write_req_gen
//===========================================================================
wire                ch0_write_req        ;
wire                ch0_write_req_ack    ;
wire    [1:0]       ch0_write_addr_index ;
wire    [1:0]       ch0_read_addr_index  ;

cmos_write_req_gen cmos_write_req_gen_inst0(
    /*input   wire            */.clk             ( pixclk_out           ) ,
    /*input   wire            */.rst_n           ( rst_n & init_calib_complete ) ,
    /*input   wire            */.cmos_vsync      ( bar_vs               ) ,
    /*output  reg             */.write_req       ( ch0_write_req        ) ,
    /*input   wire            */.write_req_ack   ( ch0_write_req_ack    ) ,
    /*output  reg     [1:0]   */.write_addr_index( ch0_write_addr_index ) ,
    /*output  reg     [1:0]   */.read_addr_index ( ch0_read_addr_index  ) 
);

wire    btn_flag;

btn_deb_fix#(
    .BTN_WIDTH ( 4'd1 ),
    .BTN_DELAY ( 20'h7_ffff )
) btn_deb_fix_inst(
    /*input   wire                    */.clk           ( rgmii_clk     )  , //
    /*input   wire                    */.rst_n         ( rst_n       ) , //
    /*input   wire    [BTN_WIDTH-1:0] */.btn_in        ( key         ) ,
    /*output  reg     [BTN_WIDTH-1:0] */.btn_flag      ( btn_flag    ) , // 脉冲信号：按键按下瞬间产生一个时钟周期的高电平
    /*output  reg     [BTN_WIDTH-1:0] */.btn_deb_fix   () // 电平信号：消抖后的按键状态
);

ethernet_top ethernet_top_inst(
    /*input   wire            */.clk           ( sys_clk ) ,
    /*input   wire            */.video_clk     ( pixclk_out ) ,
    /*input   wire            */.rst_n         ( rst_n ) ,
    /*output  wire            */.read_req      ( ch0_read_req ) ,
    /*input   wire            */.read_req_ack  ( ch0_read_req_ack ) ,
    /*output  wire            */.read_en       ( ch0_read_en ) ,
    /*input   wire    [15:0]  */.read_data     ( ch0_read_data ) ,

    /*input   wire            */.key_flag1     ( btn_flag ) ,

    /*output  wire            */.udp_rx_en     () ,
    /*output  wire    [7:0]   */.udp_idata     () ,
    //ethernet
    /*output  wire            */.rgmii_clk     ( rgmii_clk ) ,
    /*input   wire            */.eth_rx_clk    ( rgmii_rxc ) ,//PHY芯片
    /*input   wire            */.eth_rx_valid  ( rgmii_rx_ctl ) ,
    /*input   wire    [3:0]   */.eth_rx_data   ( rgmii_rxd ) ,
    /*output  wire            */.eth_tx_clk    ( rgmii_txc ) ,
    /*output  wire            */.eth_tx_valid  ( rgmii_tx_ctl ) ,
    /*output  wire    [3:0]   */.eth_tx_data   ( rgmii_txd )      
 );

reg[31:0] cnt_timer;
always @(posedge rgmii_clk)begin
	if( cnt_timer==32'h1_fff_fff) begin
		led <= ~led;
		cnt_timer<=32'h0;
	end
	else begin
		led <= led;
		cnt_timer<=cnt_timer + 1'b1;
	end
end

//===========================================================================
// DDR
//===========================================================================
Top_ddr3 #(
    .MEM_DATA_BITS          ( 256  ) , //external memory user interface data width
    .ADDR_BITS              ( 25   ) , //external memory user interface address width
    .BURST_BITS             ( 10   ) , //external memory user interface burst width
    .READ_DATA_BITS         ( 16   ) , //external memory user interface read data width
    .WRITE_DATA_BITS        ( 16   ) , //external memory user interface write data width
    .BURST_SIZE             ( 16   ) , //external memory user interface burst size
    .FRAME_SIZE0            ( 1280 * 720 ) , // ch0 frame size
    .FRAME_SIZE1            ( 640  * 720 ) , // ch1 frame size 
    .FRAME_SIZE2            ( 1280 * 360 ) , // ch2 frame size
    .FRAME_SIZE3            ( 1280 * 720 )   // ch3 frame size
) Top_ddr3_inst (
    /*input   wire            */.clk_200M             ( clk_200m ) ,
    /*input   wire            */.rst_n                ( rst_n   ) ,
    /*//ddr3*/
    /*output  wire [14:0]     */.ddr3_addr            ( ddr3_addr            ) ,
    /*output  wire [2:0]      */.ddr3_ba              ( ddr3_ba              ) ,
    /*output  wire            */.ddr3_cas_n           ( ddr3_cas_n           ) ,
    /*output  wire [0:0]      */.ddr3_ck_n            ( ddr3_ck_n            ) ,
    /*output  wire [0:0]      */.ddr3_ck_p            ( ddr3_ck_p            ) ,
    /*output  wire [0:0]      */.ddr3_cke             ( ddr3_cke             ) ,
    /*output  wire            */.ddr3_ras_n           ( ddr3_ras_n           ) ,
    /*output  wire            */.ddr3_reset_n         ( ddr3_reset_n         ) ,
    /*output  wire            */.ddr3_we_n            ( ddr3_we_n            ) ,
    /*inout   wire [31:0]     */.ddr3_dq              ( ddr3_dq              ) ,
    /*inout   wire [3:0]      */.ddr3_dqs_n           ( ddr3_dqs_n           ) ,
    /*inout   wire [3:0]      */.ddr3_dqs_p           ( ddr3_dqs_p           ) ,
    /*output  wire            */.init_calib_complete  ( init_calib_complete  ) ,
    /*output  wire [0:0]      */.ddr3_cs_n            ( ddr3_cs_n            ) ,
    /*output  wire [3:0]      */.ddr3_dm              ( ddr3_dm              ) ,
    /*output  wire [0:0]      */.ddr3_odt             ( ddr3_odt             ) ,
    /*//channel 0*/
    /*input   wire            */.ch0_write_clk        ( pixclk_out           ) ,
    /*input   wire            */.ch0_write_req        ( ch0_write_req        ) ,
    /*output  wire            */.ch0_write_req_ack    ( ch0_write_req_ack    ) ,
    /*output  wire            */.ch0_write_finish     () ,
    /*input   wire    [1:0]   */.ch0_write_addr_index ( ch0_write_addr_index ) ,
    /*input   wire            */.ch0_write_en         ( ch0_write_en         ) ,
    /*input   wire    [15:0]  */.ch0_write_data       ( ch0_write_data       ) ,
    /*input   wire            */.ch0_read_clk         ( rgmii_clk            ) ,
    /*input   wire            */.ch0_read_req         ( ch0_read_req         ) ,
    /*output  wire            */.ch0_read_req_ack     ( ch0_read_req_ack     ) ,
    /*output  wire            */.ch0_read_finish      () ,
    /*input   wire    [1:0]   */.ch0_read_addr_index  ( ch0_read_addr_index  ) ,
    /*input   wire            */.ch0_read_en          ( ch0_read_en          ) ,
    /*output  wire    [15:0]  */.ch0_read_data        ( ch0_read_data        ) ,
    /*//channel 1*/
    /*input   wire            */.ch1_write_clk        () ,
    /*input   wire            */.ch1_write_req        () ,
    /*output  wire            */.ch1_write_req_ack    () ,
    /*output  wire            */.ch1_write_finish     () ,
    /*input   wire    [1:0]   */.ch1_write_addr_index () ,
    /*input   wire            */.ch1_write_en         () ,
    /*input   wire    [15:0]  */.ch1_write_data       () ,
    /*input   wire            */.ch1_read_clk         () ,
    /*input   wire            */.ch1_read_req         () ,
    /*output  wire            */.ch1_read_req_ack     () ,
    /*output  wire            */.ch1_read_finish      () ,
    /*input   wire    [1:0]   */.ch1_read_addr_index  () ,
    /*input   wire            */.ch1_read_en          () ,
    /*output  wire    [15:0]  */.ch1_read_data        () ,
    /*//channel 2*/
    /*input   wire            */.ch2_write_clk        () ,
    /*input   wire            */.ch2_write_req        () ,
    /*output  wire            */.ch2_write_req_ack    () ,
    /*output  wire            */.ch2_write_finish     () ,
    /*input   wire    [1:0]   */.ch2_write_addr_index () ,
    /*input   wire            */.ch2_write_en         () ,
    /*input   wire    [15:0]  */.ch2_write_data       () ,
    /*input   wire            */.ch2_read_clk         () ,
    /*input   wire            */.ch2_read_req         () ,
    /*output  wire            */.ch2_read_req_ack     () ,
    /*output  wire            */.ch2_read_finish      () ,
    /*input   wire    [1:0]   */.ch2_read_addr_index  () ,
    /*input   wire            */.ch2_read_en          () ,
    /*output  wire    [15:0]  */.ch2_read_data        () ,
    /*//channel 3*/
    /*input   wire            */.ch3_write_clk        () ,
    /*input   wire            */.ch3_write_req        () ,
    /*output  wire            */.ch3_write_req_ack    () ,
    /*output  wire            */.ch3_write_finish     () ,
    /*input   wire    [1:0]   */.ch3_write_addr_index () ,
    /*input   wire            */.ch3_write_en         () ,
    /*input   wire    [15:0]  */.ch3_write_data       () ,
    /*input   wire            */.ch3_read_clk         () ,
    /*input   wire            */.ch3_read_req         () ,
    /*output  wire            */.ch3_read_req_ack     () ,
    /*output  wire            */.ch3_read_finish      () ,
    /*input   wire    [1:0]   */.ch3_read_addr_index  () ,
    /*input   wire            */.ch3_read_en          () ,
    /*output  wire    [15:0]  */.ch3_read_data        () 
);


endmodule