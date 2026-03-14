`timescale 1ns / 1ps

module image_data #(
    parameter	H_PIXEL = 16'd1280,//分辨率为1280*720
    parameter	V_PIXEL = 16'd720  //一个udp包传输1280字节，需要传输1440次
)(
    input   wire            clk                 ,
    input   wire            rst_n               ,
    
    input   wire            udp_data_start      ,//开始执行本模块信号
    input   wire            udp_tx_done         ,//以太网传输完一个包结束信号
    input   wire            udp_data_valid      ,//udp数据有效信号
    output  reg             read_req            , // Start reading a frame of data     
    input   wire            read_req_ack        , // Read request response
    output  wire            read_en             , // Read data enable
    input   wire    [15:0]  read_data           , // Read data
   
    output  reg     [7:0]   image_data_out      ,//封装好的图像数据
    output  reg             udp_tx_data_start   ,//以太网开始传输信号
    output  reg     [15:0]  image_data_num       //以太网传输数据个数
    );

//==============================================================================
//localparam
//==============================================================================
localparam
    CNT_PACKET_WAIT = 28'd200,      // 包与包之间留 0.8us 间隙
    CNT_FRAME_WAIT  = 28'd5000,
    CNT_HEAD_WAIT   = 28'd600; 

    
localparam 
    HEAD = 32'hFA_32_69_44 ,
    TAIL = 32'hFA_CC_CC_AF ;

localparam
    IDLE        = 6'd0,                               
    HEAD_PACKET = 6'd1,//第一包数据，包含包头    
    HEAD_WAIT   = 6'd2,//包头等待时间
    DATA_STARTE = 6'd3,//第二包数据，包含包头    
    DATA_PACKET = 6'd4,//图像数据
    LAST_PACKET = 6'd5,//最后一包数据
    PACKET_WAIT = 6'd6,//单包发送完，等待时间
    FRAME_WAIT  = 6'd7;//一帧数据发送完，等待时间

reg     [5:0]   curr_state;
reg     [5:0]   next_state;
reg     [27:0]  cnt_packet;//单包等待时间计数
reg     [27:0]  cnt_frame;//单帧等待时间计数
reg     [27:0]  cnt_head;//包头等待时间计数
//reg     [10:0]  cnt_v;//
reg     [15:0]  cnt_h;//一帧图像发送udp包的个数
reg     [10:0]  cnt_data;//传输数据个数计数，2字节

reg             udp_data_start_reg;
reg             udp_data_valid_reg;
                   
wire	[15:0]	h_num;
wire	[15:0]	v_num;
assign	h_num = (H_PIXEL <= 16'd736) ? H_PIXEL*2 : H_PIXEL;
assign	v_num = (H_PIXEL <= 16'd736) ? V_PIXEL : V_PIXEL*2;

//==============================================================================
//read_req
//==============================================================================
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        read_req <= 1'b0;
    else if(curr_state == IDLE)
        read_req <= 1'b1;
    else if(read_req_ack == 1'b1)
        read_req <= 1'b0;
end

//==============================================================================
//state
//==============================================================================
//--------------------one--------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        curr_state <= IDLE;
    else
        curr_state <= next_state;
end

//---------------------two--------------------
always @(*) begin
    if(!rst_n)
        next_state = IDLE;
    else begin
        case(curr_state)
            IDLE       :begin
                if(udp_data_start)
                    next_state = HEAD_PACKET;
                else
                    next_state = curr_state;
            end
            HEAD_PACKET:begin//帧头
                if(udp_tx_done)
                    next_state = HEAD_WAIT;
                else
                    next_state = curr_state;
            end
            HEAD_WAIT:begin//帧头等待时间
                if(cnt_head == CNT_HEAD_WAIT - 1)
                    next_state = DATA_STARTE;
                else
                    next_state = curr_state;
            end
            DATA_STARTE:begin
                if(udp_data_start)
                    next_state = DATA_PACKET;
                else
                    next_state = curr_state;
            end
            DATA_PACKET:begin//图像数据
                if(udp_tx_done)
                    next_state = PACKET_WAIT;
                else
                    next_state = curr_state;
            end
            LAST_PACKET: begin//帧尾
                if(udp_tx_done)
                    next_state = FRAME_WAIT;
                else
                    next_state = curr_state;
            end
            PACKET_WAIT: begin//单包发送完，等待时间
                if(cnt_packet == CNT_PACKET_WAIT - 1) begin
                    if(cnt_h < v_num)
                        next_state = DATA_STARTE;
                    else if(cnt_h == v_num)
                        next_state = LAST_PACKET;
                end
                else
                    next_state = curr_state;
            end
            FRAME_WAIT : begin//一帧数据发送完，等待时间
                if(cnt_frame == CNT_FRAME_WAIT - 1)
                    next_state = IDLE;
                else
                    next_state = curr_state;
            end
            default:next_state = IDLE;
        endcase
    end
end

//==============================================================================
//start开始执行本模块信号
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        udp_data_start_reg <= 1'b0;
    else if(udp_data_start)
        udp_data_start_reg <= 1'b1;
    else
        udp_data_start_reg <= udp_data_start_reg;
end

//==============================================================================
//打拍udp_data_valid
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        udp_data_valid_reg <= 1'b0;
    else
        udp_data_valid_reg <= udp_data_valid;
end

//==============================================================================
//单包数据等待时间
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt_packet <= 28'd0;
    else if((curr_state == IDLE || curr_state == PACKET_WAIT) && udp_data_start_reg) begin
        if(cnt_packet == CNT_PACKET_WAIT)
            cnt_packet <= 28'd0;
        else
            cnt_packet <= cnt_packet + 28'd1;
    end
    else
        cnt_packet <= 28'd0;
end

//==============================================================================
//单帧数据等待时间
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt_frame <= 28'd0;
    else if(curr_state == FRAME_WAIT) begin
        if(cnt_frame == CNT_FRAME_WAIT)
            cnt_frame <= 28'd0;
        else
            cnt_frame <= cnt_frame + 1;
    end
    else
        cnt_frame <= 28'd0;
end

//==============================================================================
//包头等待时间
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt_head <= 28'd0;
    else if(curr_state == HEAD_WAIT) begin
        if(cnt_head == CNT_HEAD_WAIT)
            cnt_head <= 28'd0;
        else
            cnt_head <= cnt_head + 1;
    end
    else
        cnt_head <= 28'd0;
end

//==============================================================================
//传输数据计数
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt_data <= 11'd0;
    else if(curr_state == HEAD_PACKET || curr_state == DATA_PACKET || curr_state == LAST_PACKET) begin
        if(udp_data_valid_reg)
            cnt_data <= cnt_data + 1;
        else
            cnt_data <= cnt_data;
    end
    else
        cnt_data <= 11'd0;
end

//==============================================================================
//传输数据
//==============================================================================
always @(*) begin
    if(!rst_n)
        image_data_out = 8'h0;
    else begin
        case(curr_state)
            HEAD_PACKET:begin
                case(cnt_data)                             
                    11'd0:image_data_out = HEAD[31:24];           
                    11'd1:image_data_out = HEAD[23:16];  
                    11'd2:image_data_out = HEAD[15:8] ;           
                    11'd3:image_data_out = HEAD[7:0]  ;
                    default:image_data_out = 8'h00; 
                endcase
            end
            DATA_PACKET:begin
                if(cnt_data == 11'd0)
                    image_data_out = 8'hFA;
                else if(cnt_data == 11'd1281)
                    image_data_out = cnt_h[15:8];
                else if(cnt_data == 11'd1282)
                    image_data_out = cnt_h[7:0];
                else if(cnt_data == 11'd1283)
                    image_data_out = 8'hAF;
                else if(cnt_data[0] == 1'b1)
                    image_data_out = read_data[15:8];
                else
                    image_data_out = read_data[7:0];
            end
            LAST_PACKET:begin
                case(cnt_data)                             
                    11'd0:image_data_out = TAIL[31:24];           
                    11'd1:image_data_out = TAIL[23:16];  
                    11'd2:image_data_out = TAIL[15:8] ;           
                    11'd3:image_data_out = TAIL[7:0]  ;
                    default:image_data_out = 8'h00; 
                endcase
            end
            default:image_data_out = 8'h0;
        endcase
    end
end

//==============================================================================
//ddr读fifo使能
//==============================================================================
assign read_en = udp_data_valid && ( curr_state == DATA_PACKET && cnt_data > 11'd0 && cnt_data < 11'd1281 && cnt_data[0] == 1'b1);

//==============================================================================
//以太网开始传输信号
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        udp_tx_data_start <= 1'b0;
    else if((next_state == HEAD_PACKET || next_state == DATA_PACKET || next_state == LAST_PACKET) && (curr_state != next_state))
        udp_tx_data_start <= 1'b1;
    else
        udp_tx_data_start <= 1'b0;
end

//==============================================================================
//一帧图像发送的个数
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt_h <= 16'd0;
    else if(curr_state == IDLE)
        cnt_h <= 16'd0;
    else if(udp_tx_done && curr_state == DATA_PACKET) // 只统计数据包，不统计帧头包
        cnt_h <= cnt_h + 16'd1;
    else
        cnt_h <= cnt_h;
end

//==============================================================================
//以太网单包发送数据个数
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        image_data_num <= 16'd0;
    else if(curr_state == HEAD_PACKET)
        image_data_num <= 16'd4;
    else if(curr_state == DATA_PACKET)
        image_data_num <= h_num + 16'd4;
    else if(curr_state == LAST_PACKET)
        image_data_num <= 16'd4;
    else
        image_data_num <= image_data_num;
end

endmodule
