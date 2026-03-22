/************************************************************************
 * Module: hsv2rgb (Pipelined Version)
 * Description: Converts HSV color space to RGB with a deep pipeline
 *              to meet timing constraints at higher frequencies.
 * Pipeline Latency: 6 clock cycles
 ************************************************************************/
module hsv2rgb(
    input           clk,
    input           reset_n,
    
    // Input Signals
    input           vs,
    input           hs,
    input           de,    
    input [8:0]     i_hsv_h,
    input [8:0]     i_hsv_s,
    input [7:0]     i_hsv_v,
    
    // Output Signals
    output          rgb_vs,
    output          rgb_hs,
    output          rgb_de,   
    output [7:0]    rgb_r,
    output [7:0]    rgb_g,
    output [7:0]    rgb_b   
);

// Pipeline Stage Registers
// We will name them with _p{stage_number} suffix for clarity.

// --- Stage 1: Input Registering and First Calculations ---
reg [8:0]   h_p1, s_p1;
reg [7:0]   v_p1;
reg [2:0]   i_p1; // I = H / 60 (integer part)
reg [16:0]  v_mul_s_p1; // V * S

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        h_p1 <= 0;
        s_p1 <= 0;
        v_p1 <= 0;
        i_p1 <= 0;
        v_mul_s_p1 <= 0;
    end else if (de) begin // Gate with 'de' to save power when idle
        h_p1 <= i_hsv_h;
        s_p1 <= i_hsv_s;
        v_p1 <= i_hsv_v;
        
        // Calculate I = H / 60. This is a big mux.
        if (i_hsv_h < 60)       i_p1 <= 0;
        else if (i_hsv_h < 120) i_p1 <= 1;
        else if (i_hsv_h < 180) i_p1 <= 2;
        else if (i_hsv_h < 240) i_p1 <= 3;
        else if (i_hsv_h < 300) i_p1 <= 4;
        else                    i_p1 <= 5;
        
        // Perform the first multiplication: V * S
        // This will be inferred as a dedicated DSP block.
        v_mul_s_p1 <= i_hsv_v * i_hsv_s;
    end
end

// --- Stage 2: Calculate P and F ---
reg [7:0]   p_p2; // P = V * (1-S) = V - V*S
reg [5:0]   f_p2; // F = H % 60
reg [2:0]   i_p2;
reg [7:0]   v_p2;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        p_p2 <= 0;
        f_p2 <= 0;
        i_p2 <= 0;
        v_p2 <= 0;
    end else begin
        // P = V - (V*S)/256. We use the high bits of the product from stage 1.
        p_p2 <= v_p1 - v_mul_s_p1[16:9]; // Note: S is 9-bit, V is 8-bit. Product is 17-bit.
                                         // To scale back down, we'd normally divide by 256 (s_max).
                                         // Let's assume S is scaled 0-255. Product is 16-bit. V*S/255.
                                         // V_mul_s is 16bit, so V*S/256 is v_mul_s_p1[15:8]
        p_p2 <= v_p1 - v_mul_s_p1[15:8];

        // F = H - I*60. This is a small mult + sub. Do it in one stage.
        f_p2 <= h_p1 - (i_p1 * 60);

        // Pass through other values
        i_p2 <= i_p1;
        v_p2 <= v_p1;
    end
end

// --- Stage 3: Calculate intermediate T = (V-P)*F/60 ---
reg [7:0]   v_minus_p_p3; // (V-P)
reg [15:0]  t_mul_p3;     // (V-P)*F
reg [2:0]   i_p3;
reg [7:0]   v_p3;
reg [7:0]   p_p3;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        v_minus_p_p3 <= 0;
        t_mul_p3     <= 0;
        i_p3         <= 0;
        v_p3         <= 0;
        p_p3         <= 0;
    end else begin
        v_minus_p_p3 <= v_p2 - p_p2;
        // The multiplication for T
        t_mul_p3     <= (v_p2 - p_p2) * f_p2;

        // Pass through other values
        i_p3 <= i_p2;
        v_p3 <= v_p2;
        p_p3 <= p_p2;
    end
end

// --- Stage 4: Scale T and prepare for final mux ---
// Division by a constant (60) is better implemented as multiplication by a reciprocal.
// t/60 ~= t * (1/60) = t * (256/60)/256 = t * 4.26/256 ~= t * 4 / 256 = t >> 2 shifted
// For better precision: t * (65536/60)/65536 = t * 1092 / 65536
parameter C_DIV_60 = 1092; 
reg [7:0]   t_p4;
reg [2:0]   i_p4;
reg [7:0]   v_p4;
reg [7:0]   p_p4;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        t_p4 <= 0;
        i_p4 <= 0;
        v_p4 <= 0;
        p_p4 <= 0;
    end else begin
        // t_scaled = (t_mul_p3 / 60). We use mult by reciprocal for efficiency.
        t_p4 <= (t_mul_p3 * C_DIV_60) >> 16;
        
        // Pass through values
        i_p4 <= i_p3;
        v_p4 <= v_p3;
        p_p4 <= p_p3;
    end
