module VIP_Video_add_rectangular
#(
	parameter	[9:0]	IMG_HDISP = 10'd640,//640*480
	parameter	[9:0]	IMG_VDISP = 10'd480
)
(
	//global clock
	input				clk,  				 
	input				rst_n,				 
                                             
	//Image data prepred to be processd      
	input				per_frame_vsync,	 
	input				per_frame_href ,	 
	input				per_frame_clken,	 
	input		[7:0]	per_img_red		,		 
	input		[7:0]	per_img_green	,		 
	input		[7:0]	per_img_blue	,		 
                                             
	input  		[40:0]	target_pos_out[15:0],   
                                             
	//Image data has been processd           
	output reg			post_frame_vsync,	 
	output reg			post_frame_href ,	 
	output reg			post_frame_clken,	 
	output wire	[7:0]	post_img_red	,		 
	output wire	[7:0]	post_img_green	,		 
	output wire	[7:0]	post_img_blue	  	
);

reg [9:0]  	x_cnt;
reg [9:0]   y_cnt;

//------------------------------------------
//对输入的像素进行 行/场 方向计数，得到其纵横坐标。
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
			x_cnt <= 10'd0;
			y_cnt <= 10'd0;
		end
	else
		if(per_frame_vsync)begin
			x_cnt <= 10'd0;
			y_cnt <= 10'd0;
		end
		else if(per_frame_clken) begin
			if(x_cnt < IMG_HDISP - 1) begin
				x_cnt <= x_cnt + 1'b1;
				y_cnt <= y_cnt;
			end
			else begin
				x_cnt <= 10'd0;
				y_cnt <= y_cnt + 1'b1;
			end
		end
end


//------------------------------------------
//寄存坐标
reg [9:0]  	x_cnt_r;
reg [9:0]   y_cnt_r;

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)  begin
        x_cnt_r <= 10'd0;
		y_cnt_r <= 10'd0;
	end
	else begin
		x_cnt_r <= x_cnt;
        y_cnt_r <= y_cnt;
	end
end

//------------------------------------------
//lag 2 clocks signal sync  
reg			per_frame_vsync_r;
reg			per_frame_href_r ;	
reg			per_frame_clken_r;
reg	[7:0]	per_img_red_r	 ;		 
reg	[7:0]	per_img_green_r	 ;		 
reg	[7:0]	per_img_blue_r	 ;	

reg	[7:0]	per_img_red_r2	 ;		 
reg	[7:0]	per_img_green_r2 ;		 
reg	[7:0]	per_img_blue_r2	 ;	

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		per_frame_vsync_r 	<= 0;
		per_frame_href_r 	<= 0;
		per_frame_clken_r 	<= 0;
		
		per_img_red_r	 	<= 0;
		per_img_green_r	 	<= 0;
		per_img_blue_r	 	<= 0;
		
		post_frame_vsync 	<= 0;
		post_frame_href 	<= 0;
		post_frame_clken 	<= 0;	

		per_img_red_r2	 	<= 0;
		per_img_green_r2	<= 0;
		per_img_blue_r2	 	<= 0;		
		end
	else
		begin
		per_frame_vsync_r 	<= 	per_frame_vsync		;
		per_frame_href_r	<= 	per_frame_href		;
		per_frame_clken_r 	<= 	per_frame_clken		;
		
		per_img_red_r	 	<=  per_img_red		;
		per_img_green_r	 	<=  per_img_green	;
		per_img_blue_r	 	<=  per_img_blue	;
		
		post_frame_vsync 	<= 	per_frame_vsync_r 	;
		post_frame_href 	<= 	per_frame_href_r	;
		post_frame_clken 	<= 	per_frame_clken_r 	;
		
		per_img_red_r2	 	<=  per_img_red_r	;
		per_img_green_r2 	<=  per_img_green_r	;
		per_img_blue_r2	 	<=  per_img_blue_r	;
		end
end



//------------------------------------------
//祛除重叠的边框

//------------------------------------------
//各目标的左/右/上/下边界
wire [15:0] target_flag;
wire [ 9:0] target_boarder_left 	[15:0] ;	  
wire [ 9:0] target_boarder_right 	[15:0] ;								 
wire [ 9:0] target_boarder_top		[15:0] ;								 
wire [ 9:0] target_boarder_bottom	[15:0] ;	

