`timescale 1ns / 1ps

module video_mode(
    input   wire                clk                 ,    
    input   wire                rst_n               ,
    input   wire                key_mode            ,

    input   wire                camera_vsync_0      ,
    input   wire                camera_vsync_1      ,
    input   wire                camera_vsync_2      ,
    input   wire                vs_in               ,

    output  reg     [2:0]       mode_data           , 
    
    output  reg     [11:0]      video_left_offset_0 ,
    output  reg     [11:0]      video_top_offset_0  ,
    output  reg     [11:0]      video_width_0       ,
    output  reg     [11:0]      video_height_0      ,

    output  reg     [11:0]      video_left_offset_1 ,
    output  reg     [11:0]      video_top_offset_1  ,
    output  reg     [11:0]      video_width_1       ,
    output  reg     [11:0]      video_height_1      ,

    output  reg     [11:0]      video_left_offset_2 ,
    output  reg     [11:0]      video_top_offset_2  ,
    output  reg     [11:0]      video_width_2       ,
    output  reg     [11:0]      video_height_2      ,

    output  reg     [11:0]      video_left_offset_3 ,
    output  reg     [11:0]      video_top_offset_3  ,
    output  reg     [11:0]      video_width_3       ,
    output  reg     [11:0]      video_height_3      ,

    output  reg     [19:0]      frame_size_0        ,
    output  reg     [19:0]      frame_size_1        ,
    output  reg     [19:0]      frame_size_2        ,
    output  reg     [19:0]      frame_size_3        
);

//===========================================================================
// 输入信号vs打拍
//===========================================================================
reg vs_in_reg0;
reg vs_in_reg1;

reg camera_vsync_0_reg0;
reg camera_vsync_0_reg1;

reg camera_vsync_1_reg0;
reg camera_vsync_1_reg1;

reg camera_vsync_2_reg0;
reg camera_vsync_2_reg1;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        vs_in_reg0 <= 1'b0;
        vs_in_reg1 <= 1'b0;
    end
    else begin
        vs_in_reg0 <= vs_in;
        vs_in_reg1 <= vs_in_reg0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        camera_vsync_0_reg0 <= 1'b0;
        camera_vsync_0_reg1 <= 1'b0;
    end
    else begin
        camera_vsync_0_reg0 <= camera_vsync_0;
        camera_vsync_0_reg1 <= camera_vsync_0_reg0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        camera_vsync_1_reg0 <= 1'b0;
        camera_vsync_1_reg1 <= 1'b0;
    end
    else begin
        camera_vsync_1_reg0 <= camera_vsync_1;
        camera_vsync_1_reg1 <= camera_vsync_1_reg0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        camera_vsync_2_reg0 <= 1'b0;
        camera_vsync_2_reg1 <= 1'b0;
    end
    else begin
        camera_vsync_2_reg0 <= camera_vsync_2;
        camera_vsync_2_reg1 <= camera_vsync_2_reg0;
    end
end

wire    posedge_vs_in;
wire    posedge_camera_vsync_0;
wire    posedge_camera_vsync_1;
wire    posedge_camera_vsync_2;

assign posedge_vs_in = ~vs_in_reg1 & vs_in_reg0;
assign posedge_camera_vsync_0 = ~camera_vsync_0_reg1 & camera_vsync_0_reg0;
assign posedge_camera_vsync_1 = ~camera_vsync_1_reg1 & camera_vsync_1_reg0;
assign posedge_camera_vsync_2 = ~camera_vsync_2_reg1 & camera_vsync_2_reg0;

//===========================================================================
// 状态机
//===========================================================================
reg [2:0] curr_state;
reg [2:0] next_state;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        curr_state <= 3'b000;
    else
        curr_state <= next_state;
end

always @(*) begin
    next_state = curr_state;
    case(curr_state)
        3'b000: begin
            if(key_mode)
                next_state = 3'b001;
            else
                next_state = 3'b000;
        end
        3'b001: begin
            if(key_mode)
                next_state = 3'b010;
            else
                next_state = 3'b001;
        end
        3'b010: begin
            if(key_mode)
                next_state = 3'b011;
            else
                next_state = 3'b010;
        end
        3'b011: begin
            if(key_mode)
                next_state = 3'b100;
            else
                next_state = 3'b011;
        end
        3'b100: begin
            if(key_mode)
                next_state = 3'b000;
            else
                next_state = 3'b100;
        end
        default: begin
            next_state = 3'b000;
        end
    endcase
end

reg [2:0] vs_mode;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        vs_mode <= 3'b000;
    else if(posedge_camera_vsync_0 || posedge_camera_vsync_1 || posedge_camera_vsync_2 || posedge_vs_in)
        vs_mode <= curr_state;
    else
        vs_mode <= vs_mode;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        mode_data <= 3'd0;

        video_left_offset_0 <= 12'd0;
        video_top_offset_0  <= 12'd0;
        video_width_0       <= 12'd640;
        video_height_0      <= 12'd360;

        video_left_offset_1 <= 12'd640;
        video_top_offset_1  <= 12'd0;
        video_width_1       <= 12'd640;
        video_height_1      <= 12'd360;

        video_left_offset_2 <= 12'd0;
        video_top_offset_2  <= 12'd360;
        video_width_2       <= 12'd640;
        video_height_2      <= 12'd360;

        video_left_offset_3 <= 12'd640;
        video_top_offset_3  <= 12'd360;
        video_width_3       <= 12'd640;
        video_height_3      <= 12'd360;

        frame_size_0 <= 20'd230_400;
        frame_size_1 <= 20'd230_400;
        frame_size_2 <= 20'd230_400;
        frame_size_3 <= 20'd230_400;
    end
    else begin
        case(vs_mode)
            3'b000: begin
                mode_data <= 3'd0;
                video_left_offset_0 <= 12'd0;
                video_top_offset_0  <= 12'd0;
                video_width_0       <= 12'd640;
                video_height_0      <= 12'd360;
                video_left_offset_1 <= 12'd640;
                video_top_offset_1  <= 12'd0;
                video_width_1       <= 12'd640;
                video_height_1      <= 12'd360;
                video_left_offset_2 <= 12'd0;
                video_top_offset_2  <= 12'd360;
                video_width_2       <= 12'd640;
                video_height_2      <= 12'd360;
                video_left_offset_3 <= 12'd640;
                video_top_offset_3  <= 12'd360;
                video_width_3       <= 12'd640;
                video_height_3      <= 12'd360;

                frame_size_0 <= 20'd230_400;
                frame_size_1 <= 20'd230_400;
                frame_size_2 <= 20'd230_400;
                frame_size_3 <= 20'd230_400;
            end
            3'b001: begin
                mode_data <= 3'd1;
                video_left_offset_0 <= 12'd0;
                video_top_offset_0  <= 12'd0;
                video_width_0       <= 12'd1280;
                video_height_0      <= 12'd720;
                video_left_offset_1 <= 12'd0;
                video_top_offset_1  <= 12'd0;
                video_width_1       <= 12'd0;
                video_height_1      <= 12'd0;
                video_left_offset_2 <= 12'd0;
                video_top_offset_2  <= 12'd0;
                video_width_2       <= 12'd0;
                video_height_2      <= 12'd0;
                video_left_offset_3 <= 12'd0;
                video_top_offset_3  <= 12'd0;
                video_width_3       <= 12'd0;
                video_height_3      <= 12'd0;

                frame_size_0 <= 20'd921_600;
                frame_size_1 <= 20'd921_600;
                frame_size_2 <= 20'd921_600;
                frame_size_3 <= 20'd921_600;
            end
            3'b010: begin
                mode_data <= 3'd2;
                video_left_offset_0 <= 12'd0;
                video_top_offset_0  <= 12'd0;
                video_width_0       <= 12'd0;
                video_height_0      <= 12'd0;
                video_left_offset_1 <= 12'd0;
                video_top_offset_1  <= 12'd0;
                video_width_1       <= 12'd1280;
                video_height_1      <= 12'd720;
                video_left_offset_2 <= 12'd0;
                video_top_offset_2  <= 12'd0;
                video_width_2       <= 12'd0;
                video_height_2      <= 12'd0;
                video_left_offset_3 <= 12'd0;
                video_top_offset_3  <= 12'd0;
                video_width_3       <= 12'd0;
                video_height_3      <= 12'd0;

                frame_size_0 <= 20'd921_600;
                frame_size_1 <= 20'd921_600;
                frame_size_2 <= 20'd921_600;
                frame_size_3 <= 20'd921_600;
            end
            3'b011: begin
                mode_data <= 3'd3;
                video_left_offset_0 <= 12'd0;
                video_top_offset_0  <= 12'd0;
                video_width_0       <= 12'd0;
                video_height_0      <= 12'd0;
                video_left_offset_1 <= 12'd0;
                video_top_offset_1  <= 12'd0;
                video_width_1       <= 12'd0;
                video_height_1      <= 12'd0;
                video_left_offset_2 <= 12'd0;
                video_top_offset_2  <= 12'd0;
                video_width_2       <= 12'd1280;
                video_height_2      <= 12'd720;
                video_left_offset_3 <= 12'd0;
                video_top_offset_3  <= 12'd0;
                video_width_3       <= 12'd0;
                video_height_3      <= 12'd0;

                frame_size_0 <= 20'd921_600;
                frame_size_1 <= 20'd921_600;
                frame_size_2 <= 20'd921_600;
                frame_size_3 <= 20'd921_600;
            end
            3'b100: begin
                mode_data <= 3'd4;
                video_left_offset_0 <= 12'd0;
                video_top_offset_0  <= 12'd0;
                video_width_0       <= 12'd0;
                video_height_0      <= 12'd0;
                video_left_offset_1 <= 12'd0;
                video_top_offset_1  <= 12'd0;
                video_width_1       <= 12'd0;
                video_height_1      <= 12'd0;
                video_left_offset_2 <= 12'd0;
                video_top_offset_2  <= 12'd0;
                video_width_2       <= 12'd0;
                video_height_2      <= 12'd0;
                video_left_offset_3 <= 12'd0;
                video_top_offset_3  <= 12'd0;
                video_width_3       <= 12'd1280;
                video_height_3      <= 12'd720;

                frame_size_0 <= 20'd921_600;
                frame_size_1 <= 20'd921_600;
                frame_size_2 <= 20'd921_600;
                frame_size_3 <= 20'd921_600;
            end
            default: begin
                video_left_offset_0 <= 12'd0;
                video_top_offset_0  <= 12'd0;
                video_width_0       <= 12'd640;
                video_height_0      <= 12'd360;
                video_left_offset_1 <= 12'd640;
                video_top_offset_1  <= 12'd0;
                video_width_1       <= 12'd640;
                video_height_1      <= 12'd360;
                video_left_offset_2 <= 12'd0;
                video_top_offset_2  <= 12'd360;
                video_width_2       <= 12'd640;
                video_height_2      <= 12'd360;
                video_left_offset_3 <= 12'd640;
                video_top_offset_3  <= 12'd360;
                video_width_3       <= 12'd640;
                video_height_3      <= 12'd360;

                frame_size_0 <= 20'd230_400;
                frame_size_1 <= 20'd230_400;
                frame_size_2 <= 20'd230_400;
                frame_size_3 <= 20'd230_400;
            end
        endcase
    end
end

endmodule