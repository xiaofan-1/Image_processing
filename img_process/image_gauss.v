`timescale 1ns / 1ps

module image_gauss(
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
    output  reg  [7:0]  data_o      
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

reg  [11:0] num_a;
reg  [11:0] num_b;
reg  [11:0] num_c;

reg  [11:0] sum;

//==============流水线处理==================
//==============各行相加====================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        num_a <= 12'd0;
        num_b <= 12'd0;
        num_c <= 12'd0;
    end
    else begin
        num_a <= a0     + a1 * 2 + a2;
        num_b <= b0 * 2 + b1 * 4 + b2 * 2;
        num_c <= c0     + c1 * 2 + c2;
    end
end

//==============全部相加====================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sum <= 12'd0;
    else
        sum <= num_a + num_b + num_c;
end

// reg [11:0]  pix_cnt;
// reg         de_i_reg0,de_i_reg1;

// always @(posedge clk or negedge rst_n) begin
    // if(!rst_n) begin  
        // de_i_reg0 <= 'd0;
        // de_i_reg1 <= 'd0;
    // end
    // else begin
        // de_i_reg0 <= de_i;
        // de_i_reg1 <= de_i_reg0;
    // end
// end

// wire de_i_posedge = (de_i_reg0 && ~de_i_reg1) ? 1 : 0;

// always @(posedge clk or negedge rst_n) begin
    // if (!rst_n)                   
        // pix_cnt <= 0;
    // else if (pix_cnt == 4)             
        // pix_cnt <= pix_cnt;
    // else if (de_i_posedge)                
        // pix_cnt <= pix_cnt + 1;
    // else                          
        // pix_cnt <= pix_cnt;
// end

//==============输出结果====================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        data_o <= 12'd0;
    // else if(pix_cnt == 4)
        // data_o <= sum[11:4];
	else
        data_o <= sum[11:4];
    // else
        // data_o <= data_o;
end



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

image_template image_template_gauss(
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

endmodule