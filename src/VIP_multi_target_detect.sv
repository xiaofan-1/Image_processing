
//多个运动目标检测&计数

//作者：大磊

//QQ : 3183701261

//B站 ：大磊FPGA

module VIP_multi_target_detect
#(
	parameter	[9:0]	IMG_HDISP = 10'd640, 
	parameter	[9:0]	IMG_VDISP = 10'd480  
)                                            
(                                            
	input					clk,  				 
	input					rst_n,				 
												 
	input					per_frame_vsync,	 
	input					per_frame_href,		 
	input					per_frame_clken,	 
	input	 				per_img_Bit,		 
	
	output	reg	[40:0]		target_pos_out [15:0],	// {Flag,ymax[39:30],xmax[29:20],ymin[19:10],xmin[9:0]}
    output  reg [ 3:0]      target_num_out,         //最终目标数目      
    output  reg             target_pos_valid,       //目标合并完成，输出目标地址有效

 	input		[ 9:0]		MIN_DIST	,
	input					disp_sel    
);

//------------------------------------------
//lag 1 clocks signal sync  
reg			per_frame_vsync_r;
reg			per_frame_href_r;	
reg			per_frame_clken_r;
reg      	per_img_Bit_r;

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		per_frame_vsync_r 	<= 0;
		per_frame_href_r 	<= 0;
		per_frame_clken_r 	<= 0;
		per_img_Bit_r		<= 8'd0;
		end
	else
		begin
		per_frame_vsync_r 	<= 	per_frame_vsync	;
		per_frame_href_r	<= 	per_frame_href	;
		per_frame_clken_r 	<= 	per_frame_clken	;
		per_img_Bit_r		<= 	per_img_Bit		;
		end
end

wire vsync_pos_flag;//场同步信号上升沿
wire vsync_neg_flag;//场同步信号下降沿

assign vsync_pos_flag = per_frame_vsync & (~per_frame_vsync_r);
assign vsync_neg_flag = (~per_frame_vsync) & per_frame_vsync_r;

//------------------------------------------
//对输入的像素进行"行/场"方向计数，得到其纵横坐标
reg [9:0]  	x_cnt;
reg [9:0]   y_cnt;

always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
			x_cnt <= 10'd0;
			y_cnt <= 10'd0;
	end
	else if(per_frame_vsync)begin
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
reg  [40:0]	target_pos		[15:0] ;	//寄存各个运动目标的边界 

wire [15:0] target_flag;				//各目标的有效标志
wire [ 9:0] target_left 	[15:0] ;	//各目标的左/右/上/下边界  
wire [ 9:0] target_right 	[15:0] ;								 
wire [ 9:0] target_top		[15:0] ;								 
wire [ 9:0] target_bottom	[15:0] ;								 

wire [ 9:0] target_boarder_left 	[15:0] ;	//各目标的左/右/上/下边界  
wire [ 9:0] target_boarder_right 	[15:0] ;								 
wire [ 9:0] target_boarder_top		[15:0] ;								 
wire [ 9:0] target_boarder_bottom	[15:0] ;	

