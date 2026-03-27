`timescale 1ns/1ns
module VIP_Frame_Difference(
	//global clock
	input				clk,  				//cmos video pixel clock
	input				rst_n,				//global reset

	//Image data prepred to be processd
	input				per_frame_vsync,	//Prepared Image data vsync valid signal
	input				per_frame_href,	//Prepared Image data href vaild  signal
	input				per_frame_clken,	//Prepared Image data output/capture enable clock
	input	[7:0]		per_img_Y_current,			//Prepared Image brightness input
	
	input 	[7:0]		YCbCr_img_Y_previous,		//同时从SDRAM中读出前一帧的灰度

	//Image data has been processd
	output				post_frame_vsync,	//Processed Image data vsync valid signal
	output				post_frame_href,	//Processed Image data href vaild  signal
	output				post_frame_clken,	//Processed Image data output/capture enable clock
	output				post_img_Bit,		//Processed Image Bit flag outout(1: Value, 0:inValid)
    output  [7:0]       post_img_Byte ,
	
	//user interface
	input	[7:0]		user_Threshold		//Sobel Threshold for image edge detect
);

wire YCbCr_img_Y_previous_valid;
reg [7:0] per_img_Y_delay;

//将当前帧灰度延迟一个时钟周期
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		per_img_Y_delay <= 8'd0;	 
	else 
		per_img_Y_delay <= per_img_Y_current;
end

//---------------------------------------
//Compare and get the difference
 
reg	post_img_Bit_r;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		post_img_Bit_r <= 1'b0;	 
	else if(YCbCr_img_Y_previous_valid) begin		//视频灰度数据有效
	
		if(per_img_Y_delay > YCbCr_img_Y_previous) begin
			if(per_img_Y_delay - YCbCr_img_Y_previous > user_Threshold)	//灰度差大于阈值
				post_img_Bit_r <= 1'b1;	//Edge Flag
			else
				post_img_Bit_r <= 1'b0;	//Edge Flag
		end
		else begin
			if(YCbCr_img_Y_previous - per_img_Y_delay > user_Threshold)	//灰度差大于阈值
				post_img_Bit_r <= 1'b1;	//Edge Flag
			else
				post_img_Bit_r <= 1'b0;	//Edge Flag
		end
		
	end
end

reg	[7:0] post_img_Byte_r;
always@(posedge clk or negedge rst_n)begin
	if(!rst_n)
		post_img_Byte_r <= 8'b0;	 
	else if(YCbCr_img_Y_previous_valid) begin		//视频灰度数据有效 
		if(per_img_Y_delay > YCbCr_img_Y_previous)  
			post_img_Byte_r <= (per_img_Y_delay - YCbCr_img_Y_previous);   
		else 
            post_img_Byte_r <= (YCbCr_img_Y_previous - per_img_Y_delay) ;	 
	end
end

//------------------------------------------
//lag 2 clocks signal sync  
reg	[1:0]	per_frame_vsync_r;
reg	[1:0]	per_frame_href_r;	
reg	[1:0]	per_frame_clken_r;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		per_frame_vsync_r <= 0;
		per_frame_href_r <= 0;
		per_frame_clken_r <= 0;
		end
	else
		begin
		per_frame_vsync_r 	<= 	{per_frame_vsync_r[0], 	per_frame_vsync};
		per_frame_href_r	<= 	{per_frame_href_r[0], 	per_frame_href};
		per_frame_clken_r 	<= 	{per_frame_clken_r[0], 	per_frame_clken};
		end
end
assign	post_frame_vsync 	= 	per_frame_vsync_r[1];
assign	post_frame_href 	= 	per_frame_href_r[1];
assign	post_frame_clken 	= 	per_frame_clken_r[1];
assign	post_img_Bit		=	post_frame_href ? post_img_Bit_r : 1'b0;
assign  post_img_Byte       =   post_frame_href ? post_img_Byte_r : 8'b0;



//前一帧的灰度，与当前帧灰度相差一个时钟周期
assign YCbCr_img_Y_previous_valid = per_frame_clken_r[0];


endmodule
