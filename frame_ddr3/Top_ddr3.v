`timescale  1ns/1ps

module Top_ddr3 #(
    parameter MEM_DATA_BITS          = 256  , //external memory user interface data width
    parameter ADDR_BITS              = 25   , //external memory user interface address width
    parameter BURST_BITS             = 10   , //external memory user interface burst width
    parameter READ_DATA_BITS         = 16   , //external memory user interface read data width
    parameter WRITE_DATA_BITS        = 16   , //external memory user interface write data width
    parameter BURST_SIZE             = 16   , //external memory user interface burst size
    parameter H_PIXEL                = 1280 , //horizontal pixel
    parameter V_PIXEL                = 720    //vertical pixel
)(
    input   wire            clk             ,
    input   wire            rst_n           ,
    //ddr3
    output  wire [14:0]     ddr3_addr		    ,
    output  wire [2:0]      ddr3_ba			    ,
    output  wire            ddr3_cas_n		    ,
    output  wire [0:0]      ddr3_ck_n		    ,
    output  wire [0:0]      ddr3_ck_p		    ,
    output  wire [0:0]      ddr3_cke		    ,
    output  wire            ddr3_ras_n		    ,
    output  wire            ddr3_reset_n	    ,
    output  wire            ddr3_we_n		    ,
    inout   wire [31:0]     ddr3_dq			    ,
    inout   wire [3:0]      ddr3_dqs_n		    ,
    inout   wire [3:0]      ddr3_dqs_p		    ,
    output  wire            init_calib_complete ,
    output  wire [0:0]      ddr3_cs_n			,
    output  wire [3:0]      ddr3_dm			    ,
    output  wire [0:0]      ddr3_odt			 
);

//===========================================================
//axi
//===========================================================
// Master Write Address
wire [3:0]                      s00_axi_awid	;
wire [63:0]                     s00_axi_awaddr	;
wire [7:0]                      s00_axi_awlen	; // burst length: 0-255
wire [2:0]                      s00_axi_awsize	; // burst size: fixed 2'b011
wire [1:0]                      s00_axi_awburst	; // burst type: fixed 2'b01(incremental burst)
wire                            s00_axi_awlock	; // lock: fixed 2'b00
wire [3:0]                      s00_axi_awcache	; // cache: fiex 2'b0011
wire [2:0]                      s00_axi_awprot	; // protect: fixed 2'b000
wire [3:0]                      s00_axi_awqos	; // qos: fixed 2'b0000
wire [0:0]                      s00_axi_awuser	; // user: fixed 32'd0
wire                            s00_axi_awvalid	;
wire                            s00_axi_awready	;
// master write data
wire [MEM_DATA_BITS - 1 : 0]    s00_axi_wdata	;
wire [MEM_DATA_BITS/8 - 1:0]    s00_axi_wstrb	;
wire                            s00_axi_wlast	;
wire [0:0]                      s00_axi_wuser	;
wire                            s00_axi_wvalid	;
wire                            s00_axi_wready	;
// master write response
wire [3:0]                      s00_axi_bid		;
wire [1:0]                      s00_axi_bresp	;
wire [0:0]                      s00_axi_buser	;
wire                            s00_axi_bvalid	;
wire                            s00_axi_bready	;
// master read address
wire [3:0]                      s00_axi_arid	;
wire [63:0]                     s00_axi_araddr	;
wire [7:0]                      s00_axi_arlen	;
wire [2:0]                      s00_axi_arsize	;
wire [1:0]                      s00_axi_arburst	;
wire [1:0]                      s00_axi_arlock	;
wire [3:0]                      s00_axi_arcache	;
wire [2:0]                      s00_axi_arprot	;
wire [3:0]                      s00_axi_arqos	;
wire [0:0]                      s00_axi_aruser	;
wire                            s00_axi_arvalid	;
wire                            s00_axi_arready	;
// master read data
wire [3:0]                      s00_axi_rid		;
wire [MEM_DATA_BITS - 1 : 0]    s00_axi_rdata	;
wire [1:0]                      s00_axi_rresp	;
wire                            s00_axi_rlast	;
wire [0:0]                      s00_axi_ruser	;
wire                            s00_axi_rvalid	;
wire                            s00_axi_rready	;	

wire                            wr_burst_req;
wire[BURST_BITS - 1:0]          wr_burst_len;
wire[ADDR_BITS - 1:0]           wr_burst_addr;
wire                            wr_burst_data_req;
wire[MEM_DATA_BITS - 1 : 0]     wr_burst_data;
wire                            wr_burst_finish;

wire                            rd_burst_req;
wire[BURST_BITS - 1:0]          rd_burst_len;
wire[ADDR_BITS - 1:0]           rd_burst_addr;
wire                            rd_burst_data_valid;
wire[MEM_DATA_BITS - 1 : 0]     rd_burst_data;
wire                            rd_burst_finish;

//===========================================================
//channel 0
//===========================================================
localparam CH0_READ_ADDR_0 = 0;
localparam CH0_READ_ADDR_1 = H_PIXEL * V_PIXEL;
localparam CH0_READ_ADDR_2 = H_PIXEL * V_PIXEL * 2;
localparam CH0_READ_ADDR_3 = H_PIXEL * V_PIXEL * 3;
localparam CH0_WRITE_LEN = H_PIXEL * V_PIXEL / 16;

wire                            ch0_rd_burst_req;
wire[BURST_BITS - 1:0]          ch0_rd_burst_len;
wire[ADDR_BITS - 1:0]           ch0_rd_burst_addr;
wire                            ch0_rd_burst_data_valid;
wire[MEM_DATA_BITS - 1 : 0]     ch0_rd_burst_data;
wire                            ch0_rd_burst_finish;

wire                            ch0_wr_burst_req;
wire[BURST_BITS - 1:0]          ch0_wr_burst_len;
wire[ADDR_BITS - 1:0]           ch0_wr_burst_addr;
wire                            ch0_wr_burst_data_req;
wire[MEM_DATA_BITS - 1 : 0]     ch0_wr_burst_data;
wire                            ch0_wr_burst_finish;

wire                            ch0_read_req;
wire                            ch0_read_req_ack;
wire[1:0]                       ch0_read_addr_index;
wire                            ch0_read_en;
wire[15:0]                      ch0_read_data;

wire                            ch0_write_req;
wire                            ch0_write_req_ack;
wire[1:0]                       ch0_write_addr_index;
wire                            ch0_write_en;
wire[15:0]                      ch0_write_data;

//===========================================================
//channel 1
//===========================================================
localparam CH1_READ_ADDR_0 = H_PIXEL * V_PIXEL * 4;
localparam CH1_READ_ADDR_1 = H_PIXEL * V_PIXEL * 5;
localparam CH1_READ_ADDR_2 = H_PIXEL * V_PIXEL * 6;
localparam CH1_READ_ADDR_3 = H_PIXEL * V_PIXEL * 7;
localparam CH1_WRITE_LEN = H_PIXEL * V_PIXEL / 16;

wire                            ch1_rd_burst_req;
wire[BURST_BITS - 1:0]          ch1_rd_burst_len;
wire[ADDR_BITS - 1:0]           ch1_rd_burst_addr;
wire                            ch1_rd_burst_data_valid;
wire[MEM_DATA_BITS - 1 : 0]     ch1_rd_burst_data;
wire                            ch1_rd_burst_finish;

wire                            ch1_wr_burst_req;
wire[BURST_BITS - 1:0]          ch1_wr_burst_len;
wire[ADDR_BITS - 1:0]           ch1_wr_burst_addr;
wire                            ch1_wr_burst_data_req;
wire[MEM_DATA_BITS - 1 : 0]     ch1_wr_burst_data;
wire                            ch1_wr_burst_finish;

wire                            ch1_read_req;
wire                            ch1_read_req_ack;
wire[1:0]                       ch1_read_addr_index;
wire                            ch1_read_en;
wire[15:0]                      ch1_read_data;

wire                            ch1_write_req;
wire                            ch1_write_req_ack;
wire[1:0]                       ch1_write_addr_index;
wire                            ch1_write_en;
wire[15:0]                      ch1_write_data;

//===========================================================
//channel 2
//===========================================================
localparam CH2_READ_ADDR_0 = H_PIXEL * V_PIXEL * 8;
localparam CH2_READ_ADDR_1 = H_PIXEL * V_PIXEL * 9;
localparam CH2_READ_ADDR_2 = H_PIXEL * V_PIXEL * 10;
localparam CH2_READ_ADDR_3 = H_PIXEL * V_PIXEL * 11;   
localparam CH2_WRITE_LEN = H_PIXEL * V_PIXEL / 16;

wire                            ch2_rd_burst_req;
wire[BURST_BITS - 1:0]          ch2_rd_burst_len;
wire[ADDR_BITS - 1:0]           ch2_rd_burst_addr;
wire                            ch2_rd_burst_data_valid;
wire[MEM_DATA_BITS - 1 : 0]     ch2_rd_burst_data;
wire                            ch2_rd_burst_finish;

wire                            ch2_wr_burst_req;
wire[BURST_BITS - 1:0]          ch2_wr_burst_len;
wire[ADDR_BITS - 1:0]           ch2_wr_burst_addr;
wire                            ch2_wr_burst_data_req;
wire[MEM_DATA_BITS - 1 : 0]     ch2_wr_burst_data;
wire                            ch2_wr_burst_finish;

wire                            ch2_read_req;
wire                            ch2_read_req_ack;
wire[1:0]                       ch2_read_addr_index;
wire                            ch2_read_en;
wire[15:0]                      ch2_read_data;

wire                            ch2_write_req;
wire                            ch2_write_req_ack;
wire[1:0]                       ch2_write_addr_index;
wire                            ch2_write_en;
wire[15:0]                      ch2_write_data;

//===========================================================
//channel 3
//===========================================================
localparam CH3_READ_ADDR_0 = H_PIXEL * V_PIXEL * 12;
localparam CH3_READ_ADDR_1 = H_PIXEL * V_PIXEL * 13;
localparam CH3_READ_ADDR_2 = H_PIXEL * V_PIXEL * 14;
localparam CH3_READ_ADDR_3 = H_PIXEL * V_PIXEL * 15;   
localparam CH3_WRITE_LEN = H_PIXEL * V_PIXEL / 16;

wire                            ch3_rd_burst_req;
wire[BURST_BITS - 1:0]          ch3_rd_burst_len;
wire[ADDR_BITS - 1:0]           ch3_rd_burst_addr;
wire                            ch3_rd_burst_data_valid;
wire[MEM_DATA_BITS - 1 : 0]     ch3_rd_burst_data;
wire                            ch3_rd_burst_finish;

wire                            ch3_wr_burst_req;
wire[BURST_BITS - 1:0]          ch3_wr_burst_len;
wire[ADDR_BITS - 1:0]           ch3_wr_burst_addr;
wire                            ch3_wr_burst_data_req;
wire[MEM_DATA_BITS - 1 : 0]     ch3_wr_burst_data;
wire                            ch3_wr_burst_finish;

wire                            ch3_read_req;
wire                            ch3_read_req_ack;
wire[1:0]                       ch3_read_addr_index;
wire                            ch3_read_en;
wire[15:0]                      ch3_read_data;

wire                            ch3_write_req;
wire                            ch3_write_req_ack;
wire[1:0]                       ch3_write_addr_index;
wire                            ch3_write_en;
wire[15:0]                      ch3_write_data;

//===========================================================
//ddr cache
//===========================================================
//channel 0
frame_read_write #(
    .MEM_DATA_BITS          ( MEM_DATA_BITS   ),
    .READ_DATA_BITS         ( READ_DATA_BITS  ),
    .WRITE_DATA_BITS        ( WRITE_DATA_BITS ),
    .ADDR_BITS              ( ADDR_BITS       ),
    .BURST_BITS             ( BURST_BITS      ),
    .BURST_SIZE             ( BURST_SIZE      )
)frame_read_write_inst0(
    /*input	    wire							*/.rst				   (),                  
    /*input	    wire							*/.mem_clk			   (), // external memory controller user interface clock
    /*output	wire							*/.rd_burst_req		   ( ch0_rd_burst_req        ), // to external memory controller,send out a burst read request
    /*output	wire	[BURST_BITS - 1:0]		*/.rd_burst_len		   ( ch0_rd_burst_len        ), // to external memory controller,data length of the burst read request, not bytes
    /*output	wire	[ADDR_BITS - 1:0]		*/.rd_burst_addr	   ( ch0_rd_burst_addr       ), // to external memory controller,base address of the burst read request 
    /*input	    wire							*/.rd_burst_data_valid ( ch0_rd_burst_data_valid ), // from external memory controller,read data valid 
    /*input	    wire	[MEM_DATA_BITS - 1:0]	*/.rd_burst_data	   ( ch0_rd_burst_data       ), // from external memory controller,read request data
    /*input     wire							*/.rd_burst_finish	   ( ch0_rd_burst_finish     ), // from external memory controller,burst read finish
    /*input     wire							*/.read_clk			   (), // data read module clock
    /*input     wire							*/.read_req			   ( ch0_read_req    		 ), // data read module read request,keep '1' until read_req_ack = '1'
    /*output    wire							*/.read_req_ack		   ( ch0_read_req_ack		 ), // data read module read request response
    /*output    wire							*/.read_finish		   (), // data read module read request finish
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_0		   ( CH0_READ_ADDR_0         ), // data read module read request base address 0, used when read_addr_index = 0
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_1		   ( CH0_READ_ADDR_1         ), // data read module read request base address 1, used when read_addr_index = 1
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_2		   ( CH0_READ_ADDR_2         ), // data read module read request base address 1, used when read_addr_index = 2
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_3		   ( CH0_READ_ADDR_3         ), // data read module read request base address 1, used when read_addr_index = 3
    /*input	    wire	[1:0]					*/.read_addr_index	   ( ch0_read_addr_index     ), // select valid base address from read_addr_0 read_addr_1 read_addr_2 read_addr_3
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_len			   ( CH0_READ_LEN            ), // data read module read request data length
    /*input	    wire                        	*/.read_en			   ( ch0_read_en             ), // data read module read request for one data, read_data valid next clock
    /*output	wire	[READ_DATA_BITS  - 1:0] */.read_data		   ( ch0_read_data           ), // read data
    
    /*output	wire                           	*/.wr_burst_req		   ( ch0_wr_burst_req        ), // to external memory controller,send out a burst write request
    /*output	wire	[BURST_BITS - 1:0]      */.wr_burst_len		   ( ch0_wr_burst_len        ), // to external memory controller,data length of the burst write request, not bytes
    /*output	wire	[ADDR_BITS - 1:0]       */.wr_burst_addr	   ( ch0_wr_burst_addr       ), // to external memory controller,base address of the burst write request 
    /*input     wire		                    */.wr_burst_data_req   ( ch0_wr_burst_data_req   ), // from external memory controller,write data request ,before data 1 clock
    /*output	wire	[MEM_DATA_BITS - 1:0]   */.wr_burst_data	   ( ch0_wr_burst_data       ), // to external memory controller,write data
    /*input     wire		                    */.wr_burst_finish	   ( ch0_wr_burst_finish     ), // from external memory controller,burst write finish
    /*input     wire		                    */.write_clk		   (), // data write module clock
    /*input     wire		                    */.write_req		   ( ch0_read_req            ), // data write module write request,keep '1' until read_req_ack = '1'
    /*output    wire		                    */.write_req_ack	   ( ch0_read_req_ack        ), // data write module write request response
    /*output    wire		                    */.write_finish		   (), // data write module write request finish
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_0		   ( CH0_READ_ADDR_0         ), // data write module write request base address 0, used when write_addr_index = 0
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_1		   ( CH0_READ_ADDR_1         ), // data write module write request base address 1, used when write_addr_index = 1
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_2		   ( CH0_READ_ADDR_2         ), // data write module write request base address 1, used when write_addr_index = 2
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_3		   ( CH0_READ_ADDR_3         ), // data write module write request base address 1, used when write_addr_index = 3
    /*input     wire		[1:0]               */.write_addr_index	   ( ch0_write_addr_index    ), // select valid base address from write_addr_0 write_addr_1 write_addr_2 write_addr_3
    /*input     wire		[ADDR_BITS - 1:0]   */.write_len		   ( CH0_READ_LEN            ), // data write module write request data length
    /*input	    wire                            */.write_en			   ( ch0_write_en            ), // data write module write
    /*input	    wire	[WRITE_DATA_BITS - 1:0] */.write_data		   ( ch0_write_data          )  // write data
);

//channel 1
frame_read_write #(
    .MEM_DATA_BITS          ( MEM_DATA_BITS   ),
    .READ_DATA_BITS         ( READ_DATA_BITS  ),
    .WRITE_DATA_BITS        ( WRITE_DATA_BITS ),
    .ADDR_BITS              ( ADDR_BITS       ),
    .BURST_BITS             ( BURST_BITS      ),
    .BURST_SIZE             ( BURST_SIZE      )
)frame_read_write_inst1(
    /*input	    wire							*/.rst				   (),                  
    /*input	    wire							*/.mem_clk			   (), // external memory controller user interface clock
    /*output	wire							*/.rd_burst_req		   ( ch1_rd_burst_req        ), // to external memory controller,send out a burst read request
    /*output	wire	[BURST_BITS - 1:0]		*/.rd_burst_len		   ( ch1_rd_burst_len        ), // to external memory controller,data length of the burst read request, not bytes
    /*output	wire	[ADDR_BITS - 1:0]		*/.rd_burst_addr	   ( ch1_rd_burst_addr       ), // to external memory controller,base address of the burst read request 
    /*input	    wire							*/.rd_burst_data_valid ( ch1_rd_burst_data_valid ), // from external memory controller,read data valid 
    /*input	    wire	[MEM_DATA_BITS - 1:0]	*/.rd_burst_data	   ( ch1_rd_burst_data       ), // from external memory controller,read request data
    /*input     wire							*/.rd_burst_finish	   ( ch1_rd_burst_finish     ), // from external memory controller,burst read finish
    /*input     wire							*/.read_clk			   (), // data read module clock
    /*input     wire							*/.read_req			   ( ch1_read_req    		 ), // data read module read request,keep '1' until read_req_ack = '1'
    /*output    wire							*/.read_req_ack		   ( ch1_read_req_ack		 ), // data read module read request response
    /*output    wire							*/.read_finish		   (), // data read module read request finish
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_0		   ( CH1_READ_ADDR_0         ), // data read module read request base address 0, used when read_addr_index = 0
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_1		   ( CH1_READ_ADDR_1         ), // data read module read request base address 1, used when read_addr_index = 1
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_2		   ( CH1_READ_ADDR_2         ), // data read module read request base address 1, used when read_addr_index = 2
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_3		   ( CH1_READ_ADDR_3         ), // data read module read request base address 1, used when read_addr_index = 3
    /*input	    wire	[1:0]					*/.read_addr_index	   ( ch1_read_addr_index     ), // select valid base address from read_addr_0 read_addr_1 read_addr_2 read_addr_3
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_len			   ( CH1_READ_LEN            ), // data read module read request data length
    /*input	    wire                        	*/.read_en			   ( ch1_read_en             ), // data read module read request for one data, read_data valid next clock
    /*output	wire	[READ_DATA_BITS  - 1:0] */.read_data		   ( ch1_read_data           ), // read data
    
    /*output	wire                           	*/.wr_burst_req		   ( ch1_wr_burst_req        ), // to external memory controller,send out a burst write request
    /*output	wire	[BURST_BITS - 1:0]      */.wr_burst_len		   ( ch1_wr_burst_len        ), // to external memory controller,data length of the burst write request, not bytes
    /*output	wire	[ADDR_BITS - 1:0]       */.wr_burst_addr	   ( ch1_wr_burst_addr       ), // to external memory controller,base address of the burst write request 
    /*input     wire		                    */.wr_burst_data_req   ( ch1_wr_burst_data_req   ), // from external memory controller,write data request ,before data 1 clock
    /*output	wire	[MEM_DATA_BITS - 1:0]   */.wr_burst_data	   ( ch1_wr_burst_data       ), // to external memory controller,write data
    /*input     wire		                    */.wr_burst_finish	   ( ch1_wr_burst_finish     ), // from external memory controller,burst write finish
    /*input     wire		                    */.write_clk		   (), // data write module clock
    /*input     wire		                    */.write_req		   ( ch1_read_req            ), // data write module write request,keep '1' until read_req_ack = '1'
    /*output    wire		                    */.write_req_ack	   ( ch1_read_req_ack        ), // data write module write request response
    /*output    wire		                    */.write_finish		   (), // data write module write request finish
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_0		   ( CH1_READ_ADDR_0         ), // data write module write request base address 0, used when write_addr_index = 0
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_1		   ( CH1_READ_ADDR_1         ), // data write module write request base address 1, used when write_addr_index = 1
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_2		   ( CH1_READ_ADDR_2         ), // data write module write request base address 1, used when write_addr_index = 2
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_3		   ( CH1_READ_ADDR_3         ), // data write module write request base address 1, used when write_addr_index = 3
    /*input     wire		[1:0]               */.write_addr_index	   ( ch1_write_addr_index    ), // select valid base address from write_addr_0 write_addr_1 write_addr_2 write_addr_3
    /*input     wire		[ADDR_BITS - 1:0]   */.write_len		   ( CH1_READ_LEN            ), // data write module write request data length
    /*input	    wire                            */.write_en			   ( ch1_write_en            ), // data write module write
    /*input	    wire	[WRITE_DATA_BITS - 1:0] */.write_data		   ( ch1_write_data          )  // write data
);

//channel 2
frame_read_write #(
    .MEM_DATA_BITS          ( MEM_DATA_BITS   ),
    .READ_DATA_BITS         ( READ_DATA_BITS  ),
    .WRITE_DATA_BITS        ( WRITE_DATA_BITS ),
    .ADDR_BITS              ( ADDR_BITS       ),
    .BURST_BITS             ( BURST_BITS      ),
    .BURST_SIZE             ( BURST_SIZE      )
)frame_read_write_inst2(
    /*input	    wire							*/.rst				   (),                  
    /*input	    wire							*/.mem_clk			   (), // external memory controller user interface clock
    /*output	wire							*/.rd_burst_req		   ( ch2_rd_burst_req        ), // to external memory controller,send out a burst read request
    /*output	wire	[BURST_BITS - 1:0]		*/.rd_burst_len		   ( ch2_rd_burst_len        ), // to external memory controller,data length of the burst read request, not bytes
    /*output	wire	[ADDR_BITS - 1:0]		*/.rd_burst_addr	   ( ch2_rd_burst_addr       ), // to external memory controller,base address of the burst read request 
    /*input	    wire							*/.rd_burst_data_valid ( ch2_rd_burst_data_valid ), // from external memory controller,read data valid 
    /*input	    wire	[MEM_DATA_BITS - 1:0]	*/.rd_burst_data	   ( ch2_rd_burst_data       ), // from external memory controller,read request data
    /*input     wire							*/.rd_burst_finish	   ( ch2_rd_burst_finish     ), // from external memory controller,burst read finish
    /*input     wire							*/.read_clk			   (), // data read module clock
    /*input     wire							*/.read_req			   ( ch2_read_req    		 ), // data read module read request,keep '1' until read_req_ack = '1'
    /*output    wire							*/.read_req_ack		   ( ch2_read_req_ack		 ), // data read module read request response
    /*output    wire							*/.read_finish		   (), // data read module read request finish
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_0		   ( CH2_READ_ADDR_0         ), // data read module read request base address 0, used when read_addr_index = 0
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_1		   ( CH2_READ_ADDR_1         ), // data read module read request base address 1, used when read_addr_index = 1
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_2		   ( CH2_READ_ADDR_2         ), // data read module read request base address 1, used when read_addr_index = 2
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_3		   ( CH2_READ_ADDR_3         ), // data read module read request base address 1, used when read_addr_index = 3
    /*input	    wire	[1:0]					*/.read_addr_index	   ( ch2_read_addr_index     ), // select valid base address from read_addr_0 read_addr_1 read_addr_2 read_addr_3
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_len			   ( CH2_READ_LEN            ), // data read module read request data length
    /*input	    wire                        	*/.read_en			   ( ch2_read_en             ), // data read module read request for one data, read_data valid next clock
    /*output	wire	[READ_DATA_BITS  - 1:0] */.read_data		   ( ch2_read_data           ), // read data
    
    /*output	wire                           	*/.wr_burst_req		   ( ch2_wr_burst_req        ), // to external memory controller,send out a burst write request
    /*output	wire	[BURST_BITS - 1:0]      */.wr_burst_len		   ( ch2_wr_burst_len        ), // to external memory controller,data length of the burst write request, not bytes
    /*output	wire	[ADDR_BITS - 1:0]       */.wr_burst_addr	   ( ch2_wr_burst_addr       ), // to external memory controller,base address of the burst write request 
    /*input     wire		                    */.wr_burst_data_req   ( ch2_wr_burst_data_req   ), // from external memory controller,write data request ,before data 1 clock
    /*output	wire	[MEM_DATA_BITS - 1:0]   */.wr_burst_data	   ( ch2_wr_burst_data       ), // to external memory controller,write data
    /*input     wire		                    */.wr_burst_finish	   ( ch2_wr_burst_finish     ), // from external memory controller,burst write finish
    /*input     wire		                    */.write_clk		   (), // data write module clock
    /*input     wire		                    */.write_req		   ( ch2_read_req            ), // data write module write request,keep '1' until read_req_ack = '1'
    /*output    wire		                    */.write_req_ack	   ( ch2_read_req_ack        ), // data write module write request response
    /*output    wire		                    */.write_finish		   (), // data write module write request finish
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_0		   ( CH2_READ_ADDR_0         ), // data write module write request base address 0, used when write_addr_index = 0
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_1		   ( CH2_READ_ADDR_1         ), // data write module write request base address 1, used when write_addr_index = 1
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_2		   ( CH2_READ_ADDR_2         ), // data write module write request base address 1, used when write_addr_index = 2
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_3		   ( CH2_READ_ADDR_3         ), // data write module write request base address 1, used when write_addr_index = 3
    /*input     wire		[1:0]               */.write_addr_index	   ( ch2_write_addr_index    ), // select valid base address from write_addr_0 write_addr_1 write_addr_2 write_addr_3
    /*input     wire		[ADDR_BITS - 1:0]   */.write_len		   ( CH2_READ_LEN            ), // data write module write request data length
    /*input	    wire                            */.write_en			   ( ch2_write_en            ), // data write module write
    /*input	    wire	[WRITE_DATA_BITS - 1:0] */.write_data		   ( ch2_write_data          )  // write data
);

//channel 3
frame_read_write #(
    .MEM_DATA_BITS          ( MEM_DATA_BITS   ),
    .READ_DATA_BITS         ( READ_DATA_BITS  ),
    .WRITE_DATA_BITS        ( WRITE_DATA_BITS ),
    .ADDR_BITS              ( ADDR_BITS       ),
    .BURST_BITS             ( BURST_BITS      ),
    .BURST_SIZE             ( BURST_SIZE      )
)frame_read_write_inst3(
    /*input	    wire							*/.rst				   (),                  
    /*input	    wire							*/.mem_clk			   (), // external memory controller user interface clock
    /*output	wire							*/.rd_burst_req		   ( ch3_rd_burst_req        ), // to external memory controller,send out a burst read request
    /*output	wire	[BURST_BITS - 1:0]		*/.rd_burst_len		   ( ch3_rd_burst_len        ), // to external memory controller,data length of the burst read request, not bytes
    /*output	wire	[ADDR_BITS - 1:0]		*/.rd_burst_addr	   ( ch3_rd_burst_addr       ), // to external memory controller,base address of the burst read request 
    /*input	    wire							*/.rd_burst_data_valid ( ch3_rd_burst_data_valid ), // from external memory controller,read data valid 
    /*input	    wire	[MEM_DATA_BITS - 1:0]	*/.rd_burst_data	   ( ch3_rd_burst_data       ), // from external memory controller,read request data
    /*input     wire							*/.rd_burst_finish	   ( ch3_rd_burst_finish     ), // from external memory controller,burst read finish
    /*input     wire							*/.read_clk			   (), // data read module clock
    /*input     wire							*/.read_req			   ( ch3_read_req    		 ), // data read module read request,keep '1' until read_req_ack = '1'
    /*output    wire							*/.read_req_ack		   ( ch3_read_req_ack		 ), // data read module read request response
    /*output    wire							*/.read_finish		   (), // data read module read request finish
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_0		   ( CH3_READ_ADDR_0         ), // data read module read request base address 0, used when read_addr_index = 0
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_1		   ( CH3_READ_ADDR_1         ), // data read module read request base address 1, used when read_addr_index = 1
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_2		   ( CH3_READ_ADDR_2         ), // data read module read request base address 1, used when read_addr_index = 2
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_addr_3		   ( CH3_READ_ADDR_3         ), // data read module read request base address 1, used when read_addr_index = 3
    /*input	    wire	[1:0]					*/.read_addr_index	   ( ch3_read_addr_index     ), // select valid base address from read_addr_0 read_addr_1 read_addr_2 read_addr_3
    /*input	    wire	[ADDR_BITS - 1:0]		*/.read_len			   ( CH3_READ_LEN            ), // data read module read request data length
    /*input	    wire                        	*/.read_en			   ( ch3_read_en             ), // data read module read request for one data, read_data valid next clock
    /*output	wire	[READ_DATA_BITS  - 1:0] */.read_data		   ( ch3_read_data           ), // read data
    
    /*output	wire                           	*/.wr_burst_req		   ( ch3_wr_burst_req        ), // to external memory controller,send out a burst write request
    /*output	wire	[BURST_BITS - 1:0]      */.wr_burst_len		   ( ch3_wr_burst_len        ), // to external memory controller,data length of the burst write request, not bytes
    /*output	wire	[ADDR_BITS - 1:0]       */.wr_burst_addr	   ( ch3_wr_burst_addr       ), // to external memory controller,base address of the burst write request 
    /*input     wire		                    */.wr_burst_data_req   ( ch3_wr_burst_data_req   ), // from external memory controller,write data request ,before data 1 clock
    /*output	wire	[MEM_DATA_BITS - 1:0]   */.wr_burst_data	   ( ch3_wr_burst_data       ), // to external memory controller,write data
    /*input     wire		                    */.wr_burst_finish	   ( ch3_wr_burst_finish     ), // from external memory controller,burst write finish
    /*input     wire		                    */.write_clk		   (), // data write module clock
    /*input     wire		                    */.write_req		   ( ch3_read_req            ), // data write module write request,keep '1' until read_req_ack = '1'
    /*output    wire		                    */.write_req_ack	   ( ch3_read_req_ack        ), // data write module write request response
    /*output    wire		                    */.write_finish		   (), // data write module write request finish
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_0		   ( CH3_READ_ADDR_0         ), // data write module write request base address 0, used when write_addr_index = 0
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_1		   ( CH3_READ_ADDR_1         ), // data write module write request base address 1, used when write_addr_index = 1
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_2		   ( CH3_READ_ADDR_2         ), // data write module write request base address 1, used when write_addr_index = 2
    /*input     wire		[ADDR_BITS - 1:0]   */.write_addr_3		   ( CH3_READ_ADDR_3         ), // data write module write request base address 1, used when write_addr_index = 3
    /*input     wire		[1:0]               */.write_addr_index	   ( ch3_write_addr_index    ), // select valid base address from write_addr_0 write_addr_1 write_addr_2 write_addr_3
    /*input     wire		[ADDR_BITS - 1:0]   */.write_len		   ( CH3_READ_LEN            ), // data write module write request data length
    /*input	    wire                            */.write_en			   ( ch3_write_en            ), // data write module write
    /*input	    wire	[WRITE_DATA_BITS - 1:0] */.write_data		   ( ch3_write_data          )  // write data
);
//===========================================================
//axi arbiter
//===========================================================
//write arbiter
mem_write_arbi #(
    .MEM_DATA_BITS ( MEM_DATA_BITS ),
    .ADDR_BITS     ( ADDR_BITS     ),
    .BURST_BITS    ( BURST_BITS    )
) mem_write_arbi_inst (
    //global signal
    /*input	    wire							*/.rst_n					(),
    /*input	    wire							*/.mem_clk					(),
    //channel 0
    /*input	    wire							*/.ch0_wr_burst_req		    ( ch0_wr_burst_req      ),
    /*input	    wire	[BURST_BITS - 1:0] 		*/.ch0_wr_burst_len		    ( ch0_wr_burst_len      ),
    /*input	    wire	[ADDR_BITS - 1:0] 		*/.ch0_wr_burst_addr		( ch0_wr_burst_addr     ),
    /*output	wire							*/.ch0_wr_burst_data_req	( ch0_wr_burst_data_req ),
    /*input	    wire	[MEM_DATA_BITS - 1:0] 	*/.ch0_wr_burst_data		( ch0_wr_burst_data     ),
    /*output	wire							*/.ch0_wr_burst_finish		( ch0_wr_burst_finish   ),
    //channel 1
    /*input	    wire							*/.ch1_wr_burst_req		    ( ch1_wr_burst_req      ),
    /*input	    wire	[BURST_BITS - 1:0] 		*/.ch1_wr_burst_len		    ( ch1_wr_burst_len      ),
    /*input	    wire	[ADDR_BITS - 1:0] 		*/.ch1_wr_burst_addr		( ch1_wr_burst_addr     ),
    /*output	wire							*/.ch1_wr_burst_data_req	( ch1_wr_burst_data_req ),
    /*input	    wire	[MEM_DATA_BITS - 1:0] 	*/.ch1_wr_burst_data		( ch1_wr_burst_data     ),
    /*output	wire							*/.ch1_wr_burst_finish		( ch1_wr_burst_finish   ),
    //channel 2
    /*input	    wire							*/.ch2_wr_burst_req		    ( ch2_wr_burst_req      ),
    /*input	    wire	[BURST_BITS - 1:0] 		*/.ch2_wr_burst_len		    ( ch2_wr_burst_len      ),
    /*input	    wire	[ADDR_BITS - 1:0] 		*/.ch2_wr_burst_addr		( ch2_wr_burst_addr     ),
    /*output	wire							*/.ch2_wr_burst_data_req	( ch2_wr_burst_data_req ),
    /*input	    wire	[MEM_DATA_BITS - 1:0] 	*/.ch2_wr_burst_data		( ch2_wr_burst_data     ),
    /*output	wire							*/.ch2_wr_burst_finish		( ch2_wr_burst_finish   ),
    //channel 3
    /*input	    wire							*/.ch3_wr_burst_req		    ( ch3_wr_burst_req      ),
    /*input	    wire	[BURST_BITS - 1:0] 		*/.ch3_wr_burst_len		    ( ch3_wr_burst_len      ),
    /*input	    wire	[ADDR_BITS - 1:0] 		*/.ch3_wr_burst_addr		( ch3_wr_burst_addr     ),
    /*output	wire							*/.ch3_wr_burst_data_req	( ch3_wr_burst_data_req ),
    /*input	    wire	[MEM_DATA_BITS - 1:0] 	*/.ch3_wr_burst_data		( ch3_wr_burst_data     ),
    /*output	wire							*/.ch3_wr_burst_finish		( ch3_wr_burst_finish   ),
    //arbiter output
    /*output 	reg								*/.wr_burst_req			    ( wr_burst_req          ),
    /*output 	reg	[BURST_BITS - 1:0] 			*/.wr_burst_len			    ( wr_burst_len          ),
    /*output 	reg	[ADDR_BITS - 1:0] 			*/.wr_burst_addr			( wr_burst_addr         ),
    /*input     wire							*/.wr_burst_data_req		( wr_burst_data_req     ),
    /*output 	reg	[MEM_DATA_BITS - 1:0] 		*/.wr_burst_data			( wr_burst_data         ),
    /*input     wire							*/.wr_burst_finish			( wr_burst_finish       )
);

//read arbiter
mem_read_arbi #(
    .MEM_DATA_BITS          ( MEM_DATA_BITS ),
    .ADDR_BITS              ( ADDR_BITS     ),
    .BURST_BITS             ( BURST_BITS    )
) mem_read_arbi_inst (
    /*input 	wire							*/.rst_n					(),
    /*input 	wire							*/.mem_clk					(),
    //channel 0
    /*input 	wire							*/.ch0_rd_burst_req         ( ch0_rd_burst_req         ),
    /*input 	wire	[BURST_BITS - 1:0] 		*/.ch0_rd_burst_len         ( ch0_rd_burst_len         ),
    /*input 	wire	[ADDR_BITS - 1:0] 		*/.ch0_rd_burst_addr        ( ch0_rd_burst_addr        ),
    /*output 	wire							*/.ch0_rd_burst_data_valid	( ch0_rd_burst_data_valid  ),
    /*output 	wire	[MEM_DATA_BITS - 1:0] 	*/.ch0_rd_burst_data        ( ch0_rd_burst_data        ),
    /*output 	wire							*/.ch0_rd_burst_finish      ( ch0_rd_burst_finish      ),
    //channel 1 
    /*input 	wire							*/.ch1_rd_burst_req         ( ch1_rd_burst_req         ),
    /*input 	wire	[BURST_BITS - 1:0] 		*/.ch1_rd_burst_len         ( ch1_rd_burst_len         ),
    /*input 	wire	[ADDR_BITS - 1:0] 		*/.ch1_rd_burst_addr        ( ch1_rd_burst_addr        ),
    /*output 	wire							*/.ch1_rd_burst_data_valid	( ch1_rd_burst_data_valid  ),
    /*output 	wire	[MEM_DATA_BITS - 1:0] 	*/.ch1_rd_burst_data        ( ch1_rd_burst_data        ),
    /*output 	wire							*/.ch1_rd_burst_finish      ( ch1_rd_burst_finish      ),
    //channel 2 
    /*input 	wire							*/.ch2_rd_burst_req		    ( ch2_rd_burst_req         ),
    /*input 	wire	[BURST_BITS - 1:0] 		*/.ch2_rd_burst_len		    ( ch2_rd_burst_len         ),
    /*input 	wire	[ADDR_BITS - 1:0] 		*/.ch2_rd_burst_addr		( ch2_rd_burst_addr        ),
    /*output 	wire							*/.ch2_rd_burst_data_valid	( ch2_rd_burst_data_valid  ),
    /*output 	wire	[MEM_DATA_BITS - 1:0] 	*/.ch2_rd_burst_data		( ch2_rd_burst_data        ),
    /*output 	wire							*/.ch2_rd_burst_finish		( ch2_rd_burst_finish      ),
    //channel 3 
    /*input 	wire							*/.ch3_rd_burst_req		    ( ch3_rd_burst_req         ),
    /*input 	wire	[BURST_BITS - 1:0] 		*/.ch3_rd_burst_len		    ( ch3_rd_burst_len         ),
    /*input 	wire	[ADDR_BITS - 1:0] 		*/.ch3_rd_burst_addr		( ch3_rd_burst_addr        ),
    /*output 	wire							*/.ch3_rd_burst_data_valid	( ch3_rd_burst_data_valid  ),
    /*output 	wire	[MEM_DATA_BITS - 1:0] 	*/.ch3_rd_burst_data        ( ch3_rd_burst_data        ),
    /*output 	wire							*/.ch3_rd_burst_finish		( ch3_rd_burst_finish      ),
    //arbiter output
    /*output 	reg 							*/.rd_burst_req			    ( rd_burst_req            ),
    /*output 	reg		[BURST_BITS - 1:0] 		*/.rd_burst_len			    ( rd_burst_len            ),
    /*output 	reg		[ADDR_BITS - 1:0] 		*/.rd_burst_addr			( rd_burst_addr           ),
    /*input 	wire							*/.rd_burst_data_valid		( rd_burst_data_valid     ),
    /*input 	wire	[MEM_DATA_BITS - 1:0] 	*/.rd_burst_data			( rd_burst_data           ),
    /*input 	wire							*/.rd_burst_finish			( rd_burst_finish         )
);

//===========================================================
//axi interface
//===========================================================
aq_axi_master_256 #(
    .DATA_WIDTH           ( MEM_DATA_BITS   )
) aq_axi_master_256_inst (
    // Reset, Clock
    /*input   wire                      */.ARESETN          (),
    /*input   wire                      */.ACLK             (),
    // Master Write Address
    /*output  wire [0:0]            	*/.M_AXI_AWID		( s00_axi_awid    ),
    /*output  wire [29:0]           	*/.M_AXI_AWADDR	    ( s00_axi_awaddr  ),
    /*output  wire [7:0]            	*/.M_AXI_AWLEN		( s00_axi_awlen   ), // Burst Length: 0-255
    /*output  wire [2:0]            	*/.M_AXI_AWSIZE	    ( s00_axi_awsize  ), // Burst Size: 100
    /*output  wire [1:0]            	*/.M_AXI_AWBURST	( s00_axi_awburst ), // Burst Type: Fixed 2'b01(Incremental Burst)
    /*output  wire                      */.M_AXI_AWLOCK	    ( s00_axi_awlock  ), // Lock: Fixed 2'b00
    /*output  wire [3:0]  			    */.M_AXI_AWCACHE	( s00_axi_awcache ), // Cache: Fiex 2'b0011
    /*output  wire [2:0]  			    */.M_AXI_AWPROT	    ( s00_axi_awprot  ), // Protect: Fixed 2'b000
    /*output  wire [3:0] 				*/.M_AXI_AWQOS		( s00_axi_awqos   ), // QoS: Fixed 2'b0000
    /*output  wire       				*/.M_AXI_AWVALID	( s00_axi_awvalid ),
    /*input   wire       				*/.M_AXI_AWREADY	( s00_axi_awready ),
    // Master Write Data
    /*output  wire [DATA_WIDTH-1:0]	    */.M_AXI_WDATA		( s00_axi_wdata   ),
    /*output  wire [DATA_WIDTH/8-1:0]	*/.M_AXI_WSTRB		( s00_axi_wstrb   ),
    /*output  wire        			    */.M_AXI_WLAST		( s00_axi_wlast   ),
    /*output  wire [0:0]  			    */.M_AXI_WUSER		( s00_axi_wuser   ),
    /*output  wire        			    */.M_AXI_WVALID	    ( s00_axi_wvalid  ),
    /*input   wire        			    */.M_AXI_WREADY	    ( s00_axi_wready  ),
    // Master Write Response  
    /*input   wire [0:0]   			    */.M_AXI_BID		( s00_axi_bid     ),
    /*input   wire [1:0]   			    */.M_AXI_BRESP		( s00_axi_bresp   ),
    /*input   wire [0:0]   			    */.M_AXI_BUSER		( s00_axi_buser   ),
    /*input   wire         			    */.M_AXI_BVALID	    ( s00_axi_bvalid  ),
    /*output  wire         			    */.M_AXI_BREADY	    ( s00_axi_bready  ),
    // Master Read Address 
    /*output  wire [0:0]  			    */.M_AXI_ARID		( s00_axi_arid    ),
    /*output  wire [29:0] 			    */.M_AXI_ARADDR	    ( s00_axi_araddr  ),
    /*output  wire [7:0]  			    */.M_AXI_ARLEN		( s00_axi_arlen   ),
    /*output  wire [2:0]  			    */.M_AXI_ARSIZE	    ( s00_axi_arsize  ),
    /*output  wire [1:0]  			    */.M_AXI_ARBURST	( s00_axi_arburst ),
    /*output  wire [1:0]  			    */.M_AXI_ARLOCK	    ( s00_axi_arlock  ),
    /*output  wire [3:0]  			    */.M_AXI_ARCACHE	( s00_axi_arcache ),
    /*output  wire [2:0]  			    */.M_AXI_ARPROT	    ( s00_axi_arprot  ),
    /*output  wire [3:0]  			    */.M_AXI_ARQOS		( s00_axi_arqos   ),
    /*output  wire [0:0]  			    */.M_AXI_ARUSER	    ( s00_axi_aruser  ),
    /*output  wire        			    */.M_AXI_ARVALID	( s00_axi_arvalid ),
    /*input   wire        			    */.M_AXI_ARREADY	( s00_axi_arready ),
    // Master Read Data     
    /*input   wire [0:0]   			    */.M_AXI_RID		( s00_axi_rid     ),
    /*input   wire [DATA_WIDTH-1:0]  	*/.M_AXI_RDATA		( s00_axi_rdata   ),//
    /*input   wire [1:0]   			    */.M_AXI_RRESP		( s00_axi_rresp   ),
    /*input   wire         			    */.M_AXI_RLAST		( s00_axi_rlast   ),
    /*input   wire [0:0]   			    */.M_AXI_RUSER		( s00_axi_ruser   ),
    /*input   wire         			    */.M_AXI_RVALID	    ( s00_axi_rvalid  ),
    /*output  wire         			    */.M_AXI_RREADY	    ( s00_axi_rready  ),
    // Local Bus    
    /*input   wire         			    */.MASTER_RST		(),
    
    /*input   wire         			    */.WR_START		    (),
    /*input   wire [31:0]  			    */.WR_ADRS			(),
    /*input   wire [31:0]  			    */.WR_LEN			(), 
    /*output  wire       				*/.WR_READY		    (),
    /*output  wire       				*/.WR_FIFO_RE		(),
    /*input   wire       				*/.WR_FIFO_EMPTY	(),
    /*input   wire       				*/.WR_FIFO_AEMPTY	(),
    /*input   wire [DATA_WIDTH-1:0]  	*/.WR_FIFO_DATA	    (),
    /*output  wire       				*/.WR_DONE			(),

    /*input   wire         			    */.RD_START		    (),
    /*input   wire [31:0]  			    */.RD_ADRS			(),
    /*input   wire [31:0]  			    */.RD_LEN			(), 
    /*output  wire         			    */.RD_READY		    (),
    /*output  wire         			    */.RD_FIFO_WE		(),
    /*input   wire         			    */.RD_FIFO_FULL	    (),
    /*input   wire         			    */.RD_FIFO_AFULL	(),
    /*output  wire [DATA_WIDTH-1:0]     */.RD_FIFO_DATA	    (),
    /*output  wire         			    */.RD_DONE			(),
    /*output  wire [31:0] 			    */.DEBUG            ()
);

//===========================================================
//mig
//===========================================================
mig_ddr3 mig_ddr3_inst (
    // Memory interface ports
    .ddr3_addr                      ( ddr3_addr			  ),  // output [14:0]		ddr3_addr
    .ddr3_ba                        ( ddr3_ba			  ),  // output [2:0]		ddr3_ba
    .ddr3_cas_n                     ( ddr3_cas_n		  ),  // output			ddr3_cas_n
    .ddr3_ck_n                      ( ddr3_ck_n			  ),  // output [0:0]		ddr3_ck_n
    .ddr3_ck_p                      ( ddr3_ck_p			  ),  // output [0:0]		ddr3_ck_p
    .ddr3_cke                       ( ddr3_cke			  ),  // output [0:0]		ddr3_cke
    .ddr3_ras_n                     ( ddr3_ras_n		  ),  // output			ddr3_ras_n
    .ddr3_reset_n                   ( ddr3_reset_n		  ),  // output			ddr3_reset_n
    .ddr3_we_n                      ( ddr3_we_n			  ),  // output			ddr3_we_n
    .ddr3_dq                        ( ddr3_dq			  ),  // inout [31:0]		ddr3_dq
    .ddr3_dqs_n                     ( ddr3_dqs_n		  ),  // inout [3:0]		ddr3_dqs_n
    .ddr3_dqs_p                     ( ddr3_dqs_p		  ),  // inout [3:0]		ddr3_dqs_p
    .init_calib_complete            ( init_calib_complete ),  // output			init_calib_complete
    .ddr3_cs_n                      ( ddr3_cs_n			  ),  // output [0:0]		ddr3_cs_n
    .ddr3_dm                        ( ddr3_dm			  ),  // output [3:0]		ddr3_dm
    .ddr3_odt                       ( ddr3_odt			  ),  // output [0:0]		ddr3_odt
    // Application interface ports
    .ui_clk                         (ui_clk				),  // output			ui_clk
    .ui_clk_sync_rst                (ui_clk_sync_rst	),  // output			ui_clk_sync_rst
    .mmcm_locked                    (mmcm_locked		),  // output			mmcm_locked
    .aresetn                        (aresetn			),  // input			aresetn
    .app_sr_req                     (app_sr_req			),  // input			app_sr_req
    .app_ref_req                    (app_ref_req		),  // input			app_ref_req
    .app_zq_req                     (app_zq_req			),  // input			app_zq_req
    .app_sr_active                  (app_sr_active		),  // output			app_sr_active
    .app_ref_ack                    (app_ref_ack		),  // output			app_ref_ack
    .app_zq_ack                     (app_zq_ack			),  // output			app_zq_ack
    // Slave Interface Write Address Ports
    .s_axi_awid                     ( s00_axi_awid    ),  // input [3:0]			s_axi_awid
    .s_axi_awaddr                   ( s00_axi_awaddr  ),  // input [29:0]			s_axi_awaddr
    .s_axi_awlen                    ( s00_axi_awlen   ),  // input [7:0]			s_axi_awlen
    .s_axi_awsize                   ( s00_axi_awsize  ),  // input [2:0]			s_axi_awsize
    .s_axi_awburst                  ( s00_axi_awburst ),  // input [1:0]			s_axi_awburst
    .s_axi_awlock                   ( s00_axi_awlock  ),  // input [0:0]			s_axi_awlock
    .s_axi_awcache                  ( s00_axi_awcache ),  // input [3:0]			s_axi_awcache
    .s_axi_awprot                   ( s00_axi_awprot  ),  // input [2:0]			s_axi_awprot
    .s_axi_awqos                    ( s00_axi_awqos   ),  // input [3:0]			s_axi_awqos
    .s_axi_awvalid                  ( s00_axi_awvalid ),  // input			s_axi_awvalid
    .s_axi_awready                  ( s00_axi_awready ),  // output			s_axi_awready
    // Slave Interface Write Data Ports
    .s_axi_wdata                    ( s00_axi_wdata   ),  // input [255:0]			s_axi_wdata
    .s_axi_wstrb                    ( s00_axi_wstrb   ),  // input [31:0]			s_axi_wstrb
    .s_axi_wlast                    ( s00_axi_wlast   ),  // input			s_axi_wlast
    .s_axi_wvalid                   ( s00_axi_wvalid  ),  // input			s_axi_wvalid
    .s_axi_wready                   ( s00_axi_wready  ),  // output			s_axi_wready
    // Slave Interface Write Response Ports
    .s_axi_bid                      ( s00_axi_bid     ),  // output [3:0]			s_axi_bid
    .s_axi_bresp                    ( s00_axi_bresp   ),  // output [1:0]			s_axi_bresp
    .s_axi_bvalid                   ( s00_axi_bvalid  ),  // output			s_axi_bvalid
    .s_axi_bready                   ( s00_axi_bready  ),  // input			s_axi_bready
    // Slave Interface Read Address Ports
    .s_axi_arid                     ( s00_axi_arid    ),  // input [3:0]			s_axi_arid
    .s_axi_araddr                   ( s00_axi_araddr  ),  // input [29:0]			s_axi_araddr
    .s_axi_arlen                    ( s00_axi_arlen   ),  // input [7:0]			s_axi_arlen
    .s_axi_arsize                   ( s00_axi_arsize  ),  // input [2:0]			s_axi_arsize
    .s_axi_arburst                  ( s00_axi_arburst ),  // input [1:0]			s_axi_arburst
    .s_axi_arlock                   ( s00_axi_arlock  ),  // input [0:0]			s_axi_arlock
    .s_axi_arcache                  ( s00_axi_arcache ),  // input [3:0]			s_axi_arcache
    .s_axi_arprot                   ( s00_axi_arprot  ),  // input [2:0]			s_axi_arprot
    .s_axi_arqos                    ( s00_axi_arqos   ),  // input [3:0]			s_axi_arqos
    .s_axi_arvalid                  ( s00_axi_arvalid ),  // input			s_axi_arvalid
    .s_axi_arready                  ( s00_axi_arready ),  // output			s_axi_arready
    // Slave Interface Read Data Ports
    .s_axi_rid                      ( s00_axi_rid     ),  // output [3:0]			s_axi_rid
    .s_axi_rdata                    ( s00_axi_rdata   ),  // output [255:0]			s_axi_rdata
    .s_axi_rresp                    ( s00_axi_rresp   ),  // output [1:0]			s_axi_rresp
    .s_axi_rlast                    ( s00_axi_rlast   ),  // output			s_axi_rlast
    .s_axi_rvalid                   ( s00_axi_rvalid  ),  // output			s_axi_rvalid
    .s_axi_rready                   ( s00_axi_rready  ),  // input			s_axi_rready
    // System Clock Ports
    .sys_clk_i                      (sys_clk_i			),
    .sys_rst                        (sys_rst			)   // input sys_rst
    );
endmodule