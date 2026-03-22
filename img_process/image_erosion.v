`timescale 1ns / 1ps

module image_erosion(
    input   wire        clk         ,
    input   wire        rst_n       ,
    //
    input   wire        hsync_i     ,
    input   wire        vsync_i     ,
    input   wire        de_i        ,
    input	wire [7:0]  data_i		,
    //输出行场信号
    output  wire        hsync_o     ,
    output  wire        vsync_o     ,
    output  wire        de_o        ,
    output  wire [7:0]  data_erode
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
    
reg  [7:0]  erode0,erode1,erode2,erode;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        erode0 <= 8'd0;
        erode1 <= 8'd0;
        erode2 <= 8'd0;
    end
    else begin
        erode0 <= a0 && a1 && a2;
        erode1 <= b0 && b1 && b2;
        erode2 <= c0 && c1 && c2;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        erode <= 8'b0;
    else
        erode <= erode0 && erode1 && erode2;
end

assign data_erode = erode ? 8'hff : 8'h0;

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

image_template image_template_u(
    /*input   wire        */.clk      (clk  )   ,
    /*input   wire        */.rst_n    (rst_n)   ,
    /*输入行场信号          */
    /*input   wire        */.de_i     (de_i   )   ,
    /*input   wire [7:0]  */.data_i   (data_i )   ,
    /*输出数据             */
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

endmodule
