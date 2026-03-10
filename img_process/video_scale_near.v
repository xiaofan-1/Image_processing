// video_scale_near.v
// 修正版临近插值视频缩放模块：修正了定点数精度丢失、行尾越界、以及坐标滑窗对齐问题
`timescale 1ns / 1ps

module video_scale_near #(
    parameter PIX_DATA_WIDTH = 16
)(
    input   wire                            vin_clk         , //输入视频时钟
    input   wire                            rst_n           ,
    input   wire                            frame_sync_n    , //输入视频帧同步，低有效
    input   wire    [PIX_DATA_WIDTH-1:0]    vin_dat         , //输入视频数据
    input   wire                            vin_valid       , //输入视频数据有效
    output  wire                            vin_ready       , //输入准备好
    output  reg     [PIX_DATA_WIDTH-1:0]    vout_dat        , //输出视频数据
    output  reg                             vout_valid      , //输出视频数据有效
    input   wire                            vout_ready      , //输出准备好
    input   wire    [15:0]                  vin_xres        , //输入视频水平分辨率
    input   wire    [15:0]                  vin_yres        , //输入视频垂直分辨率
    input   wire    [15:0]                  vout_xres       , //输出视频水平分辨率
    input   wire    [15:0]                  vout_yres         //输出视频垂直分辨率
);

//==============================================================================================
//缩放系数计算: (不用强制加1，用半步长补偿即可，防止溢出)
//==============================================================================================
reg [31:0] scaler_height = 0; 
reg [31:0] scaler_width  = 0; 

always @(posedge frame_sync_n) begin
    scaler_width  <= (vin_xres << 16) / vout_xres;  
    scaler_height <= (vin_yres << 16) / vout_yres;  
end

//==============================================================================================
// 输入视频水平计数和垂直计数
//==============================================================================================
reg [15:0] vin_x; 
reg [15:0] vin_y;

always @(posedge vin_clk or negedge rst_n) begin    
    if(!rst_n) begin
        vin_x <= 0;
        vin_y <= 0;
    end
    else if(frame_sync_n == 0) begin
        vin_x <= 0;
        vin_y <= 0;
    end
    else if (vin_valid && vout_ready) begin
        if(vin_x < vin_xres - 1) begin  
            vin_x <= vin_x + 1;
        end
        else begin
            vin_x <= 0;
            vin_y <= vin_y + 1;
        end
    end
end 

//==============================================================================================
// 临近缩小算法核心逻辑（重构点：修复了换行精度丢失和盲目空跑的Bug）
//==============================================================================================
reg [31:0] vout_x; 
reg [31:0] vout_y; 

always @(posedge vin_clk or negedge rst_n) begin 
    if(!rst_n) begin
        vout_x <= 0;
        vout_y <= 0;
    end
    else if(frame_sync_n == 0) begin
        // 这里改为了填入半个降采样步长作为初始偏置，解决左边或上边沿始终偏离1个像素的错位
        vout_x <= scaler_width  >> 1;  
        vout_y <= scaler_height >> 1;  
    end
    else if (vin_valid && vout_ready) begin 
        if(vin_x < vin_xres - 1) begin
            // 只有当这一行是有效的“被选中行”时，X坐标才去累加！否则就在原点待命，节省功耗并防止错位
            if(vout_y[31:16] == vin_y) begin
               if (vout_x[31:16] == vin_x) begin          
                   vout_x <= vout_x + scaler_width;        
               end
            end
        end
        else begin
            // 行末换行时：只重置整数部分为0，保留定点小数精度继续累积给下一行！(只保留[15:0])
            // 并赋予半步长偏置（否则累加到最右端可能差1个像素凑不齐）
            vout_x <= {16'd0, vout_x[15:0]} + (scaler_width >> 1);
            
            if (vout_y[31:16] == vin_y) begin
                vout_y <= vout_y + scaler_height;
            end
        end
    end
end

//==============================================================================================
// 数据滞后打拍对齐（极为关键！！！）
// 因为 vin_x 和 vout_x[31:16] 的比较是在时钟上升沿之前，
// vin_dat 的有效性和命中条件由于经过了判断器，必须要和 vin_dat 在同一拍输出
// 原代码由于判断用的寄存器是上一拍的值，存在 1 周期错位。
//==============================================================================================
reg  hit_flag;
reg  [PIX_DATA_WIDTH-1:0] vin_dat_d0;
reg  vin_valid_d0;

always @(posedge vin_clk or negedge rst_n) begin
    if(!rst_n) begin
        hit_flag     <= 0;
        vin_dat_d0   <= 0;
        vin_valid_d0 <= 0;
    end
    else begin
        // 判断坐标匹配（当前输入坐标等不等于目标跟踪采样坐标）
        hit_flag     <= (vout_x[31:16] == vin_x) && (vout_y[31:16] == vin_y);
        vin_dat_d0   <= vin_dat;
        
        // 只有当有输入数据，且下游准备好接收时，有效性才向后传递
        vin_valid_d0 <= vin_valid && vout_ready;
    end
end

//==============================================================================================
// 最终缓冲输出
//==============================================================================================
always @(posedge vin_clk or negedge rst_n) begin
    if(!rst_n) begin
        vout_dat   <= 0;
        vout_valid <= 0;
    end
    else if(frame_sync_n == 0) begin
        vout_dat   <= 0;
        vout_valid <= 0;
    end
    else begin
        if(hit_flag && vin_valid_d0) begin
            vout_valid <= 1'b1;
            vout_dat   <= vin_dat_d0;
        end
        else begin
            vout_valid <= 1'b0;
        end
    end 
end

// 流控简单传递
assign vin_ready = vout_ready;

endmodule
