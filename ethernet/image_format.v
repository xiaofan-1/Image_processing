`timescale 1ns / 1ps

module image_format #(
	parameter	FORMAT   =   8'h04     ,//图像格式 04:(RGB565) 05:(RGB888)
    parameter	H_PIXEL  =   16'd1280  ,//行像素个数：1280
    parameter	V_PIXEL  =   16'd720    //场像素个数：720
)(
    input   wire            clk                 ,
    input   wire            rst_n               ,
    input   wire            udp_data_valid      ,//udp数据有效信号
    input   wire            udp_cmd_start       ,//发送命令开始信号
    input   wire            udp_tx_done         ,//udp发送完一个数据包结束信号
    output  reg             udp_tx_cmd_start    ,//发送图像数据格式开始信号
    output  reg     [7:0]   image_format_data   ,//图像数据格式
    output  wire            image_format_end    ,//图像数据格式结束信号
    output  wire    [15:0]  image_format_num    ,//udp发送数据字节个数
    output  wire            image_format_busy
    );

localparam
    HEAD     =   32'h53_5a_48_59 ,//包头    
    ADDR     =   8'h00           ,//设备地址             
    DATA_NUM =   32'h11_00_00_00 ,//包长：17字节，十六进制为11                   
    CMD      =   8'h01           ,//指令
    CRC      =   16'h7C_0B       ;//CRC-16校验：关闭上位机校验，可填写任意值

localparam CNT_DATA_MAX = 5'd17;//需要传输17字节，每次传输2字节，需要传输9次
localparam CNT_START_MAX = 28'd25_000_000; //初始状态等待时钟周期数
localparam CNT_END_MAX = 28'd25_00; //初始状态等待时钟周期数

localparam
    IDLE     = 4'b0001,
    CMD_SEND = 4'b0010,//发送指令
    CYCLE    = 4'b0100,//循环发送指令
    END      = 4'b1000;//结束

reg     [3:0]   curr_state;
reg     [3:0]   next_state;
reg     [27:0]  cnt_start;
reg     [27:0]	cnt_end;
reg     [4:0]   cnt_data;
reg     [3:0]   cnt_cycle;
reg             udp_cmd_start_reg;

reg             udp_data_valid_reg;

wire [15:0] H_PIXE; // LE = Little Endian
wire [15:0] V_PIXE; // LE = Little Endian

assign H_PIXE = {H_PIXEL[7:0], H_PIXEL[15:8]};
assign V_PIXE = {V_PIXEL[7:0], V_PIXEL[15:8]};

//----------------------------state_one----------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        curr_state <= IDLE;
    else
        curr_state <= next_state;
end

//----------------------------state_two----------------------
always @(*) begin
    if(!rst_n)
        next_state = IDLE;
    else begin
        case(curr_state)
            IDLE    :begin
                if(cnt_start == CNT_START_MAX)
                    next_state = CMD_SEND;
                else
                    next_state = curr_state;
            end
            CMD_SEND:begin
                if(cnt_data == CNT_DATA_MAX - 5'd1 && udp_tx_done)
                    next_state = CYCLE;
                else
                    next_state = curr_state;
            end
            CYCLE   :begin
                if(cnt_cycle == 4'd4)
                    next_state = END;
                else
                    next_state = IDLE;
            end
            END     : next_state = END;
            default : next_state = IDLE;
        endcase
    end
end
//----------------------------开始信号------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        udp_cmd_start_reg <= 0;
    else if(udp_cmd_start)
        udp_cmd_start_reg <= 1'b1;
    else if(curr_state == END)
        udp_cmd_start_reg <= 1'b0;
end
//----------------------------开始发送图像格式信号------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        udp_tx_cmd_start <= 0;
    else if(cnt_start == CNT_START_MAX)
        udp_tx_cmd_start <= 1'b1;
    else 
        udp_tx_cmd_start <= 1'b0;
end
//----------------------------初始状态等待计数----------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt_start <= 28'd0;
    else if(curr_state == IDLE && udp_cmd_start_reg) begin
        if(cnt_start == CNT_START_MAX)
            cnt_start <= 28'd0;
        else
            cnt_start <= cnt_start + 28'd1;
    end
    else
        cnt_start <= 28'd0;
end
//---------------------------结束状态计数-------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt_end <= 28'd0;
    else if(curr_state == END) begin
        if(cnt_end == CNT_END_MAX)
            cnt_end <= cnt_end;
        else
            cnt_end <= cnt_end + 28'd1;
    end
    else
        cnt_end <= 28'd0;
end
//----------------------------打拍udp_data_valid----------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        udp_data_valid_reg <= 1'b0;
    else
        udp_data_valid_reg <= udp_data_valid;
end
//----------------------------传输数据计数----------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt_data <= 5'd0;
    else if(cnt_data == CNT_DATA_MAX - 1 && curr_state == IDLE)
        cnt_data <= 5'd0;
    else if(cnt_data == 5'd16)
        cnt_data <= cnt_data;
    else if(udp_data_valid_reg)
        cnt_data <= cnt_data + 5'd1;
end
//----------------------------循环发送指令计数----------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt_cycle <= 4'd0;
    else if(curr_state == END)
        cnt_cycle <= 4'd0;
    else if(udp_tx_done && cnt_cycle < 4'd4)
        cnt_cycle <= cnt_cycle + 4'd1;
    else
        cnt_cycle <= cnt_cycle;
end
//----------------------------传输指令数据----------------------
always @(*) begin
    if(!rst_n)
        image_format_data = 8'd0;
    else if(curr_state == IDLE)
        image_format_data = 8'd0;
    else if(curr_state == CMD_SEND) begin
        case(cnt_data)
            5'd0 :image_format_data = HEAD[31:24];
            5'd1 :image_format_data = HEAD[23:16] ;
			5'd2 :image_format_data = HEAD[15:8];
            5'd3 :image_format_data = HEAD[7:0] ;
            5'd4 :image_format_data = ADDR;
			5'd5 :image_format_data = DATA_NUM[31:24];
            5'd6 :image_format_data = DATA_NUM[23:16];
			5'd7 :image_format_data = DATA_NUM[16:8];
            5'd8 :image_format_data = DATA_NUM[7:0];
            5'd9 :image_format_data = CMD;
			5'd10:image_format_data = FORMAT;
            5'd11:image_format_data = H_PIXE[15:8];
			5'd12:image_format_data = H_PIXE[7:0];
            5'd13:image_format_data = V_PIXE[15:8];
			5'd14:image_format_data = V_PIXE[7:0];
            5'd15:image_format_data = CRC[15:8];
            5'd16:image_format_data = CRC[7:0];
            default:image_format_data = 8'h0;
        endcase
    end
    else
        image_format_data = 8'd0;
end
//--------------------------图像数据格式结束信号----------------------
assign image_format_end = (curr_state == END && cnt_end == CNT_END_MAX) ? 1 : 0 ;
//--------------------------udp发送数据字节个数----------------------
assign image_format_num = 16'd17;
//
assign image_format_busy = (curr_state == END) ? 0 : 1;

endmodule