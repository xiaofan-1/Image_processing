`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/12/24 16:11:02
// Design Name: 
// Module Name: rgb_yuv444
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
// 	Y   =   0.2990R  + 0.5870G + 0.1140B
//  U   =   -0.1684R - 0.3316G + 0.5B + 128
//	V   =   0.5R     -0.4187G  - 0.0813B + 128

// 	Y 	=	(77 *R 	+ 	150*G 	+ 	29 *B)>>8
//	U 	=	(-43*R	- 	85 *G	+ 	128*B)>>8 + 128
//	V 	=	(128*R 	-	107*G  	-	21 *B)>>8 + 128

//	Y	=	(77 *R 	+ 	150*G 	+ 	29 *B)>>8
//	U 	=	(-43*R	- 	85 *G	+ 	128*B + 32768)>>8
//	V 	=	(128*R 	-	107*G  	-	21 *B + 32768)>>8


module rgb_yuv444 
(
    input   wire                    i_clk           ,
    input   wire                    i_rst           ,

    input   wire                    i_pre_vs        ,
    input   wire                    i_pre_hs        ,
    input   wire                    i_pre_de        ,
    input   wire    [23:0]          i_pre_data      ,

    output  wire                    o_post_vs       ,
    output  wire                    o_post_hs       ,
    output  wire                    o_post_de       ,
    output  wire    [23:0]          o_post_data     
);

reg     [1 :0]                      ri_pre_vs       ;
reg     [1 :0]                      ri_pre_hs       ;
reg     [1 :0]                      ri_pre_de       ;

reg                                 ro_post_vs      ;
reg                                 ro_post_hs      ;
reg                                 ro_post_de      ;
reg     [23:0]                      ro_post_data    ;

reg     [15:0]                      r_R_mult0       ;
reg     [15:0]                      r_R_mult1       ;
reg     [15:0]                      r_R_mult2       ;

reg     [15:0]                      r_G_mult0       ;
reg     [15:0]                      r_G_mult1       ;
reg     [15:0]                      r_G_mult2       ;

reg     [15:0]                      r_B_mult0       ;
reg     [15:0]                      r_B_mult1       ;
reg     [15:0]                      r_B_mult2       ;

reg     [15:0]                      r_add_Y         ;
reg     [15:0]                      r_add_U         ;
reg     [15:0]                      r_add_V         ;

assign o_post_vs    = ro_post_vs                    ;
assign o_post_de    = ro_post_de                    ;
assign o_post_data  = ro_post_data                  ;

// first cycle
always @(posedge i_clk) begin
    if(i_rst) begin
        r_R_mult0 <= 'd0;
        r_R_mult1 <= 'd0;
        r_R_mult2 <= 'd0;
    end
    else begin
        r_R_mult0 <= 77  * i_pre_data[23:16];
        r_R_mult1 <= 43  * i_pre_data[23:16];
        r_R_mult2 <= 128 * i_pre_data[23:16];
    end
end

always @(posedge i_clk) begin
    if(i_rst) begin
        r_G_mult0 <= 'd0;
        r_G_mult1 <= 'd0;
        r_G_mult2 <= 'd0;
    end
    else begin
        r_G_mult0 <= 150 * i_pre_data[15:8];
        r_G_mult1 <= 85  * i_pre_data[15:8];
        r_G_mult2 <= 107 * i_pre_data[15:8];
    end
end

always @(posedge i_clk) begin
    if(i_rst) begin
        r_B_mult0 <= 'd0;
        r_B_mult1 <= 'd0;
        r_B_mult2 <= 'd0;
    end
    else begin
        r_B_mult0 <= 29  * i_pre_data[7 :0];
        r_B_mult1 <= 128 * i_pre_data[7 :0];
        r_B_mult2 <= 21  * i_pre_data[7 :0];
    end
end
// second cycle
always @(posedge i_clk) begin
    if(i_rst) begin
        r_add_Y <= 'd0;
        r_add_U <= 'd0;
        r_add_V <= 'd0;
    end
    else begin
        r_add_Y <= r_R_mult0  + r_G_mult0 + r_B_mult0;
        r_add_U <= -r_R_mult1 - r_G_mult1 + r_B_mult1 + 32768;
        r_add_V <= r_R_mult2  - r_G_mult2 - r_B_mult2 + 32768;
    end
end

always @(posedge i_clk) begin
    if(i_rst) begin
        ri_pre_vs <= 'd0;
        ri_pre_hs <= 'd0;
        ri_pre_de <= 'd0;
    end 
    else begin
        ri_pre_vs <= {ri_pre_vs[0],i_pre_vs};
        ri_pre_hs <= {ri_pre_hs[0],i_pre_hs};
        ri_pre_de <= {ri_pre_de[0],i_pre_de};
    end
end

// third cycle
always @(posedge i_clk) begin
    if(i_rst) begin
        ro_post_vs   <= 'd0;
        ro_post_hs   <= 'd0;
        ro_post_de   <= 'd0;
        ro_post_data <= 'd0;
    end 
    else begin
        ro_post_vs   <= ri_pre_vs[1];
        ro_post_hs   <= ri_pre_hs[1];
        ro_post_de   <= ri_pre_de[1];
        ro_post_data <= {r_add_Y[15:8],r_add_U[15:8],r_add_V[15:8]};
    end
end



















endmodule
