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
    // input   wire            pixclk_in           ,                            
    // input   wire            vs_in               , 
    // input   wire            hs_in               , 
    // input   wire            de_in               ,
    // input   wire    [7:0]   r_in                , 
    // input   wire    [7:0]   g_in                , 
    // input   wire    [7:0]   b_in                , 
    //hdmi_out      
    // output  wire            pixclk_out          , 
    // output  wire            vs_out              , 
    // output  wire            hs_out              , 
    // output  wire            de_out              ,
    // output  wire    [7:0]   r_out               , 
    // output  wire    [7:0]   g_out               , 
    // output  wire    [7:0]   b_out               ,
    //hdmi_out 
    output	wire			tmds_clk_n             ,
    output	wire			tmds_clk_p             ,
    output	wire [2:0]      tmds_data_n            ,
    output	wire [2:0]      tmds_data_p            ,    
    //
    // output  wire            init_over           ,
    //
    // output  wire            hdmi_scl            ,
    // inout   wire            hdmi_sda            ,
    //cam0
    input   wire            camera_clk_0           ,
    input   wire    [7:0]   camera_data_0          ,
    input   wire            camera_href_0          ,
    input   wire            camera_vsync_0         ,
    output  wire            SCL_0                  ,
    output  wire            SDA_0                  ,
    output  wire            cam_rst_0              ,
    //cam1
    input   wire            camera_clk_1           ,
    input   wire   [7:0]    camera_data_1          ,
    input   wire            camera_href_1          ,
    input   wire            camera_vsync_1         ,
    output  wire            SCL_1                  ,
    output  wire            SDA_1                  ,
    output  wire            cam_rst_1              ,

    output  reg             cam_led0                ,
    output  reg             cam_led1                ,
    output  wire            cam_init_done        
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
// ms72xx_ctl ms72xx_ctl_inst(
//     /*input   wire    */.clk       ( cfg_clk   ), //10mhz
//     /*input   wire    */.rst_n     ( rst_n     ),
//     /*output  wire    */.init_over ( init_over ),
//     /*output  wire    */.iic_scl   ( hdmi_scl  ),
//     /*inout   wire    */.iic_sda   ( hdmi_sda  )
// );

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

wire                vs_out     ;
wire                hs_out     ;
wire                de_out     ;
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

    // /*output  reg                         */.vs_out  ( vs_out     ) , 
    // /*output  reg                         */.hs_out  ( hs_out     ) , 
    // /*output  reg                         */.de_out  ( de_out     ) ,
    // /*output  reg     [COCLOR_DEPP-1:0]   */.r_out   ( r_out      ) , 
    // /*output  reg     [COCLOR_DEPP-1:0]   */.g_out   ( g_out      ) , 
    // /*output  reg     [COCLOR_DEPP-1:0]   */.b_out   ( b_out      )
);

//===========================================================================
// camera
//===========================================================================
localparam  H_COMS_DISP = 12'd1280;
localparam  V_COMS_DISP = 12'd720;

localparam  TOTAL_H_PIXEL = H_COMS_DISP + 12'd1216;
localparam  TOTAL_V_PIXEL = V_COMS_DISP + 12'd504;

wire            cam_init_done_0;
wire            cam_init_done_1;

assign cam_init_done = cam_init_done_0 & cam_init_done_1;

wire            cam_vsync_0;
wire            cam_href_0;
wire            cam_write_en_0;
wire    [15:0]  cam_data_0;

wire            cam_vsync_1;
wire            cam_href_1;
wire            cam_write_en_1;
wire    [15:0]  cam_data_1;

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
    /*output  wire            */.init_done     ( cam_init_done_0     )  ,
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
    /*output  wire            */.init_done     ( cam_init_done_1     )  ,
    /*output  wire    [15:0]  */.wf_wr_data    ( cam_data_1          )  ,   //RGB565
    /*output  wire            */.wf_wr_en      ( cam_write_en_1      )  ,
    /*output  wire            */.vs            ( cam_vsync_1         )  ,
    /*output  wire            */.hs            ( cam_href_1          )  ,
    /*output  wire            */.sop           ()  ,
    /*output  wire            */.eop           ()  
);

