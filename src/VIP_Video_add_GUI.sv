module VIP_Video_add_GUI
#(
	parameter	[9:0]	IMG_HDISP = 10'd640,//640*480
	parameter	[9:0]	IMG_VDISP = 10'd480
)
(
	//global clock
	input				clk,  				 
	input				rst_n,				 
                                             
	//Image data prepred to be processd      
	input				per_frame_vsync ,	 
	input				per_frame_href  ,	 
	input				per_frame_clken ,	 
	input		[7:0]	per_img_red		,		 
	input		[7:0]	per_img_green	,		 
	input		[7:0]	per_img_blue	,		 
                                             
	input  		[3:0] 	target_num      ,   //目标个数
    
	//Image data has been processd           
	output reg			post_frame_vsync,	 
	output reg			post_frame_href ,	 
	output reg			post_frame_clken,	 
	output wire	[7:0]	post_img_red	,		 
	output wire	[7:0]	post_img_green	,		 
	output wire	[7:0]	post_img_blue	  	
);

localparam BACK_COLOR  = 24'b11111111_11111111_11111111;     //背景色，白色
localparam CHAR_BLUE   = 24'b00000000_00000000_11111111;     //字符颜色，蓝色
localparam CHAR_RED    = 24'b11111111_00000000_00000000;     //字符颜色，红色

localparam HANZI_POS_X      = 11'd20;   //汉字起始点横坐标
localparam CHAR_POS_X       = 11'd160;  //字符区域起始点横坐标

localparam CHAR_POS_Y_0     = 11'd120;  //字符起始点纵坐标
localparam CHAR_POS_Y_1     = 11'd160;     
   

localparam CHAR_WIDTH   = 11'd16;       //字符区域宽度
localparam CHAR_HEIGHT  = 11'd32;       //字符区域高度
localparam HANZI_WIDTH  = 11'd128;      //汉字宽度,4个字符:32*4
localparam HANZI_HEIGHT = 11'd32;       //汉字高度

reg  [511:0] char  [9:0] ;      //数字“0-9”,16p x 32p 
reg  [127:0] CHINA_0[31:0];     //汉字"大磊FPGA"
reg  [127:0] CHINA_1[31:0];     //汉字"目标个数"

reg [23:0] gui_data;

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
reg	[7:0]	per_img_red_r	 ;		 
reg	[7:0]	per_img_green_r	 ;		 
reg	[7:0]	per_img_blue_r	 ;	

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin	
		per_img_red_r	 	<= 0;
		per_img_green_r	 	<= 0;
		per_img_blue_r	 	<= 0;
		
		post_frame_vsync 	<= 0;
		post_frame_href 	<= 0;
		post_frame_clken 	<= 0;		
		end
	else begin
		post_frame_vsync 	<= 	per_frame_vsync		;
		post_frame_href 	<= 	per_frame_href		;
		post_frame_clken 	<= 	per_frame_clken		;
		
		per_img_red_r	 	<=  per_img_red		;
		per_img_green_r	 	<=  per_img_green	;
		per_img_blue_r	 	<=  per_img_blue	;
		end
end

assign	post_img_red	=	(gui_data == BACK_COLOR) ? per_img_red_r	 : gui_data[23:16];			
assign	post_img_green	=	(gui_data == BACK_COLOR) ? per_img_green_r	 : gui_data[15: 8];		
assign	post_img_blue	=	(gui_data == BACK_COLOR) ? per_img_blue_r	 : gui_data[ 7: 0];


