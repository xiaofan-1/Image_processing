`timescale 1ns / 1ps

module arp_top #(
	parameter	fpga_mac = 48'h11_22_33_44_55_66,//源mac
	parameter	fpga_ip  = 32'hc0_a8_00_08		,//源ip--192.168.0.8
	parameter	pc_mac   = 48'hff_ff_ff_ff_ff_ff,//目的mac，不知道pc的mac，以广播的形式发送
	parameter	pc_ip    = 32'hc0_a8_00_02		 //目的ip--192.168.0.2
)(
    input   wire            rst_n           ,
    //tx
    input   wire            arp_tx_clk      ,
    input   wire            arp_tx_en       ,
    input   wire            arp_tx_op       ,
    output  wire    [7:0]   arp_tx_data     ,
    output  wire            arp_tx_valid    ,
    //rx
    input   wire            arp_rx_clk      ,
    input   wire            arp_rx_valid    ,
    input   wire    [7:0]   arp_rx_data     ,
    output  wire    [47:0]  des_mac         ,
    output  wire    [31:0]  des_ip          ,
    output  wire            arp_rx_op       ,
    output  wire            arp_rx_done      
    );
    
wire    arp_tx_done;
wire    crc_en  ;
wire    crc_done;

wire    [31:0]  crc_data;
wire    [31:0]  crc_next;

arp_tx #(
		.fpga_mac (fpga_mac),//源mac
		.fpga_ip  (fpga_ip ),//源ip--192.168.0.8
		.pc_mac   (pc_mac  ),//目的mac，不知道pc的mac，以广播的形式发送
		.pc_ip    (pc_ip   ) //目的ip--192.168.0.2
)arp_tx_u(
    /*input   wire            */.clk           (arp_tx_clk)  ,
    /*input   wire            */.rst_n         (rst_n     )  ,
    /*input   wire            */.arp_tx_en     (arp_tx_en )  ,//arp开始发送使能
    /*input   wire            */.arp_tx_op     (arp_tx_op )  ,//arp发送数据包的类型，请求包：1，应答包：0
    //当arp接收到请求包，发送应答包时：                     
    /*input   wire    [47:0]  */.des_mac       (fpga_mac)  ,//目的mac ：源mac接收到请求包，发送应答包（目的mac）到pc
    /*input   wire    [31:0]  */.des_ip        (fpga_ip )  ,//目的ip
                                            
    /*output  reg     [7:0]   */.arp_tx_data   (arp_tx_data )  ,
    /*output  reg             */.arp_tx_valid  (arp_tx_valid)  ,
    /*output  wire            */.arp_tx_done   (arp_tx_done )  ,
    //crc校验                                   
    /*input   wire    [31:0]  */.crc_data      (crc_data)  ,
    /*output  wire            */.crc_en        (crc_en  )  ,//CRC校验开始信号
    /*output  wire            */.crc_done      (crc_done)   //CRC校验结束信号
    );
    
arp_rx #(
		.fpga_mac (fpga_mac),//源mac
		.fpga_ip  (fpga_ip ) //源ip--192.168.0.8
)arp_rx_u(
    /*input   wire            */.clk           (arp_rx_clk   )  ,
    /*input   wire            */.rst_n         (rst_n        )  ,
    /*input   wire            */.arp_rx_valid  (arp_rx_valid )  ,
    /*input   wire    [7:0]   */.arp_rx_data   (arp_rx_data  )  ,
    /*output  reg     [47:0]  */.pc_mac        (des_mac)  ,
    /*output  reg     [31:0]  */.pc_ip         (des_ip )  ,
    /*output  wire            */.arp_rx_op     (arp_rx_op  )  ,
    /*output  wire            */.arp_rx_done   (arp_rx_done)
    );
    
crc32_data crc32_data_u(
    /*input                 */.clk      (arp_tx_clk),  //时钟信号
    /*input                 */.rst_n    (rst_n),  //复位信号，低电平有效
    /*input         [7:0]   */.data     (arp_tx_data),  //输入待校验8位数据
    /*input                 */.crc_en   (crc_en  ),  //crc使能，开始校验标志
    /*input                 */.crc_clr  (crc_done),  //crc数据复位信号            
    /*output   reg  [31:0]  */.crc_data (crc_data),  //CRC校验数据
    /*output        [31:0]  */.crc_next ()   //CRC下次校验完成数据
    );
endmodule