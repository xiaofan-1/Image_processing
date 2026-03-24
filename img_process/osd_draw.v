`timescale 1ns / 1ps

module osd_draw(
    input   wire            clk         ,
    input   wire            rst_n       ,
    
    // 输入纯净的视频流（或者经过其他处理但不带框的视频流）
    input   wire            hsync_i     ,
    input   wire            vsync_i     ,
    input   wire            de_i        ,
    input   wire    [23:0]  rgb_data_i  ,
    input   wire    [11:0]  pixel_x     , // 当前像素X坐标
    input   wire    [11:0]  pixel_y     , // 当前像素Y坐标
    
    // 接收动态检测传来的坐标
    input   wire    [11:0]  frame_x_min ,
    input   wire    [11:0]  frame_x_max ,
    input   wire    [11:0]  frame_y_min ,
    input   wire    [11:0]  frame_y_max ,
    
    // 接收颜色识别传来的坐标
    input   wire    [11:0]  color_x_min ,
    input   wire    [11:0]  color_x_max ,
    input   wire    [11:0]  color_y_min ,
    input   wire    [11:0]  color_y_max ,
    
    // 输出最终带各种框的视频流
    output  wire            hsync_o     ,
    output  wire            vsync_o     ,
    (* MARK_DEBUG="true" *)output  wire            de_o        ,
    (* MARK_DEBUG="true" *)output  reg     [23:0]  rgb_data_o  
);

// 提取画框的条件 (极简版)
wire draw_frame_box = ((pixel_y == frame_y_min || pixel_y == frame_y_max) && (pixel_x >= frame_x_min && pixel_x <= frame_x_max)) || 
                      ((pixel_x == frame_x_min || pixel_x == frame_x_max) && (pixel_y >= frame_y_min && pixel_y <= frame_y_max));

// 为了防止两个框万一完美重合导致看不清，你可以让颜色框稍微往外扩1个像素画
wire draw_color_box = ((pixel_y == color_y_min - 1 || pixel_y == color_y_max + 1) && (pixel_x >= color_x_min - 1 && pixel_x <= color_x_max + 1)) || 
                      ((pixel_x == color_x_min - 1 || pixel_x == color_x_max + 1) && (pixel_y >= color_y_min - 1 && pixel_y <= color_y_max + 1));

// 数据输出与优先级判断
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rgb_data_o <= 24'b0;
    end 
    else if (de_i) begin
        if (draw_frame_box)
            rgb_data_o <= 24'hff_00_00; // 动态框画红色
        else if (draw_color_box)
            rgb_data_o <= 24'h00_ff_00; // 颜色框画绿色
        else
            rgb_data_o <= rgb_data_i;   // 啥也不是就透传原图
    end
    else begin
        rgb_data_o <= 24'b0;
    end
end

// 信号同步打拍 (因为上面的 always 块消耗了 1 个时钟周期)
reg hsync_r, vsync_r, de_r;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hsync_r <= 1'b0;
        vsync_r <= 1'b0;
        de_r    <= 1'b0;
    end else begin
        hsync_r <= hsync_i;
        vsync_r <= vsync_i;
        de_r    <= de_i;
    end
end

assign hsync_o = hsync_r;
assign vsync_o = vsync_r;
assign de_o    = de_r;

endmodule