`timescale 1ns / 1ps

module image_frame(
    input   wire        clk           ,
    input   wire        rst_n         ,
    //输入                             
    input   wire        hsync_i       ,//行信号
    input   wire        vsync_i       ,//场信号
    input   wire        de_i          ,//图像有效信号
    input   wire [7:0]  data_i        ,//处理后的图像
    input   wire [11:0] pixle_x       ,
    input   wire [11:0] pixle_y       ,
    input   wire [23:0] rgb_data      ,

    input   wire [11:0] frame_top     ,
    input   wire [11:0] frame_bottom  ,
    input   wire [11:0] frame_left    ,
    input   wire [11:0] frame_right   ,

    //输出                             
    output  wire        pixel_valid   ,
    (* MARK_DEBUG="true" *)output  reg  [11:0] x_min_r       ,
    (* MARK_DEBUG="true" *)output  reg  [11:0] x_max_r       ,
    (* MARK_DEBUG="true" *)output  reg  [11:0] y_min_r       ,
    (* MARK_DEBUG="true" *)output  reg  [11:0] y_max_r       ,
    (* MARK_DEBUG="true" *)output  wire [11:0] pixle_x_reg   ,
    (* MARK_DEBUG="true" *)output  wire [11:0] pixle_y_reg   ,
    output  wire        hsync_o       ,
    output  wire        vsync_o       ,
    (* MARK_DEBUG="true" *)output  wire        de_o          ,
    (* MARK_DEBUG="true" *)output  reg  [23:0] data_o       
    );

// assign data_o = rgb_data_reg;

localparam pix_h = 1280,
           pix_v = 720;
               
reg  [11:0]  x,y;
wire add_x = de_i;
wire end_x = add_x && x == pix_h - 1;
wire add_y = end_x;
wire end_y = add_y && y == pix_v - 1;

//==============行计数器====================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        x <= 0;
    else if (add_x)
        x <= end_x ? 0 : x + 1;
end

//==============列计数器====================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        y <= 0;
    else if (add_y)
        y <= end_y ? 0 : y + 1;
end

reg vsync_reg0, vsync_reg1;
// =============提取同步信号边沿============
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        vsync_reg0 <= 0;
        vsync_reg1 <= 0;
    end else begin
        vsync_reg0 <= ~vsync_i;
        vsync_reg1 <= vsync_reg0;
    end
end

wire pos_vsync = (vsync_reg0 && ~vsync_reg1);
wire neg_vsync = (~vsync_reg0 && vsync_reg1);

// 边界检测（边缘像素即有效像素）
assign pixel_valid = (data_i == 8'd1 && x > frame_left && x < frame_right && y > frame_top && y < frame_bottom);
// 记录边界（极值法）
reg [10:0] x_min;
reg [10:0] x_max;
reg [10:0] y_min;
reg [10:0] y_max;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n || pos_vsync)
        x_min <= pix_h;
    else if (pixel_valid && x < x_min)
        x_min <= x;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n || pos_vsync)
        x_max <= 0;
    else if (pixel_valid && x > x_max)
        x_max <= x;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n || pos_vsync)
        y_min <= pix_v;
    else if (pixel_valid && y < y_min)
        y_min <= y;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n || pos_vsync)
        y_max <= 0;
    else if (pixel_valid && y > y_max)
        y_max <= y;
end

// =============锁存边界到下一帧=============
// always @(posedge clk or negedge rst_n) begin
    // if (!rst_n) begin
        // x_min_r <= 0; 
        // x_max_r <= 0;
        // y_min_r <= 0; 
        // y_max_r <= 0;
    // end 
    // else if (neg_vsync) begin
        // x_min_r <= x_min;
        // x_max_r <= x_max;
        // y_min_r <= y_min;
        // y_max_r <= y_max;
    // end
// end

reg [5:0] miss_cnt; // 目标丢失计数器

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_min_r <= 0; 
        x_max_r <= 0;
        y_min_r <= 0; 
        y_max_r <= 0;
        miss_cnt <= 0;
    end 
    else if (neg_vsync) begin
        if (x_min < x_max && y_min < y_max && (x_max - x_min) > 5 && (y_max - y_min) > 5) begin
            miss_cnt <= 0; 
            
            if (x_min_r == 0 && x_max_r == 0) begin
                x_min_r <= x_min;
                x_max_r <= x_max;
                y_min_r <= y_min;
                y_max_r <= y_max;
            end 
            else begin
                // X轴最小值 (左边缘)：越小说明物体越往左动。比原来小就瞬间跟上，比原来大就平滑收缩
                x_min_r <= (x_min < x_min_r) ? x_min : ((x_min_r + x_min) >> 1);
                
                // X轴最大值 (右边缘)：越大说明物体越往右动。比原来大就瞬间跟上，比原来小就平滑收缩
                x_max_r <= (x_max > x_max_r) ? x_max : ((x_max_r + x_max) >> 1);
                
                // Y轴最小值 (上边缘)：越小说明物体越往上动。比原来小就瞬间跟上，比原来大就平滑收缩
                y_min_r <= (y_min < y_min_r) ? y_min : ((y_min_r + y_min) >> 1);
                
                // Y轴最大值 (下边缘)：越大说明物体越往下动。比原来大就瞬间跟上，比原来小就平滑收缩
                y_max_r <= (y_max > y_max_r) ? y_max : ((y_max_r + y_max) >> 1);
            end
        end
        else begin
            if (miss_cnt < 6'd10) begin
                miss_cnt <= miss_cnt + 1'b1;
            end 
            else begin
                x_min_r <= 0;
                x_max_r <= 0;
                y_min_r <= 0;
                y_max_r <= 0;
            end
        end
    end
end
//==========================================================================================
//同步信号
//==========================================================================================
reg [23:0] rgb_data_pipe [28:0];
reg [11:0] pixle_x_pipe [4:0];
reg [11:0] pixle_y_pipe [4:0];
integer i;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for (i = 0; i < 29; i = i + 1)
            rgb_data_pipe[i] <= 24'h0;
    end
    else begin
        rgb_data_pipe[0] <= rgb_data;
        for (i = 1; i < 29; i = i + 1)
            rgb_data_pipe[i] <= rgb_data_pipe[i-1];
    end
end

integer j;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for (j = 0; j < 5; j = j + 1) begin
            pixle_x_pipe[j] <= 12'h0;
            pixle_y_pipe[j] <= 12'h0;
        end
    end
    else begin
        pixle_x_pipe[0] <= pixle_x;
        pixle_y_pipe[0] <= pixle_y;
        for (j = 1; j < 5; j = j + 1) begin
            pixle_x_pipe[j] <= pixle_x_pipe[j-1];
            pixle_y_pipe[j] <= pixle_y_pipe[j-1];
        end
    end
end

(* MARK_DEBUG="true" *)wire [23:0] rgb_data_reg;
assign rgb_data_reg = rgb_data_pipe[27];
assign pixle_x_reg = pixle_x_pipe[2];
assign pixle_y_reg = pixle_y_pipe[2];

//==========================================================================================
//数据输出
//==========================================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_o <= 24'b0;
    else if ((pixle_y_reg == y_min_r || pixle_y_reg == y_max_r) && (pixle_x_reg >= x_min_r && pixle_x_reg <= x_max_r))
        data_o <= 24'hff_00_00; // 横线
    else if ((pixle_x_reg == x_min_r || pixle_x_reg == x_max_r) && (pixle_y_reg >= y_min_r && pixle_y_reg <= y_max_r))
        data_o <= 24'hff_00_00; // 竖线
    else
        data_o <= rgb_data_reg;
end

//==============信号同步====================
reg  [2:0]  hsync_i_reg;
reg  [2:0]  vsync_i_reg;
reg  [2:0]  de_i_reg   ;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        hsync_i_reg <= 3'b0;
        vsync_i_reg <= 3'b0;
        de_i_reg    <= 3'b0;
    end
    else begin  
        hsync_i_reg <= {hsync_i_reg[1:0], hsync_i};
        vsync_i_reg <= {vsync_i_reg[1:0], vsync_i};
        de_i_reg    <= {de_i_reg   [1:0], de_i   };
    end
end

assign hsync_o = hsync_i_reg[2];
assign vsync_o = vsync_i_reg[2];
assign de_o    = de_i_reg   [2];

endmodule
