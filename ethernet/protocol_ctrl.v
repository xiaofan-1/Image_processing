`timescale 1ns / 1ps

module protocol_ctrl#(
	parameter	FORMAT   =   8'h04     ,//图像格式 04:(RGB565) 05:(RGB888)
    parameter	H_PIXEL  =   16'd1280  ,//行像素个数：1280
    parameter	V_PIXEL  =   16'd720    //场像素个数：720
)(
    input   wire            rst_n           ,
    output  wire            read_req        , // Start reading a frame of data     
    input   wire            read_req_ack    , // Read request response
    output  wire            read_en         , // Read data enable
    input   wire    [15:0]  read_data       , // Read data
    //arp
    input   wire            arp_tx_valid    ,
    input   wire            arp_tx_en       ,
    input   wire            arp_rx_op       ,
    input   wire            arp_rx_done     ,
    input   wire    [7:0]   arp_tx_data     ,
    //udp
    input   wire    [7:0]   udp_tx_data     ,
    input   wire            udp_tx_valid    ,
    input   wire            udp_tx_done     ,
	input   wire            udp_data_valid  ,//udp数据有效信号
    output  wire    [7:0]   udp_odata       ,//udp发送的数据
    output  wire            udp_tx_en       ,//以太网传输数据开始信号
    output  wire    [15:0]  udp_tx_data_num ,
    //rgmii
    input   wire            clk             ,
    output  wire            mac_tx_valid    ,
    output  wire    [7:0]   mac_tx_data     
    );
    
reg flag; //0:arp ,1:udp
assign mac_tx_valid = (flag) ? udp_tx_valid:arp_tx_valid;
assign mac_tx_data  = (flag) ? udp_tx_data :arp_tx_data ;

wire            udp_tx_data_start;
wire    [15:0]  image_data_num;
wire    [7:0]   image_data;

assign udp_tx_en = udp_tx_data_start;
assign udp_tx_data_num = image_data_num;
assign udp_odata = image_data;

always @(posedge clk) begin
    if(!rst_n)
        flag <= 0;
    else if(arp_tx_en)//arp工作
        flag <= 0;
    else if(arp_rx_op == 0 && arp_rx_done)//arp接收应答包，并工作完成
        flag <= 1;
    else
        flag <= flag;
end

image_data #(
    .H_PIXEL (H_PIXEL),//分辨率为1280*720
    .V_PIXEL (V_PIXEL) //一个udp包传输1280字节，需要传输1440次
)image_data_u(
    /*input   wire            */.clk               ( clk               )  ,
    /*input   wire            */.rst_n             ( rst_n             )  ,
    /*input   wire            */.udp_data_start    ( flag              )  ,//开始执行本模块信号
    /*input   wire            */.udp_tx_done       ( udp_tx_done       )  ,//以太网传输完一个包结束信号
	/*input   wire            */.udp_data_valid    ( udp_data_valid    )  ,//udp数据有效信号
    /*output  reg             */.read_req          ( read_req          ) , // Start reading a frame of data     
    /*input   wire            */.read_req_ack      ( read_req_ack      ) , // Read request response
    /*output  wire            */.read_en           ( read_en           ) , // Read data enable
    /*input   wire    [15:0]  */.read_data         ( read_data         ) , // Read data
    /*output  reg     [7:0]   */.image_data_out    ( image_data        )  ,//封装好的图像数据
    /*output  reg             */.udp_tx_data_start ( udp_tx_data_start )  ,//以太网开始传输信号
    /*output  reg     [15:0]  */.image_data_num    ( image_data_num    )   //以太网传输数据个数
    );

endmodule
