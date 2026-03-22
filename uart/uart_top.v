`timescale 1ns / 1ps
`define UD #1

module uart_top(
    //input ports
    input   wire            clk              ,
    input   wire            rst_n            ,
         
    input   wire            uart_rx          ,
    output  wire            uart_tx          ,
    (* MARK_DEBUG="true" *)output  reg     [7:0]   diff_value       ,
    output  reg     [11:0]  cur_frame_top    ,
    output  reg     [11:0]  cur_frame_bottom ,
    output  reg     [11:0]  cur_frame_left   ,
    output  reg     [11:0]  cur_frame_right  ,
    output  reg     [11:0]  cur_color_top    ,
    output  reg     [11:0]  cur_color_bottom ,
    output  reg     [11:0]  cur_color_left   ,
    output  reg     [11:0]  cur_color_right  
);

parameter      BPS_NUM = 16'd645;
//  设置波特率为4800时，  bit位宽时钟周期个数:50MHz set 10417  40MHz set 8333  27MHz set 5625
//  设置波特率为9600时，  bit位宽时钟周期个数:50MHz set 5208   40MHz set 4167  27MHz set 2813
//  设置波特率为115200时，bit位宽时钟周期个数:50MHz set 434    40MHz set 347   27MHz set 234
//  设置波特率为115200时，bit位宽时钟周期个数:50MHz set 434    40MHz set 347   74.25MHz set 154

//==========================================================================
//wire and reg in the module
//==========================================================================

wire           tx_busy;         //transmitter is free.
wire           rx_finish;       //receiver is free.
(* MARK_DEBUG="true" *)wire    [7:0]  rx_data;         //the data receive from uart_rx.
                                
wire    [7:0]  tx_data;         
                                
wire           tx_en;           //enable transmit.
(* MARK_DEBUG="true" *)wire           rx_en;
reg     [7:0]   move_area_sel;
reg     [7:0]   color_area_sel;

//==========================================================================
// 支持在串口助手的“文本模式”下直接敲击键盘发送：fa01123
//==========================================================================
localparam S_WAIT_F  = 3'd0; // 等待字符 'f' 或 'F'
localparam S_WAIT_A  = 3'd1; // 等待字符 'a' 或 'A'
localparam S_CMD_1   = 3'd2; // 命令码高位
localparam S_CMD_2   = 3'd3; // 命令码低位
localparam S_DAT_100 = 3'd4; // 数据百位
localparam S_DAT_10  = 3'd5; // 数据十位
localparam S_DAT_1   = 3'd6; // 数据个位

(* MARK_DEBUG="true" *)reg [2:0] rx_state;
reg [7:0] cmd_val;
reg [7:0] d100_val;
reg [7:0] d10_val;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rx_state      <= S_WAIT_F;
        cmd_val       <= 8'd0;
        d100_val      <= 8'd0;
        d10_val       <= 8'd0;
        diff_value    <= 8'd60; 
        move_area_sel <= 8'd1;
        color_area_sel<= 8'd2;
    end
    else if(rx_finish) begin // 串口收到一个完整的字节[cite: 31]
        case(rx_state)
            S_WAIT_F: begin
                // 兼容大小写 F
                if(rx_data == 8'h66 || rx_data == 8'h46) 
                    rx_state <= S_WAIT_A;
            end
            S_WAIT_A: begin
                // 兼容大小写 A
                if(rx_data == 8'h61 || rx_data == 8'h41) 
                    rx_state <= S_CMD_1;
                else 
                    rx_state <= S_WAIT_F; // 输错字母重新等
            end
            S_CMD_1: begin
                cmd_val <= (rx_data - 8'h30) * 10; // 命令码的十位
                rx_state <= S_CMD_2;
            end
            S_CMD_2: begin
                cmd_val <= cmd_val + (rx_data - 8'h30); // 命令码算出
                rx_state <= S_DAT_100;
            end
            S_DAT_100: begin
                d100_val <= rx_data - 8'h30; // 存下百位真实的数字 (0~2)
                rx_state <= S_DAT_10;
            end
            S_DAT_10: begin
                d10_val <= rx_data - 8'h30;  // 存下十位真实的数字 (0~9)
                rx_state <= S_DAT_1;
            end
            S_DAT_1: begin
                case(cmd_val)
                    8'd1: diff_value     <= (d100_val * 8'd100) + (d10_val * 8'd10) + (rx_data - 8'h30);
                    8'd2: move_area_sel  <= (d100_val * 8'd100) + (d10_val * 8'd10) + (rx_data - 8'h30);
                    8'd3: color_area_sel <= (d100_val * 8'd100) + (d10_val * 8'd10) + (rx_data - 8'h30);
                    default: ; // 
                endcase
                rx_state <= S_WAIT_F; // 收完归位，等下一次
            end
            default: rx_state <= S_WAIT_F;
        endcase
    end
