`timescale 1ns / 1ps

module tmds_encoder (
    input            pix_clk,  // pixel clock input 像素时钟
    input            rstn,     // async. reset input (active low) 异步复位，低电平有效
    input      [7:0] din,      // data inputs: expect registered 8bit数据输入
    input            c0,       // c0 input 控制信号0
    input            c1,       // c1 input 控制信号1
    input            de,       // de input 数据有效信号
    output reg [9:0] dout      // data outputs 10bit TMDS编码输出
);

//==========================================================================
// Counting number of 1s and 0s for each incoming pixel
// component. Pipe line the result.
// Register Data Input so it matches the pipe lined adder
// output
// 统计输入数据中1的个数，并对输入数据打拍
//==========================================================================
reg [3:0] n1d; // number of 1s in din 输入数据中1的个数
reg [7:0] din_q;

always @ (posedge pix_clk or negedge rstn) begin
    if(!rstn) begin
        n1d   <= 4'h0;
        din_q <= 8'h0;
    end
    else begin
        n1d   <= din[0] + din[1] + din[2] + din[3] + din[4] + din[5] + din[6] + din[7];
        din_q <= din;
    end
end

//==========================================================================
// Stage 1: 8 bit -> 9 bit
// Refer to DVI 1.0 Specification, page 29, Figure 3-5
// 第一阶段: 8bit -> 9bit 编码
// 参考 DVI 1.0 规范, 第29页, 图3-5
// if((n1d > 4'h4) | ((n1d == 4'h4) & (din_q[0] == 1'b0)))
//     qm[0] = D[0]
//     qm[n] = qm[n-1] ~^ D[n];  // XNOR
// else
//     qm[0] = D[0]
//     qm[n] = qm[n-1] ^ D[n];   // XOR
// qm[8] = ~((n1d > 4'h4) | ((n1d == 4'h4) & (din_q[0] == 1'b0)))
//==========================================================================
wire decision1;
assign decision1 = (n1d > 4'h4) | ((n1d == 4'h4) & (din_q[0] == 1'b0));
wire [8:0] q_m;
assign q_m[0] = din_q[0];
generate
   genvar  i;
   for (i = 1; i < 8; i = i + 1)
   begin
       assign q_m[i] = (decision1) ? (q_m[i-1'b1] ^~ din_q[i]) : (q_m[i-1'b1] ^ din_q[i]);
   end
endgenerate

assign q_m[8] = (decision1) ? 1'b0 : 1'b1;

//==========================================================================
// Stage 2: 9 bit -> 10 bit
// Refer to DVI 1.0 Specification, page 29, Figure 3-5
// 第二阶段: 9bit -> 10bit 编码
// 计算q_m中1和0的个数
//==========================================================================
reg [3:0] n1q_m, n0q_m; // number of 1s and 0s for q_m q_m中1和0的个数
always @ (posedge pix_clk or negedge rstn) begin
    if(!rstn) begin
        n1q_m <= 4'h0;
        n0q_m <= 4'h0;
    end
    else begin
        n1q_m <= q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7];
        n0q_m <= 4'h8 - (q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7]);
    end
end

// 控制字符定义(消隐期间使用)
parameter CTRLTOKEN0 = 10'b1101010100;  // c1=0, c0=0
parameter CTRLTOKEN1 = 10'b0010101011;  // c1=0, c0=1
parameter CTRLTOKEN2 = 10'b0101010100;  // c1=1, c0=0
parameter CTRLTOKEN3 = 10'b1010101011;  // c1=1, c0=1

reg signed [4:0] cnt; // disparity counter, MSB is the sign bit 极性计数器，最高位是符号位
wire decision2, decision3;

assign decision2 = (cnt == 5'h0) | (n1q_m == n0q_m);

//==========================================================================
// [(cnt > 0) and (N1q_m > N0q_m)] or [(cnt < 0) and (N0q_m > N1q_m)]
// cnt 正值表示累计传输1多，负值表示累计传输0多
// 传输1多时，当前1的数值比0多、或者传输0多时，当前0比1多：
//            将q_m[7:0]取反
// 若历史传输与当前互补1与0的平衡，则不对q_m[7:0]更改，使得传输的1与0的数量处于平衡
//==========================================================================
assign decision3 = (~cnt[4] & (n1q_m > n0q_m)) | (cnt[4] & (n0q_m > n1q_m));

////////////////////////////////////
// pipe line alignment
// 流水线对齐
////////////////////////////////////
reg       de_q, de_reg;
reg       c0_q, c1_q;
reg       c0_reg, c1_reg;
reg [8:0] q_m_reg;

always @ (posedge pix_clk or negedge rstn) begin
    if(!rstn) begin
        de_q    <= 1'b0;
        de_reg  <= 1'b0;
        c0_q    <= 1'b0;
        c0_reg  <= 1'b0;
        c1_q    <= 1'b0;
        c1_reg  <= 1'b0;
        q_m_reg <= 9'h0;
    end
    else begin
        de_q    <= de;
        de_reg  <= de_q;
        c0_q    <= c0;
        c0_reg  <= c0_q;
        c1_q    <= c1;
        c1_reg  <= c1_q;
        q_m_reg <= q_m;
    end
end

///////////////////////////////
// 10-bit out
// disparity counter
// 10bit输出和极性计数器
///////////////////////////////
always @ (posedge pix_clk or negedge rstn) begin
    if(!rstn) 
        dout <= 10'h0;
    else begin
        if (de_reg) begin // active pixels DE == HIGH 有效像素区域
            if(decision2) begin // 累计传输1与0的数量一致，或者当前0与1的数值一致
                dout[9]   <= ~q_m_reg[8]; 
                dout[8]   <= q_m_reg[8]; 
                dout[7:0] <= (q_m_reg[8]) ? q_m_reg[7:0] : ~q_m_reg[7:0];
            end 
            else begin
                if(decision3) begin // 需要取反以平衡极性
                    dout[9]   <= 1'b1;
                    dout[8]   <= q_m_reg[8];
                    dout[7:0] <= ~q_m_reg[7:0];
                end 
                else begin // 不需要取反
                    dout[9]   <= 1'b0;
                    dout[8]   <= q_m_reg[8];
                    dout[7:0] <= q_m_reg[7:0];
                end
            end
        end 
        else begin // blank DE == LOW 消隐区域，发送控制字符
            case ({c0_reg, c1_reg})
                2'b00:   dout <= CTRLTOKEN0;  // {c0=0,c1=0} -> 1101010100
                2'b01:   dout <= CTRLTOKEN1;  // {c0=0,c1=1} -> 0010101011
                2'b10:   dout <= CTRLTOKEN2;  // {c0=1,c1=0} -> 0101010100
                default: dout <= CTRLTOKEN3;  // {c0=1,c1=1} -> 1010101011
            endcase
        end
    end
end

// 极性计数器更新
always @ (posedge pix_clk or negedge rstn) begin
    if(!rstn) 
        cnt <= 5'h0;
    else begin
        if (de_reg) begin // active pixels DE == HIGH 有效像素区域
            if(decision2) // 累计传输1与0的数量一致，或者当前0与1的数值一致
                cnt <= (~q_m_reg[8]) ? (cnt + n0q_m - n1q_m) : (cnt + n1q_m - n0q_m);
            else begin
                if(decision3) 
                    cnt <= cnt + {q_m_reg[8], 1'b0} + (n0q_m - n1q_m);
                else 
                    cnt <= cnt - {~q_m_reg[8], 1'b0} + (n1q_m - n0q_m);
            end
        end 
        else // blank DE == LOW 消隐区域，极性计数器清零
            cnt <= 5'h0;
    end
end
  
endmodule
