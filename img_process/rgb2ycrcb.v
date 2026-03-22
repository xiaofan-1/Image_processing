`timescale 1ns / 1ps

module rgb2ycrcb(
    input   wire        clk         ,
    input   wire        rst_n       ,
    //输入
    input   wire        hsync_i     ,//行信号
    input   wire        vsync_i     ,//场信号
    input   wire        de_i        ,
    input   wire [23:0] data_i      ,//
    //输出
    output  wire        hsync_o     ,
    output  wire        vsync_o     ,
    output  wire        de_o        ,
	output  wire [7:0]  data_y      , 
	output  wire [7:0]  data_cb     , 
    output  wire [7:0]  data_cr      
);

//Y = (77*R + 150*G + 29*B) >> 8
//Cb= (-43*R - 85*G + 128*B + 32768) >>8
//Cr= (128*R - 107*G - 21*b + 32768) >>8
//第一级流水线 乘法运算
//第二级流水线 加法运算
//第三级流水线 移位运算
reg [15:0] y_r,y_g,y_b;
reg [15:0] cb_r,cb_g,cb_b;
reg [15:0] cr_r,cr_g,cr_b;

reg [15:0] Y,Cb,Cr;
reg [15:0] Y1,Cb1,Cr1;
reg [15:0] Y2,Cb2,Cr2;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        y_r  <= 16'b0;
        y_g  <= 16'b0;
        y_b  <= 16'b0;
        cb_r <= 16'd0;
        cb_g <= 16'd0;
        cb_b <= 16'd0;
        cr_r <= 16'd0;
        cr_g <= 16'd0;
        cr_b <= 16'd0;
    end
    else begin
        y_r <= data_i[23:16]*77;
        y_g <= data_i[15:8] *150;
        y_b <= data_i[7:0]  *29;
        cb_r <= data_i[23:16]*43 ;
        cb_g <= data_i[15:8] *85 ;
        cb_b <= data_i[7:0]  *128; 
        cr_r <= data_i[23:16]*128; 
        cr_g <= data_i[15:8] *107; 
        cr_b <= data_i[7:0]  *21 ;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        Y1  <= 16'd0;
        Cb1 <= 16'd0;
        Cr1 <= 16'd0;
    end
    else begin
        Y1  <= y_r + y_g + y_b;
        Cb1 <= -cb_r - cb_g + cb_b + 16'd32768; //128扩大256倍
        Cr1 <= cr_r - cr_g - cr_b + 16'd32768; //128扩大256倍
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        Y2  <= 8'd0;
        Cb2 <= 8'd0;
        Cr2 <= 8'd0;
    end
    else begin
        Y2  <= Y1[15:8];  
        Cb2 <= Cb1[15:8];
        Cr2 <= Cr1[15:8];
    end
end

assign data_y  = Y2  ;
assign data_cb = Cb2 ;
assign data_cr = Cr2 ;

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