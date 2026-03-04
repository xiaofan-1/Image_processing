`timescale 1ns / 1ps

module ddr_tb();

// clock & reset
reg clk_200M;
reg rst_n;

// ddr3 signals
wire    [14:0]    ddr3_addr          ;
wire    [2:0]     ddr3_ba            ;
wire              ddr3_cas_n         ;
wire    [0:0]     ddr3_ck_n          ;
wire    [0:0]     ddr3_ck_p          ;
wire    [0:0]     ddr3_cke           ;
wire              ddr3_ras_n         ;
wire              ddr3_reset_n       ;
wire              ddr3_we_n          ;
wire    [31:0]    ddr3_dq            ;
wire    [3:0]     ddr3_dqs_n         ;
wire    [3:0]     ddr3_dqs_p         ;
wire              init_calib_complete;
wire    [0:0]     ddr3_cs_n          ;
wire    [3:0]     ddr3_dm            ;
wire    [0:0]     ddr3_odt           ;

// channel 0
reg               ch0_write_clk      ;
reg               ch0_write_req      ;
wire              ch0_write_req_ack  ;
wire              ch0_write_finish   ;
reg     [1:0]     ch0_write_addr_index;
reg               ch0_write_en       ;
reg     [15:0]    ch0_write_data     ;
reg               ch0_read_clk       ;
reg               ch0_read_req       ;
wire              ch0_read_req_ack   ;
wire              ch0_read_finish    ;
reg     [1:0]     ch0_read_addr_index;
reg               ch0_read_en        ;
wire    [15:0]    ch0_read_data      ;

//===========================================================
// clock generation
//===========================================================
initial clk_200M = 0;
always #2.5 clk_200M = ~clk_200M;  // 200MHz

initial ch0_write_clk = 0;
always #5 ch0_write_clk = ~ch0_write_clk;  // 100MHz

initial ch0_read_clk = 0;
always #5 ch0_read_clk = ~ch0_read_clk;    // 100MHz

//===========================================================
// reset
//===========================================================
initial begin
    rst_n = 0;
    #2000;
    rst_n = 1;
end

//===========================================================
// channel 0 test stimulus
//===========================================================
// 用 flag 捕获 write_finish / read_finish 的单周期脉冲
// 避免在 repeat 循环中错过 posedge
reg wr_finish_flag;
reg rd_finish_flag;

always @(posedge ch0_write_finish or negedge rst_n) begin
    if (!rst_n)
        wr_finish_flag <= 1'b0;
    else
        wr_finish_flag <= 1'b1;
end

always @(posedge ch0_read_finish or negedge rst_n) begin
    if (!rst_n)
        rd_finish_flag <= 1'b0;
    else
        rd_finish_flag <= 1'b1;
end

initial begin
    ch0_write_req       = 0;
    ch0_write_addr_index= 2'd0;
    ch0_write_en        = 0;
    ch0_write_data      = 16'd0;
    ch0_read_req        = 0;
    ch0_read_addr_index = 2'd0;  // 必须和 write_addr_index 一致，才能读到写入的数据
    ch0_read_en         = 0;

    // wait for DDR3 calibration complete
    @(posedge init_calib_complete);
    $display("DDR3 calibration complete at %0t", $time);
    #1000;

    // ---- write a frame ----
    ch0_write_req = 1;
    @(posedge ch0_write_req_ack);
    ch0_write_req = 0;

    #1000;

    // write test data
    // 需要多于 32*16=512 像素，因为 AXI master 的 rd_first_data
    // 每次 burst 会额外消耗 1 个 FIFO 条目（2次burst多消耗2个）
    // 32 个 FIFO 条目不够 2 次 burst（需要 34 个），所以多写一些
    repeat(48 * 16) begin
        @(posedge ch0_write_clk);
        ch0_write_en   = 1;
        ch0_write_data = ch0_write_data + 16'd1;
    end
    ch0_write_en = 0;

    // 等待写完成 — 用 flag 而不是 @(posedge)
    // 因为 write_finish 是单周期脉冲，可能在 repeat 循环期间就已经触发了
    wait(wr_finish_flag == 1'b1);
    $display("Write phase done at %0t", $time);
    #1000;

    // ---- read back ----
    ch0_read_req = 1;
    @(posedge ch0_read_req_ack);
    ch0_read_req = 0;

    wait(rd_finish_flag == 1'b1);

    // 读 32*16=512 个像素（与 write_len = H*V/16 = 32 个 burst 条目匹配）
    repeat(32 * 16) begin
        @(posedge ch0_read_clk);
        ch0_read_en = 1;
    end
    ch0_read_en = 0;

    // 等待读完成
    #5200;
    $display("Read phase done at %0t", $time);
    #1000;
    $finish;
end

//===========================================================
// ddr3 model (2 x16 chips = 32bit DQ)
//===========================================================
// chip 0: dq[15:0]
ddr3_model ddr3_model_lo (
    .rst_n   (ddr3_reset_n     ),
    .ck      (ddr3_ck_p        ),
    .ck_n    (ddr3_ck_n        ),
    .cke     (ddr3_cke         ),
    .cs_n    (ddr3_cs_n        ),
    .ras_n   (ddr3_ras_n       ),
    .cas_n   (ddr3_cas_n       ),
    .we_n    (ddr3_we_n        ),
    .dm_tdqs (ddr3_dm[1:0]     ),
    .ba      (ddr3_ba          ),
    .addr    (ddr3_addr        ),
    .dq      (ddr3_dq[15:0]    ),
    .dqs     (ddr3_dqs_p[1:0]  ),
    .dqs_n   (ddr3_dqs_n[1:0]  ),
    .tdqs_n  (                 ),
    .odt     (ddr3_odt         )
);

// chip 1: dq[31:16]
ddr3_model ddr3_model_hi (
    .rst_n   (ddr3_reset_n     ),
    .ck      (ddr3_ck_p        ),
    .ck_n    (ddr3_ck_n        ),
    .cke     (ddr3_cke         ),
    .cs_n    (ddr3_cs_n        ),
    .ras_n   (ddr3_ras_n       ),
    .cas_n   (ddr3_cas_n       ),
    .we_n    (ddr3_we_n        ),
    .dm_tdqs (ddr3_dm[3:2]     ),
    .ba      (ddr3_ba          ),
    .addr    (ddr3_addr        ),
    .dq      (ddr3_dq[31:16]   ),
    .dqs     (ddr3_dqs_p[3:2]  ),
    .dqs_n   (ddr3_dqs_n[3:2]  ),
    .tdqs_n  (                 ),
    .odt     (ddr3_odt         )
);

//===========================================================
// DUT
//===========================================================
Top_ddr3 #(
    .MEM_DATA_BITS          (256  ),
    .ADDR_BITS              (25   ),
    .BURST_BITS             (10   ),
    .READ_DATA_BITS         (16   ),
    .WRITE_DATA_BITS        (16   ),
    .BURST_SIZE             (16   ),
    .H_PIXEL                (32   ),
    .V_PIXEL                (16   )
) Top_ddr3_inst (
    .clk_200M             (clk_200M            ),
    .rst_n                (rst_n               ),
    // ddr3
    .ddr3_addr            (ddr3_addr           ),
    .ddr3_ba              (ddr3_ba             ),
    .ddr3_cas_n           (ddr3_cas_n          ),
    .ddr3_ck_n            (ddr3_ck_n           ),
    .ddr3_ck_p            (ddr3_ck_p           ),
    .ddr3_cke             (ddr3_cke            ),
    .ddr3_ras_n           (ddr3_ras_n          ),
    .ddr3_reset_n         (ddr3_reset_n        ),
    .ddr3_we_n            (ddr3_we_n           ),
    .ddr3_dq              (ddr3_dq             ),
    .ddr3_dqs_n           (ddr3_dqs_n          ),
    .ddr3_dqs_p           (ddr3_dqs_p          ),
    .init_calib_complete  (init_calib_complete  ),
    .ddr3_cs_n            (ddr3_cs_n           ),
    .ddr3_dm              (ddr3_dm             ),
    .ddr3_odt             (ddr3_odt            ),
    // channel 0
    .ch0_write_clk        (ch0_write_clk       ),
    .ch0_write_req        (ch0_write_req       ),
    .ch0_write_req_ack    (ch0_write_req_ack   ),
    .ch0_write_finish     (ch0_write_finish    ),
    .ch0_write_addr_index (ch0_write_addr_index),
    .ch0_write_en         (ch0_write_en        ),
    .ch0_write_data       (ch0_write_data      ),
    .ch0_read_clk         (ch0_read_clk        ),
    .ch0_read_req         (ch0_read_req        ),
    .ch0_read_req_ack     (ch0_read_req_ack    ),
    .ch0_read_finish      (ch0_read_finish     ),
    .ch0_read_addr_index  (ch0_read_addr_index ),
    .ch0_read_en          (ch0_read_en         ),
    .ch0_read_data        (ch0_read_data       ),
    // channel 1 - unused
    .ch1_write_clk        (1'b0                ),
    .ch1_write_req        (1'b0                ),
    .ch1_write_req_ack    (                    ),
    .ch1_write_finish     (                    ),
    .ch1_write_addr_index (2'd0                ),
    .ch1_write_en         (1'b0                ),
    .ch1_write_data       (16'd0               ),
    .ch1_read_clk         (1'b0                ),
    .ch1_read_req         (1'b0                ),
    .ch1_read_req_ack     (                    ),
    .ch1_read_finish      (                    ),
    .ch1_read_addr_index  (2'd0                ),
    .ch1_read_en          (1'b0                ),
    .ch1_read_data        (                    ),
    // channel 2 - unused
    .ch2_write_clk        (1'b0                ),
    .ch2_write_req        (1'b0                ),
    .ch2_write_req_ack    (                    ),
    .ch2_write_finish     (                    ),
    .ch2_write_addr_index (2'd0                ),
    .ch2_write_en         (1'b0                ),
    .ch2_write_data       (16'd0               ),
    .ch2_read_clk         (1'b0                ),
    .ch2_read_req         (1'b0                ),
    .ch2_read_req_ack     (                    ),
    .ch2_read_finish      (                    ),
    .ch2_read_addr_index  (2'd0                ),
    .ch2_read_en          (1'b0                ),
    .ch2_read_data        (                    ),
    // channel 3 - unused
    .ch3_write_clk        (1'b0                ),
    .ch3_write_req        (1'b0                ),
    .ch3_write_req_ack    (                    ),
    .ch3_write_finish     (                    ),
    .ch3_write_addr_index (2'd0                ),
    .ch3_write_en         (1'b0                ),
    .ch3_write_data       (16'd0               ),
    .ch3_read_clk         (1'b0                ),
    .ch3_read_req         (1'b0                ),
    .ch3_read_req_ack     (                    ),
    .ch3_read_finish      (                    ),
    .ch3_read_addr_index  (2'd0                ),
    .ch3_read_en          (1'b0                ),
    .ch3_read_data        (                    )
);

endmodule
