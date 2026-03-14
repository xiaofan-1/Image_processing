`timescale 1ns / 1ps

module udp_top #(
	parameter	fpga_mac 	= 48'h11_22_33_44_55_66	,//源mac
	parameter	fpga_ip  	= 32'hc0_a8_00_08		,//源ip--192.168.0.8
	parameter	source_port = 16'd1234				,//源端口
	parameter	des_port    = 16'd5678			 	 //目的端口
)(
    input   wire            rst_n           ,
    //-------------tx---------------------
    input   wire            udp_tx_en       ,//udp开始信号
    input   wire    [7:0]   udp_odata       ,//udp发送的数据
    input   wire    [47:0]  des_mac         ,
    input   wire    [31:0]  des_ip          ,
    input   wire    [15:0]  udp_tx_data_num ,
    output  wire            udp_data_valid  ,//udp数据有效信号
    output  wire            udp_tx_done     ,//udp结束信号
    //rgmii
    input   wire            udp_tx_clk      ,
    output  wire    [7:0]   udp_tx_data     ,//udp数据包：ip首部、udp首部、udp数据
    output  wire            udp_tx_valid    ,//udp数据包有效信号
    //-------------rx---------------------
    output  wire    [7:0]   udp_idata       ,//udp接收的数据
    output  wire            udp_rx_en       ,
    output  wire            udp_rx_done     ,
    //rgmii
    input   wire            udp_rx_clk      ,
    input   wire            udp_rx_valid    ,
    input   wire    [7:0]   udp_rx_data     
    );

wire    [31:0]  crc_data        ;           
wire            crc_en          ;//CRC校验开始信号
wire            crc_done        ;//CRC校验结束信号


udp_tx #(
	.fpga_mac 	 (fpga_mac 	 ),//源mac
	.fpga_ip  	 (fpga_ip  	 ),//源ip--192.168.0.8
	.source_port (source_port),//源端口
	.des_port    (des_port   ) //目的端口
)udp_tx_u(
    /*input   wire            */.clk            (udp_tx_clk    ) ,
    /*input   wire            */.rst_n          (rst_n         ) ,
    /*input   wire    [15:0]  */.udp_tx_data_num(udp_tx_data_num) ,
    /*input   wire            */.udp_tx_en      (udp_tx_en     ) ,//udp开始信号
    /*input   wire    [7:0]   */.udp_odata      (udp_odata     ) ,//udp发送的数据
    /*input   wire    [47:0]  */.des_mac        (des_mac       ) ,
    /*input   wire    [31:0]  */.des_ip         (des_ip        ) ,
                                         
    /*output  reg     [7:0]   */.udp_tx_data    (udp_tx_data   ) ,//udp数据包：ip首部、udp首部、udp数据
    /*output  reg             */.udp_tx_valid   (udp_tx_valid  ) ,//udp数据包有效信号
    /*output  wire            */.udp_tx_done    (udp_tx_done   ) ,//udp结束信号
    /*output  wire            */.udp_data_valid (udp_data_valid) ,//udp数据有效信号
    //crc校验                             
    /*input   wire    [31:0]  */.crc_data       (crc_data      ) ,
    /*output  wire            */.crc_en         (crc_en        ) ,//CRC校验开始信号
    /*output  wire            */.crc_done       (crc_done      )  //CRC校验结束信号
    );

udp_rx #(
	.fpga_mac (fpga_mac),//源mac
	.fpga_ip  (fpga_ip ) //源ip--192.168.0.8
)udp_rx_u(
    /*input   wire            */.clk           (udp_rx_clk  ) ,
    /*input   wire            */.rst_n         (rst_n       ) ,
    /*input   wire            */.udp_rx_valid  (udp_rx_valid) ,
    /*input   wire    [7:0]   */.udp_rx_data   (udp_rx_data ) ,
    /*output  reg     [7:0]   */.udp_idata     (udp_idata   ) ,//udp接收的数据
    /*output  reg             */.udp_rx_en     (udp_rx_en   ) ,
    /*output  wire            */.udp_rx_done   (udp_rx_done )
    );

crc32_data crc32_data_u(
    /*input                 */.clk      (udp_tx_clk),  //时钟信号
    /*input                 */.rst_n    (rst_n),  //复位信号，低电平有效
    /*input         [7:0]   */.data     (udp_tx_data),  //输入待校验8位数据
    /*input                 */.crc_en   (crc_en  ),  //crc使能，开始校验标志
    /*input                 */.crc_clr  (crc_done),  //crc数据复位信号            
    /*output   reg  [31:0]  */.crc_data (crc_data),  //CRC校验数据
    /*output        [31:0]  */.crc_next ()   //CRC下次校验完成数据
    );

endmodule
