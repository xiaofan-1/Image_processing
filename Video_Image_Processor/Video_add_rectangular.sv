`timescale 1ns/1ns

module Video_add_rectangular #(
    parameter   [11:0]  IMG_HDISP = 12'd1280    ,
    parameter   [11:0]  IMG_VDISP = 12'd720
)(
    input   wire            clk                  ,
    input   wire            rst_n                ,
    input   wire            hsync_i              ,
    input   wire            vsync_i              ,
    input   wire            de_i                 ,
    input   wire    [23:0]  rgb_data_i           ,

    input   wire    [48:0]  target_pos_out[15:0] ,

    // 接收颜色识别传来的坐标
    input   wire    [11:0]  color_x_min          ,
    input   wire    [11:0]  color_x_max          ,
    input   wire    [11:0]  color_y_min          ,
    input   wire    [11:0]  color_y_max          ,
         
    (* MARK_DEBUG="true" *)output  reg             hsync_o              ,
    (* MARK_DEBUG="true" *)output  reg             vsync_o              ,
    (* MARK_DEBUG="true" *)output  reg             de_o                 ,
    (* MARK_DEBUG="true" *)output  wire    [23:0]  rgb_data_o           
);

(* MARK_DEBUG="true" *)reg [11:0]  x_cnt;
(* MARK_DEBUG="true" *)reg [11:0]  y_cnt;

//------------------------------------------
//对输入的像素进行 行/场 方向计数，得到其纵横坐标。
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        x_cnt <= 12'd0;
        y_cnt <= 12'd0;
    end
    else if(vsync_i) begin
        x_cnt <= 12'd0;
        y_cnt <= 12'd0;
    end
    else if(de_i) begin
        if(x_cnt < IMG_HDISP - 1) begin
            x_cnt <= x_cnt + 1'b1;
            y_cnt <= y_cnt;
        end
        else begin
            x_cnt <= 12'd0;
            y_cnt <= y_cnt + 1'b1;
        end
    end
end

//------------------------------------------
//寄存坐标
(* MARK_DEBUG="true" *)reg [11:0]  x_cnt_r;
(* MARK_DEBUG="true" *)reg [11:0]  y_cnt_r;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        x_cnt_r <= 12'd0;
        y_cnt_r <= 12'd0;
    end
    else begin
        x_cnt_r <= x_cnt;
        y_cnt_r <= y_cnt;
    end
end

//------------------------------------------
//lag 2 clocks signal sync  
reg         hsync_i_r    ;
reg         vsync_i_r    ;
reg         de_i_r       ;
reg [23:0]  rgb_data_i_r ;
reg [23:0]  rgb_data_i_r2;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        hsync_o     <= 0;
        vsync_o     <= 0;
        de_o        <= 0;
        
        hsync_i_r   <= 0;
        vsync_i_r   <= 0;
        de_i_r      <= 0;
        
        rgb_data_i_r <= 24'b0;
        rgb_data_i_r2<= 24'b0;
        end
    else begin
        hsync_i_r   <= hsync_i;
        vsync_i_r   <= vsync_i;
        de_i_r      <= de_i;

        hsync_o     <= hsync_i_r;
        vsync_o     <= vsync_i_r;
        de_o        <= de_i_r;

        rgb_data_i_r <= rgb_data_i;
        rgb_data_i_r2<= rgb_data_i_r;
    end
end



//------------------------------------------
//祛除重叠的边框

//------------------------------------------
//各目标的左/右/上/下边界
wire [15:0] target_flag;
wire [11:0] target_boarder_left     [15:0] ;
wire [11:0] target_boarder_right    [15:0] ;
wire [11:0] target_boarder_top      [15:0] ;
wire [11:0] target_boarder_bottom   [15:0] ;

generate
genvar i; 
    for(i=0; i<16; i = i+1) begin: voluation    
        assign target_flag[i] 				=  target_pos_out[i][48]; 
        
        assign target_boarder_bottom[i] 	=  target_pos_out[i][47:36];	//下边界的像素坐标
        assign target_boarder_right[i] 		=  target_pos_out[i][35:24];	//右边界的像素坐标
        assign target_boarder_top[i] 		=  target_pos_out[i][23:12];	//上边界的像素坐标
        assign target_boarder_left[i] 		=  target_pos_out[i][11: 0];	//左边界的像素坐标

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

// assign	post_img_red	=	(border_flag_final_r) ? 8'd255 :	per_img_red_r2	 ;			
// assign	post_img_green	=	(border_flag_final_r) ? 8'd000 :	per_img_green_r2 ;		
// assign	post_img_blue	=	(border_flag_final_r) ? 8'd000 :   per_img_blue_r2	 ;

// 颜色框判断
wire draw_color_box ;
assign draw_color_box = ((y_cnt == color_y_min || y_cnt == color_y_max) 
                       && (x_cnt >= color_x_min && x_cnt <= color_x_max)) 
                    || ((x_cnt == color_x_min || x_cnt == color_x_max) 
                       && (y_cnt >= color_y_min && y_cnt <= color_y_max));

// 输出优先级：运动框 > 颜色框 > 原图
assign rgb_data_o = (border_flag_final_r && !inter_border_flag_final) ? 24'hff_00_00 :  // 红色运动框
                    draw_color_box      ? 24'h00_ff_00 :  // 绿色颜色框
                    rgb_data_i_r2;                         // 原图

// assign rgb_data_o = border_flag_final_r ? 24'hff_00_00 : rgb_data_i_r2;

always@(posedge clk or negedge rst_n)begin
    if(!rst_n) begin
        border_flag			<= 16'd0;
        inter_border_flag	<= 16'd0;
    end
    else begin 
    //------------------------------------------
    //第一个时钟周期，判断当前像素点是否位于边框上
        if(de_i) begin
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
        if(de_i_r && border_flag_final ) begin		 
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