// ov5640_dri ov5640_dri_inst(
//     /*input           */.clk              ( sys_clk_in          ) ,  //时钟
//     /*input           */.rst_n            ( rst_n               ) ,  //复位信号,低电平有效
//     //摄像头接口 
//     /*input           */.cam_pclk         ( camera_clk_0        ) ,  //cmos 数据像素时钟
//     /*input           */.cam_vsync        ( camera_vsync_0      ) ,  //cmos 场同步信号
//     /*input           */.cam_href         ( camera_href_0       ) ,  //cmos 行同步信号
//     /*input    [7:0]  */.cam_data         ( camera_data_0       ) ,  //cmos 数据  
//     /*output          */.cam_rst_n        ( cam_rst_0           ) ,  //cmos 复位信号，低电平有效
//     /*output          */.cam_pwdn         () ,  //cmos 电源休眠模式选择信号
//     /*output          */.cam_scl          ( SCL_0               ) ,  //cmos SCCB_SCL线
//     /*inout           */.cam_sda          ( SDA_0               ) ,  //cmos SCCB_SDA线
//     //摄像头分辨率配置接口     
//     /*input    [12:0] */.cmos_h_pixel     ( H_COMS_DISP         ) ,  //水平方向分辨率
//     /*input    [12:0] */.cmos_v_pixel     ( V_COMS_DISP         ) ,  //垂直方向分辨率
//     /*input    [12:0] */.total_h_pixel    ( TOTAL_H_PIXEL       ) ,  //水平总像素大小
//     /*input    [12:0] */.total_v_pixel    ( TOTAL_V_PIXEL       ) ,  //垂直总像素大小
//     /*input           */.capture_start    ( init_calib_complete & cam_init_done_0 ) ,  //图像采集开始信号
//     /*output          */.cam_init_done    ( cam_init_done_0     ) ,  //摄像头初始化完成
//     //用户接口
//     /*output          */.cmos_frame_vsync ( cmos_frame_vsync    ) ,  //帧有效信号    
//     /*output          */.cmos_frame_href  ( cmos_frame_href     ) ,  //行有效信号
//     /*output          */.cmos_frame_valid ( ch0_write_en        ) ,  //数据有效使能信号
//     /*output  [15:0]  */.cmos_frame_data  ( ch0_write_data      )    //有效数据  
// );

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
    /*input   wire    [15:0]                  */.vout_yres      ( 16'd720        )   //输出视频垂直分辨率
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
    /*input   wire    [15:0]                  */.vout_yres      ( 16'd720        )   //输出视频垂直分辨率
);

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

cmos_write_req_gen cmos_write_req_gen_inst0(
    /*input   wire            */.rst             ( ~rst_n               ) ,
    /*input   wire            */.pclk            ( camera_clk_0         ) ,
    /*input   wire            */.cmos_vsync      ( cam_vsync_0          ) ,
    /*output  reg             */.write_req       ( ch0_write_req        ) ,
    /*input   wire            */.write_req_ack   ( ch0_write_req_ack    ) ,
    /*output  reg     [1:0]   */.write_addr_index( ch0_write_addr_index ) ,
    /*output  reg     [1:0]   */.read_addr_index ( ch0_read_addr_index  ) 
);

cmos_write_req_gen cmos_write_req_gen_inst1(
    /*input   wire            */.rst             ( ~rst_n               ) ,
    /*input   wire            */.pclk            ( camera_clk_1         ) ,
    /*input   wire            */.cmos_vsync      ( cam_vsync_1          ) ,
    /*output  reg             */.write_req       ( ch1_write_req        ) ,
    /*input   wire            */.write_req_ack   ( ch1_write_req_ack    ) ,
    /*output  reg     [1:0]   */.write_addr_index( ch1_write_addr_index ) ,
    /*output  reg     [1:0]   */.read_addr_index ( ch1_read_addr_index  ) 
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
wire            ch0_read_en;
wire    [15:0]  ch0_read_data;

wire            ch1_read_req    ;
wire            ch1_read_req_ack;
wire            ch1_read_en;
wire    [15:0]  ch1_read_data;

wire            hs_out_0;
wire            vs_out_0;
wire            de_out_0;

wire    [15:0]  vout_data_0;
wire    [15:0]  vout_data_1;

video_rect_read_data video_rect_read_data_inst0(
    /*input   wire                        */.video_clk          ( pixclk_out       ) , // Video pixel clock
    /*input   wire                        */.rst                ( ~rst_n           ) ,
    /*input   wire    [11:0]              */.video_left_offset  ( 12'd0            ) ,
    /*input   wire    [11:0]              */.video_top_offset   ( 12'd0            ) ,
    /*input   wire    [11:0]              */.video_width        ( 12'd640          ) ,
    /*input   wire    [11:0]              */.video_height       ( 12'd720          ) ,
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

video_rect_read_data video_rect_read_data_inst(
    /*input   wire                        */.video_clk          ( pixclk_out       ) , // Video pixel clock
    /*input   wire                        */.rst                ( ~rst_n           ) ,
    /*input   wire    [11:0]              */.video_left_offset  ( 12'd640          ) ,
    /*input   wire    [11:0]              */.video_top_offset   ( 12'd0            ) ,
    /*input   wire    [11:0]              */.video_width        ( 12'd640          ) ,
    /*input   wire    [11:0]              */.video_height       ( 12'd720          ) ,
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
    /*output  wire                        */.hs                 ( hs_out           ) , // horizontal synchronization
    /*output  wire                        */.vs                 ( vs_out           ) , // vertical synchronization
    /*output  wire                        */.de                 ( de_out           ) , // video valid
    /*output  wire    [DATA_WIDTH - 1:0]  */.vout_data          ( vout_data_1      )   // video data
);

// assign r_out = {vout_data[15:11],3'b0};
// assign g_out = {vout_data[10:5] ,2'b0};
// assign b_out = {vout_data[4:0]  ,3'b0};

rgb2tmds rgb2tmds_inst(
    .tmds_clk_p           ( tmds_clk_p           ),
    .tmds_clk_n           ( tmds_clk_n           ),
    .tmds_data_p          ( tmds_data_p          ),
    .tmds_data_n          ( tmds_data_n          ),

    .rstn                 ( rst_n             ),

    .vid_pdata            ( {vout_data_1[15:11],3'b0,vout_data_1[10:5],2'b0,vout_data_1[4:0],3'b0}  ),
    .vid_pvde             ( de_out               ),
    .vid_phsync           ( hs_out               ),
    .vid_pvsync           ( vs_out               ),
    .pixelclk             ( pixclk_out              ),

    .serialclk            ( pixclkx5_out            )
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
    .H_PIXEL                ( 1280 ) , //horizontal pixel
    .V_PIXEL                ( 720  )   //vertical pixel
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
