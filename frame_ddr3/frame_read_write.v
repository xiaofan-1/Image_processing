`timescale 1ns/1ps
module frame_read_write #(
    parameter MEM_DATA_BITS          = 64,
    parameter READ_DATA_BITS         = 16,
    parameter WRITE_DATA_BITS        = 16,
    parameter ADDR_BITS              = 25,
    parameter BURST_BITS             = 10,
    parameter BURST_SIZE             = 64
)(
    input	wire							rst					,                  
    input	wire							mem_clk				, // external memory controller user interface clock
    output	wire							rd_burst_req		, // to external memory controller,send out a burst read request
    output	wire	[BURST_BITS - 1:0]		rd_burst_len		, // to external memory controller,data length of the burst read request, not bytes
    output	wire	[ADDR_BITS - 1:0]		rd_burst_addr		, // to external memory controller,base address of the burst read request 
    input	wire							rd_burst_data_valid , // from external memory controller,read data valid 
    input	wire	[MEM_DATA_BITS - 1:0]	rd_burst_data		, // from external memory controller,read request data
    input   wire							rd_burst_finish		, // from external memory controller,burst read finish
    input   wire							read_clk			, // data read module clock
    input   wire							read_req			, // data read module read request,keep '1' until read_req_ack = '1'
    output  wire							read_req_ack		, // data read module read request response
    output  wire							read_finish			, // data read module read request finish
    input	wire	[ADDR_BITS - 1:0]		read_addr_0			, // data read module read request base address 0, used when read_addr_index = 0
    input	wire	[ADDR_BITS - 1:0]		read_addr_1			, // data read module read request base address 1, used when read_addr_index = 1
    input	wire	[ADDR_BITS - 1:0]		read_addr_2			, // data read module read request base address 1, used when read_addr_index = 2
    input	wire	[ADDR_BITS - 1:0]		read_addr_3			, // data read module read request base address 1, used when read_addr_index = 3
    input	wire	[1:0]					read_addr_index		, // select valid base address from read_addr_0 read_addr_1 read_addr_2 read_addr_3
    input	wire	[ADDR_BITS - 1:0]		read_len			, // data read module read request data length
    input	wire                        	read_en				, // data read module read request for one data, read_data valid next clock
    output	wire	[READ_DATA_BITS  - 1:0] read_data			, // read data
    output	wire                           	wr_burst_req		, // to external memory controller,send out a burst write request
    output	wire	[BURST_BITS - 1:0]      wr_burst_len		, // to external memory controller,data length of the burst write request, not bytes
    output	wire	[ADDR_BITS - 1:0]       wr_burst_addr		, // to external memory controller,base address of the burst write request 
    input   wire		                    wr_burst_data_req	, // from external memory controller,write data request ,before data 1 clock
    output	wire	[MEM_DATA_BITS - 1:0]   wr_burst_data		, // to external memory controller,write data
    input   wire		                    wr_burst_finish		, // from external memory controller,burst write finish
    input   wire		                    write_clk			, // data write module clock
    input   wire		                    write_req			, // data write module write request,keep '1' until read_req_ack = '1'
    output  wire		                    write_req_ack		, // data write module write request response
    output  wire		                    write_finish		, // data write module write request finish
    input   wire		[ADDR_BITS - 1:0]   write_addr_0		, // data write module write request base address 0, used when write_addr_index = 0
    input   wire		[ADDR_BITS - 1:0]   write_addr_1		, // data write module write request base address 1, used when write_addr_index = 1
    input   wire		[ADDR_BITS - 1:0]   write_addr_2		, // data write module write request base address 1, used when write_addr_index = 2
    input   wire		[ADDR_BITS - 1:0]   write_addr_3		, // data write module write request base address 1, used when write_addr_index = 3
    input   wire		[1:0]               write_addr_index	, // select valid base address from write_addr_0 write_addr_1 write_addr_2 write_addr_3
    input   wire		[ADDR_BITS - 1:0]   write_len			, // data write module write request data length
    input	wire                            write_en			, // data write module write
    input	wire	[WRITE_DATA_BITS - 1:0] write_data		      // write data
);
wire[7:0]                            wrusedw;                    // write used words
wire[7:0]                            rdusedw;                    // read used words
wire                                 read_fifo_aclr;             // fifo Asynchronous clear
wire                                 write_fifo_aclr;            // fifo Asynchronous clear
//instantiate an asynchronous FIFO 
// afifo_16i_64o_512 write_buf(
//     .wr_clk(write_clk),
//     .wr_rst(write_fifo_aclr),
//     .wr_en(write_en),
//     .wr_data(write_data),
//     .wr_full(),
//     .wr_water_level(),
//     .almost_full(),
//     .rd_clk(mem_clk),
//     .rd_rst(write_fifo_aclr),
//     .rd_en(wr_burst_data_req),
//     .rd_data(wr_burst_data),
//     .rd_empty(),
//     .rd_water_level(rdusedw[8:0]),
//     .almost_empty());

// 简单拼接：每2个16bit拼成1个32bit
reg [31:0] pack_data;
reg        pack_flag;
wire       pack_wr_en;

always @(posedge write_clk) begin
    if(write_fifo_aclr) begin
        pack_flag <= 1'b0;
        pack_data <= 32'b0;
    end
    else if(write_en) begin
        pack_flag <= ~pack_flag;
        if(pack_flag == 1'b0)
            pack_data[15:0]  <= write_data;  // 先存低16位
        else
            pack_data[31:16] <= write_data;  // 再存高16位
    end
end

assign pack_wr_en = write_en & pack_flag;  // 每2个数据写一次FIFO


wr_fifo wr_fifo_inst (
  .rst(write_fifo_aclr),                      // input wire rst
  .wr_clk(write_clk),                // input wire wr_clk
  .rd_clk(mem_clk),                // input wire rd_clk
  .din(pack_data),                      // input wire [31 : 0] din
  .wr_en(pack_wr_en),                  // input wire wr_en
  .rd_en(wr_burst_data_req),                  // input wire rd_en
  .dout(wr_burst_data),                    // output wire [255 : 0] dout
  .full(),                    // output wire full
  .almost_full(),      // output wire almost_full
  .empty(),                  // output wire empty
  .almost_empty(),    // output wire almost_empty
  .rd_data_count(rdusedw),  // output wire [7 : 0] rd_data_count
  .wr_data_count()  // output wire [10 : 0] wr_data_count
);


frame_fifo_write #(
    .MEM_DATA_BITS              (MEM_DATA_BITS            ),
    .ADDR_BITS                  (ADDR_BITS                ),
    .BURST_BITS                 (BURST_BITS               ),
    .BURST_SIZE                 (BURST_SIZE               )
) frame_fifo_write_inst (
    .rst                        (rst                      ),
    .mem_clk                    (mem_clk                  ),
    .wr_burst_req               (wr_burst_req             ),
    .wr_burst_len               (wr_burst_len             ),
    .wr_burst_addr              (wr_burst_addr            ),
    .wr_burst_data_req          (wr_burst_data_req        ),
    .wr_burst_finish            (wr_burst_finish          ),
    .write_req                  (write_req                ),
    .write_req_ack              (write_req_ack            ),
    .write_finish               (write_finish             ),
    .write_addr_0               (write_addr_0             ),
    .write_addr_1               (write_addr_1             ),
    .write_addr_2               (write_addr_2             ),
    .write_addr_3               (write_addr_3             ),
    .write_addr_index           (write_addr_index         ),    
    .write_len                  (write_len                ),
    .fifo_aclr                  (write_fifo_aclr          ),
    .rdusedw                    ({8'b0,rdusedw}           )
);

//instantiate an asynchronous FIFO

// afifo_64i_16o_128 read_buf (
//     .wr_clk(mem_clk),
//     .wr_rst(read_fifo_aclr),
//     .wr_en(rd_burst_data_valid),
//     .wr_data(rd_burst_data),
//     .wr_full(),
//     .wr_water_level(wrusedw[8:0]),
//     .almost_full(),
//     .rd_clk(read_clk),
//     .rd_rst(read_fifo_aclr),
//     .rd_en(read_en),
//     .rd_data(read_data),
//     .rd_empty(),
//     .rd_water_level(),
//     .almost_empty());

wire [31:0] fifo_dout;    // FIFO出来32bit
wire        fifo_rd_en;
reg         sel;           // 选高16还是低16

always @(posedge read_clk) begin
    if(read_fifo_aclr)  
        sel <= 0;
    else if(read_en)    
        sel <= ~sel;
end

reg [15:0] read_data_r;
always @(posedge read_clk) begin
    if(read_fifo_aclr)
        read_data_r <= 16'd0;
    else
        read_data_r <= sel ? fifo_dout[31:16] : fifo_dout[15:0];
end
assign read_data = read_data_r;

assign fifo_rd_en = read_en & ~sel;  // 每2次read_en才真正读一次FIFO

rd_fifo rd_fifo_inst (
  .rst(read_fifo_aclr),                      // input wire rst
  .wr_clk(mem_clk),                // input wire wr_clk
  .rd_clk(read_clk),                // input wire rd_clk
  .din(rd_burst_data),                      // input wire [255 : 0] din
  .wr_en(rd_burst_data_valid),                  // input wire wr_en
  .rd_en(fifo_rd_en),                  // input wire rd_en
  .dout(fifo_dout),                    // output wire [31 : 0] dout
  .full(),                    // output wire full
  .almost_full(),      // output wire almost_full
  .empty(),                  // output wire empty
  .almost_empty(),    // output wire almost_empty
  .rd_data_count(),  // output wire [10 : 0] rd_data_count
  .wr_data_count(wrusedw)  // output wire [7 : 0] wr_data_count
);

frame_fifo_read #(
    .MEM_DATA_BITS              (MEM_DATA_BITS            ),
    .ADDR_BITS                  (ADDR_BITS                ),
    .BURST_BITS                 (BURST_BITS               ),
    .FIFO_DEPTH                 (128                      ),
    .BURST_SIZE                 (BURST_SIZE               )
) frame_fifo_read_inst (
    .rst                        (rst                      ),
    .mem_clk                    (mem_clk                  ),
    .rd_burst_req               (rd_burst_req             ),   
    .rd_burst_len               (rd_burst_len             ),  
    .rd_burst_addr              (rd_burst_addr            ),
    .rd_burst_data_valid        (rd_burst_data_valid      ),    
    .rd_burst_finish            (rd_burst_finish          ),
    .read_req                   (read_req                 ),
    .read_req_ack               (read_req_ack             ),
    .read_finish                (read_finish              ),
    .read_addr_0                (read_addr_0              ),
    .read_addr_1                (read_addr_1              ),
    .read_addr_2                (read_addr_2              ),
    .read_addr_3                (read_addr_3              ),
    .read_addr_index            (read_addr_index          ),    
    .read_len                   (read_len                 ),
    .fifo_aclr                  (read_fifo_aclr           ),
    .wrusedw                    ({8'b0,wrusedw}           )
);

endmodule
