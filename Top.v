`timescale 1ns / 1ps

module Top(
    input   wire            sys_clk             ,
    input   wire            sys_rst_n           ,
    
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
    //hdmi_in
    output  wire            rstn_out            ,
    input   wire            pixclk_in           ,                            
    input   wire            vs_in               , 
    input   wire            hs_in               , 
    input   wire            de_in               ,
    input   wire    [7:0]   r_in                , 
    input   wire    [7:0]   g_in                , 
    input   wire    [7:0]   b_in                , 
    //hdmi_out 
    output	wire			tmds_clk_n          ,
    output	wire			tmds_clk_p          ,
    output	wire [2:0]      tmds_data_n         ,
    output	wire [2:0]      tmds_data_p         ,    
    //
    output  wire            init_over           ,
    
    output  wire            hdmi_scl            ,
    inout   wire            hdmi_sda            ,
    //
    //key
    input   wire    [4:0]   key                 ,
    //uart
    output  wire            uart_tx             ,
    input   wire            uart_rx             ,
    //cam0
    input   wire            camera_clk_0        ,
    input   wire    [7:0]   camera_data_0       ,
    input   wire            camera_href_0       ,
    input   wire            camera_vsync_0      ,
    output  wire            SCL_0               ,
    output  wire            SDA_0               ,
    output  wire            cam_rst_0           ,
    //cam1
    input   wire            camera_clk_1        ,
    input   wire   [7:0]    camera_data_1       ,
    input   wire            camera_href_1       ,
    input   wire            camera_vsync_1      ,
    output  wire            SCL_1               ,
    output  wire            SDA_1               ,
    output  wire            cam_rst_1           ,
    //cam2
    input   wire            camera_clk_2        ,
    input   wire   [7:0]    camera_data_2       ,
    input   wire            camera_href_2       ,
    input   wire            camera_vsync_2      ,
    output  wire            SCL_2               ,
    output  wire            SDA_2               ,
    output  wire            cam_rst_2           ,

    output  reg             cam_led0            ,
    output  reg             cam_led1            ,
    //eth
    output 	reg   			led			        ,
    input	wire			rgmii_rxc	        ,
    input	wire			rgmii_rx_ctl        ,
    input	wire	[3:0]  	rgmii_rxd	        ,
                             
    output	wire			rgmii_txc	        ,
    output	wire			rgmii_tx_ctl        ,
    output	wire	[3:0] 	rgmii_txd        
);

//===========================================================================
// pll
//===========================================================================
wire    sys_clk_in;
wire    cfg_clk;
wire    rst_n;
wire    locked_0;
wire    locked_1;
wire    mig_clk;
wire    pixclk_out;
wire    pixclkx5_out;
wire    rgmii_clk;

IBUF #(
   .IBUF_LOW_PWR("TRUE"),  // Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
   .IOSTANDARD("DEFAULT")  // Specify the input I/O standard
) IBUF_inst (
   .O(sys_clk_in),     // Buffer output
   .I(sys_clk)      // Buffer input (connect directly to top-level port)
);

hdmi_clk hdmi_clk_inst (
    // Clock out ports
    .clk_out1(cfg_clk),     // output clk_out1 10MHZ
    .clk_out2(pixclk_out),     // output clk_out2 74.25MHz
    .clk_out3(pixclkx5_out),     // output clk_out2 74.25MHz
    // Status and control signals
    .resetn(sys_rst_n), // input resetn
    .locked(locked_0),       // output locked
   // Clock in ports
    .clk_in1(sys_clk_in));      // input clk_in1 27MHZ
    
ddr_clk ddr_clk_inst (
    // Clock out ports
    .clk_out1(mig_clk),     // output clk_out1 200MHz
    // Status and control signals
    .resetn(sys_rst_n), // input resetn
    .locked(locked_1),       // output locked 
   // Clock in ports
    .clk_in1(sys_clk_in));      // input clk_in1 27MHZ

assign rst_n = locked_0 & locked_1 & sys_rst_n;
//===========================================================================
// HDMI
//===========================================================================
ms72xx_ctl ms72xx_ctl_inst(
    /*input   wire    */.clk          ( cfg_clk   ), //10mhz
    /*input   wire    */.rst_n        ( rstn_out  ),
    /*output  wire    */.init_over_rx ( init_over ),
    /*output  wire    */.iic_scl      ( hdmi_scl  ),
    /*inout   wire    */.iic_sda      ( hdmi_sda  )
);

reg  [15:0] rstn_1ms;
always @(posedge cfg_clk or negedge sys_rst_n) begin
	if(!sys_rst_n)
		rstn_1ms <= 16'd0;
	else if(!locked_0)
	    rstn_1ms <= 16'd0;
	else begin
		if(rstn_1ms == 16'h2710)
		    rstn_1ms <= rstn_1ms;
		else
		    rstn_1ms <= rstn_1ms + 1'b1;
	end
end

assign rstn_out = (rstn_1ms == 16'h2710);

//===========================================================================
// key
//===========================================================================
wire [4:0] btn_flag;

btn_deb_fix#(
    .BTN_WIDTH ( 5'd5 ),
    .BTN_DELAY ( 20'h7_ffff )
) btn_deb_fix_inst(
    /*input   wire                    */.clk           ( pixclk_out     )  , //
    /*input   wire                    */.rst_n         ( rst_n       ) , //
    /*input   wire    [BTN_WIDTH-1:0] */.btn_in        ( key         ) ,
    /*output  reg     [BTN_WIDTH-1:0] */.btn_flag      ( btn_flag    ) , // 脉冲信号：按键按下瞬间产生一个时钟周期的高电平
    /*output  reg     [BTN_WIDTH-1:0] */.btn_deb_fix   () // 电平信号：消抖后的按键状态
);

//===========================================================================
// uart
//===========================================================================
wire [7:0]  diff_value;

wire [11:0] cur_frame_top   ;
wire [11:0] cur_frame_bottom;
wire [11:0] cur_frame_left  ;
wire [11:0] cur_frame_right ;

wire [11:0] cur_color_top   ;
wire [11:0] cur_color_bottom;
wire [11:0] cur_color_left  ;
wire [11:0] cur_color_right ;

uart_top uart_top_inst(
    //input ports
    /*input   wire            */.clk              ( pixclk_out       ) ,
    /*input   wire            */.rst_n            ( rst_n            ) ,
               
    /*input   wire            */.uart_rx          ( uart_rx          ) ,
    /*output  wire            */.uart_tx          ( uart_tx          ) ,
    /*output  reg     [7:0]   */.diff_value       ( diff_value       ) ,
    /*output  reg     [11:0]  */.cur_frame_top    ( cur_frame_top    ) ,
    /*output  reg     [11:0]  */.cur_frame_bottom ( cur_frame_bottom ) ,
    /*output  reg     [11:0]  */.cur_frame_left   ( cur_frame_left   ) ,
    /*output  reg     [11:0]  */.cur_frame_right  ( cur_frame_right  ) ,
    /*output  reg     [11:0]  */.cur_color_top    ( cur_color_top    ) ,
    /*output  reg     [11:0]  */.cur_color_bottom ( cur_color_bottom ) ,
    /*output  reg     [11:0]  */.cur_color_left   ( cur_color_left   ) ,
    /*output  reg     [11:0]  */.cur_color_right  ( cur_color_right  ) 
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

wire             bar_vs     ;
wire             bar_hs     ;
wire             bar_de     ;
wire    [7:0]    bar_r      ;
wire    [7:0]    bar_g      ;
wire    [7:0]    bar_b      ;

wire    [15:0]  rgb_data   ;
assign rgb_data = {bar_r[7:3],bar_g[7:2],bar_b[7:3]};

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
    /*input   wire                        */.rst_n   ( rst_n      ) , 
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

//===========================================================================
// camera
//===========================================================================
wire            cam_vsync_0;
wire            cam_href_0;
wire            cam_write_en_0;
wire    [15:0]  cam_data_0;

wire            cam_vsync_1;
wire            cam_href_1;
wire            cam_write_en_1;
wire    [15:0]  cam_data_1;

wire            cam_vsync_2;
wire            cam_href_2;
wire            cam_write_en_2;
wire    [15:0]  cam_data_2;

camera camera_inst0(
    /*input   wire            */.clk           ( sys_clk_in          )  ,
    /*input   wire            */.rst_n         ( rst_n               )  ,
    /*output  wire            */.SCL           ( SCL_0               )  ,  
    /*output  wire            */.SDA           ( SDA_0               )  ,  
    /*input   wire            */.camera_clk    ( camera_clk_0        )  ,
    /*input   wire    [7:0]   */.camera_data   ( camera_data_0       )  ,
    /*input   wire            */.camera_herf   ( camera_href_0       )  ,
    /*input   wire            */.camera_vsync  ( camera_vsync_0      )  ,
    /*input   wire            */.ddr_init      ( init_calib_complete )  ,
    /*output  wire            */.camera_rstn   ( cam_rst_0           )  ,
    /*output  wire            */.camera_pwnd   ()  ,
    /*output  wire            */.init_done     ()  ,
    /*output  wire    [15:0]  */.wf_wr_data    ( cam_data_0          )  ,   //RGB565
    /*output  wire            */.wf_wr_en      ( cam_write_en_0      )  ,
    /*output  wire            */.vs            ( cam_vsync_0         )  ,
    /*output  wire            */.hs            ( cam_href_0          )  ,
    /*output  wire            */.sop           ()  ,
    /*output  wire            */.eop           ()  
);

camera camera_inst1(
    /*input   wire            */.clk           ( sys_clk_in          )  ,
    /*input   wire            */.rst_n         ( rst_n               )  ,
    /*output  wire            */.SCL           ( SCL_1               )  ,  
    /*output  wire            */.SDA           ( SDA_1               )  ,  
    /*input   wire            */.camera_clk    ( camera_clk_1        )  ,
    /*input   wire    [7:0]   */.camera_data   ( camera_data_1       )  ,
    /*input   wire            */.camera_herf   ( camera_href_1       )  ,
    /*input   wire            */.camera_vsync  ( camera_vsync_1      )  ,
    /*input   wire            */.ddr_init      ( init_calib_complete )  ,
    /*output  wire            */.camera_rstn   ( cam_rst_1           )  ,
    /*output  wire            */.camera_pwnd   ()  ,
    /*output  wire            */.init_done     ()  ,
    /*output  wire    [15:0]  */.wf_wr_data    ( cam_data_1          )  ,   //RGB565
    /*output  wire            */.wf_wr_en      ( cam_write_en_1      )  ,
    /*output  wire            */.vs            ( cam_vsync_1         )  ,
    /*output  wire            */.hs            ( cam_href_1          )  ,
    /*output  wire            */.sop           ()  ,
    /*output  wire            */.eop           ()  
);

camera camera_inst2(
    /*input   wire            */.clk           ( sys_clk_in          )  ,
    /*input   wire            */.rst_n         ( rst_n               )  ,
    /*output  wire            */.SCL           ( SCL_2               )  ,  
    /*output  wire            */.SDA           ( SDA_2               )  ,  
    /*input   wire            */.camera_clk    ( camera_clk_2        )  ,
    /*input   wire    [7:0]   */.camera_data   ( camera_data_2       )  ,
    /*input   wire            */.camera_herf   ( camera_href_2       )  ,
    /*input   wire            */.camera_vsync  ( camera_vsync_2      )  ,
    /*input   wire            */.ddr_init      ( init_calib_complete )  ,
    /*output  wire            */.camera_rstn   ( cam_rst_2           )  ,
    /*output  wire            */.camera_pwnd   ()  ,
    /*output  wire            */.init_done     ()  ,
    /*output  wire    [15:0]  */.wf_wr_data    ( cam_data_2          )  ,   //RGB565
    /*output  wire            */.wf_wr_en      ( cam_write_en_2      )  ,
    /*output  wire            */.vs            ( cam_vsync_2         )  ,
    /*output  wire            */.hs            ( cam_href_2          )  ,
    /*output  wire            */.sop           ()  ,
    /*output  wire            */.eop           ()  
);

//camera clk signal
reg  [27:0]     cam_cnt_0;
reg             cam_cnt_flag_0;

reg  [27:0]     cam_cnt_1;
reg             cam_cnt_flag_1;

always @(posedge camera_clk_0 or negedge rst_n) begin
    if (!rst_n) begin
        cam_cnt_0 <= 28'd0;
        cam_cnt_flag_0 <= 1'b0;
    end
    else if(cam_cnt_0 == 28'd24_000_000) begin
        cam_cnt_0 <= 28'd0;
        cam_cnt_flag_0 <= 1'b1;
    end
    else begin
        cam_cnt_0 <= cam_cnt_0 + 28'd1;
        cam_cnt_flag_0 <= 1'b0;
    end
end

always @(posedge camera_clk_1 or negedge rst_n) begin
    if (!rst_n) begin
        cam_cnt_1 <= 28'd0;
        cam_cnt_flag_1 <= 1'b0;
    end
    else if(cam_cnt_1 == 28'd24_000_000) begin
        cam_cnt_1 <= 28'd0;
        cam_cnt_flag_1 <= 1'b1;
    end
    else begin
        cam_cnt_1 <= cam_cnt_1 + 28'd1;
        cam_cnt_flag_1 <= 1'b0;
    end
end

always @(posedge camera_clk_0 or negedge rst_n) begin
    if (!rst_n)
        cam_led0 <= 1'b1;
    else if(cam_cnt_flag_0)
        cam_led0 <= ~cam_led0;
end

always @(posedge camera_clk_1 or negedge rst_n) begin
    if (!rst_n)
        cam_led1 <= 1'b1;
    else if(cam_cnt_flag_1)
        cam_led1 <= ~cam_led1;
end

//===========================================================================
// video_scale_near
//===========================================================================
wire [15:0] ch0_write_data;
wire        ch0_write_en;

wire [15:0] ch1_write_data;
wire        ch1_write_en;

wire [15:0] ch2_write_data;
wire        ch2_write_en;

wire [15:0] ch3_write_data;
wire        ch3_write_en;

wire [15:0] ch4_write_data;
wire        ch4_write_en;

wire [15:0] ch5_write_data;
wire        ch5_write_en;

video_scale_near #(
    .PIX_DATA_WIDTH ( 16 )
) video_scale_near_inst0 (
    /*input   wire                            */.vin_clk        ( camera_clk_0   ) , //输入视频时钟
    /*input   wire                            */.rst_n          ( rst_n          ) ,
    /*input   wire                            */.frame_sync_n   ( ~cam_vsync_0   ) , //输入视频帧同步，低有效
    /*input   wire    [PIX_DATA_WIDTH-1:0]    */.vin_dat        ( cam_data_0     ) , //输入视频数据
    /*input   wire                            */.vin_valid      ( cam_write_en_0 ) , //输入视频数据有效
    /*output  wire                            */.vin_ready      () , //输入准备好
    /*output  reg     [PIX_DATA_WIDTH-1:0]    */.vout_dat       ( ch0_write_data ) , //输出视频数据
    /*output  reg                             */.vout_valid     ( ch0_write_en   ) , //输出视频数据有效
    /*input   wire                            */.vout_ready     ( 1'b1           ) , //输出准备好
    /*input   wire    [15:0]                  */.vin_xres       ( 16'd1280       ) , //输入视频水平分辨率
    /*input   wire    [15:0]                  */.vin_yres       ( 16'd720        ) , //输入视频垂直分辨率
    /*input   wire    [15:0]                  */.vout_xres      ( 16'd640        ) , //输出视频水平分辨率
    /*input   wire    [15:0]                  */.vout_yres      ( 16'd360        )   //输出视频垂直分辨率
);

video_scale_near #(
    .PIX_DATA_WIDTH ( 16 )
) video_scale_near_inst1 (
    /*input   wire                            */.vin_clk        ( camera_clk_1   ) , //输入视频时钟
    /*input   wire                            */.rst_n          ( rst_n          ) ,
    /*input   wire                            */.frame_sync_n   ( ~cam_vsync_1   ) , //输入视频帧同步，低有效
    /*input   wire    [PIX_DATA_WIDTH-1:0]    */.vin_dat        ( cam_data_1     ) , //输入视频数据
    /*input   wire                            */.vin_valid      ( cam_write_en_1 ) , //输入视频数据有效
    /*output  wire                            */.vin_ready      () , //输入准备好
    /*output  reg     [PIX_DATA_WIDTH-1:0]    */.vout_dat       ( ch1_write_data ) , //输出视频数据
    /*output  reg                             */.vout_valid     ( ch1_write_en   ) , //输出视频数据有效
    /*input   wire                            */.vout_ready     ( 1'b1           ) , //输出准备好
    /*input   wire    [15:0]                  */.vin_xres       ( 16'd1280       ) , //输入视频水平分辨率
    /*input   wire    [15:0]                  */.vin_yres       ( 16'd720        ) , //输入视频垂直分辨率
    /*input   wire    [15:0]                  */.vout_xres      ( 16'd640        ) , //输出视频水平分辨率
    /*input   wire    [15:0]                  */.vout_yres      ( 16'd360        )   //输出视频垂直分辨率
);

video_scale_near #(
    .PIX_DATA_WIDTH ( 16 )
) video_scale_near_inst2 (
    /*input   wire                            */.vin_clk        ( camera_clk_2   ) , //输入视频时钟
    /*input   wire                            */.rst_n          ( rst_n          ) ,
    /*input   wire                            */.frame_sync_n   ( ~cam_vsync_2   ) , //输入视频帧同步，低有效
    /*input   wire    [PIX_DATA_WIDTH-1:0]    */.vin_dat        ( cam_data_2     ) , //输入视频数据
    /*input   wire                            */.vin_valid      ( cam_write_en_2 ) , //输入视频数据有效
    /*output  wire                            */.vin_ready      () , //输入准备好
    /*output  reg     [PIX_DATA_WIDTH-1:0]    */.vout_dat       ( ch2_write_data ) , //输出视频数据
    /*output  reg                             */.vout_valid     ( ch2_write_en   ) , //输出视频数据有效
    /*input   wire                            */.vout_ready     ( 1'b1           ) , //输出准备好
    /*input   wire    [15:0]                  */.vin_xres       ( 16'd1280       ) , //输入视频水平分辨率
    /*input   wire    [15:0]                  */.vin_yres       ( 16'd720        ) , //输入视频垂直分辨率
    /*input   wire    [15:0]                  */.vout_xres      ( 16'd640        ) , //输出视频水平分辨率
    /*input   wire    [15:0]                  */.vout_yres      ( 16'd360        )   //输出视频垂直分辨率
);


wire [15:0] hdmi_in_data;
assign hdmi_in_data = {r_in[7:3], g_in[7:2], b_in[7:3]};

video_scale_near #(
    .PIX_DATA_WIDTH ( 16 )
) video_scale_near_inst3 (
    /*input   wire                            */.vin_clk        ( pixclk_in      ) , //输入视频时钟
    /*input   wire                            */.rst_n          ( rst_n          ) ,
    /*input   wire                            */.frame_sync_n   ( ~vs_in         ) , //输入视频帧同步，低有效
    /*input   wire    [PIX_DATA_WIDTH-1:0]    */.vin_dat        ( hdmi_in_data   ) , //输入视频数据
    /*input   wire                            */.vin_valid      ( de_in          ) , //输入视频数据有效
    /*output  wire                            */.vin_ready      () , //输入准备好
    /*output  reg     [PIX_DATA_WIDTH-1:0]    */.vout_dat       ( ch3_write_data ) , //输出视频数据
    /*output  reg                             */.vout_valid     ( ch3_write_en   ) , //输出视频数据有效
    /*input   wire                            */.vout_ready     ( 1'b1           ) , //输出准备好
    /*input   wire    [15:0]                  */.vin_xres       ( 16'd1280       ) , //输入视频水平分辨率
    /*input   wire    [15:0]                  */.vin_yres       ( 16'd720        ) , //输入视频垂直分辨率
    /*input   wire    [15:0]                  */.vout_xres      ( 16'd640        ) , //输出视频水平分辨率
    /*input   wire    [15:0]                  */.vout_yres      ( 16'd360        )   //输出视频垂直分辨率
);

// wire [15:0] bar_data;
// assign bar_data = {bar_r[7:3], bar_g[7:2], bar_b[7:3]};

// video_scale_near #(
//     .PIX_DATA_WIDTH ( 16 )
// ) video_scale_near_inst3 (
//     /*input   wire                            */.vin_clk        ( pixclk_out     ) , //输入视频时钟
//     /*input   wire                            */.rst_n          ( rst_n          ) ,
//     /*input   wire                            */.frame_sync_n   ( ~bar_vs        ) , //输入视频帧同步，低有效
//     /*input   wire    [PIX_DATA_WIDTH-1:0]    */.vin_dat        ( bar_data       ) , //输入视频数据
//     /*input   wire                            */.vin_valid      ( bar_de         ) , //输入视频数据有效
//     /*output  wire                            */.vin_ready      () , //输入准备好
//     /*output  reg     [PIX_DATA_WIDTH-1:0]    */.vout_dat       ( ch3_write_data ) , //输出视频数据
//     /*output  reg                             */.vout_valid     ( ch3_write_en   ) , //输出视频数据有效
//     /*input   wire                            */.vout_ready     ( 1'b1           ) , //输出准备好
//     /*input   wire    [15:0]                  */.vin_xres       ( 16'd1280       ) , //输入视频水平分辨率
//     /*input   wire    [15:0]                  */.vin_yres       ( 16'd720        ) , //输入视频垂直分辨率
//     /*input   wire    [15:0]                  */.vout_xres      ( 16'd640        ) , //输出视频水平分辨率
//     /*input   wire    [15:0]                  */.vout_yres      ( 16'd360        )   //输出视频垂直分辨率
// );


//===========================================================================
// cmos_write_req_gen
//===========================================================================
wire                ch0_write_req        ;
wire                ch0_write_req_ack    ;
wire    [1:0]       ch0_write_addr_index ;
wire    [1:0]       ch0_read_addr_index  ;

wire                ch1_write_req        ;
wire                ch1_write_req_ack    ;
wire    [1:0]       ch1_write_addr_index ;
wire    [1:0]       ch1_read_addr_index  ;

wire                ch2_write_req        ;
wire                ch2_write_req_ack    ;
wire    [1:0]       ch2_write_addr_index ;
wire    [1:0]       ch2_read_addr_index  ;

wire                ch3_write_req        ;
wire                ch3_write_req_ack    ;
wire    [1:0]       ch3_write_addr_index ;
wire    [1:0]       ch3_read_addr_index  ;

wire                ch4_write_req        ;
wire                ch4_write_req_ack    ;
wire    [1:0]       ch4_write_addr_index ;
wire    [1:0]       ch4_read_addr_index  ;

wire                ch5_write_req        ;
wire                ch5_write_req_ack    ;
wire    [1:0]       ch5_write_addr_index ;
wire    [1:0]       ch5_read_addr_index  ;

cmos_write_req_gen cmos_write_req_gen_inst0(
    /*input   wire            */.clk             ( camera_clk_0         ) ,
    /*input   wire            */.rst_n           ( rst_n                ) ,
    /*input   wire            */.cmos_vsync      ( cam_vsync_0          ) ,
    /*output  reg             */.write_req       ( ch0_write_req        ) ,
    /*input   wire            */.write_req_ack   ( ch0_write_req_ack    ) ,
    /*output  reg     [1:0]   */.write_addr_index( ch0_write_addr_index ) ,
    /*output  reg     [1:0]   */.read_addr_index ( ch0_read_addr_index  ) 
);

cmos_write_req_gen cmos_write_req_gen_inst1(
    /*input   wire            */.clk             ( camera_clk_1         ) ,
    /*input   wire            */.rst_n           ( rst_n                ) ,
    /*input   wire            */.cmos_vsync      ( cam_vsync_1          ) ,
    /*output  reg             */.write_req       ( ch1_write_req        ) ,
    /*input   wire            */.write_req_ack   ( ch1_write_req_ack    ) ,
    /*output  reg     [1:0]   */.write_addr_index( ch1_write_addr_index ) ,
    /*output  reg     [1:0]   */.read_addr_index ( ch1_read_addr_index  ) 
);

cmos_write_req_gen cmos_write_req_gen_inst2(
    /*input   wire            */.clk             ( camera_clk_1         ) ,
    /*input   wire            */.rst_n           ( rst_n                ) ,
    /*input   wire            */.cmos_vsync      ( cam_vsync_1          ) ,
    /*output  reg             */.write_req       ( ch2_write_req        ) ,
    /*input   wire            */.write_req_ack   ( ch2_write_req_ack    ) ,
    /*output  reg     [1:0]   */.write_addr_index( ch2_write_addr_index ) ,
    /*output  reg     [1:0]   */.read_addr_index ( ch2_read_addr_index  ) 
);

cmos_write_req_gen cmos_write_req_gen_inst3(
    /*input   wire            */.clk             ( pixclk_in            ) ,
    /*input   wire            */.rst_n           ( rst_n                ) ,
    /*input   wire            */.cmos_vsync      ( vs_in                ) ,
    /*output  reg             */.write_req       ( ch3_write_req        ) ,
    /*input   wire            */.write_req_ack   ( ch3_write_req_ack    ) ,
    /*output  reg     [1:0]   */.write_addr_index( ch3_write_addr_index ) ,
    /*output  reg     [1:0]   */.read_addr_index ( ch3_read_addr_index  ) 
);

//===========================================================================
// read_data
//===========================================================================
wire    rd_vs;
wire    rd_hs;
wire    rd_de;

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
) sync_vg_rd_inst (
    /*input   wire                    */.clk     ( pixclk_out ) , 
    /*input   wire                    */.rst_n   ( rst_n      ) ,
    /*output  reg                     */.vs_out  ( rd_vs      ) ,
    /*output  reg                     */.hs_out  ( rd_hs      ) ,
    /*output  reg                     */.de_out  ( rd_de      ) ,
    /*output  reg     [X_BITS-1:0]    */.x_act   () ,
    /*output  reg     [Y_BITS-1:0]    */.y_act   ()  
);

wire            ch0_read_req    ;
wire            ch0_read_req_ack;
wire            ch0_read_en     ;
wire    [15:0]  ch0_read_data   ;

wire            ch1_read_req    ;
wire            ch1_read_req_ack;
wire            ch1_read_en     ;
wire    [15:0]  ch1_read_data   ;

wire            ch2_read_req    ;
wire            ch2_read_req_ack;
wire            ch2_read_en     ;
wire    [15:0]  ch2_read_data   ;

wire            ch3_read_req    ;
wire            ch3_read_req_ack;
wire            ch3_read_en     ;
wire    [15:0]  ch3_read_data   ;

wire            ch4_read_req    ;
wire            ch4_read_req_ack;
wire            ch4_read_en     ;
wire    [15:0]  ch4_read_data   ;

wire            ch5_read_req    ;
wire            ch5_read_req_ack;
wire            ch5_read_en     ;
wire    [15:0]  ch5_read_data   ;

wire            hs_out;
wire            vs_out;
wire            de_out;

wire            hs_out_0;
wire            vs_out_0;
wire            de_out_0;

wire            hs_out_1;
wire            vs_out_1;
wire            de_out_1;

wire            hs_out_2;
wire            vs_out_2;
wire            de_out_2;

wire            hs_out_3;
wire            vs_out_3;
wire            de_out_3;

wire    [23:0]  vout_data;
wire    [15:0]  vout_data_0;
wire    [15:0]  vout_data_1;
wire    [15:0]  vout_data_2;
wire    [15:0]  vout_data_3;

video_rect_read_data video_rect_read_data_inst0 (
    /*input   wire                        */.video_clk          ( pixclk_out       ) , // Video pixel clock
    /*input   wire                        */.rst                ( ~rst_n           ) ,
    /*input   wire    [11:0]              */.video_left_offset  ( 12'd0            ) ,
    /*input   wire    [11:0]              */.video_top_offset   ( 12'd0            ) ,
    /*input   wire    [11:0]              */.video_width        ( 12'd640          ) ,
    /*input   wire    [11:0]              */.video_height       ( 12'd360          ) ,
    /*output  reg                         */.read_req           ( ch0_read_req     ) , // Start reading a frame of data     
    /*input   wire                        */.read_req_ack       ( ch0_read_req_ack ) , // Read request response
    /*output  wire                        */.read_en            ( ch0_read_en      ) , // Read data enable
    /*input   wire    [DATA_WIDTH - 1:0]  */.read_data          ( ch0_read_data    ) , // Read data
    /*input   wire                        */.timing_hs          ( rd_hs            ) ,
    /*input   wire                        */.timing_vs          ( rd_vs            ) ,
    /*input   wire                        */.timing_de          ( rd_de            ) ,
    /*input   wire    [DATA_WIDTH - 1:0]  */.timing_data        ( 16'd0            ) , 
    /*output  reg     [11:0]              */.x_cnt              () ,
    /*output  reg     [11:0]              */.y_cnt              () ,
    /*output  wire                        */.hs                 ( hs_out_0         ) , // horizontal synchronization
    /*output  wire                        */.vs                 ( vs_out_0         ) , // vertical synchronization
    /*output  wire                        */.de                 ( de_out_0         ) , // video valid
    /*output  wire    [DATA_WIDTH - 1:0]  */.vout_data          ( vout_data_0      )   // video data
);

video_rect_read_data video_rect_read_data_inst1 (
    /*input   wire                        */.video_clk          ( pixclk_out       ) , // Video pixel clock
    /*input   wire                        */.rst                ( ~rst_n           ) ,
    /*input   wire    [11:0]              */.video_left_offset  ( 12'd640          ) ,
    /*input   wire    [11:0]              */.video_top_offset   ( 12'd0            ) ,
    /*input   wire    [11:0]              */.video_width        ( 12'd640          ) ,
    /*input   wire    [11:0]              */.video_height       ( 12'd360          ) ,
    /*output  reg                         */.read_req           ( ch1_read_req     ) , // Start reading a frame of data     
    /*input   wire                        */.read_req_ack       ( ch1_read_req_ack ) , // Read request response
    /*output  wire                        */.read_en            ( ch1_read_en      ) , // Read data enable
    /*input   wire    [DATA_WIDTH - 1:0]  */.read_data          ( ch1_read_data    ) , // Read data
    /*input   wire                        */.timing_hs          ( hs_out_0         ) ,
    /*input   wire                        */.timing_vs          ( vs_out_0         ) ,
    /*input   wire                        */.timing_de          ( de_out_0         ) ,
    /*input   wire    [DATA_WIDTH - 1:0]  */.timing_data        ( vout_data_0      ) , 
    /*output  reg     [11:0]              */.x_cnt              () ,
    /*output  reg     [11:0]              */.y_cnt              () ,
    /*output  wire                        */.hs                 ( hs_out_1         ) , // horizontal synchronization
    /*output  wire                        */.vs                 ( vs_out_1         ) , // vertical synchronization
    /*output  wire                        */.de                 ( de_out_1         ) , // video valid
    /*output  wire    [DATA_WIDTH - 1:0]  */.vout_data          ( vout_data_1      )   // video data
);

video_rect_read_data video_rect_read_data_inst2 (
    /*input   wire                        */.video_clk          ( pixclk_out       ) , // Video pixel clock
    /*input   wire                        */.rst                ( ~rst_n           ) ,
    /*input   wire    [11:0]              */.video_left_offset  ( 12'd0            ) ,
    /*input   wire    [11:0]              */.video_top_offset   ( 12'd360          ) ,
    /*input   wire    [11:0]              */.video_width        ( 12'd640          ) ,
    /*input   wire    [11:0]              */.video_height       ( 12'd360          ) ,
    /*output  reg                         */.read_req           ( ch2_read_req     ) , // Start reading a frame of data     
    /*input   wire                        */.read_req_ack       ( ch2_read_req_ack ) , // Read request response
    /*output  wire                        */.read_en            ( ch2_read_en      ) , // Read data enable
    /*input   wire    [DATA_WIDTH - 1:0]  */.read_data          ( ch2_read_data    ) , // Read data
    /*input   wire                        */.timing_hs          ( hs_out_1         ) ,
    /*input   wire                        */.timing_vs          ( vs_out_1         ) ,
    /*input   wire                        */.timing_de          ( de_out_1         ) ,
    /*input   wire    [DATA_WIDTH - 1:0]  */.timing_data        ( vout_data_1      ) , 
    /*output  reg     [11:0]              */.x_cnt              () ,
    /*output  reg     [11:0]              */.y_cnt              () ,
    /*output  wire                        */.hs                 ( hs_out_2         ) , // horizontal synchronization
    /*output  wire                        */.vs                 ( vs_out_2         ) , // vertical synchronization
    /*output  wire                        */.de                 ( de_out_2         ) , // video valid
    /*output  wire    [DATA_WIDTH - 1:0]  */.vout_data          ( vout_data_2      )   // video data
);

video_rect_read_data video_rect_read_data_inst3 (
    /*input   wire                        */.video_clk          ( pixclk_out       ) , // Video pixel clock
    /*input   wire                        */.rst                ( ~rst_n           ) ,
    /*input   wire    [11:0]              */.video_left_offset  ( 12'd640          ) ,
    /*input   wire    [11:0]              */.video_top_offset   ( 12'd360          ) ,
    /*input   wire    [11:0]              */.video_width        ( 12'd640          ) ,
    /*input   wire    [11:0]              */.video_height       ( 12'd360          ) ,
    /*output  reg                         */.read_req           ( ch3_read_req     ) , // Start reading a frame of data     
    /*input   wire                        */.read_req_ack       ( ch3_read_req_ack ) , // Read request response
    /*output  wire                        */.read_en            ( ch3_read_en      ) , // Read data enable
    /*input   wire    [DATA_WIDTH - 1:0]  */.read_data          ( ch3_read_data    ) , // Read data
    /*input   wire                        */.timing_hs          ( hs_out_2         ) ,
    /*input   wire                        */.timing_vs          ( vs_out_2         ) ,
    /*input   wire                        */.timing_de          ( de_out_2         ) ,
    /*input   wire    [DATA_WIDTH - 1:0]  */.timing_data        ( vout_data_2      ) , 
    /*output  reg     [11:0]              */.x_cnt              () ,
    /*output  reg     [11:0]              */.y_cnt              () ,
    /*output  wire                        */.hs                 ( hs_out_3         ) , // horizontal synchronization
    /*output  wire                        */.vs                 ( vs_out_3         ) , // vertical synchronization
    /*output  wire                        */.de                 ( de_out_3         ) , // video valid
    /*output  wire    [DATA_WIDTH - 1:0]  */.vout_data          ( vout_data_3      )   // video data
);
//===========================================================================
// isp
//===========================================================================
wire [15:0] y_data;
wire        y_hs_out;
wire        y_vs_out;
wire        y_de_out;
wire [23:0] vout_data_3_ext;

assign vout_data_3_ext = {vout_data_3[15:11],3'b0,vout_data_3[10:5],2'b0,vout_data_3[4:0],3'b0};

image_top image_top_inst(
    /*input   wire            */.clk     ( pixclk_out      ) ,
    /*input   wire            */.rst_n   ( rst_n           ) ,

    /*input   wire            */.hsync_i ( hs_out_3        ) ,//行信号
    /*input   wire            */.vsync_i ( vs_out_3        ) ,//场信号
    /*input   wire            */.de_i    ( de_out_3        ) ,
    /*input   wire    [23:0]  */.data_i  ( vout_data_3_ext ) ,//

    /*output  wire            */.hsync_o ( y_hs_out        ) ,
    /*output  wire            */.vsync_o ( y_vs_out        ) ,
    /*output  wire            */.de_o    ( y_de_out        ) ,
    /*output  wire    [15:0]  */.data_o  ( y_data          )     
);

assign ch4_write_en = y_de_out;
assign ch4_write_data = y_data;

cmos_write_req_gen cmos_write_req_gen_inst_diff (
    /*input   wire            */.clk             ( pixclk_out           ) ,
    /*input   wire            */.rst_n           ( rst_n                ) ,
    /*input   wire            */.cmos_vsync      ( y_vs_out             ) ,
    /*output  reg             */.write_req       ( ch4_write_req        ) ,
    /*input   wire            */.write_req_ack   ( ch4_write_req_ack    ) ,
    /*output  reg     [1:0]   */.write_addr_index( ch4_write_addr_index ) ,
    /*output  reg     [1:0]   */.read_addr_index ( ch4_read_addr_index  ) 
);

//===========================================================================
// 帧差
//===========================================================================
wire       diff_hs_out;
wire       diff_vs_out;
wire       diff_de_out;
wire [7:0] diff_data;
wire [11:0] pixle_x;
wire [11:0] pixle_y;

diff_pic diff_pic_inst(
    /*input    wire              */.sys_clk      ( pixclk_out           ) ,
    /*input    wire              */.sys_rst_n    ( rst_n                ) ,

    /*output   reg               */.read_req     ( ch4_read_req         ) , // Start reading a frame of data     
    /*input    wire              */.read_req_ack ( ch4_read_req_ack     ) , // Read request response
    /*output   wire              */.read_en      ( ch4_read_en          ) , // Read data enable
    /*input    wire    [15:0]    */.read_data    ( ch4_read_data        ) , // Read data

    /*input    wire              */.hsync_i      ( y_hs_out             ) ,
	/*input    wire              */.vsync_i      ( y_vs_out             ) ,
	/*input    wire              */.de_i         ( ch4_write_en         ) ,

    /*output   reg    [11:0]     */.pixle_x      ( pixle_x              ) ,
    /*output   reg    [11:0]     */.pixle_y      ( pixle_y              ) ,

    /*input    wire    [7:0]     */.new_pic      ( ch4_write_data[15:8] ) ,
    /*input    wire    [7:0]     */.last_pic     () ,
    /*input    wire    [7:0]     */.DIFF_THR     ( diff_value           ) ,
    /*output   wire              */.hsync_o      ( diff_hs_out          ) ,
    /*output   wire              */.vsync_o      ( diff_vs_out          ) ,
	/*output   wire              */.de_o         ( diff_de_out          ) ,
 
    /*output   wire    [7:0]     */.diff_data    ( diff_data            ) 
);

//===========================================================================
// 帧差
//===========================================================================
wire [11:0] frame_x_min;
wire [11:0] frame_x_max;
wire [11:0] frame_y_min;
wire [11:0] frame_y_max;

wire [11:0] pixle_x_reg;
wire [11:0] pixle_y_reg;

wire        frame_hs_out;
wire        frame_vs_out;
wire        frame_de_out;
wire [23:0] frame_data_out;

image_frame image_frame_inst(
    /*input   wire        */.clk           ( pixclk_out           ) ,
    /*input   wire        */.rst_n         ( rst_n                ) ,
    //输入                             
    /*input   wire        */.hsync_i       ( diff_hs_out          ) ,//行信号
    /*input   wire        */.vsync_i       ( diff_vs_out          ) ,//场信号
    /*input   wire        */.de_i          ( diff_de_out          ) ,//图像有效信号
    /*input   wire [7:0]  */.data_i        ( diff_data            ) ,//处理后的图像
    /*input   wire [11:0] */.pixle_x       ( pixle_x              ) ,
    /*input   wire [11:0] */.pixle_y       ( pixle_y              ) ,
    /*input   wire [23:0] */.rgb_data      ( vout_data_3_ext      ) ,

    /*input   wire [11:0] */.frame_top     ( cur_frame_top        ) ,
    /*input   wire [11:0] */.frame_bottom  ( cur_frame_bottom     ) ,
    /*input   wire [11:0] */.frame_left    ( cur_frame_left       ) ,
    /*input   wire [11:0] */.frame_right   ( cur_frame_right      ) ,
    //输出                             
    /*output  reg  [11:0] */.x_min_r       ( frame_x_min          ) ,
    /*output  reg  [11:0] */.x_max_r       ( frame_x_max          ) ,
    /*output  reg  [11:0] */.y_min_r       ( frame_y_min          ) ,
    /*output  reg  [11:0] */.y_max_r       ( frame_y_max          ) ,
	/*output  reg  [11:0] */.pixle_x_reg   ( pixle_x_reg          ) ,
	/*output  reg  [11:0] */.pixle_y_reg   ( pixle_y_reg          ) ,
    /*output  wire        */.hsync_o       ( frame_hs_out         ) ,
    /*output  wire        */.vsync_o       ( frame_vs_out         ) ,
    /*output  wire        */.de_o          ( frame_de_out         ) ,
    /*output  reg  [23:0] */.data_o        ( frame_data_out       ) 
);

//===========================================================================
// 颜色
//===========================================================================
wire [23:0] color_data;
wire        color_hs;
wire        color_vs;
wire        color_de;

wire [11:0] x_min_r_color;
wire [11:0] x_max_r_color;
wire [11:0] y_min_r_color;
wire [11:0] y_max_r_color;

wire [11:0] pixle_x_color;
wire [11:0] pixle_y_color;

image_color image_color_inst(
    /*input	wire            */.clk	           ( pixclk_out       ) ,
    /*input	wire            */.rst_n           ( rst_n            ) ,
              
    /*input   wire            */.hsync_i       ( hs_out_3         ) ,//行信号
    /*input   wire            */.vsync_i       ( vs_out_3         ) ,//场信号
    /*input   wire            */.de_i          ( de_out_3         ) ,
    /*input   wire    [23:0]  */.data_i        ( vout_data_3_ext  ) ,//
                
    /*input   wire            */.key2_flag     ( btn_flag[1]      ) ,
    /*input   wire            */.key3_flag     ( btn_flag[2]      ) ,
    /*input   wire            */.key4_flag     ( btn_flag[3]      ) ,
        
    /*input   wire    [10:0]  */.pixel_x       ( pixle_x          ) ,
    /*input   wire    [10:0]  */.pixel_y       ( pixle_y          ) ,
    
    /*input   wire    [11:0]  */.frame_top     ( cur_color_top    ) ,
    /*input   wire    [11:0]  */.frame_bottom  ( cur_color_bottom ) ,
    /*input   wire    [11:0]  */.frame_left    ( cur_color_left   ) ,
    /*input   wire    [11:0]  */.frame_right   ( cur_color_right  ) ,

    /*input   wire    [11:0]  */.x_min_move    ( frame_x_min      ) ,
    /*input   wire    [11:0]  */.x_max_move    ( frame_x_max      ) ,
    /*input   wire    [11:0]  */.y_min_move    ( frame_y_min      ) ,
    /*input   wire    [11:0]  */.y_max_move    ( frame_y_max      ) ,

    /*output  reg     [11:0]  */.x_min_r       ( x_min_r_color    ) ,
    /*output  reg     [11:0]  */.x_max_r       ( x_max_r_color    ) ,
    /*output  reg     [11:0]  */.y_min_r       ( y_min_r_color    ) ,
    /*output  reg     [11:0]  */.y_max_r       ( y_max_r_color    ) ,
    
    /*output  wire    [11:0] */.pixle_x_reg    ( pixle_x_color    ) ,
    /*output  wire    [11:0] */.pixle_y_reg    ( pixle_y_color    ) ,
        
    /*output  wire            */.hsync_o       ( color_hs         ) ,
    /*output  wire            */.vsync_o       ( color_vs         ) ,
    /*output  wire            */.de_o          ( color_de         ) ,
    /*output  reg     [23:0]  */.data_o        ( color_data       ) 
);

// wire [15:0] video_data;
// wire [23:0] video_data;
// assign video_data = {color_data[15:11],3'b0,color_data[10:5],2'b0,color_data[4:0],3'b0};
// assign video_data = {color_data[23:19],color_data[15:10],color_data[7:3]};
// assign video_data = {3{diff_data}};

wire        osd_hs  ;
wire        osd_vs  ;
wire        osd_de  ;
wire [23:0] osd_data;

osd_draw osd_draw_isnt( 
    /*input   wire            */.clk         ( pixclk_out       ) ,
    /*input   wire            */.rst_n       ( rst_n            ) ,
    
    // 输入纯净的视频流（或者经过其他处理但不带框的视频流）
    /*input   wire            */.hsync_i     ( color_hs         ) ,
    /*input   wire            */.vsync_i     ( color_vs         ) ,
    /*input   wire            */.de_i        ( color_de         ) ,
    /*input   wire    [23:0]  */.rgb_data_i  ( color_data       ) ,
    /*input   wire    [11:0]  */.pixel_x     ( pixle_x_color    ) , // 当前像素X坐标
    /*input   wire    [11:0]  */.pixel_y     ( pixle_y_color    ) , // 当前像素Y坐标
    
    // 接收动态检测传来的坐标
    /*input   wire    [11:0]  */.frame_x_min ( frame_x_min ) ,
    /*input   wire    [11:0]  */.frame_x_max ( frame_x_max ) ,
    /*input   wire    [11:0]  */.frame_y_min ( frame_y_min ) ,
    /*input   wire    [11:0]  */.frame_y_max ( frame_y_max ) ,
    
    // 接收颜色识别传来的坐标
    /*input   wire    [11:0]  */.color_x_min ( x_min_r_color ) ,
    /*input   wire    [11:0]  */.color_x_max ( x_max_r_color ) ,
    /*input   wire    [11:0]  */.color_y_min ( y_min_r_color ) ,
    /*input   wire    [11:0]  */.color_y_max ( y_max_r_color ) ,
    
    // 输出最终带各种框的视频流
    /*output  wire            */.hsync_o     ( osd_hs   ) ,
    /*output  wire            */.vsync_o     ( osd_vs   ) ,
    /*output  wire            */.de_o        ( osd_de   ) ,
    /*output  reg     [23:0]  */.rgb_data_o  ( osd_data ) 
);

assign hs_out    =  osd_hs   ;
assign vs_out    =  osd_vs   ;
assign de_out    =  osd_de   ;
assign vout_data =  osd_data ;

rgb2tmds rgb2tmds_inst (
    /*output  wire            */.tmds_clk_p  ( tmds_clk_p   ) ,
    /*output  wire            */.tmds_clk_n  ( tmds_clk_n   ) ,
    /*output  wire    [2:0]   */.tmds_data_p ( tmds_data_p  ) ,
    /*output  wire    [2:0]   */.tmds_data_n ( tmds_data_n  ) ,

    /*input   wire            */.rstn        ( rst_n        ) ,

    /*input   wire    [23:0]  */.vid_pdata   ( vout_data    ) ,
    /*input   wire            */.vid_pvde    ( de_out       ) ,
    /*input   wire            */.vid_phsync  ( hs_out       ) ,
    /*input   wire            */.vid_pvsync  ( vs_out       ) ,
 
    /*input   wire            */.pixelclk    ( pixclk_out   ) ,
    /*input   wire            */.serialclk   ( pixclkx5_out ) 
);

assign ch5_write_en = de_out;
assign ch5_write_data = {vout_data[23:19],vout_data[15:10],vout_data[7:3]};

cmos_write_req_gen cmos_write_req_gen_inst_eth(
    /*input   wire            */.clk             ( pixclk_out           ) ,
    /*input   wire            */.rst_n           ( rst_n                ) ,
    /*input   wire            */.cmos_vsync      ( vs_out               ) ,
    /*output  reg             */.write_req       ( ch5_write_req        ) ,
    /*input   wire            */.write_req_ack   ( ch5_write_req_ack    ) ,
    /*output  reg     [1:0]   */.write_addr_index( ch5_write_addr_index ) ,
    /*output  reg     [1:0]   */.read_addr_index ( ch5_read_addr_index  ) 
);

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
    .FRAME_SIZE0            ( 640 * 360  ) , // ch0 frame size
    .FRAME_SIZE1            ( 640 * 360  ) , // ch1 frame size
    .FRAME_SIZE2            ( 640 * 360  ) , // ch2 frame size
    .FRAME_SIZE3            ( 640 * 360  ) , // ch3 frame size
    .FRAME_SIZE4            ( 1280 * 720 ) , // ch4 frame size
    .FRAME_SIZE5            ( 1280 * 720 )   // ch5 frame size
) Top_ddr3_inst (
    /*input   wire            */.clk_200M             ( mig_clk ) ,
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
    /*input   wire            */.ch0_write_clk        ( camera_clk_0         ) ,
    /*input   wire            */.ch0_write_req        ( ch0_write_req        ) ,
    /*output  wire            */.ch0_write_req_ack    ( ch0_write_req_ack    ) ,
    /*output  wire            */.ch0_write_finish     () ,
    /*input   wire    [1:0]   */.ch0_write_addr_index ( ch0_write_addr_index ) ,
    /*input   wire            */.ch0_write_en         ( ch0_write_en         ) ,
    /*input   wire    [15:0]  */.ch0_write_data       ( ch0_write_data       ) ,
    /*input   wire            */.ch0_read_clk         ( pixclk_out           ) ,
    /*input   wire            */.ch0_read_req         ( ch0_read_req         ) ,
    /*output  wire            */.ch0_read_req_ack     ( ch0_read_req_ack     ) ,
    /*output  wire            */.ch0_read_finish      () ,
    /*input   wire    [1:0]   */.ch0_read_addr_index  ( ch0_read_addr_index  ) ,
    /*input   wire            */.ch0_read_en          ( ch0_read_en          ) ,
    /*output  wire    [15:0]  */.ch0_read_data        ( ch0_read_data        ) ,
    /*//channel 1*/
    /*input   wire            */.ch1_write_clk        ( camera_clk_1         ) ,
    /*input   wire            */.ch1_write_req        ( ch1_write_req        ) ,
    /*output  wire            */.ch1_write_req_ack    ( ch1_write_req_ack    ) ,
    /*output  wire            */.ch1_write_finish     () ,
    /*input   wire    [1:0]   */.ch1_write_addr_index ( ch1_write_addr_index ) ,
    /*input   wire            */.ch1_write_en         ( ch1_write_en         ) ,
    /*input   wire    [15:0]  */.ch1_write_data       ( ch1_write_data       ) ,
    /*input   wire            */.ch1_read_clk         ( pixclk_out           ) ,
    /*input   wire            */.ch1_read_req         ( ch1_read_req         ) ,
    /*output  wire            */.ch1_read_req_ack     ( ch1_read_req_ack     ) ,
    /*output  wire            */.ch1_read_finish      () ,
    /*input   wire    [1:0]   */.ch1_read_addr_index  ( ch1_read_addr_index  ) ,
    /*input   wire            */.ch1_read_en          ( ch1_read_en          ) ,
    /*output  wire    [15:0]  */.ch1_read_data        ( ch1_read_data        ) ,
    /*//channel 2*/
    /*input   wire            */.ch2_write_clk        ( camera_clk_2         ) ,
    /*input   wire            */.ch2_write_req        ( ch2_write_req        ) ,
    /*output  wire            */.ch2_write_req_ack    ( ch2_write_req_ack    ) ,
    /*output  wire            */.ch2_write_finish     () ,
    /*input   wire    [1:0]   */.ch2_write_addr_index ( ch2_write_addr_index ) ,
    /*input   wire            */.ch2_write_en         ( ch2_write_en         ) ,
    /*input   wire    [15:0]  */.ch2_write_data       ( ch2_write_data       ) ,
    /*input   wire            */.ch2_read_clk         ( pixclk_out           ) ,
    /*input   wire            */.ch2_read_req         ( ch2_read_req         ) ,
    /*output  wire            */.ch2_read_req_ack     ( ch2_read_req_ack     ) ,
    /*output  wire            */.ch2_read_finish      () ,
    /*input   wire    [1:0]   */.ch2_read_addr_index  ( ch2_read_addr_index  ) ,
    /*input   wire            */.ch2_read_en          ( ch2_read_en          ) ,
    /*output  wire    [15:0]  */.ch2_read_data        ( ch2_read_data        ) ,
    /*//channel 3*/
    /*input   wire            */.ch3_write_clk        ( pixclk_in            ) ,
    /*input   wire            */.ch3_write_req        ( ch3_write_req        ) ,
    /*output  wire            */.ch3_write_req_ack    ( ch3_write_req_ack    ) ,
    /*output  wire            */.ch3_write_finish     () ,
    /*input   wire    [1:0]   */.ch3_write_addr_index ( ch3_write_addr_index ) ,
    /*input   wire            */.ch3_write_en         ( ch3_write_en         ) ,
    /*input   wire    [15:0]  */.ch3_write_data       ( ch3_write_data       ) ,
    /*input   wire            */.ch3_read_clk         ( pixclk_out           ) ,
    /*input   wire            */.ch3_read_req         ( ch3_read_req         ) ,
    /*output  wire            */.ch3_read_req_ack     ( ch3_read_req_ack     ) ,
    /*output  wire            */.ch3_read_finish      () ,
    /*input   wire    [1:0]   */.ch3_read_addr_index  ( ch3_read_addr_index  ) ,
    /*input   wire            */.ch3_read_en          ( ch3_read_en          ) ,
    /*output  wire    [15:0]  */.ch3_read_data        ( ch3_read_data        ) ,
    /*//channel 4*/
    /*input   wire            */.ch4_write_clk        ( pixclk_out           ) ,
    /*input   wire            */.ch4_write_req        ( ch4_write_req        ) ,
    /*output  wire            */.ch4_write_req_ack    ( ch4_write_req_ack    ) ,
    /*output  wire            */.ch4_write_finish     () ,
    /*input   wire    [1:0]   */.ch4_write_addr_index ( ch4_write_addr_index ) ,
    /*input   wire            */.ch4_write_en         ( ch4_write_en         ) ,
    /*input   wire    [15:0]  */.ch4_write_data       ( ch4_write_data       ) ,
    /*input   wire            */.ch4_read_clk         ( pixclk_out           ) ,
    /*input   wire            */.ch4_read_req         ( ch4_read_req         ) ,
    /*output  wire            */.ch4_read_req_ack     ( ch4_read_req_ack     ) ,
    /*output  wire            */.ch4_read_finish      () ,
    /*input   wire    [1:0]   */.ch4_read_addr_index  ( ch4_read_addr_index  ) ,
    /*input   wire            */.ch4_read_en          ( ch4_read_en          ) ,
    /*output  wire    [15:0]  */.ch4_read_data        ( ch4_read_data        ) ,
    /*//channel 5*/
    /*input   wire            */.ch5_write_clk        ( pixclk_out           ) ,
    /*input   wire            */.ch5_write_req        ( ch5_write_req        ) ,
    /*output  wire            */.ch5_write_req_ack    ( ch5_write_req_ack    ) ,
    /*output  wire            */.ch5_write_finish     () ,
    /*input   wire    [1:0]   */.ch5_write_addr_index ( ch5_write_addr_index ) ,
    /*input   wire            */.ch5_write_en         ( ch5_write_en         ) ,
    /*input   wire    [15:0]  */.ch5_write_data       ( ch5_write_data       ) ,
    /*input   wire            */.ch5_read_clk         ( rgmii_clk            ) ,
    /*input   wire            */.ch5_read_req         ( ch5_read_req         ) ,
    /*output  wire            */.ch5_read_req_ack     ( ch5_read_req_ack     ) ,
    /*output  wire            */.ch5_read_finish      () ,
    /*input   wire    [1:0]   */.ch5_read_addr_index  ( ch5_read_addr_index  ) ,
    /*input   wire            */.ch5_read_en          ( ch5_read_en          ) ,
    /*output  wire    [15:0]  */.ch5_read_data        ( ch5_read_data        ) 
);

reg [7:0] dly_cnt;
reg       idelay_rst;

always @(posedge mig_clk or negedge rst_n) begin
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
    .REFCLK(mig_clk),
    .RST(idelay_rst) // 使用延时后的复位
);

ethernet_top ethernet_top_inst(
    /*input   wire            */.clk           ( sys_clk_in       ) ,
    /*input   wire            */.video_clk     ( pixclk_out       ) ,
    /*input   wire            */.rst_n         ( rst_n            ) ,
    /*output  wire            */.read_req      ( ch5_read_req     ) ,
    /*input   wire            */.read_req_ack  ( ch5_read_req_ack ) ,
    /*output  wire            */.read_en       ( ch5_read_en      ) ,
    /*input   wire    [15:0]  */.read_data     ( ch5_read_data    ) ,

    /*input   wire            */.key_flag1     ( btn_flag[4]      ) ,

    /*output  wire            */.udp_rx_en     () ,
    /*output  wire    [7:0]   */.udp_idata     () ,
    //ethernet
    /*output  wire            */.rgmii_clk     ( rgmii_clk        ) ,
    /*input   wire            */.eth_rx_clk    ( rgmii_rxc        ) ,//PHY芯片
    /*input   wire            */.eth_rx_valid  ( rgmii_rx_ctl     ) ,
    /*input   wire    [3:0]   */.eth_rx_data   ( rgmii_rxd        ) ,
    /*output  wire            */.eth_tx_clk    ( rgmii_txc        ) ,
    /*output  wire            */.eth_tx_valid  ( rgmii_tx_ctl     ) ,
    /*output  wire    [3:0]   */.eth_tx_data   ( rgmii_txd        )      
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

endmodule
