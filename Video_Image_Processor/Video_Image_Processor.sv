
//视频图像处理模块，实现多个运动目标的检测与计数

//作者：大磊

//QQ : 3183701261

//B站 ：大磊FPGA


`timescale 1ns/1ns
module Video_Image_Processor
#(
	parameter	[10:0]	IMG_HDISP = 10'd640,	//640*480
	parameter	[10:0]	IMG_VDISP = 10'd480
)
(
	//global clock
	input				clk					,  	 
	input				rst_n				,	 
												 
	//来自摄像头的当前帧         
	input				per_frame_vsync		,	 
	input				per_frame_href		,	 
	input				per_frame_clken		,	 
	input		[7:0]	per_img_red			,	 
	input		[7:0]	per_img_green		,	 
	input		[7:0]	per_img_blue		,	 
												 
	//将当前帧转成灰度数据输出，用于缓存到SDRAM          
	output				YCbCr_frame_vsync	,	 
	output				YCbCr_frame_href	,	 
	output				YCbCr_frame_clken	,	 
	output		[7:0]	YCbCr_img_Y_current	,	
	
	//来自SDRAM的前一帧灰度图像
	input		[7:0]	YCbCr_img_Y_previous, 	 
												 
	//输出帧差运动目标检测之后的结果      
	output				post_frame_vsync	,	 
	output				post_frame_href		,	 
	output				post_frame_clken	,	 
	output		[7:0]	post_img_red		,	 
	output		[7:0]	post_img_green		,	 
	output		[7:0]	post_img_blue		,
    
    output      [3:0]   target_num_out      ,   //最终目标数目      

    //user interface
	input		[7:0]	Diff_Threshold	    ,	//  帧差阈值
	input		[9:0]	MIN_DIST			    //	多目标之间的最小间距
);

//-------------------------------------------------------------------------
//彩色转灰度

wire 			post0_frame_vsync;   
wire 			post0_frame_href ;   
wire 			post0_frame_clken;    
wire [7:0]		post0_img_Y      ;   
wire [7:0]		post0_img_Cb     ;   
wire [7:0]		post0_img_Cr     ;   

VIP_RGB888_YCbCr444 u_VIP_RGB888_YCbCr444(
	.clk					(clk),  			  
	.rst_n					(rst_n),			  
												  
	//Image data prepred to be processd           
	.per_frame_vsync		(per_frame_vsync),	  
	.per_frame_href			(per_frame_href),	  
	.per_frame_clken		(per_frame_clken),	  
	.per_img_red			(per_img_red),		  
	.per_img_green			(per_img_green),	  
	.per_img_blue			(per_img_blue),		  
	
	//Image data has been processd
	.post_frame_vsync		(post0_frame_vsync),
	.post_frame_href		(post0_frame_href),	
	.post_frame_clken		(post0_frame_clken),
	.post_img_Y				(post0_img_Y),		
	.post_img_Cb			(post0_img_Cb),		
	.post_img_Cr			(post0_img_Cr)		
);


//--------------------------------------------------------------
//将色彩空间转换之后的灰度图像输出

assign		YCbCr_frame_vsync		=	post0_frame_vsync	;
assign		YCbCr_frame_href		=	post0_frame_href	;	
assign		YCbCr_frame_clken		=	post0_frame_clken 	;
assign		YCbCr_img_Y_current 	=	post0_img_Y			;
 
//--------------------------------------
//帧差运算

wire	post1_frame_vsync	;
wire	post1_frame_href	;
wire	post1_frame_clken	;
wire	post1_img_Bit	    ;

VIP_Frame_Difference u_VIP_Frame_Difference(
	//global clock
	.clk					(clk),  				 
	.rst_n					(rst_n),				 

	.per_frame_vsync		(post0_frame_vsync),	 
	.per_frame_href			(post0_frame_href),		 
	.per_frame_clken		(post0_frame_clken),	 
	.per_img_Y_current		(YCbCr_img_Y_current),	
	
	.YCbCr_img_Y_previous	(YCbCr_img_Y_previous),  

	.post_frame_vsync		(post1_frame_vsync	),	 
	.post_frame_href		(post1_frame_href	),	 
	.post_frame_clken		(post1_frame_clken	),	 
	.post_img_Bit			(post1_img_Bit		),	 
													 
	//User interface                                 
 	.user_Threshold			(Diff_Threshold)		 
 );
 
//--------------------------------------
//腐蚀

wire						post2_frame_vsync 	;	 
wire						post2_frame_href 	;		 
wire						post2_frame_clken 	;	 
wire						post2_img_Bit 		;		 
 
VIP_Bit_Erosion_Detector
#(
	.IMG_HDISP	(IMG_HDISP),	//640*480
	.IMG_VDISP	(IMG_VDISP)
)
u_Bit_Erosion_Detector
(
	.clk					(clk),  							 
	.rst_n					(rst_n),							 

	.per_frame_vsync		(post1_frame_vsync),				 
	.per_frame_href			(post1_frame_href),					 
	.per_frame_clken		(post1_frame_clken),				 
	.per_img_Bit			(post1_img_Bit),					 

	.post_frame_vsync		(post2_frame_vsync	),	 
	.post_frame_href		(post2_frame_href	),	 
	.post_frame_clken		(post2_frame_clken 	),	 
	.post_img_Bit			(post2_img_Bit 		) 
);                                                               																 

//--------------------------------------
//膨胀

wire						post3_frame_vsync 	;		 
wire						post3_frame_href 	;		 
wire						post3_frame_clken 	;		 
wire						post3_img_Bit 		;		 

VIP_Bit_Dilation_Detector 
#(
	.IMG_HDISP	(IMG_HDISP),	//640*480
	.IMG_VDISP	(IMG_VDISP)
)
u_Bit_Dilation_Detector 
(
	.clk					(clk),  				 
	.rst_n					(rst_n),				 

	.per_frame_vsync		(post2_frame_vsync	), 
	.per_frame_href			(post2_frame_href	), 
	.per_frame_clken		(post2_frame_clken 	), 
	.per_img_Bit			(post2_img_Bit 		),  

	.post_frame_vsync		(post3_frame_vsync 	),	 
	.post_frame_href		(post3_frame_href 	),	 
	.post_frame_clken		(post3_frame_clken 	),	 
	.post_img_Bit			(post3_img_Bit 		)		 
);
 
//*****************************************************
//  多个运动目标的检测 （作者：大磊）
//*****************************************************

wire	[40:0] 	target_pos_out[15:0];

VIP_multi_target_detect
#(
	.IMG_HDISP 	(IMG_HDISP),	//640*480
	.IMG_VDISP 	(IMG_VDISP)
)
u_VIP_multi_target_detect
(
	.clk					(clk),  			
	.rst_n					(rst_n),			
												
	.per_frame_vsync		(post3_frame_vsync),
	.per_frame_href			(post3_frame_href),	
	.per_frame_clken		(post3_frame_clken),
	.per_img_Bit			(post3_img_Bit),	

 	.target_pos_out			(target_pos_out),		//共41bit  {Flag,ymax[9:0],xmax[9:0],ymin[9:0],xmin[9:0]} 

    .target_num_out         (target_num_out),       //最终目标数目

 	.MIN_DIST				(MIN_DIST) 				//目标之间的最小间距
); 

//--------------------------------------
//绘制多个目标的方框 

wire			post4_frame_vsync	;
wire			post4_frame_href	;
wire			post4_frame_clken	;
wire	[7:0]	post4_img_red		;
wire	[7:0]	post4_img_green	    ;
wire	[7:0]	post4_img_blue	    ;

VIP_Video_add_rectangular
#(
	.IMG_HDISP 	(IMG_HDISP),	//640*480
	.IMG_VDISP 	(IMG_VDISP)
)
u_VIP_Video_add_rectangular
(
	//global clock
	.clk					(clk),  				 
	.rst_n					(rst_n),	
	
 	//在彩色图像上画方框          
	.per_frame_vsync		(per_frame_vsync    ),	 
	.per_frame_href			(per_frame_href     ),	 
    .per_frame_clken		(per_frame_clken    ),	 
	.per_img_red			(per_img_red        ),		 
	.per_img_green			(per_img_green      ),	 
	.per_img_blue			(per_img_blue       ),		 

    //各目标位置
	.target_pos_out 		(target_pos_out     ),
	
	//Image data has been processd                 
	.post_frame_vsync		(post4_frame_vsync	), 
	.post_frame_href		(post4_frame_href	), 
	.post_frame_clken		(post4_frame_clken	), 
	.post_img_red			(post4_img_red		), 
	.post_img_green			(post4_img_green	), 
	.post_img_blue			(post4_img_blue		) 
);


//--------------------------------------
//绘制GUI界面，显示目标个数

wire			post5_frame_vsync	;
wire			post5_frame_href	;
wire			post5_frame_clken	;
wire	[7:0]	post5_img_red		;
wire	[7:0]	post5_img_green	    ;
wire	[7:0]	post5_img_blue	    ;

VIP_Video_add_GUI
#(
	.IMG_HDISP 	(IMG_HDISP),	//640*480
	.IMG_VDISP 	(IMG_VDISP)
)
u_VIP_Video_add_GUI
(
	//global clock
	.clk					(clk),  				 
	.rst_n					(rst_n),	
	        
	.per_frame_vsync		(post4_frame_vsync	),  
	.per_frame_href			(post4_frame_href	),  
    .per_frame_clken		(post4_frame_clken	),  
	.per_img_red			(post4_img_red		),  
	.per_img_green			(post4_img_green	),  
	.per_img_blue			(post4_img_blue		), 

    //目标个数
    .target_num             (target_num_out     ),
	
	.post_frame_vsync		(post5_frame_vsync	), 
	.post_frame_href		(post5_frame_href	), 
	.post_frame_clken		(post5_frame_clken	), 
	.post_img_red			(post5_img_red		), 
	.post_img_green			(post5_img_green	), 
	.post_img_blue			(post5_img_blue		) 
);

//----------------------------------------------------
// 输出结果 标记了运动目标的彩色图像
assign	post_frame_vsync	=   post5_frame_vsync	;
assign	post_frame_href	    =   post5_frame_href	;
assign	post_frame_clken	=   post5_frame_clken	;
assign	post_img_red		=   post5_img_red		;
assign	post_img_green		=   post5_img_green	    ;
assign	post_img_blue		=   post5_img_blue		; 

endmodule 