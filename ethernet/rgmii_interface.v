`timescale 1ns / 1ps

module rgmii_interface(
    input   wire            rst                 ,
    output  wire            rgmii_clk           ,

    input   wire            mac_tx_data_valid   ,
    input   wire    [7:0]   mac_tx_data         ,
    
    output  wire            mac_rx_data_valid   ,
    output  wire    [7:0]   mac_rx_data         ,
    
    input   wire            rgmii_rxc           ,
    input   wire            rgmii_rx_ctl        ,
    input   wire    [3:0]   rgmii_rxd           ,
                        
    output  wire            rgmii_txc           ,
    output  wire            rgmii_tx_ctl        ,
    output  wire    [3:0]   rgmii_txd 
);

assign rgmii_clk = rgmii_rxc;

rgmii_rx u_rgmii_rx (
	//以太网RGMII接口
    .rgmii_rxc   	    (rgmii_rxc          ),//RGMII接收时钟
    .rgmii_rx_ctl	    (rgmii_rx_ctl       ),//RGMII接收数据控制信号
    .rgmii_rxd   	    (rgmii_rxd          ),//RGMII接收数据
	//以太网GMII接口
    .gmii_rx_clk 	    (                   ),//GMII接收时钟
    .gmii_rx_dv  	    (mac_rx_data_valid  ),//GMII接收数据有效信号
    .gmii_rxd           (mac_rx_data        ) //GMII接收数据   
);
rgmii_tx u_rgmii_tx (
	//GMII发送端口
    .gmii_tx_clk        (rgmii_rxc          ), //GMII发送时钟    
    .gmii_tx_en         (mac_tx_data_valid  ), //GMII输出数据有效信号
    .gmii_txd           (mac_tx_data        ), //GMII输出数据        
    //RGMII发送端口
    .rgmii_txc          (rgmii_txc          ), //RGMII发送数据时钟    
    .rgmii_tx_ctl       (rgmii_tx_ctl       ), //RGMII输出数据有效信号
    .rgmii_txd          (rgmii_txd          )  //RGMII输出数据     
    );
endmodule