//给不同的区域赋值不同的像素数据
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)  begin
         gui_data   <= BACK_COLOR ;
    end
    //显示数字
	else if((x_cnt >= CHAR_POS_X)   && (x_cnt < CHAR_POS_X + CHAR_WIDTH*1)
		 && (y_cnt >= CHAR_POS_Y_1) && (y_cnt < CHAR_POS_Y_1 + CHAR_HEIGHT)) begin
		if(char [target_num] [ (CHAR_HEIGHT+CHAR_POS_Y_1 - y_cnt)*CHAR_WIDTH - ((x_cnt-CHAR_POS_X)%CHAR_WIDTH) -1 ])
			gui_data <= CHAR_RED;         //显示字符
		else            
			gui_data <= BACK_COLOR;          //显示字符区域背景
	end

    //显示汉字 
    else if((x_cnt >= HANZI_POS_X) && (x_cnt < HANZI_POS_X + HANZI_WIDTH)	
         && (y_cnt >= CHAR_POS_Y_0) && (y_cnt < CHAR_POS_Y_0 + HANZI_HEIGHT)) begin	
        if(CHINA_0[y_cnt - CHAR_POS_Y_0][HANZI_POS_X + HANZI_WIDTH - x_cnt -1'b1])	
            gui_data <= CHAR_BLUE;    //显示字符	
        else	
            gui_data <= BACK_COLOR;    //显示字符区域的背景色	
    end	
    //显示汉字
    else if((x_cnt >= HANZI_POS_X) && (x_cnt < HANZI_POS_X + HANZI_WIDTH)	
         && (y_cnt >= CHAR_POS_Y_1) && (y_cnt < CHAR_POS_Y_1 + HANZI_HEIGHT)) begin	
        if(CHINA_1[y_cnt - CHAR_POS_Y_1][HANZI_POS_X + HANZI_WIDTH - x_cnt -1'b1])	
            gui_data <= CHAR_RED;    //显示字符	
        else	
            gui_data <= BACK_COLOR;    //显示字符区域的背景色	
    end	

	else begin
		gui_data   <= BACK_COLOR ;
	end
end

///////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////
//                                  字库
///////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////


 //给字符数组赋值，用于存储字模数据 数字“0-9”
always @(posedge clk) begin
    char[0 ]  <= 512'h00000000000000000000000007E00FF01C383C3C3C1C781C781E781E781E781E781E781E781E781E781E781E781C383C3C3C1C380FF007E00000000000000000; // "0"
    char[1 ]  <= 512'h000000000000000000000000008001801F800180018001800180018001800180018001800180018001800180018001800180018003C01FF80000000000000000; // "1"
    char[2 ]  <= 512'h00000000000000000000000007E008381018200C200C300C300C000C001800180030006000C0018003000200040408041004200C3FF83FF80000000000000000; // "2"
    char[3 ]  <= 512'h00000000000000000000000007C018603030301830183018001800180030006003C0007000180008000C000C300C300C30083018183007C00000000000000000; // "3"
    char[4 ]  <= 512'h0000000000000000000000000060006000E000E0016001600260046004600860086010603060206040607FFC0060006000600060006003FC0000000000000000; // "4"
    char[5 ]  <= 512'h0000000000000000000000000FFC0FFC10001000100010001000100013E0143018181008000C000C000C000C300C300C20182018183007C00000000000000000; // "5"
    char[6 ]  <= 512'h00000000000000000000000001E006180C180818180010001000300033E0363038183808300C300C300C300C300C180C18080C180E3003E00000000000000000; // "6"
    char[7 ]  <= 512'h0000000000000000000000001FFC1FFC100830102010202000200040004000400080008001000100010001000300030003000300030003000000000000000000; // "7"
    char[8 ]  <= 512'h00000000000000000000000007E00C301818300C300C300C380C38081E180F2007C018F030783038601C600C600C600C600C3018183007C00000000000000000; // "8"
    char[9 ]  <= 512'h00000000000000000000000007C01820301030186008600C600C600C600C600C701C302C186C0F8C000C0018001800103030306030C00F800000000000000000; // "9"
end

 //给字符数组赋值，用于存储字模数据 汉字 
always @(posedge clk) begin
    CHINA_0[0 ]  <= 128'h00000000000000000000000000000000;
    CHINA_0[1 ]  <= 128'h00000000000000000000000000000000;
    CHINA_0[2 ]  <= 128'h00000000000000000000000000000000;
    CHINA_0[3 ]  <= 128'h00060000000000000000000000000000;
    CHINA_0[4 ]  <= 128'h0003C00000007FC00000000000000000;
    CHINA_0[5 ]  <= 128'h0003C000003FF8000000000000000000;
    CHINA_0[6 ]  <= 128'h00038000000180007FFF3FF007F003C0;
    CHINA_0[7 ]  <= 128'h000380000003C0007FFF3FFC0FF803E0;
    CHINA_0[8 ]  <= 128'h000380000003800078003C7E1F3C03E0;
    CHINA_0[9 ]  <= 128'h0003800000071F8078003C1E1E1E03E0;
    CHINA_0[10]  <= 128'h00038000000FF78078003C0F3C1E07E0;
    CHINA_0[11]  <= 128'h00038000001E070078003C0F3C1E07F0;
    CHINA_0[12]  <= 128'h00038FC0003E060078003C0F381E07F0;
    CHINA_0[13]  <= 128'h0003FFC000E6FF0078003C0F78000F70;
    CHINA_0[14]  <= 128'h03FFC00001C7800078003C0F78000F78;
    CHINA_0[15]  <= 128'h01F38000070600007FF83C1E78000F78;
    CHINA_0[16]  <= 128'h000380000000007E7FF83C7E78000E38;
    CHINA_0[17]  <= 128'h00038000003FFFE07FF83FFC78FE1E3C;
    CHINA_0[18]  <= 128'h0007C00003FC3F0078003FF078FE1FFC;
    CHINA_0[19]  <= 128'h0007C0000030078078003C00780E1FFC;
    CHINA_0[20]  <= 128'h000760000078070078003C00780E3FFC;
    CHINA_0[21]  <= 128'h000E700000E00E7078003C003C0E3C1E;
    CHINA_0[22]  <= 128'h000E380000DF1DFC78003C003C0E3C1E;
    CHINA_0[23]  <= 128'h001C3C0003F71F3C78003C003C1E781E;
    CHINA_0[24]  <= 128'h001C1E0003863C3878003C001E3E780F;
    CHINA_0[25]  <= 128'h00380F00078E7C3878003C001FFE780F;
    CHINA_0[26]  <= 128'h00700FC00FFECC7878003C0007FE780F;
    CHINA_0[27]  <= 128'h01C007F01DC18FC00000000001CE0000;
    CHINA_0[28]  <= 128'h030003FE31800C000000000000000000;
    CHINA_0[29]  <= 128'h00000000000000000000000000000000;
    CHINA_0[30]  <= 128'h00000000000000000000000000000000;
    CHINA_0[31]  <= 128'h00000000000000000000000000000000;
end

 //给字符数组赋值，用于存储字模数据 汉字 
always @(posedge clk) begin
    CHINA_1[0 ]  <= 128'h00000000000000000000000000000000;
    CHINA_1[1 ]  <= 128'h00000000000000000000000000000000;
    CHINA_1[2 ]  <= 128'h00000000018000000001800000700C00;
    CHINA_1[3 ]  <= 128'h0180018001E000000003E00000780F00;
    CHINA_1[4 ]  <= 128'h01FFFFE0018000300003C0000E71CE00;
    CHINA_1[5 ]  <= 128'h01C001C00183FFF80007C00007739C00;
    CHINA_1[6 ]  <= 128'h01C001C0018000000007600007F71C00;
    CHINA_1[7 ]  <= 128'h01C001C001800000000F300003761800;
    CHINA_1[8 ]  <= 128'h01C001C001800000000E3800007D980C;
    CHINA_1[9 ]  <= 128'h01C001C001980000001C1C003FFFFFFE;
    CHINA_1[10]  <= 128'h01C001C03FFC000000380E0000F03870;
    CHINA_1[11]  <= 128'h01FFFFC00180001C0071C70001FC3870;
    CHINA_1[12]  <= 128'h01C001C0038FFFFE00F1C78001FF7870;
    CHINA_1[13]  <= 128'h01C001C003800E0001C1C1E003777870;
    CHINA_1[14]  <= 128'h01C001C003C00E000381C0FC0673D860;
    CHINA_1[15]  <= 128'h01C001C007F00E000701C07F1C70D860;
    CHINA_1[16]  <= 128'h01C001C007B80E001C01C01830618CE0;
    CHINA_1[17]  <= 128'h01C001C007B9EEC03001C00000F00CE0;
    CHINA_1[18]  <= 128'h01C001C00F99CEE00001C00000E30CE0;
    CHINA_1[19]  <= 128'h01FFFFC00D81CE700001C0003FFF8EC0;
    CHINA_1[20]  <= 128'h01C001C01D838E380001C00001C70FC0;
    CHINA_1[21]  <= 128'h01C001C019830E380001C000018707C0;
    CHINA_1[22]  <= 128'h01C001C031870E1C0001C000038E0780;
    CHINA_1[23]  <= 128'h01C001C031860E1C0001C00003CE0780;
    CHINA_1[24]  <= 128'h01C001C0018C0E1E0001C000007C0780;
    CHINA_1[25]  <= 128'h01C001C0019C0E0C0001C000003F8FC0;
    CHINA_1[26]  <= 128'h01FFFFC001980E0C0001C00000F39CF0;
    CHINA_1[27]  <= 128'h01C001C001B18E000001C00001C1B878;
    CHINA_1[28]  <= 128'h01C001C00180FE000001C0000700E03F;
    CHINA_1[29]  <= 128'h01C001C001803C000001C0003C018018;
    CHINA_1[30]  <= 128'h01800000018018000001800000070000;
    CHINA_1[31]  <= 128'h00000000000000000000000000000000;
end

endmodule 