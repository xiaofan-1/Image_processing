`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/12/24 16:11:02
// Design Name: 
// Module Name: yuv444_rgb
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
//R = Y + 1.4075 (V-128)
//G = Y - 0.3455 (U-128) -0.7169(V-128)
//B = Y + 1.7790 (U-128)

//R = Y + 1.4075V - 1.4075*128
//G = Y - 0.3455U + 0.3455*128 - 0.7169V + 0.7169*128
//B = Y + 1.7790U - 1.7790*128;

//R = Y + 1.4075V - 180.16
//G = Y - 0.3455U + 44.224 - 0.7169V + 91.7632
//B = Y + 1.7790U - 227.712;

//R = Y + 1.4075V - 180.16
//G = Y - 0.3455U - 0.7169V + 135.9872 
//B = Y + 1.7790U - 227.712;

//R = (128Y +       180V - 23060)/128
//G = (128Y - 44U - 92V  + 17406)/128
//B = (128Y + 228U       - 29147)/128


module yuv444_rgb 
(
    input   wire                    i_clk           ,
    input   wire                    i_rst           ,

    input   wire                    i_pre_vs        ,
    input   wire                    i_pre_de        ,
    input   wire    [23:0]          i_pre_data      ,

    output  wire                    o_post_vs       ,
    output  wire                    o_post_de       ,
    output  wire    [23:0]          o_post_data     
);


reg     [3 :0]                      ro_post_vs      ;
reg     [3 :0]                      ro_post_de      ;
reg     [23:0]                      ro_post_data    ;

reg     [15:0]                      r_Y_mult0       ;
reg     [15:0]                      r_Y_mult1       ;
reg     [15:0]                      r_Y_mult2       ;

reg     [15:0]                      r_U_mult0       ;
reg     [15:0]                      r_U_mult1       ;
reg     [15:0]                      r_U_mult2       ;

reg     [15:0]                      r_V_mult0       ;
reg     [15:0]                      r_V_mult1       ;
reg     [15:0]                      r_V_mult2       ;

reg     [16:0]                      r_add_R         ;
reg     [16:0]                      r_add_G         ;
reg     [16:0]                      r_add_B         ;

reg     [7 :0]                      r_R_pre_data    ;
reg     [7 :0]                      r_G_pre_data    ;
reg     [7 :0]                      r_B_pre_data    ;

wire    [16:0]                      w_add_R_S       ;
wire    [16:0]                      w_add_G_S       ;
wire    [16:0]                      w_add_B_S       ;

assign o_post_vs        = ro_post_vs[3]             ;
assign o_post_de        = ro_post_de[3]             ;
assign o_post_data      = ro_post_data              ;

assign w_add_R_S        = $signed(r_add_R) / 128    ;
assign w_add_G_S        = $signed(r_add_G) / 128    ;
assign w_add_B_S        = $signed(r_add_B) / 128    ;

// first cycle
always @(posedge i_clk) begin
    if(i_rst) begin
        r_Y_mult0 <= 'd0;
        r_Y_mult1 <= 'd0;
        r_Y_mult2 <= 'd0;
    end
    else begin
        r_Y_mult0 <= 128 * i_pre_data[23:16];
        r_Y_mult1 <= 128 * i_pre_data[23:16];
        r_Y_mult2 <= 128 * i_pre_data[23:16];
    end
end

always @(posedge i_clk) begin
    if(i_rst) begin
        r_U_mult0 <= 'd0;
        r_U_mult1 <= 'd0;
        r_U_mult2 <= 'd0;
    end
    else begin
        r_U_mult0 <= 'd0;
        r_U_mult1 <= 44  * i_pre_data[15:8];
        r_U_mult2 <= 228 * i_pre_data[15:8];
    end
end

always @(posedge i_clk) begin
    if(i_rst) begin
        r_V_mult0 <= 'd0;
        r_V_mult1 <= 'd0;
        r_V_mult2 <= 'd0;
    end
    else begin
        r_V_mult0 <= 180 * i_pre_data[7 :0];
        r_V_mult1 <= 92  * i_pre_data[7 :0];
        r_V_mult2 <= 'd0;
    end
end

// second cycle
always @(posedge i_clk) begin
    if(i_rst) begin
        r_add_R <= 'd0;
        r_add_G <= 'd0;
        r_add_B <= 'd0;
    end
    else begin
        r_add_R <= r_Y_mult0 + r_U_mult0 + r_V_mult0 - 23060;
        r_add_G <= r_Y_mult1 - r_U_mult1 - r_V_mult1 + 17406;
        r_add_B <= r_Y_mult2 + r_U_mult2 + r_V_mult2 - 29147;
    end
end

// third cycle
always @(posedge i_clk) begin
    if(i_rst) 
        r_R_pre_data <= 'D0;
    else if(w_add_R_S[16])
        r_R_pre_data <= 'd0;
    else if(w_add_R_S[8])
        r_R_pre_data <= 255;
    else 
        r_R_pre_data <= w_add_R_S;
end

always @(posedge i_clk) begin
    if(i_rst) 
        r_G_pre_data <= 'D0;
    else if(w_add_G_S[16])
        r_G_pre_data <= 'd0;
    else if(w_add_G_S[8])
        r_G_pre_data <= 255;
    else 
        r_G_pre_data <= w_add_G_S;
end

always @(posedge i_clk) begin
    if(i_rst) 
        r_B_pre_data <= 'D0;
    else if(w_add_B_S[16])
        r_B_pre_data <= 'd0;
    else if(w_add_B_S[8])
        r_B_pre_data <= 255;
    else 
        r_B_pre_data <= w_add_B_S;
end

always @(posedge i_clk) begin
    if(i_rst) begin
        ro_post_vs   <= 'd0;
        ro_post_de   <= 'd0;
        ro_post_data <= 'd0;
    end
    else begin
        ro_post_vs   <= {ro_post_vs[2:0],i_pre_vs};
        ro_post_de   <= {ro_post_de[2:0],i_pre_de};
        ro_post_data <= {r_R_pre_data,r_G_pre_data,r_B_pre_data};
    end
end

endmodule