generate
genvar i; 
	for(i=0; i<16; i = i+1) begin: voluation    
		assign target_flag[i] 		=  target_pos[i][40]; 
		
		assign target_bottom[i] 	=  (target_pos[i][39:30] < IMG_VDISP-1 - MIN_DIST  ) ? (target_pos[i][39:30] + MIN_DIST) : IMG_VDISP-1;	//下边界的像素坐标
		assign target_right[i] 		=  (target_pos[i][29:20] < IMG_HDISP-1 - MIN_DIST  ) ? (target_pos[i][29:20] + MIN_DIST) : IMG_HDISP-1;	//右边界的像素坐标
		assign target_top[i] 		=  (target_pos[i][19:10] > 10'd0       + MIN_DIST  ) ? (target_pos[i][19:10] - MIN_DIST) : 10'd0;		//上边界的像素坐标
		assign target_left[i] 		=  (target_pos[i][ 9: 0] > 10'd0       + MIN_DIST  ) ? (target_pos[i][ 9: 0] - MIN_DIST) : 10'd0;		//左边界的像素坐标

		assign target_boarder_bottom[i] 	=  target_pos[i][39:30];	//下边界的像素坐标
		assign target_boarder_right[i] 		=  target_pos[i][29:20];	//右边界的像素坐标
		assign target_boarder_top[i] 		=  target_pos[i][19:10];	//上边界的像素坐标
		assign target_boarder_left[i] 		=  target_pos[i][ 9: 0];	//左边界的像素坐标

	end
endgenerate 

//------------------------------------------
//检测并标记目标需要两个像素时钟 
integer j ;
reg [ 3:0] target_cnt;
reg [15:0] new_target_flag;		//检测到新目标的投票箱	 

always@(posedge clk or negedge rst_n)begin
	if(!rst_n) begin
		//初始化各运动目标的边界为0
		for(j=0; j<16; j = j+1) begin	
			target_pos[j] <= {1'b0,10'd0,10'd0,10'd0,10'd0};
		end
		new_target_flag	<= 16'd0;
		target_cnt 		<= 4'd0;
	end
		//在一帧开始进行初始化
	else if(vsync_neg_flag)begin  
		for(j=0; j<16; j = j+1) begin	
			target_pos[j] <= {1'b0,10'd0,10'd0,10'd0,10'd0};
		end
		new_target_flag	<= 16'd0;
		target_cnt 		<= 4'd0;
	end  
	else begin 
	//------------------------------------------
    //第一个时钟周期，找出标记为运动目标的像素点，由运动目标列表中的元素进行投票，判断是否为全新的运动目标
		if(per_frame_clken && per_img_Bit ) begin		 
			for(j=0; j<16; j = j+1) begin
				if(target_flag[j] == 1'b0) begin		//运动目标列表中的数据无效，则该元素投票认定输入的灰度为新的最大值					
					new_target_flag[j] <= 1'b1; 
				end	
				else begin								//运动目标列表中的数据有效，则判断当前像素是否落在该元素临域里
					if((x_cnt < target_left[j])||(x_cnt > target_right[j])||(y_cnt < target_top[j])||(y_cnt > target_bottom[j])) begin 
						new_target_flag[j] <= 1'b1;		//如果坐标距离超出目标临域范围，投票认定为新的目标
					end	
					else begin
						new_target_flag[j] <= 1'b0;		//否则不认定为新的目标	
					end
				end
			end
		end
		else begin
            new_target_flag	<= 16'd0;					//输入像素点不是运动目标 
        end  
		
        //------------------------------------------
		//第二个时钟周期，根据投票结果，将候选数据更新到运动目标列表中
		if(per_frame_clken_r && per_img_Bit_r) begin 
			if(new_target_flag == 16'hffff)begin  		//全票通过，标志着出现新的运动目标 
				target_pos[target_cnt] <= {1'b1,y_cnt_r,x_cnt_r,y_cnt_r,x_cnt_r};
				target_cnt <= target_cnt + 1'b1;
			end	
			else if (new_target_flag > 16'd0)begin		//出现被标记为运动目标的像素点，但是落在运动目标列表中某个元素的临域内
			
				for(j=0; j<16; j = j+1) begin	       	//遍历运动目标列表，扩展其中各元素的临域范围
				
					if(new_target_flag[j] == 1'b0) begin //未投票认定为新目标的元素，表示当前像素位于它的临域内
					
						target_pos[j][40] 		<= 1'b1; 
						
						if(x_cnt_r < target_pos[j][ 9: 0] )		//若X坐标小于左边界，则将其X坐标扩展为左边界
							target_pos[j][ 9: 0] <= x_cnt_r ;
							
						if(x_cnt_r > target_pos[j][29:20] )		//若X坐标大于右边界，则将其X坐标扩展为右边界
							target_pos[j][29:20] <=	x_cnt_r ;
							
						if(y_cnt_r < target_pos[j][19:10] )		//若Y坐标小于上边界，则将其Y坐标扩展为上边界
							target_pos[j][19:10] <=	y_cnt_r ;
							
						if(y_cnt_r > target_pos[j][39:30] )		//若Y坐标大于下边界，则将其Y坐标扩展为下边界
							target_pos[j][39:30] <=	y_cnt_r ;

					end
				end
				
			end  
		end
	end 
end 

/////////////////////////////////////////
//一帧统计结束后，寄存输出结果
integer k;

reg [ 3:0] repet_target_cnt;    //用于排除重复的目标
reg [ 3:0] check_target_cnt;    //用于排除重复的目标
reg [ 3:0] valid_target_cnt;    //最终有效的目标数
reg [ 3:0] delete_repet_state;  //状态机，用于查找并删除重复目标

reg	[40:0] target_pos_reg[15:0];//临时寄存各坐标

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) begin
		for(k=0; k<16; k = k+1) begin	
			target_pos_out[k] <= {1'b0,10'd0,10'd0,10'd0,10'd0};
			target_pos_reg[k] <= {1'b0,10'd0,10'd0,10'd0,10'd0};
		end
        
        repet_target_cnt    <= 4'd0;
        check_target_cnt    <= 4'd0;
        valid_target_cnt    <= 4'd0;
        target_pos_valid    <= 1'b0;
        delete_repet_state  <= 4'd0;
        
        target_num_out      <= 4'd0;
	end
	else begin
        case(delete_repet_state)
            4'd0: begin
                if(vsync_pos_flag)begin                     //一帧统计结束后，输出寄存器清零，开始查找并删除重复目标
                    for(k=0; k<16; k = k+1) begin	
                        target_pos_out[k] <= {1'b0,10'd0,10'd0,10'd0,10'd0};
                        target_pos_reg[k] <= target_pos[k]; //寄存各目标结果
                    end
                    
                    repet_target_cnt    <= 4'd0;            //从第0个目标开始排除
                    check_target_cnt    <= 4'd1;            //由第1目标开始比较（0目标不必和自己比较）
                    valid_target_cnt    <= 4'd0;
                    target_pos_valid    <= 1'b0;
                    delete_repet_state  <= 4'd1;
                end
            end
    
            4'd1: begin
                if(target_pos_reg[repet_target_cnt][40] == 1'b0) begin    //如果当前目标的FLAG标志位为0，则所有目标遍历完成    
                    target_pos_valid    <= 1'b1;
                    delete_repet_state  <= 4'd0;
                    
                    target_num_out      <= valid_target_cnt; //寄存最终合并之后的目标数目
                end
                else if(target_pos_reg[check_target_cnt][40] == 1'b0) begin    //如果比较目标的FLAG标志位为0，则当前目标检查完成    
                    delete_repet_state  <= 4'd2;
                end
                else begin  //目标有效，则与其余各目标比较，判断是否有重叠区域
                
                    //没有重叠区域，则与下一目标继续比较
                    if((target_pos_reg[repet_target_cnt][ 9: 0] > target_pos_reg[check_target_cnt][29:20]) ||       //左边界大于右边界
                        (target_pos_reg[repet_target_cnt][29:20] < target_pos_reg[check_target_cnt][ 9: 0]) ||      //右边界小于左边界
                            (target_pos_reg[repet_target_cnt][19:10] > target_pos_reg[check_target_cnt][39:30]) ||  //上边界大于下边界
                                (target_pos_reg[repet_target_cnt][39:30] < target_pos_reg[check_target_cnt][19:10]) //下边界小于上边界
                                    ) begin   
                        if(check_target_cnt < 4'd15) begin  //继续比较下一个目标
                            check_target_cnt    <= check_target_cnt + 1'b1;
                            delete_repet_state  <= 4'd1;
                        end
                        else begin
                            delete_repet_state  <= 4'd2;    //比较到最后一个目标，当前目标检查完成
                        end    
                    end
                    //有重叠区域，将当前目标的坐标合并到比较目标中，同时排除掉当前目标
                    else begin                           
						if(target_pos_reg[repet_target_cnt][ 9: 0] < target_pos_reg[check_target_cnt][ 9: 0] )		//若X坐标小于左边界，则将其X坐标扩展为左边界
							target_pos_reg[check_target_cnt][ 9: 0] <= target_pos_reg[repet_target_cnt][ 9: 0] ;
							
						if(target_pos_reg[repet_target_cnt][29:20] > target_pos_reg[check_target_cnt][29:20] )		//若X坐标大于右边界，则将其X坐标扩展为右边界
							target_pos_reg[check_target_cnt][29:20] <=	target_pos_reg[repet_target_cnt][29:20] ;
							
						if(target_pos_reg[repet_target_cnt][19:10]  < target_pos_reg[check_target_cnt][19:10] )		//若Y坐标小于上边界，则将其Y坐标扩展为上边界
							target_pos_reg[check_target_cnt][19:10] <=	target_pos_reg[repet_target_cnt][19:10]  ;
							
						if(target_pos_reg[repet_target_cnt][39:30] > target_pos_reg[check_target_cnt][39:30] )		//若Y坐标大于下边界，则将其Y坐标扩展为下边界
							target_pos_reg[check_target_cnt][39:30] <=	target_pos_reg[repet_target_cnt][39:30] ;

                        if(repet_target_cnt < 4'd14) begin      //继续排除下一个目标
                            repet_target_cnt    <= repet_target_cnt + 1'b1;
                            check_target_cnt    <= repet_target_cnt + 4'd2;
                            delete_repet_state  <= 4'd1;
                        end
                        else begin
                            repet_target_cnt    <= repet_target_cnt + 1'b1; //最后一个目标直接输出 
                            delete_repet_state  <= 4'd2;
                        end
                    end
                end
            end
          
            4'd2: begin //目标检查完成，没有重复目标，将该目标写入最终的输出接口
                target_pos_out[valid_target_cnt] <= target_pos_reg[repet_target_cnt];
                
                valid_target_cnt        <= valid_target_cnt + 1'b1; 
                
                if(repet_target_cnt < 4'd14) begin //检查下一个目标
                    repet_target_cnt    <= repet_target_cnt + 1'b1; //最大值为14
                    check_target_cnt    <= repet_target_cnt + 4'd2; //最大值为15
                    delete_repet_state  <= 4'd1;    //继续排除
                end
                else if(repet_target_cnt == 4'd14) begin   //下一个目标为最后一个目标，不用检查，直接输出
                    repet_target_cnt    <= repet_target_cnt + 1'b1; //最后一个目标为15
                    delete_repet_state  <= 4'd2;    //直接输出
                end
                else begin
                    target_pos_valid    <= 1'b1;    //所有目标比较完成
                    delete_repet_state  <= 4'd0;
                    
                    target_num_out      <= valid_target_cnt; //寄存最终合并之后的目标数目
                end
            end
    
        endcase
        
    end
end

/*
/////////////////////////////////////////
//一帧统计结束后，寄存输出结果
integer k;

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) begin
		for(k=0; k<16; k = k+1) begin	
			target_pos_out[k] <= {1'b0,10'd0,10'd0,10'd0,10'd0};
		end
	end
	else if(vsync_pos_flag)begin   //一帧统计结束后，寄存输出结果
		for(k=0; k<16; k = k+1) begin	
			target_pos_out[k] <= target_pos[k];
		end
    end
end
*/

endmodule 