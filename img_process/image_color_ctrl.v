`timescale 1ns / 1ps

module image_color_ctrl(
    input           clk     ,
    input           rst_n ,
    input	[2:0]	SELECT_BIT		,//灰度通道选择
	input	[8:0]	ADD_VALUE		,//H值增量
    input	[7:0]	THRESHOLD		,//二值化阈值
	
    input           i_rgb_vsync		,//输入帧同步
    input           i_rgb_href		,//输出行有效
    input           i_rgb_clken		,//输入时钟有效
    input [7:0]     i_rgb_r			,//R通道
    input [7:0]     i_rgb_g			,//G通道
    input [7:0]     i_rgb_b			,//B通道
	
	output          o_c_extract_vsync	,//灰度帧同步
    output          o_c_extract_href	,//灰度行有效
    output          o_c_extract_clken	,//灰度时钟有效  
    output	[7:0] 	o_c_extract_y		,//灰度灰度值
	output	[7:0] 	o_c_extract_cb		,//灰度蓝色色度
	output	[7:0] 	o_c_extract_cr		,//灰度红色色度
    
    output	reg     o_b_extract_vsync	,//二值化帧同步
    output	reg     o_b_extract_href	,//二值化行有效
    output	reg     o_b_extract_clken	,//二值化时钟有效
    output	reg 	[7:0] 	o_b_extract_data	 //二值化处理数据	  
);

wire			hsv_vsync	; 
wire			hsv_href	; 
wire			hsv_clken	; 
wire	[8:0]	hsv_h		;  
wire	[8:0]	hsv_s		;  
wire	[7:0]	hsv_v		;
wire			hsv_rgb_vsync	; 
wire			hsv_rgb_href	; 
wire			hsv_rgb_clken	; 
wire	[7:0]	hsv_rgb_r		;  
wire	[7:0]	hsv_rgb_g		;  
wire	[7:0]	hsv_rgb_b		;



/***************************************************************
模块功能 ： 将RGB转为HSV
***************************************************************/
rgb2hsv rgb2hsv_u(
    .clk     (clk),
    .reset_n (rst_n),

    .vs      (i_rgb_vsync	),
    .hs      (i_rgb_href	),
    .de      (i_rgb_clken	),
    .rgb_r   (i_rgb_r		),
    .rgb_g   (i_rgb_g		),
    .rgb_b   (i_rgb_b		), 

    .hsv_vs  (hsv_vsync	),     
    .hsv_hs  (hsv_href	),
    .hsv_de  (hsv_clken	),    
    .hsv_h   (hsv_h		),
    .hsv_s   (hsv_s		),
    .hsv_v   (hsv_v		)
);

wire [8:0]	change_h     ;
assign change_h =  (hsv_h + ADD_VALUE >= 360) ?   (hsv_h + ADD_VALUE - 360) : (hsv_h + ADD_VALUE);
/***************************************************************
模块功能 ： 将改变H值后的HSV转化为RGB显示
***************************************************************/
hsv2rgb hsv2rgb_u(
    .clk     (clk),
    .reset_n (rst_n),

    .vs      (hsv_vsync	),
    .hs      (hsv_href	),
    .de      (hsv_clken	),    
    .i_hsv_h (change_h	),
    .i_hsv_s (hsv_s		),
    .i_hsv_v (hsv_v		),

    .rgb_vs  (hsv_rgb_vsync	),
    .rgb_hs  (hsv_rgb_href	),
    .rgb_de  (hsv_rgb_clken	),   
    .rgb_r   (hsv_rgb_r		),
    .rgb_g   (hsv_rgb_g		),
    .rgb_b   (hsv_rgb_b		)
);    
/***************************************************************
模块功能 ：灰度处理模块，可以提取RGB的灰度分量，红色色度分量和蓝色色度分量
***************************************************************/
rgb2ycrcb rgb2ycrcb_u(
    /*input   wire        */.clk       (clk  ),
    /*input   wire        */.rst_n     (rst_n),
    //输入                             
    /*input   wire        */.hsync_i   (hsv_rgb_href	),//行信号
    /*input   wire        */.vsync_i   (hsv_rgb_vsync	),//场信号
    /*input   wire        */.de_i      (hsv_rgb_clken	),
    /*input   wire [23:0] */.data_i    ({hsv_rgb_r,hsv_rgb_g,hsv_rgb_b} ),//
    //输出                            
    /*output  wire        */.hsync_o   (o_c_extract_href	),
    /*output  wire        */.vsync_o   (o_c_extract_vsync	),
    /*output  wire        */.de_o      (o_c_extract_clken	),
	/*output  wire [7:0]  */.data_y    (o_c_extract_y   ), 
	/*output  wire [7:0]  */.data_cb   (o_c_extract_cb), 
    /*output  wire [7:0]  */.data_cr   (o_c_extract_cr) 
);

	
wire	[7:0]	s_data;

assign	s_data = SELECT_BIT[0] ? o_c_extract_y : (SELECT_BIT[1] ? o_c_extract_cb : (SELECT_BIT[2] ? o_c_extract_cr : 8'd0));

//二值化处理数据
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		o_b_extract_vsync	<= 1'b0;	
		o_b_extract_href	<= 1'b0;
		o_b_extract_clken	<= 1'b0;
		o_b_extract_data	<= 8'b0;
	end
	else	begin
		o_b_extract_vsync	<= o_c_extract_vsync;	
		o_b_extract_href	<= o_c_extract_href;
        o_b_extract_clken	<= o_c_extract_clken;
        
		o_b_extract_data	<= s_data > THRESHOLD ? 8'h0 : 8'hff;			
																		  
	end
end

endmodule