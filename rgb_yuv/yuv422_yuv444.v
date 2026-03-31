`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/12/24 16:11:02
// Design Name: 
// Module Name: yuv422_yuv444
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
//YUV422 {Y0,U0}   ,{Y1,V1},    {Y2,U2},    {Y3,V3}
//YUV444 {Y0,U0,V0} {Y1,U0,V1}, {Y2,U2,V1}, {Y3,U2,V3}


module yuv422_yuv444 
(
    input   wire                    i_clk           ,
    input   wire                    i_rst           ,

    input   wire                    i_pre_vs        ,
    input   wire                    i_pre_de        ,
    input   wire    [15:0]          i_pre_data      ,

    output  wire                    o_post_vs       ,
    output  wire                    o_post_de       ,
    output  wire    [23:0]          o_post_data     
);

reg     [15:0]                      ri_pre_data     ;
reg                                 ro_post_vs      ;
reg                                 ro_post_de      ;
reg     [23:0]                      ro_post_data    ;

reg                                 r_data_type     ;

assign o_post_vs        = ro_post_vs                ;
assign o_post_de        = ro_post_de                ;
assign o_post_data      = ro_post_data              ;

always @(posedge i_clk) begin
    if(i_rst) 
        ri_pre_data <= 'd0;
    else 
        ri_pre_data <= i_pre_data;
end

always @(posedge i_clk) begin
    if(i_rst) begin
        ro_post_vs <= 'd0;
        ro_post_de <= 'd0;
    end
    else begin
        ro_post_vs <= i_pre_vs;
        ro_post_de <= i_pre_de;
    end 
end

always @(posedge i_clk) begin
    if(i_rst) 
        r_data_type <= 'd0;
    else if(i_pre_de) 
        r_data_type <= ~r_data_type;
    else 
        r_data_type <= r_data_type;
end

always @(posedge i_clk) begin
    if(i_rst) 
        ro_post_data <= 'd0;
    else if(!r_data_type)
        ro_post_data <= {i_pre_data[15:8],i_pre_data[7 :0],ri_pre_data[7 :0]};
    else if(r_data_type)
        ro_post_data <= {i_pre_data[15:8],ri_pre_data[7 :0],i_pre_data[7 :0]};
    else 
        ro_post_data <= 'd0;
end












endmodule