end

//===========================================================================
// 动态识别区域控制逻辑
//===========================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cur_frame_top    <= 12'd5;
        cur_frame_bottom <= 12'd354;
        cur_frame_left   <= 12'd5;
        cur_frame_right  <= 12'd634;
    end
    else begin
        case(move_area_sel)
            8'd1: begin // 1号：左上角
                cur_frame_top    <= 12'd5;
                cur_frame_bottom <= 12'd354;
                cur_frame_left   <= 12'd5;
                cur_frame_right  <= 12'd634;
            end
            8'd2: begin // 2号：右上角 (假设中间有10个像素的黑边)
                cur_frame_top    <= 12'd5;
                cur_frame_bottom <= 12'd354;
                cur_frame_left   <= 12'd645;
                cur_frame_right  <= 12'd1274;
            end
            8'd3: begin // 3号：左下角
                cur_frame_top    <= 12'd365;
                cur_frame_bottom <= 12'd714;
                cur_frame_left   <= 12'd5;
                cur_frame_right  <= 12'd634;
            end
            8'd4: begin // 4号：右下角
                cur_frame_top    <= 12'd365;
                cur_frame_bottom <= 12'd714;
                cur_frame_left   <= 12'd645;
                cur_frame_right  <= 12'd1274;
            end
            default: begin // 发错了号码，默认停在左上角
                cur_frame_top    <= 12'd5;
                cur_frame_bottom <= 12'd354;
                cur_frame_left   <= 12'd5;
                cur_frame_right  <= 12'd634;
            end
        endcase
    end
end

//===========================================================================
// 动态识别区域控制逻辑
//===========================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cur_color_top    <= 12'd5;
        cur_color_bottom <= 12'd354;
        cur_color_left   <= 12'd5;
        cur_color_right  <= 12'd634;
    end
    else begin
        case(color_area_sel)
            8'd1: begin // 1号：左上角
                cur_color_top    <= 12'd5;
                cur_color_bottom <= 12'd354;
                cur_color_left   <= 12'd5;
                cur_color_right  <= 12'd634;
            end
            8'd2: begin // 2号：右上角 (假设中间有10个像素的黑边)
                cur_color_top    <= 12'd5;
                cur_color_bottom <= 12'd354;
                cur_color_left   <= 12'd645;
                cur_color_right  <= 12'd1274;
            end
            8'd3: begin // 3号：左下角
                cur_color_top    <= 12'd365;
                cur_color_bottom <= 12'd714;
                cur_color_left   <= 12'd5;
                cur_color_right  <= 12'd634;
            end
            8'd4: begin // 4号：右下角
                cur_color_top    <= 12'd365;
                cur_color_bottom <= 12'd714;
                cur_color_left   <= 12'd645;
                cur_color_right  <= 12'd1274;
            end
            default: begin // 发错了号码，默认停在左上角
                cur_color_top    <= 12'd5;
                cur_color_bottom <= 12'd354;
                cur_color_left   <= 12'd5;
                cur_color_right  <= 12'd634;
            end
        endcase
    end
end

//uart transmit data module.
uart_tx #(
    .BPS_NUM             ( BPS_NUM ) 
 )u_uart_tx( 
    .clk                 ( clk     ),// input            clk, 
    .rst_n				 ( rst_n   ),// input            rst_n,
    .tx_data             ( tx_data ),// input [7:0]      tx_data,           
    .tx_pluse            ( tx_en   ),// input            tx_pluse,          
    .uart_tx             ( uart_tx ),// output reg       uart_tx,                                  
    .tx_busy             ( tx_busy ) // output           tx_busy            
);                                             
                                           
//Uart receive data module.                
uart_rx #(
     .BPS_NUM            ( BPS_NUM   ) 
 )
 u_uart_rx (                        
    .clk                 ( clk       ),// input             clk, 
    .rst_n				 ( rst_n	  ),// input            rst_n,	
    .uart_rx             ( uart_rx   ),// input             uart_rx,            
    .rx_data             ( rx_data   ),// output reg [7:0]  rx_data,                                   
    .rx_en               ( rx_en     ),// output reg        rx_en,                          
    .rx_finish           ( rx_finish ) // output            rx_finish           
);                                            
    
endmodule