generate
genvar i; 
	for(i=0; i<16; i = i+1) begin: voluation    
		assign target_flag[i] 				=  target_pos_out[i][40]; 
		
		assign target_boarder_bottom[i] 	=  target_pos_out[i][39:30];	//下边界的像素坐标
		assign target_boarder_right[i] 		=  target_pos_out[i][29:20];	//右边界的像素坐标
		assign target_boarder_top[i] 		=  target_pos_out[i][19:10];	//上边界的像素坐标
		assign target_boarder_left[i] 		=  target_pos_out[i][ 9: 0];	//左边界的像素坐标

	end
endgenerate 

//------------------------------------------
//检测并标记目标需要两个像素时钟 
integer j ;
reg [15:0] 	border_flag; 			//标志着当前像素点是否位于边框上
reg [15:0] 	inter_border_flag;		//标志着边框位于目标范围内 

wire 		border_flag_final;
reg 		border_flag_final_r;

assign border_flag_final = (border_flag > 16'd0) ? 1'b1 : 1'b0;

//寄存一个时钟周期
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		border_flag_final_r <= 0;	
	end
	else begin
		border_flag_final_r <= 	border_flag_final ;
	end
end

wire inter_border_flag_final;
assign inter_border_flag_final = (inter_border_flag > 16'd0) ? 1'b1 : 1'b0;

//位于边框上，且不位于内部边框上
// assign	post_img_red	=	(border_flag_final_r & (~inter_border_flag_final)) ? 8'd255 :	per_img_red_r2	 ;			
// assign	post_img_green	=	(border_flag_final_r & (~inter_border_flag_final)) ? 8'd000 :	per_img_green_r2 ;		
// assign	post_img_blue	=	(border_flag_final_r & (~inter_border_flag_final)) ? 8'd000 :   per_img_blue_r2	 ;

assign	post_img_red	=	(border_flag_final_r) ? 8'd255 :	per_img_red_r2	 ;			
assign	post_img_green	=	(border_flag_final_r) ? 8'd000 :	per_img_green_r2 ;		
assign	post_img_blue	=	(border_flag_final_r) ? 8'd000 :   per_img_blue_r2	 ;


always@(posedge clk or negedge rst_n)begin
	if(!rst_n) begin
		border_flag			<= 16'd0;
		inter_border_flag	<= 16'd0;
	end
	else begin 
	//------------------------------------------
	//第一个时钟周期，判断当前像素点是否位于边框上
		if(per_frame_clken) begin
			for(j=0; j<16; j = j+1) begin
				if(target_flag[j])begin
					if(((y_cnt == target_boarder_top[j])||(y_cnt == target_boarder_bottom[j]))					//上下边框
						&&((x_cnt >= target_boarder_left[j])&&(x_cnt <= target_boarder_right[j]))) begin		
							border_flag[j] <= 1'b1;
					end	
					else if(((y_cnt >= target_boarder_top[j])&&(y_cnt <= target_boarder_bottom[j]))
						&&((x_cnt == target_boarder_left[j])||(x_cnt == target_boarder_right[j]))) begin		//左右边框
							border_flag[j] <= 1'b1;
					end	 
					else begin
						border_flag[j] <= 1'b0 ;	
					end	
				end
                else
                    border_flag[j] <= 1'b0 ;
			end
		end

	//------------------------------------------
    //第二个时钟周期，判断边框是否位于其他运动目标的范围里，如果是，说明边框有重叠部分，此时内部的边框将不显示
		if(per_frame_clken_r && border_flag_final ) begin		 
			for(j=0; j<16; j = j+1) begin
				if(target_flag[j] == 1'b0) begin		//运动目标列表中的数据无效，则该元素投票边框无重叠					
					inter_border_flag[j] <= 1'b0; 
				end	
				else begin								//运动目标列表中的数据有效，则判断当前像素是否落在运动目标范围里
					if((x_cnt_r > target_boarder_left[j])&&(x_cnt_r < target_boarder_right[j])&&
						(y_cnt_r > target_boarder_top[j])&&(y_cnt_r < target_boarder_bottom[j])) begin 
						inter_border_flag[j] <= 1'b1;		//如果坐标距离位于运动目标范围，投票认定为内部边框
					end	
					else begin
						inter_border_flag[j] <= 1'b0;		//否则不认定为内部边框	
					end
				end
			end
		end
		else begin
            inter_border_flag	<= 16'd0;					//输入像素点不是边框
        end  
		
	end 
end 


endmodule 