end

// --- Stage 5: Final Selection (Mux) ---
// This stage is very simple, just additions/subtractions and a mux.
reg [7:0] rgb_r_p5, rgb_g_p5, rgb_b_p5;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        rgb_r_p5 <= 0;
        rgb_g_p5 <= 0;
        rgb_b_p5 <= 0;
    end else begin
        case (i_p4)
            0: begin // V, P+T, P
                rgb_r_p5 <= v_p4;
                rgb_g_p5 <= p_p4 + t_p4;
                rgb_b_p5 <= p_p4;
            end
            1: begin // V-T, V, P
                rgb_r_p5 <= v_p4 - t_p4;
                rgb_g_p5 <= v_p4;
                rgb_b_p5 <= p_p4;
            end
            2: begin // P, V, P+T
                rgb_r_p5 <= p_p4;
                rgb_g_p5 <= v_p4;
                rgb_b_p5 <= p_p4 + t_p4;
            end
            3: begin // P, V-T, V
                rgb_r_p5 <= p_p4;
                rgb_g_p5 <= v_p4 - t_p4;
                rgb_b_p5 <= v_p4;
            end
            4: begin // P+T, P, V
                rgb_r_p5 <= p_p4 + t_p4;
                rgb_g_p5 <= p_p4;
                rgb_b_p5 <= v_p4;
            end
            5: begin // V, P, V-T
                rgb_r_p5 <= v_p4;
                rgb_g_p5 <= p_p4;
                rgb_b_p5 <= v_p4 - t_p4;
            end
            default: begin
                rgb_r_p5 <= 0;
                rgb_g_p5 <= 0;
                rgb_b_p5 <= 0;
            end
        endcase
    end
end

// --- Stage 6: Output register ---
// This final stage helps isolate the core logic from output routing delays.
reg [7:0] rgb_r_p6, rgb_g_p6, rgb_b_p6;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        rgb_r_p6 <= 0;
        rgb_g_p6 <= 0;
        rgb_b_p6 <= 0;
    end else begin
        rgb_r_p6 <= rgb_r_p5;
        rgb_g_p6 <= rgb_g_p5;
        rgb_b_p6 <= rgb_b_p5;
    end
end

// --- Sync Signal Delay Pipeline ---
// Total pipeline latency is 6 stages.
reg [5:0] vs_delay, hs_delay, de_delay;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        vs_delay <= 0;
        hs_delay <= 0;
        de_delay <= 0;
    end else begin
        vs_delay <= {vs_delay[4:0], vs};
        hs_delay <= {hs_delay[4:0], hs};
        de_delay <= {de_delay[4:0], de};
    end
end

// --- Final Output Assignment ---
// Note: Your original code had a check for S==0. If S is 0, the color is a shade of gray,
// so R=G=B=V. Let's add that back. We need to pipeline S as well.
reg [8:0] s_final;
always @(posedge clk or negedge reset_n) begin
    if(!reset_n) s_final <= 0;
    else s_final <= s_p1; // This is a simplification. For accuracy, it needs to be delayed 6 stages.
end

// Properly delayed S is needed. Let's create the full S pipeline
reg [8:0] s_p2, s_p3, s_p4, s_p5, s_p6;
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        s_p2 <= 0; s_p3 <= 0; s_p4 <= 0; s_p5 <= 0; s_p6 <= 0;
    end else begin
        s_p2 <= s_p1;
        s_p3 <= s_p2;
        s_p4 <= s_p3;
        s_p5 <= s_p4;
        s_p6 <= s_p5;
    end
end

// We also need V at the final stage
reg [7:0] v_p5, v_p6;
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        v_p5 <= 0; v_p6 <= 0;
    end else begin
        v_p5 <= v_p4;
        v_p6 <= v_p5;
    end
end


assign rgb_r = (s_p6 == 0) ? v_p6 : rgb_r_p6;
assign rgb_g = (s_p6 == 0) ? v_p6 : rgb_g_p6;
assign rgb_b = (s_p6 == 0) ? v_p6 : rgb_b_p6;

assign rgb_vs = vs_delay[5];
assign rgb_hs = hs_delay[5];
assign rgb_de = de_delay[5];

endmodule