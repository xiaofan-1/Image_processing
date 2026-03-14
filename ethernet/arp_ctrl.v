`timescale 1ns / 1ps

module arp_ctrl(
    input   wire            clk             ,
    input   wire            rst_n           ,
    input   wire            key             ,
    input   wire            arp_rx_op       ,
    input   wire            arp_rx_done     ,
    output  reg             arp_tx_en       ,
    output  reg             arp_tx_op        //1:请求包/0:应答包
    );
    
always @(posedge clk) begin
    if(!rst_n) begin
        arp_tx_en <= 0;
        arp_tx_op <= 0;
    end
    else if(key) begin //发送请求包
        arp_tx_en <= 1;
        arp_tx_op <= 1;
    end
    else if(arp_rx_op == 1 && arp_rx_done) begin //接收到请求包，发送应答包
        arp_tx_en <= 1;
        arp_tx_op <= 0;
    end
    else if(arp_rx_op == 0 && arp_rx_done) begin //接收到应答包，不发送
        arp_tx_en <= 0;
        arp_tx_op <= 0;
    end
    else begin
        arp_tx_en <= 0;
        arp_tx_op <= arp_tx_op;
    end
end
endmodule
