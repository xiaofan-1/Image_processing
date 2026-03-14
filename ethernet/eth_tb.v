`timescale 1ns / 1ps

module eth_tb();

parameter	fpga_mac 	= 48'h11_22_33_44_55_66	;//源mac
parameter	fpga_ip  	= 32'hc0_a8_00_08		;//源ip--192.168.0.8
parameter	pc_mac   	= 48'hff_ff_ff_ff_ff_ff	;//目的mac，不知道pc的mac，以广播的形式发送
parameter	pc_ip    	= 32'hC0_A8_01_69		;//目的ip--192.168.1.105
parameter	source_port = 16'd1234				;//源端口
parameter	des_port    = 16'd5678			 	;//目的端口

parameter	FORMAT    =   8'h04     ;//图像格式 04:(RGB565)
parameter	H_PIXEL   =   16'd1280   ;//行像素个数：1280
parameter	V_PIXEL   =   16'd720   ;//场像素个数：720				

reg video_clk;
reg rgmii_clk;
reg           key_flag1       ;
reg rst_n;

always #6.5 video_clk = ~video_clk;
always #4   rgmii_clk = ~rgmii_clk;
always #2.5 clk_200M = ~clk_200M;  // 200MHz


initial begin
    video_clk = 0;
    rgmii_clk = 0;
    clk_200M = 0;
    rst_n = 1'b0;
    key_flag1 = 1'b1;
    #100;
    rst_n = 1'b1;
    #1000;
    key_flag1 = 1'b0;
    #1000;
    key_flag1 = 1'b1;
end

//------------------------------ethernet-----------------------------
//arp_ctrl
wire            arp_tx_en;
wire            arp_tx_op;
//arp
wire            arp_rx_op  ;
wire            arp_rx_done;
wire            arp_tx_valid;
wire    [7:0]   arp_tx_data ;
wire            arp_rx_valid;
wire    [7:0]   arp_rx_data ;
//udp
wire    [7:0]   udp_tx_data ;
wire            udp_tx_valid;
wire    [7:0]   udp_odata   ;
wire            udp_data_valid;
wire            udp_rx_valid;
wire            udp_rx_data ;
// wire    [7:0]   udp_idata  ;
// wire            udp_rx_en  ;
wire            udp_rx_done;
wire    [15:0]  udp_tx_data_num ;
wire            image_format_end;
wire            udp_tx_done     ;
wire            udp_data_req    ;
wire            udp_tx_en       ;//udp开始信号
//rgmii 
wire            mac_tx_clk  ;
wire            mac_tx_valid;
wire    [7:0]   mac_tx_data ;
// wire            mac_rx_clk  ;

wire            mac_rx_valid;
wire    [7:0]   mac_rx_data ;
//protocol
wire            hs_reg          ;
wire            vs_reg          ;
wire            de_reg          ;
wire  [23:0]  vout_data       ;
//

//
wire            udp_rx_en       ;
wire    [7:0]   udp_idata       ;
//

reg 			de_flag_de;
wire 			negedge_flag_de;
wire    		negedge_vs;
reg 	[10:0]	cnt_vs;
reg 			reg_vs;
wire 			reg_de;
wire	[7:0]	udp_cam_data;
wire			vs_vild;
wire			rf_rd_en;

reg                            hs;
reg                            vs;
reg 						   de;

reg                            hs_reg0;
reg                            vs_reg0;
reg 						   de_reg0;

reg 	[15:0]					udp_wr_data;

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


wire    [7:0]    bar_r      ;
wire    [7:0]    bar_g      ;
wire    [7:0]    bar_b      ;

assign vout_data = {bar_r,bar_g,bar_b};

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
    /*input   wire                    */.clk     ( video_clk ) , 
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
    /*input   wire                        */.pix_clk ( video_clk ) ,
    /*input   wire                        */.rst_n   ( rst_n      ) , 
    /*input   wire                        */.vs_in   ( vs_in_w    ) , 
    /*input   wire                        */.hs_in   ( hs_in_w    ) , 
    /*input   wire                        */.de_in   ( de_in_w    ) ,
    /*input   wire    [X_BITS-1:0]        */.x_act   ( x_act      ) ,
    /*input   wire    [Y_BITS-1:0]        */.y_act   ( y_act      ) ,
       
    /*output  reg                         */.vs_out  ( vs_reg     ) , 
    /*output  reg                         */.hs_out  ( hs_reg     ) , 
    /*output  reg                         */.de_out  ( de_reg     ) ,
    /*output  reg     [COCLOR_DEPP-1:0]   */.r_out   ( bar_r      ) , 
    /*output  reg     [COCLOR_DEPP-1:0]   */.g_out   ( bar_g      ) , 
    /*output  reg     [COCLOR_DEPP-1:0]   */.b_out   ( bar_b      )
);


cmos_write_req_gen cmos_write_req_gen_inst0(
    /*input   wire            */.clk             ( camera_clk_0         ) ,
    /*input   wire            */.rst_n           ( rst_n                ) ,
    /*input   wire            */.cmos_vsync      ( cam_vsync_0          ) ,
    /*output  reg             */.write_req       ( ch0_write_req        ) ,
    /*input   wire            */.write_req_ack   ( ch0_write_req_ack    ) ,
    /*output  reg     [1:0]   */.write_addr_index( ch0_write_addr_index ) ,
    /*output  reg     [1:0]   */.read_addr_index ( ch0_read_addr_index  ) 
);


//================rgb888转rgb565=====================
always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n) begin
        udp_wr_data <= 16'd0;
    end
    else
        udp_wr_data <= {vout_data[23:19], vout_data[15:10], vout_data[7:3]};
end
//
always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n) begin
        hs <= 1'b0;
		vs <= 1'b0;
		de <= 1'b0;
		
        hs_reg0 <= 1'b0;
		vs_reg0 <= 1'b0;
		de_reg0 <= 1'b0;
    end
    else begin
        hs_reg0 <= hs_reg;
		vs_reg0 <= vs_reg;
		de_reg0 <= de_reg;
		hs <= hs_reg0;
		vs <= vs_reg0;
		de <= de_reg0;
    end
end

always @(posedge video_clk or negedge rst_n) begin
    if(!rst_n)
		reg_vs <= 1'b0;
    else 
		reg_vs <= vs;
end

assign negedge_vs = (reg_vs && ~vs) ? 1'b1 : 1'b0;

always @(posedge video_clk or negedge rst_n) begin
    if(!rst_n)
		cnt_vs <= 10'b0;
	else if(cnt_vs == 10'd1)
		cnt_vs <= cnt_vs;
    else if(negedge_vs)
		cnt_vs <= cnt_vs + 10'd1;
end

assign reg_de = (cnt_vs == 10'd1) ? de : 1'b0;

always @(posedge video_clk or negedge rst_n) begin
    if(!rst_n)
      de_flag_de <= 1'b0;
    else 
      de_flag_de <= reg_de;
end

assign negedge_flag_de = (de_flag_de && ~reg_de) ? 1 : 0;

// eth_fifo eth_fifo_u(
//   /*input            */.rst			(~rst_n || negedge_vs)	,
//   /*input   [15:0]   */.di			(udp_wr_data)	,
//   /*input            */.clkr		(rgmii_clk)	,
//   /*input            */.re			(rf_rd_en)	,
//   /*input            */.clkw		(video_clk)	,
//   /*input            */.we			(reg_de)	,
//   /*output  [7:0]    */.dout		(udp_cam_data)	,
//   /*output           */.empty_flag	()	,
//   /*output           */.aempty		()	,
//   /*output           */.full_flag	()	,
//   /*output  [10:0]   */.rdusedw		()	,
//   /*output  [9:0]    */.wrusedw		()	
// );

wire [12:0] rd_data_count;
wire udp_tx_req;

assign udp_tx_req = (rd_data_count > 1280) ? 1'b1 : 1'b0;

eth_fifo eth_fifo_inst (
  .rst(~rst_n),                      // input wire rst
  .wr_clk(video_clk),                // input wire wr_clk
  .rd_clk(rgmii_clk),                // input wire rd_clk
  .din(udp_wr_data),                      // input wire [15 : 0] din
  .wr_en(de_reg0),                  // input wire wr_en
  .rd_en(rf_rd_en),                  // input wire rd_en
  .dout(udp_cam_data),                    // output wire [7 : 0] dout
  .full(),                    // output wire full
  .empty(),                  // output wire empty
  .rd_data_count(rd_data_count),  // output wire [12 : 0] rd_data_count
  .wr_data_count()  // output wire [11 : 0] wr_data_count
);

//----------------------------udp-------------------------------------
udp_top #(
	.fpga_mac 	 (fpga_mac 	 ),//源mac
	.fpga_ip  	 (fpga_ip  	 ),//源ip--192.168.0.8
	.source_port (source_port),//源端口
	.des_port    (des_port   ) //目的端口
)udp_top_u(
    /*input   wire            */.rst_n           (rst_n),
    //-------------tx---------------------  
    /*input   wire            */.udp_tx_en       (udp_tx_en),//udp开始信号
    /*input   wire    [7:0]   */.udp_odata       (udp_odata),//udp发送的数据
    /*input   wire    [47:0]  */.des_mac         (48'haa_bb_cc_dd_ee_ff),
    /*input   wire    [31:0]  */.des_ip          (32'hc0_a8_01_11),
    /*input   wire    [10:0]  */.udp_tx_data_num (udp_tx_data_num),//udp发送数据的个数
    /*output  wire            */.udp_data_valid  (udp_data_valid ),//udp数据有效信号
    /*output  wire            */.udp_tx_done     (udp_tx_done    ),//udp结束信号
    //rgmii                                 
    /*input   wire            */.udp_tx_clk      (rgmii_clk),
    /*output  reg     [7:0]   */.udp_tx_data     (udp_tx_data ),//udp数据包：ip首部、udp首部、udp数据
    /*output  reg             */.udp_tx_valid    (udp_tx_valid),//udp数据包有效信号
    //-------------rx---------------------  
    /*output  reg     [7:0]   */.udp_idata       (udp_idata  ),//udp接收的数据
    /*output  reg             */.udp_rx_en       (udp_rx_en  ),
    /*output  wire            */.udp_rx_done     (udp_rx_done),
    //rgmii                                 
    /*input   wire            */.udp_rx_clk      (rgmii_clk  ),
    /*input   wire            */.udp_rx_valid    (mac_rx_valid),
    /*input   wire    [7:0]   */.udp_rx_data     (mac_rx_data )
    );
//------------------------------协议控制--------------------------------
protocol_ctrl #(
	.FORMAT   (FORMAT ),//图像格式 04:(RGB565)
    .H_PIXEL  (H_PIXEL),//行像素个数：1280
    .V_PIXEL  (V_PIXEL)//场像素个数：720
)protocol_ctrl_u(
    /*input   wire            */.rst_n           ( rst_n           ) ,
    /*input   wire    [7:0]   */.cam_data        ( udp_cam_data    ) ,//摄像头数据
    /*input   wire            */.rf_rd_req       ( udp_tx_req      ) ,
    /*output  reg             */.rf_rd_en        ( rf_rd_en        ) ,//读fifo使能

    /*output  reg             */.read_req        ( read_req        ) , // Start reading a frame of data     
    /*input   wire            */.read_req_ack    ( read_req_ack    ) , // Read request response
    /*output  wire            */.read_en         ( read_en         ) , // Read data enable
    /*input   wire    [15:0]  */.read_data       ( read_data       ) , // Read data
    //arp                                      
    /*input   wire            */.arp_tx_valid    ( arp_tx_valid    ) ,
    /*input   wire            */.arp_tx_en       ( arp_tx_en       ) ,
    /*input   wire            */.arp_rx_op       ( 1'b0            ) ,
    /*input   wire            */.arp_rx_done     ( 1'b1            ) ,
    /*input   wire    [7:0]   */.arp_tx_data     ( arp_tx_data     ) ,
    //udp                                      
    /*input   wire    [7:0]   */.udp_tx_data     ( udp_tx_data     ) ,
    /*input   wire            */.udp_tx_valid    ( udp_tx_valid    ) ,
    /*input   wire            */.udp_tx_done     ( udp_tx_done     ) ,
	/*input   wire            */.udp_data_valid  ( udp_data_valid  ) ,//udp数据有效信号
    /*output  wire    [7:0]   */.udp_odata       ( udp_odata       ) ,//udp发送的数据
    /*output  wire            */.udp_tx_en       ( udp_tx_en       ) ,//以太网传输数据开始信号
    /*output  wire    [15:0]  */.udp_tx_data_num ( udp_tx_data_num ) ,
    //rgmii                                 
    /*input   wire            */.clk             ( rgmii_clk       ) ,
    /*output  wire            */.mac_tx_valid    ( mac_tx_valid    ) ,
    /*output  wire    [7:0]   */.mac_tx_data     ( mac_tx_data     ) 
    );

      
endmodule