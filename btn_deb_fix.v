`timescale 1ns / 1ps

module btn_deb_fix#(
    parameter BTN_WIDTH = 4'd8,
    parameter BTN_DELAY = 20'h7_ffff
)(
    input   wire                    clk             , //
    input   wire                    rst_n           , //
    input   wire    [BTN_WIDTH-1:0] btn_in          ,
    output  reg     [BTN_WIDTH-1:0] btn_flag        , // 脉冲信号：按键按下瞬间产生一个时钟周期的高电平
    output  reg     [BTN_WIDTH-1:0] btn_deb_fix       // 电平信号：消抖后的按键状态
    
);
//16'h3ad43;
reg [19:0] cnt[BTN_WIDTH-1:0];
reg [BTN_WIDTH-1:0] flag;
reg [BTN_WIDTH-1:0] btn_in_reg;
reg [BTN_WIDTH-1:0] btn_deb_fix_d;  // 上一拍的消抖输出

always @(posedge clk or negedge rst_n) begin
   if(!rst_n)
       btn_in_reg <= {BTN_WIDTH{1'b1}};
   else
       btn_in_reg <= btn_in;
end

genvar i;
generate
for(i = 0; i < BTN_WIDTH; i = i + 1)begin
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            flag[i] <= 1'b1;
        else if (btn_in_reg[i] ^ btn_in[i]) //取按键边沿开始抖动区间标识
            flag[i] <= 1'b1;
        else if (cnt[i]==BTN_DELAY) //持续10ms-20ms后归零
            flag[i] <= 1'b0;
        else
            flag[i] <= flag[i];
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            cnt[i] <= 20'd0;
        else if(cnt[i]==BTN_DELAY) //计数10ms-20ms时归零
            cnt[i] <= 20'd0;
        else if(flag[i]) //抖动区间有效时计数
            cnt[i] <= cnt[i] + 1'b1;
        else //非抖动区间保持0
            cnt[i] <= 20'd0;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            btn_deb_fix[i] <= 1'b1;
        else if(flag[i]) //抖动区间，消抖输出保持
            btn_deb_fix[i] <= btn_deb_fix[i];
        else //非抖动区间，按键状态传递到消抖输出
            btn_deb_fix[i] <= btn_in[i];
    end

    // 保存上一拍的消抖输出，用于边沿检测
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            btn_deb_fix_d[i] <= 1'b1;
        else
            btn_deb_fix_d[i] <= btn_deb_fix[i];
    end

    // 检测下降沿（按键按下）产生脉冲
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            btn_flag[i] <= 1'b0;
        else if(btn_deb_fix_d[i] == 1'b1 && btn_deb_fix[i] == 1'b0)
            btn_flag[i] <= 1'b1;  // 检测到按下（下降沿），产生一个周期脉冲
        else
            btn_flag[i] <= 1'b0;
    end
end
endgenerate

endmodule