`timescale 1ns / 1ps
/************************************************************************
 * Description: 移除了纯组合逻辑除法器，调用外置 16 级流水线除法器。
 * Pipeline Latency: 20 clock cycles (原版为 3 cycles，增加了 17 cycles)
 ************************************************************************/
module rgb2hsv(
    input           clk     ,
    input           reset_n ,
    
    input           vs      ,
    input           hs      ,
    input           de      ,
    input [7:0]     rgb_r   ,
    input [7:0]     rgb_g   ,
    input [7:0]     rgb_b   , 
    
    output          hsv_vs  ,
    output          hsv_hs  ,
    output          hsv_de  ,    
    output [8:0]    hsv_h   ,
    output [8:0]    hsv_s   ,
    output [7:0]    hsv_v   
);

// =========================================================================
// Pipeline Stage 1: 计算最大最小值，预乘 60
// =========================================================================
reg [7:0]  max_p1, min_p1;
reg [7:0]  r_p1, g_p1, b_p1;
reg [13:0] r_60_p1, g_60_p1, b_60_p1;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        max_p1 <= 0; min_p1 <= 0;
        r_p1 <= 0; g_p1 <= 0; b_p1 <= 0;
        r_60_p1 <= 0; g_60_p1 <= 0; b_60_p1 <= 0;
    end else begin
        r_p1 <= rgb_r; g_p1 <= rgb_g; b_p1 <= rgb_b;
        r_60_p1 <= rgb_r * 60;
        g_60_p1 <= rgb_g * 60;
        b_60_p1 <= rgb_b * 60;
        
        // 求 Max
        if (rgb_r >= rgb_g && rgb_r >= rgb_b) max_p1 <= rgb_r;
        else if (rgb_g >= rgb_r && rgb_g >= rgb_b) max_p1 <= rgb_g;
        else max_p1 <= rgb_b;
        
        // 求 Min
        if (rgb_r <= rgb_g && rgb_r <= rgb_b) min_p1 <= rgb_r;
        else if (rgb_g <= rgb_r && rgb_g <= rgb_b) min_p1 <= rgb_g;
        else min_p1 <= rgb_b;
    end
end

// =========================================================================
// Pipeline Stage 2: 计算差值并准备除法器的被除数和除数
// =========================================================================
reg [15:0] h_num_p2, h_den_p2;
reg [15:0] s_num_p2, s_den_p2;
reg [1:0]  max_color_p2; // 0:R, 1:G, 2:B
reg        sign_flag_p2; // 记录差值符号用于后续加减
reg        max_is_0_p2;
reg        max_min_is_0_p2;
reg [7:0]  max_p2;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        h_num_p2 <= 0; h_den_p2 <= 0;
        s_num_p2 <= 0; s_den_p2 <= 0;
        max_color_p2 <= 0; sign_flag_p2 <= 0;
        max_is_0_p2 <= 0; max_min_is_0_p2 <= 0;
        max_p2 <= 0;
    end else begin
        max_p2 <= max_p1;
        max_is_0_p2 <= (max_p1 == 0);
        max_min_is_0_p2 <= ((max_p1 - min_p1) == 0);
        
        // S 的除法参数: (max - min)*256 / max
        s_num_p2 <= {(max_p1 - min_p1), 8'b0};
        s_den_p2 <= {8'b0, max_p1};
        
        // H 的除法参数
        h_den_p2 <= {8'b0, max_p1 - min_p1};
        
        if (max_p1 == r_p1) begin
            max_color_p2 <= 0;
            sign_flag_p2 <= (g_60_p1 >= b_60_p1);
            h_num_p2 <= (g_60_p1 >= b_60_p1) ? (g_60_p1 - b_60_p1) : (b_60_p1 - g_60_p1);
        end else if (max_p1 == g_p1) begin
            max_color_p2 <= 1;
            sign_flag_p2 <= (b_60_p1 >= r_60_p1);
            h_num_p2 <= (b_60_p1 >= r_60_p1) ? (b_60_p1 - r_60_p1) : (r_60_p1 - b_60_p1);
        end else begin
            max_color_p2 <= 2;
            sign_flag_p2 <= (r_60_p1 >= g_60_p1);
            h_num_p2 <= (r_60_p1 >= g_60_p1) ? (r_60_p1 - g_60_p1) : (g_60_p1 - r_60_p1);
        end
    end
end

// =========================================================================
// Pipeline Stage 3 - 19 (17 cycles): 实例化流水线除法器
// =========================================================================
wire [15:0] h_quotient;
wire [15:0] s_quotient;

// 例化外部的除法器模块
pipelined_divider #(
    .W(16)
) div_h (
    .clk(clk), 
    .rst_n(reset_n),
    .dividend(h_num_p2), 
    .divisor(h_den_p2),
    .quotient(h_quotient)
);

pipelined_divider #(
    .W(16)
) div_s (
    .clk(clk), 
    .rst_n(reset_n),
    .dividend(s_num_p2), 
    .divisor(s_den_p2),
    .quotient(s_quotient)
);

// 延时匹配控制信号 (除法器占 17 拍，需要将 stage 2 的控制信号打 17 拍对齐)
reg [1:0] max_color_d [0:16];
reg       sign_flag_d [0:16];
reg       max_is_0_d  [0:16];
reg       max_min_is_0_d [0:16];
reg [7:0] max_d [0:16];

integer i;
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        for(i=0; i<17; i=i+1) begin
            max_color_d[i] <= 0; sign_flag_d[i] <= 0;
            max_is_0_d[i] <= 0;  max_min_is_0_d[i] <= 0;
            max_d[i] <= 0;
        end
    end else begin
        max_color_d[0] <= max_color_p2;
        sign_flag_d[0] <= sign_flag_p2;
        max_is_0_d[0]  <= max_is_0_p2;
        max_min_is_0_d[0] <= max_min_is_0_p2;
        max_d[0] <= max_p2;
        
        for(i=1; i<17; i=i+1) begin
            max_color_d[i] <= max_color_d[i-1];
            sign_flag_d[i] <= sign_flag_d[i-1];
            max_is_0_d[i]  <= max_is_0_d[i-1];
            max_min_is_0_d[i] <= max_min_is_0_d[i-1];
            max_d[i] <= max_d[i-1];
        end
    end
end

// =========================================================================
// Pipeline Stage 20: 组合最终结果
// =========================================================================
reg [8:0] hsv_h_r;
reg [8:0] hsv_s_r;
reg [7:0] hsv_v_r;

wire [1:0] out_max_color = max_color_d[16];
wire       out_sign      = sign_flag_d[16];
wire       out_max_is_0  = max_is_0_d[16];
wire       out_max_min_0 = max_min_is_0_d[16];

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        hsv_h_r <= 0; hsv_s_r <= 0; hsv_v_r <= 0;
    end else begin
        if (out_max_is_0) begin
            hsv_h_r <= 0; hsv_s_r <= 0; hsv_v_r <= 0;
        end else begin
            hsv_v_r <= max_d[16];
            hsv_s_r <= s_quotient[8:0];
            
            if (out_max_min_0) begin
                hsv_h_r <= 0;
            end else begin
                case (out_max_color)
                    0: hsv_h_r <= out_sign ? h_quotient[13:0] : (14'd360 - h_quotient[13:0]);
                    1: hsv_h_r <= out_sign ? (h_quotient[13:0] + 120) : (14'd120 - h_quotient[13:0]);
                    2: hsv_h_r <= out_sign ? (h_quotient[13:0] + 240) : (14'd240 - h_quotient[13:0]);
                    default: hsv_h_r <= 0;
                endcase
            end
        end
    end
end

// =========================================================================
// 同步信号打拍 (总延迟 20 拍：S1 + S2 + Div17 + S20)
// =========================================================================
reg [19:0] vs_delay;
reg [19:0] hs_delay;
reg [19:0] de_delay;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        vs_delay <= 0; hs_delay <= 0; de_delay <= 0;
    end else begin
        vs_delay <= {vs_delay[18:0], vs};
        hs_delay <= {hs_delay[18:0], hs};
        de_delay <= {de_delay[18:0], de};
    end
end

assign hsv_vs = vs_delay[19];
assign hsv_hs = hs_delay[19];
assign hsv_de = de_delay[19];

assign hsv_h  = hsv_h_r;
assign hsv_s  = hsv_s_r;
assign hsv_v  = hsv_v_r;

endmodule