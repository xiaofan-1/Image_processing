`timescale 1ns / 1ps

module sort3(
    input  wire            clk      ,
    input  wire            rst_n    ,
    input  wire [7:0]      data1    ,
    input  wire [7:0]      data2    ,
    input  wire [7:0]      data3    ,
    output reg  [7:0]      max_data ,
    output reg  [7:0]      mid_data ,
    output reg  [7:0]      min_data
);

// --- 阶段 1: 比较 data1 与 data2 ---
wire [7:0] A1, B1;
assign A1 = (data1 < data2) ? data1 : data2; // 较小者
assign B1 = (data1 < data2) ? data2 : data1; // 较大者

// --- 阶段 2: 比较 B1 与 data3 ---
wire [7:0] Y2, Z2;
assign Y2 = (B1 < data3) ? B1 : data3;       // 较小者
assign Z2 = (B1 < data3) ? data3 : B1;       // 较大者

// --- 阶段 3: 比较 A1 与 Y2 ---
wire [7:0] X3, M3;
assign X3 = (A1 < Y2) ? A1 : Y2;             // 最小值
assign M3 = (A1 < Y2) ? Y2 : A1;             // 中间值

// --- 时序打寄存器，同步输出 ---
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        min_data <= 8'd0;
        mid_data <= 8'd0;
        max_data <= 8'd0;
    end else begin
        min_data <= X3;
        mid_data <= M3;
        max_data <= Z2;
    end
end

endmodule
