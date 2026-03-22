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
    //cam0
    input   wire            camera_clk_0        ,
    input   wire    [7:0]   camera_data_0       ,
    input   wire            camera_href_0       ,
    input   wire            camera_vsync_0      ,
    output  wire            SCL_0               ,
    output  wire            SDA_0               ,
    output  wire            cam_rst_0           ,
    output  reg             cam_led0            ,
    //hdmi_out 
    output	wire			tmds_clk_n          ,
    output	wire			tmds_clk_p          ,
    output	wire [2:0]      tmds_data_n         ,
    output	wire [2:0]      tmds_data_p         
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

(* MARK_DEBUG="true" *)wire   [X_BITS-1:0] x_act      ;
(* MARK_DEBUG="true" *)wire   [Y_BITS-1:0] y_act      ;

wire                vs_in_w      ;
wire                hs_in_w      ;
wire                de_in_w      ;

(* MARK_DEBUG="true" *)wire             bar_vs     ;
(* MARK_DEBUG="true" *)wire             bar_hs     ;
(* MARK_DEBUG="true" *)wire             bar_de     ;
wire    [7:0]    bar_r      ;
wire    [7:0]    bar_g      ;
wire    [7:0]    bar_b      ;

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
(* MARK_DEBUG="true" *)wire            cam_vsync_0;
(* MARK_DEBUG="true" *)wire            cam_href_0;
(* MARK_DEBUG="true" *)wire            cam_write_en_0;
(* MARK_DEBUG="true" *)wire    [15:0]  cam_data_0;

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

//camera clk signal
reg  [27:0]     cam_cnt_0;
reg             cam_cnt_flag_0;

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

always @(posedge camera_clk_0 or negedge rst_n) begin
    if (!rst_n)
        cam_led0 <= 1'b1;
    else if(cam_cnt_flag_0)
        cam_led0 <= ~cam_led0;
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

(* MARK_DEBUG="true" *)wire [15:0] bar_data;
assign bar_data = {bar_g,bar_b};

// assign ch0_write_data = bar_data;
// assign ch0_write_en   = bar_de;

video_scale_near #(
    .PIX_DATA_WIDTH ( 16 )
) video_scale_near_inst0 (
    /*input   wire                            */.vin_clk        ( pixclk_out   ) , //输入视频时钟
    /*input   wire                            */.rst_n          ( rst_n          ) ,
    /*input   wire                            */.frame_sync_n   ( ~bar_vs        ) , //输入视频帧同步，低有效
    /*input   wire    [PIX_DATA_WIDTH-1:0]    */.vin_dat        ( bar_data     ) , //输入视频数据
    /*input   wire                            */.vin_valid      ( bar_de       ) , //输入视频数据有效
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
) video_scale_near_inst1 (
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
    /*input   wire            */.clk             ( pixclk_out           ) ,
    /*input   wire            */.rst_n           ( rst_n                ) ,
    /*input   wire            */.cmos_vsync      ( bar_vs               ) ,
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

(* MARK_DEBUG="true" *)wire            hs_out_0;
(* MARK_DEBUG="true" *)wire            vs_out_0;
(* MARK_DEBUG="true" *)wire            de_out_0;

wire            hs_out_1;
wire            vs_out_1;
wire            de_out_1;

wire            hs_out_2;
wire            vs_out_2;
wire            de_out_2;

wire            hs_out_3;
wire            vs_out_3;
wire            de_out_3;


(* MARK_DEBUG="true" *)wire    [23:0]  vout_data;
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


assign hs_out    = hs_out_1  ;
assign vs_out    = vs_out_1  ;
assign de_out    = de_out_1  ;
assign vout_data = {vout_data_1[15:11],3'b0,vout_data_1[10:5],2'b0,vout_data_1[4:0],3'b0};

rgb2tmds rgb2tmds_inst (
    /*output  wire            */.tmds_clk_p  ( tmds_clk_p   ) ,
    /*output  wire            */.tmds_clk_n  ( tmds_clk_n   ) ,
    /*output  wire    [2:0]   */.tmds_data_p ( tmds_data_p  ) ,
    /*output  wire    [2:0]   */.tmds_data_n ( tmds_data_n  ) ,

    /*input   wire            */.rstn        ( rst_n        ) ,

    /*input   wire    [23:0]  */.vid_pdata   ( vout_data   ) ,
    /*input   wire            */.vid_pvde    ( de_out       ) ,
    /*input   wire            */.vid_phsync  ( hs_out       ) ,
    /*input   wire            */.vid_pvsync  ( vs_out       ) ,
 
    /*input   wire            */.pixelclk    ( pixclk_out   ) ,
    /*input   wire            */.serialclk   ( pixclkx5_out ) 
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
    .FRAME_SIZE0            ( 640 * 360 ) , // ch0 frame size
    .FRAME_SIZE1            ( 640 * 360 ) , // ch1 frame size 
    .FRAME_SIZE2            ( 640 * 360 ) , // ch2 frame size
    .FRAME_SIZE3            ( 640 * 360 ) , // ch3 frame size
    .FRAME_SIZE4            ( 640 * 360 )   // ch4 frame size
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
    /*input   wire            */.ch1_write_clk        ( pixclk_out           ) ,
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
    /*output  wire    [15:0]  */.ch1_read_data        ( ch1_read_data        ) 
);

endmodule
