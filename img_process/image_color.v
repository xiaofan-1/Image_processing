`timescale 1ns / 1ps

module image_color(
    input	wire            clk           ,
    input	wire            rst_n         ,
              
    input   wire            hsync_i       ,//行信号
    input   wire            vsync_i       ,//场信号
    input   wire            de_i          ,
    input   wire    [23:0]  data_i        ,//
              
    input   wire            key2_flag     ,
    input   wire            key3_flag     ,
    input   wire            key4_flag     ,
      
    input   wire    [10:0]  pixel_x       ,
    input   wire    [10:0]  pixel_y       ,
    
    input   wire    [11:0]  frame_top     ,
    input   wire    [11:0]  frame_bottom  ,
    input   wire    [11:0]  frame_left    ,
    input   wire    [11:0]  frame_right   ,

    output  reg     [11:0]  x_min_r       ,
    output  reg     [11:0]  x_max_r       ,
    output  reg     [11:0]  y_min_r       ,
    output  reg     [11:0]  y_max_r       ,
    
    (* MARK_DEBUG="true" *)output  wire [11:0] pixle_x_reg   ,
    (* MARK_DEBUG="true" *)output  wire [11:0] pixle_y_reg   ,
    
    output  wire            hsync_o       ,
    output  wire            vsync_o       ,
    (* MARK_DEBUG="true" *)output  wire            de_o          ,
    (* MARK_DEBUG="true" *)output  reg     [23:0]  data_o        //
    );
    
wire	[2:0]	color_threshold_select	;
wire	[2:0]	color_threshold_select_eth	;
wire	[7:0]	data_color;

wire        	hs_reg;
wire        	vs_reg;
(* MARK_DEBUG="true" *)wire        	de_reg;

// 【修改点】：扩大寄存器阵列深度，以容纳新增的 17 拍延迟
reg [23:0] rgb_data_pipe [63:0];
reg [11:0] pixel_x_pipe [63:0];
(* dont_touch="true" *)reg [11:0] pixel_y_pipe [63:0];
reg [7:0]  data_color_pipe [63:0];
reg        de_reg_pipe [63:0];

reg        hsync_i_reg_pipe[63:0];
reg        vsync_i_reg_pipe[63:0];
reg        de_i_reg_pipe   [63:0];

integer i;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for (i = 0; i < 64; i = i + 1) begin
            rgb_data_pipe[i] <= 24'h0;
            hsync_i_reg_pipe[i] <= 1'b0;
            vsync_i_reg_pipe[i] <= 1'b0;
            de_i_reg_pipe[i] <= 1'b0;
            de_reg_pipe[i] <= 1'b0;
            data_color_pipe[i] <= 8'h0;
        end
    end
    else begin
        rgb_data_pipe[0] <= data_i;
        hsync_i_reg_pipe[0] <= hsync_i;
        vsync_i_reg_pipe[0] <= vsync_i;
        de_i_reg_pipe[0] <= de_i;
        de_reg_pipe[0] <= de_reg;
        data_color_pipe[0] <= data_color;
        for (i = 1; i < 64; i = i + 1) begin
            rgb_data_pipe[i] <= rgb_data_pipe[i-1];
            hsync_i_reg_pipe[i] <= hsync_i_reg_pipe[i-1];
            vsync_i_reg_pipe[i] <= vsync_i_reg_pipe[i-1];
            de_i_reg_pipe[i] <= de_i_reg_pipe[i-1];
            de_reg_pipe[i] <= de_reg_pipe[i-1];
            data_color_pipe[i] <= data_color_pipe[i-1];
        end
    end
end

integer j;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for (j = 0; j < 64; j = j + 1) begin
            pixel_x_pipe[j] <= 12'h0;
            pixel_y_pipe[j] <= 12'h0;
        end
    end
    else begin
        pixel_x_pipe[0] <= pixel_x;
        pixel_y_pipe[0] <= pixel_y;
        for (j = 1; j < 64; j = j + 1) begin
            pixel_x_pipe[j] <= pixel_x_pipe[j-1];
            pixel_y_pipe[j] <= pixel_y_pipe[j-1];
        end
    end
end

(* MARK_DEBUG="true" *)wire [23:0] rgb_data_reg;

(* MARK_DEBUG="true" *)wire [11:0] pixel_x_reg_font;
(* MARK_DEBUG="true", dont_touch="true" *)wire [11:0] pixel_y_reg_font;
(* MARK_DEBUG="true" *)wire [7:0]  data_color_reg;
(* MARK_DEBUG="true" *)wire        de_reg_font;

// 【修复点】：由于 pixel_x 从 Top.sv 引入时已经与 data_i 严格对齐，
// 因此它的延迟深度必须与 rgb_data_reg(44拍) 保持完全一致，不再需要错开 25 拍。
assign rgb_data_reg = rgb_data_pipe[44];  
assign pixle_x_reg = pixel_x_pipe[44];    
assign pixle_y_reg = pixel_y_pipe[44];    

// data_color 信号已经内置了延迟，保持不变！
assign data_color_reg = data_color_pipe[13]; 
assign de_reg_font = de_reg_pipe[13];

// Font ROM 有大约 2 拍的读取延迟 (ROM流水线), 
// 为了让 ROM 的输出在第 44 拍时可用，我们需要在第 44-2=42 拍将坐标送入 ROM。
assign pixel_x_reg_font = pixel_x_pipe[42]; 
assign pixel_y_reg_font = pixel_y_pipe[42]; 

assign hsync_o = hsync_i_reg_pipe[45]; // 28 + 17 = 45
assign vsync_o = vsync_i_reg_pipe[45]; // 28 + 17 = 45
assign de_o    = de_i_reg_pipe   [45]; // 28 + 17 = 45

// colour_extract_ctrl入口选择参数
reg	[2:0]	SELECT_BIT	;
reg	[8:0]	ADD_VALUE	;
reg	[7:0]	THRESHOLD	;

// colour_extract_ctrl入口颜色寄存参数
reg	[8:0]	ADD_VALUE_GREEN ;
reg	[8:0]	ADD_VALUE_RED	;
reg	[8:0]	ADD_VALUE_BLUE	;
reg	[8:0]	ADD_VALUE_YELLOW;
reg	[7:0]	THRESHOLD_GREEN ;
reg	[7:0]	THRESHOLD_RED	;
reg	[7:0]	THRESHOLD_BLUE	;
reg	[7:0]	THRESHOLD_YELLOW;

localparam pix_h = 1280,
           pix_v = 720;
               
reg  [11:0]  x,y;
wire add_x = de_reg;
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
        vsync_reg0 <= ~vs_reg;
        vsync_reg1 <= vsync_reg0;
    end
end

wire pos_vsync = (vsync_reg0 && ~vsync_reg1);
wire neg_vsync = (~vsync_reg0 && vsync_reg1);

wire    pixel_valid;
assign pixel_valid = (data_color == 8'h0 && x > frame_left && x < frame_right && y > frame_top && y < frame_bottom);
// 记录边界（极值法）
reg [10:0] x_min, x_max, y_min, y_max;

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

(* MARK_DEBUG="true" *)wire	[23:0]	font_rom_data;
wire	[23:0]	font_rom_data_eth;
wire	[23:0]	char_data;

font_rom font_rom_u(
    /*input		wire			*/.clk			(clk					),
    /*input		wire			*/.rst_n		(rst_n					),
    /*input		wire 	[10:0]  */.pixel_x		(pixel_x_reg_font		),
    /*input		wire 	[10:0]	*/.pixel_y		(pixel_y_reg_font		),
    /*input		wire			*/.de			(de_reg_font			),
    /*input		wire			*/.vsync		(vsync_i				),  // 帧同步
    /*input		wire			*/.key			(key2_flag				),
    /*output	wire	[2:0]	*/.color_select	(color_threshold_select	),
    /*output 	reg  	[23:0] 	*/.data_o		(font_rom_data			)	
);

// =============数据输出====================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_o <= 24'b0;
	else if(pixle_y_reg < 50 && pixle_x_reg < 50)begin
		if(font_rom_data != 24'hff_ff_ff)
			data_o <= 24'hff_00_a0;
		else
			data_o <= rgb_data_reg;
	end
	else if(data_color_reg == 8'h0 && pixle_x_reg > frame_left && pixle_x_reg < frame_right && pixle_y_reg > frame_top && pixle_y_reg < frame_bottom)
		case(color_threshold_select)
			4'd1:data_o <= 24'hfe_00_00;
			4'd2:data_o <= 24'h00_fe_00;
			4'd3:data_o <= 24'h00_00_fe;
			4'd4:data_o <= 24'hfe_fe_00;
			default:data_o <= rgb_data_reg;
		endcase
	else
		data_o <= rgb_data_reg;
end

/***************************************************************
模块功能 ： 通过按键调节阈值，可以适应不同光环境
***************************************************************/
always@(posedge	clk or negedge rst_n) begin
    if(!rst_n ) begin
        ADD_VALUE_GREEN   <= 9'd120;
        ADD_VALUE_RED	  <= 9'd240;
        ADD_VALUE_BLUE	  <= 9'd0;
        ADD_VALUE_YELLOW  <= 9'd180;//黄
        THRESHOLD_GREEN   <= 8'd140;
        THRESHOLD_RED	  <= 8'd175;
        THRESHOLD_BLUE	  <= 8'd160;
        THRESHOLD_YELLOW  <= 8'd200;
    end
    else begin
        case(color_threshold_select)
            3'd1 : begin
                        if(key4_flag == 1'b1)//红色二值化阈值
                            THRESHOLD_RED	<= THRESHOLD_RED + 1'd1;
                        else	if(key3_flag == 1'b1)
                            THRESHOLD_RED	<= THRESHOLD_RED - 1'd1;
                        else
                            THRESHOLD_RED	<= THRESHOLD_RED;
                     end
            3'd2 : begin
                        if(key4_flag == 1'b1)//绿色二值化阈值
                            THRESHOLD_GREEN	<= THRESHOLD_GREEN + 1'd1;
                        else	if(key3_flag == 1'b1)
                            THRESHOLD_GREEN	<= THRESHOLD_GREEN - 1'd1;
                        else
                            THRESHOLD_GREEN	<= THRESHOLD_GREEN;
                     end
            
            3'd3 : begin
                        if(key4_flag == 1'b1)//蓝色二值化阈值
                            THRESHOLD_BLUE	<= THRESHOLD_BLUE + 1'd1;
                        else	if(key3_flag == 1'b1)
                            THRESHOLD_BLUE	<= THRESHOLD_BLUE - 1'd1;
                        else
                            THRESHOLD_BLUE	<= THRESHOLD_BLUE;
                     end
            3'd4 : begin
                        if(key4_flag == 1'b1)//黑色二值化阈值
                            THRESHOLD_YELLOW	<= THRESHOLD_YELLOW + 1'd1;
                        else	if(key3_flag == 1'b1)
                            THRESHOLD_YELLOW	<= THRESHOLD_YELLOW - 1'd1;
                        else
                            THRESHOLD_YELLOW	<= THRESHOLD_YELLOW;
                     end
            default : ;
        endcase
    end
end
/***************************************************************
模块功能 ： 通过不同参数的传入，提取不同颜色
***************************************************************/
always@(posedge	clk or negedge rst_n) begin
    if(!rst_n ) begin
        SELECT_BIT	<= 3'b0;
        ADD_VALUE	<= 9'd0;
        THRESHOLD	<= 8'd0;
    end
    else begin//启动识别，轮询赋值
        case(color_threshold_select)
        // case(2)
            3'd1 : begin
                        SELECT_BIT	<= 3'b010;
            /*红*/		ADD_VALUE	<= ADD_VALUE_RED;
                        THRESHOLD	<= THRESHOLD_RED;
                    end
            /***********************************************/
            3'd2 :  begin
                        SELECT_BIT	<= 3'b010;
            /*绿*/		ADD_VALUE	<= ADD_VALUE_GREEN;
                        THRESHOLD	<= THRESHOLD_GREEN;
                    end
            /***********************************************/
            3'd3 : begin
                        SELECT_BIT	<= 3'b010;
            /*蓝*/		ADD_VALUE	<= ADD_VALUE_BLUE;
                        THRESHOLD	<= THRESHOLD_BLUE;
                    end
            /***********************************************/
            3'd4 : begin
                        SELECT_BIT	<= 3'b010 ; 
            /*黄*/		ADD_VALUE	<= ADD_VALUE_YELLOW; 
                        THRESHOLD	<= THRESHOLD_YELLOW;
                    end
            /***********************************************/				
            default  : ;
        endcase
    end
end
/***************************************************************
颜色识别
***************************************************************/
image_color_ctrl image_color_ctrl_u(
    .clk   (clk  ),
    .rst_n (rst_n),
    
    .SELECT_BIT	(SELECT_BIT	),
    .ADD_VALUE	(ADD_VALUE	),
    .THRESHOLD	(THRESHOLD	),
    
    .i_rgb_href	(hsync_i),
    .i_rgb_vsync(vsync_i),
    .i_rgb_clken(de_i   ),    
    .i_rgb_r	(data_i[23:16]),
    .i_rgb_g	(data_i[15:8] ),
    .i_rgb_b	(data_i[7:0]  ),
    
    .o_b_extract_href	(hs_reg		),
    .o_b_extract_vsync	(vs_reg		),	
    .o_b_extract_clken	(de_reg		),
    .o_b_extract_data	(data_color )
);	
endmodule