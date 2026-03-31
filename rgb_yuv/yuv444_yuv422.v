`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/12/24 16:11:02
// Design Name: 
// Module Name: yuv444_yuv422
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
//YUV444 {Y0,U0,V0} {Y1,U1,V1}, {Y2,U2,V2}, {Y3,U3,V3}
//YUV422 {Y0,U0}   ,{Y1,V1},    {Y2,U2},    {Y3,V3}


module yuv444_yuv422 
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
    output  wire    [15:0]          o_post_data     
);
reg                                 ri_pre_vs       ;
reg                                 ri_pre_hs       ;
reg                                 ri_pre_de       ;
reg     [23:0]                      ri_pre_data     ;
reg                                 ro_post_vs      ;
reg                                 ro_post_hs      ;
reg                                 ro_post_de      ;
reg     [15:0]                      ro_post_data    ;

reg                                 r_data_type     ;

assign o_post_vs    = ro_post_vs                    ;
assign o_post_de    = ro_post_de                    ;
assign o_post_data  = ro_post_data                  ;

always @(posedge i_clk) begin
    if(i_rst) begin
        ri_pre_vs   <= 'd0;
        ri_pre_hs   <= 'd0;
        ri_pre_de   <= 'd0;
        ri_pre_data <= 'd0;
    end
    else begin
        ri_pre_vs   <= i_pre_vs  ;
        ri_pre_hs   <= i_pre_hs  ;
        ri_pre_de   <= i_pre_de  ;
        ri_pre_data <= i_pre_data;
    end
end

always @(posedge i_clk) begin
    if(i_rst) begin
        ro_post_vs <= 'd0;
        ro_post_hs <= 'd0;
        ro_post_de <= 'd0;
    end
    else begin
        ro_post_vs <= ri_pre_vs;
        ro_post_hs <= ri_pre_hs;
        ro_post_de <= ri_pre_de;
    end 
end

always @(posedge i_clk) begin
    if(i_rst)
        r_data_type <= 'd0;
    else if(ri_pre_de)
        r_data_type <= ~r_data_type;
    else 
        r_data_type <= r_data_type;
end

always @(posedge i_clk) begin
    if(i_rst)
        ro_post_data <= 'd0;
    else if(~r_data_type)
        ro_post_data <= {ri_pre_data[23:16],ri_pre_data[15:8]};
    else if(r_data_type)
        ro_post_data <= {ri_pre_data[23:16],ri_pre_data[7 :0]};
    else 
        ro_post_data <= ro_post_data;
end

















endmodule
