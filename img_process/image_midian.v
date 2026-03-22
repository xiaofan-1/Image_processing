`timescale 1ns / 1ps

module image_midian(
    input   wire        clk         ,
    input   wire        rst_n       ,
    //
    input   wire        hsync_i     ,
    input   wire        vsync_i     ,
    input   wire        de_i        ,
	input	wire [7:0]  data_i		, 
	//
    output  wire        hsync_o     ,
    output  wire        vsync_o     ,
    output  wire        de_o        ,
    output  wire [7:0]  data_mid       
    );

wire [7:0]  a0;
wire [7:0]  a1;	
wire [7:0]  a2;	
wire [7:0]  b0;	
wire [7:0]  b1;	
wire [7:0]  b2;	
wire [7:0]  c0;	
wire [7:0]  c1;	
wire [7:0]  c2;
    
wire  [7:0]  line0_max,line0_mid,line0_min;
wire  [7:0]  line1_max,line1_mid,line1_min;
wire  [7:0]  line2_max,line2_mid,line2_min;

wire  [7:0]  Max_min,Mid_mid,Min_max;

//==============信号同步====================
reg  [3:0]  hsync_i_reg;
reg  [3:0]  vsync_i_reg;
reg  [3:0]  de_i_reg   ;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        hsync_i_reg <= 4'b0;
        vsync_i_reg <= 4'b0;
        de_i_reg    <= 4'b0;
    end
    else begin  
        hsync_i_reg <= {hsync_i_reg[2:0], hsync_i};
        vsync_i_reg <= {vsync_i_reg[2:0], vsync_i};
        de_i_reg    <= {de_i_reg   [2:0], de_i   };
    end
end

assign hsync_o = hsync_i_reg[3];
assign vsync_o = vsync_i_reg[3];
assign de_o    = de_i_reg   [3];

image_template image_template_u(
    /*input   wire        */.clk      (clk  )   ,
    /*input   wire        */.rst_n    (rst_n)   ,
    /*输入行场信号        */
    /*input   wire        */.de_i     (de_i   )   ,
    /*input   wire [7:0]  */.data_i   (data_i )   ,
    /*输出数据            */
    /*output  reg  [7:0]  */.a0       (a0)   ,
    /*output  reg  [7:0]  */.a1       (a1)   ,
    /*output  reg  [7:0]  */.a2       (a2)   ,
    /*output  reg  [7:0]  */.b0       (b0)   ,
    /*output  reg  [7:0]  */.b1       (b1)   ,
    /*output  reg  [7:0]  */.b2       (b2)   ,
    /*output  reg  [7:0]  */.c0       (c0)   ,
    /*output  reg  [7:0]  */.c1       (c1)   ,
    /*output  reg  [7:0]  */.c2       (c2)             
);

//=============第一行数据======================
sort3 sort3_u0(
    /*input  wire            */.clk      (clk  ),
    /*input  wire            */.rst_n    (rst_n),
    /*input  wire [7:0]      */.data1    (a0),
    /*input  wire [7:0]      */.data2    (a1),
    /*input  wire [7:0]      */.data3    (a2),
    /*output reg  [7:0]      */.max_data (line0_max),
    /*output reg  [7:0]      */.mid_data (line0_mid),
    /*output reg  [7:0]      */.min_data (line0_min)
);

//=============第二行数据======================
sort3 sort3_u1(
    /*input  wire            */.clk      (clk  ),
    /*input  wire            */.rst_n    (rst_n),
    /*input  wire [7:0]      */.data1    (b0),
    /*input  wire [7:0]      */.data2    (b1),
    /*input  wire [7:0]      */.data3    (b2),
    /*output reg  [7:0]      */.max_data (line1_max),
    /*output reg  [7:0]      */.mid_data (line1_mid),
    /*output reg  [7:0]      */.min_data (line1_min)
);

//=============第三行数据======================
sort3 sort3_u2(
    /*input  wire            */.clk      (clk  ),
    /*input  wire            */.rst_n    (rst_n),
    /*input  wire [7:0]      */.data1    (c0),
    /*input  wire [7:0]      */.data2    (c1),
    /*input  wire [7:0]      */.data3    (c2),
    /*output reg  [7:0]      */.max_data (line2_max),
    /*output reg  [7:0]      */.mid_data (line2_mid),
    /*output reg  [7:0]      */.min_data (line2_min)
);

//=============最大值中最小值==================
sort3 sort3_u3(
    /*input  wire            */.clk      (clk  ),
    /*input  wire            */.rst_n    (rst_n),
    /*input  wire [7:0]      */.data1    (line0_max),
    /*input  wire [7:0]      */.data2    (line1_max),
    /*input  wire [7:0]      */.data3    (line2_max),
    /*output reg  [7:0]      */.max_data (),
    /*output reg  [7:0]      */.mid_data (),
    /*output reg  [7:0]      */.min_data (Max_min)
);

//=============最中值中最中值==================
sort3 sort3_u4(
    /*input  wire            */.clk      (clk  ),
    /*input  wire            */.rst_n    (rst_n),
    /*input  wire [7:0]      */.data1    (line0_mid),
    /*input  wire [7:0]      */.data2    (line1_mid),
    /*input  wire [7:0]      */.data3    (line2_mid),
    /*output reg  [7:0]      */.max_data (),
    /*output reg  [7:0]      */.mid_data (Mid_mid),
    /*output reg  [7:0]      */.min_data ()
);

//=============最小值中最大值==================
sort3 sort3_u5(
    /*input  wire            */.clk      (clk  ),
    /*input  wire            */.rst_n    (rst_n),
    /*input  wire [7:0]      */.data1    (line0_min),
    /*input  wire [7:0]      */.data2    (line1_min),
    /*input  wire [7:0]      */.data3    (line2_min),
    /*output reg  [7:0]      */.max_data (Min_max),
    /*output reg  [7:0]      */.mid_data (),
    /*output reg  [7:0]      */.min_data ()
);

//=============最终输出值=======================
sort3 sort3_u6(
    /*input  wire            */.clk      (clk  ),
    /*input  wire            */.rst_n    (rst_n),
    /*input  wire [7:0]      */.data1    (Max_min),
    /*input  wire [7:0]      */.data2    (Mid_mid),
    /*input  wire [7:0]      */.data3    (Min_max),
    /*output reg  [7:0]      */.max_data (),
    /*output reg  [7:0]      */.mid_data (data_mid),
    /*output reg  [7:0]      */.min_data ()
);

endmodule