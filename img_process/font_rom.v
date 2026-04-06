// font_rom.v
`timescale 1ns / 1ps

module font_rom (
    input   wire            clk             ,
    input   wire            rst_n           ,
    input   wire    [11:0]  pixel_x         ,
    input   wire    [11:0]  pixel_y         ,
    input   wire            de              ,
    input   wire            vsync           ,  // 帧同步信号
    input   wire            key             ,
    output  reg     [2:0]   color_select    ,
    output  reg     [23:0]  data_o          
);

localparam
    IDLE    = 3'd0,
    RED		= 3'd1,
    GREEN   = 3'd2,
    BLUE    = 3'd3,
    YELLOW  = 3'd4;

wire	[23:0]	font_red_data;
wire	[23:0]	font_green_data;
wire	[23:0]	font_blue_data;
wire	[23:0]	font_yellow_data;

reg		[2:0]	curr_state;
reg		[2:0]	next_state;

// 直接用坐标计算 ROM 地址，不依赖计数器
// addra = pixel_y * 50 + pixel_x
// 50 = 32 + 16 + 2，用移位加法实现
wire [11:0] addra;
wire [11:0] font_y_offset = {pixel_y[5:0], 5'b0} + {1'b0, pixel_y[5:0], 4'b0} + {5'b0, pixel_y[5:0], 1'b0}; // pixel_y * 50
assign addra = font_y_offset + pixel_x;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        curr_state <= IDLE;
    else
        curr_state <= next_state;
end

always @(*) begin
    if(!rst_n)
        next_state = IDLE;
    else begin
        case(curr_state)
            IDLE   :next_state = RED;
            RED	   :begin
                if(key)
                    next_state = GREEN;
                else
                    next_state = curr_state;
            end
            GREEN  :begin
                if(key)
                    next_state = BLUE;
                else
                    next_state = curr_state;
            end
            BLUE   :begin
                if(key)
                    next_state = YELLOW;
                else
                    next_state = curr_state;
            end
            YELLOW  :begin
                if(key)
                    next_state = IDLE;
                else
                    next_state = curr_state;
            end
            default:next_state = IDLE;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        color_select <= 3'd0;
        data_o       <= 24'h0;
    end
    else begin
        case(next_state)
            IDLE 	:begin
                color_select <= 3'd0;
                data_o       <= 24'h0;
            end
            RED	    :begin
                color_select <= 3'd1;
                data_o       <= font_red_data;
            end
            GREEN   :begin
                color_select <= 3'd2;
                data_o       <= font_green_data;
            end
            BLUE    :begin
                color_select <= 3'd3;
                data_o       <= font_blue_data;
            end
            YELLOW   :begin
                color_select <= 3'd4;
                data_o       <= font_yellow_data;
            end
            default :begin
                color_select <= 3'd0;
                data_o       <= 24'h0;
            end
        endcase
    end
end

font_red font_red_u( 
    .clka(clk),    // input wire clka
    .addra(addra),  // input wire [11 : 0] addra
    .douta(font_red_data)  // output wire [23 : 0] douta
);

font_green font_green_u( 
    .clka(clk),    // input wire clka
    .addra(addra),  // input wire [11 : 0] addra
    .douta(font_green_data)  // output wire [23 : 0] douta
);

font_blue font_blue_u( 
    .clka(clk),    // input wire clka
    .addra(addra),  // input wire [11 : 0] addra
    .douta(font_blue_data)  // output wire [23 : 0] douta
);

font_yellow font_yellow_u( 
    .clka(clk),    // input wire clka
    .addra(addra),  // input wire [11 : 0] addra
    .douta(font_yellow_data)  // output wire [23 : 0] douta
);



endmodule