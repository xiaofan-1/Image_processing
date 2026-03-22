`timescale 1ns / 1ps

module image_template #(
	parameter	COL = 1280,
	parameter   ROW = 720
)(
    input   wire        clk         ,
    input   wire        rst_n       ,
    //输入
    input   wire        de_i        ,
    input   wire [7:0]  data_i      ,
    //输出数据
    output  reg  [7:0]  a0          ,
    output  reg  [7:0]  a1          ,
    output  reg  [7:0]  a2          ,
    output  reg  [7:0]  b0          ,
    output  reg  [7:0]  b1          ,
    output  reg  [7:0]  b2          ,
    output  reg  [7:0]  c0          ,
    output  reg  [7:0]  c1          ,
    output  reg  [7:0]  c2                    
);
reg  [10:0] cnt_col  ;
reg  [10:0] cnt_row  ;
reg  [10:0] cnt_fifo0;
reg  [10:0] cnt_fifo1;

wire [7:0]  fifo0_dout;//fifo输出数据
wire [7:0]  fifo1_dout;

wire        fifo0_wr_en;
wire        fifo0_rd_en;
wire        fifo1_wr_en;
wire        fifo1_rd_en;
wire	       pixel_en;

assign pixel_en = de_i && (cnt_col < COL);
assign fifo0_wr_en = (cnt_row < ROW - 1 ) ? pixel_en : 1'b0;
assign fifo0_rd_en = (cnt_row > 0) ? pixel_en : 1'b0;
assign fifo1_wr_en = (cnt_row < ROW - 1 && cnt_row > 0) ? pixel_en : 1'b0;
assign fifo1_rd_en = (cnt_row > 1   ) ? pixel_en : 1'b0;

wire  [7:0]  a_reg;
wire  [7:0]  b_reg;
wire  [7:0]  c_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt_fifo0 <= 11'd0;
    else if(de_i) begin
        if(cnt_fifo0 == COL)
            cnt_fifo0 <= cnt_fifo0;
        else
            cnt_fifo0 <= cnt_fifo0 + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt_fifo1 <= 11'd0;
    else if(fifo1_wr_en) begin
        if(cnt_fifo1 == COL)
            cnt_fifo1 <= cnt_fifo1;
        else
            cnt_fifo1 <= cnt_fifo1 + 1;
    end
end
//------------------------------------------
//col计数器
//------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt_col <= 11'd0;
    else if(de_i) begin
        if(cnt_col == COL - 1)
            cnt_col <= 0;
        else
            cnt_col <= cnt_col + 1;
    end
end
//------------------------------------------
//row计数器
//------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt_row <= 11'd0;
    else if(cnt_row == ROW - 1 && cnt_col == COL - 1)
        cnt_row <= 0; 
    else if(cnt_col == COL - 1)
        cnt_row <= cnt_row + 1;
    else
        cnt_row <= cnt_row;    
end

//------------------------------------------
//取3*3模板
//------------------------------------------
assign a_reg = fifo1_dout;
assign b_reg = fifo0_dout;
assign c_reg = data_i    ;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        {a0, a1, a2} <= {8'd0, 8'd0, 8'd0};
        {b0, b1, b2} <= {8'd0, 8'd0, 8'd0};
        {c0, c1, c2} <= {8'd0, 8'd0, 8'd0};
    end
    else if(cnt_row == 0) begin
        if(cnt_col == 0) begin
            {a0, a1, a2} <= {c_reg, c_reg, c_reg};
            {b0, b1, b2} <= {c_reg, c_reg, c_reg};
            {c0, c1, c2} <= {c_reg, c_reg, c_reg};
        end
        else begin
            {a0, a1, a2} <= {a1, a2, c_reg};
            {b0, b1, b2} <= {b1, b2, c_reg};
            {c0, c1, c2} <= {c1, c2, c_reg};
        end
    end
    else if(cnt_row == 1) begin
        if(cnt_col == 0) begin
            {a0, a1, a2} <= {b_reg, b_reg, b_reg};
            {b0, b1, b2} <= {b_reg, b_reg, b_reg};
            {c0, c1, c2} <= {c_reg, c_reg, c_reg};
        end
        else begin
            {a0, a1, a2} <= {a1, a2, b_reg};
            {b0, b1, b2} <= {b1, b2, b_reg};
            {c0, c1, c2} <= {c1, c2, c_reg};
        end
    end
    else begin
        if(cnt_col == 0) begin
            {a0, a1, a2} <= {a_reg, a_reg, a_reg};
            {b0, b1, b2} <= {b_reg, b_reg, b_reg};
            {c0, c1, c2} <= {c_reg, c_reg, c_reg};
        end
        else begin
            {a0, a1, a2} <= {a1, a2, a_reg};
            {b0, b1, b2} <= {b1, b2, b_reg};
            {c0, c1, c2} <= {c1, c2, c_reg};
        end
    end
end

// fifo_temp fifo_temp_u0(
//   /*input          */.srst         (~rst_n),
//   /*input   [7:0]  */.di           (data_i),
//   /*input          */.clk          (clk),
//   /*input          */.re           (fifo0_rd_en),   
//   /*input          */.we           (fifo0_wr_en),
//   /*output  [7:0]  */.dout         (fifo0_dout)
// );

fifo_temp fifo_temp_isnt0 (
  .clk(clk),      // input wire clk
  .srst(~rst_n),    // input wire srst
  .din(data_i),      // input wire [7 : 0] din
  .wr_en(fifo0_wr_en),  // input wire wr_en
  .rd_en(fifo0_rd_en),  // input wire rd_en
  .dout(fifo0_dout),    // output wire [7 : 0] dout
  .full(),    // output wire full
  .empty()  // output wire empty
);

// fifo_temp fifo_temp_u1(
//   /*input          */.srst         (~rst_n),
//   /*input   [7:0]  */.di           (fifo0_dout),
//   /*input          */.clk          (clk),
//   /*input          */.re           (fifo1_rd_en),   
//   /*input          */.we           (fifo1_wr_en),
//   /*output  [7:0]  */.dout         (fifo1_dout)
// );

fifo_temp fifo_temp_u1 (
  .clk(clk),      // input wire clk
  .srst(~rst_n),    // input wire srst
  .din(fifo0_dout),      // input wire [7 : 0] din
  .wr_en(fifo1_wr_en),  // input wire wr_en
  .rd_en(fifo1_rd_en),  // input wire rd_en
  .dout(fifo1_dout),    // output wire [7 : 0] dout
  .full(),    // output wire full
  .empty()  // output wire empty
);


endmodule
