module ethernet_top(
    input   wire            clk             ,
    input   wire            video_clk       ,
    input   wire            rst_n           ,
    output  wire            read_req        , // Start reading a frame of data     
    input   wire            read_req_ack    , // Read request response
    output  wire            read_en         , // Read data enable
    input   wire    [15:0]  read_data       , // Read data
    //
    input   wire            key_flag1       ,
    //
    output  wire            udp_rx_en       ,
    output  wire    [7:0]   udp_idata       ,
    //ethernet
    output  wire            rgmii_clk       ,
    input   wire            eth_rx_clk      ,//PHY芯片
    input   wire            eth_rx_valid    ,
    input   wire    [3:0]   eth_rx_data     ,
    output  wire            eth_tx_clk      ,
    output  wire            eth_tx_valid    ,
    output  wire    [3:0]   eth_tx_data          
 );

parameter	fpga_mac 	= 48'h11_22_33_44_55_66	;//源mac
parameter	fpga_ip  	= 32'hc0_a8_00_08		;//源ip--192.168.0.8
parameter	pc_mac   	= 48'hff_ff_ff_ff_ff_ff	;//目的mac，不知道pc的mac，以广播的形式发送
parameter	pc_ip    	= 32'hC0_A8_01_69		;//目的ip--192.168.1.105
parameter	source_port = 16'd1234				;//源端口
parameter	des_port    = 16'd5678			 	;//目的端口

parameter	FORMAT    =   8'h04     ;//图像格式 04:(RGB565)
parameter	H_PIXEL   =   16'd1280   ;//行像素个数：1280
parameter	V_PIXEL   =   16'd720   ;//场像素个数：720				

//------------------------------ethernet-----------------------------
//arp_ctrl
wire            arp_tx_en;
wire            arp_tx_op;
//arp
wire            arp_rx_op  ;
wire            arp_rx_done;
wire            arp_tx_valid;
wire    [7:0]   arp_tx_data ;
wire            arp_rx_valid;
wire    [7:0]   arp_rx_data ;
//udp
wire    [7:0]   udp_tx_data ;
wire            udp_tx_valid;
wire    [15:0]  udp_odata   ;
wire            udp_data_valid;
wire            udp_rx_valid;
wire            udp_rx_data ;
// wire    [7:0]   udp_idata  ;
// wire            udp_rx_en  ;
wire            udp_rx_done;
wire    [15:0]  udp_tx_data_num ;
wire            image_format_end;
wire            udp_tx_done     ;
wire            udp_data_req    ;
wire            udp_tx_en       ;//udp开始信号
//rgmii 
wire            mac_tx_clk  ;
wire            mac_tx_valid;
wire    [7:0]   mac_tx_data ;
// wire            mac_rx_clk  ;

wire            mac_rx_valid;
wire    [7:0]   mac_rx_data ;
//protocol

//
wire    [47:0]  des_mac;
wire    [31:0]  des_ip ;

//----------------------------arp-------------------------------------
arp_ctrl arp_ctrl_u(
    /*input   wire            */.clk           (rgmii_clk )  ,
    /*input   wire            */.rst_n         (rst_n      )  ,
    /*input   wire            */.key           (key_flag1  )  ,
    /*input   wire            */.arp_rx_op     (arp_rx_op  )  ,
    /*input   wire            */.arp_rx_done   (arp_rx_done)  ,
    /*output  reg             */.arp_tx_en     (arp_tx_en  )  ,
    /*output  reg             */.arp_tx_op     (arp_tx_op  )   //1:请求包/0:应答包
    );

arp_top #(
	.fpga_mac (fpga_mac),//源mac
	.fpga_ip  (fpga_ip ),//源ip--192.168.0.8
	.pc_mac   (pc_mac  ),//目的mac，不知道pc的mac，以广播的形式发送
	.pc_ip    (pc_ip   ) //目的ip--192.168.0.2
)arp_top_u(
    /*input   wire            */.rst_n          (rst_n) ,
    //-------------------------tx-----------------------------                                 
    /*input   wire            */.arp_tx_clk     (rgmii_clk) ,
    /*input   wire            */.arp_tx_en      (arp_tx_en) ,
    /*input   wire            */.arp_tx_op      (arp_tx_op) ,
    /*output  wire    [7:0]   */.arp_tx_data    (arp_tx_data ) ,
    /*output  wire            */.arp_tx_valid   (arp_tx_valid) ,
    //-------------------------rx-----------------------------                                 
    /*input   wire            */.arp_rx_clk     (rgmii_clk  ) ,
    /*input   wire            */.arp_rx_valid   (mac_rx_valid) ,
    /*input   wire    [7:0]   */.arp_rx_data    (mac_rx_data ) ,
    /*output  reg     [47:0]  */.des_mac        (des_mac) ,
    /*output  reg     [31:0]  */.des_ip         (des_ip ) ,
    /*output  wire            */.arp_rx_op      (arp_rx_op  ) ,
    /*output  wire            */.arp_rx_done    (arp_rx_done)  
    );
    
//----------------------------udp-------------------------------------
udp_top #(
	.fpga_mac 	 (fpga_mac 	 ),//源mac
	.fpga_ip  	 (fpga_ip  	 ),//源ip--192.168.0.8
	.source_port (source_port),//源端口
	.des_port    (des_port   ) //目的端口
)udp_top_u(
    /*input   wire            */.rst_n           (rst_n),
    //-------------tx---------------------  
    /*input   wire            */.udp_tx_en       (udp_tx_en),//udp开始信号
    /*input   wire    [7:0]   */.udp_odata       (udp_odata),//udp发送的数据
    /*input   wire    [47:0]  */.des_mac         (des_mac),
    /*input   wire    [31:0]  */.des_ip          (des_ip ),
    /*input   wire    [10:0]  */.udp_tx_data_num (udp_tx_data_num),//udp发送数据的个数
    /*output  wire            */.udp_data_valid  (udp_data_valid ),//udp数据有效信号
    /*output  wire            */.udp_tx_done     (udp_tx_done    ),//udp结束信号
    //rgmii                                 
    /*input   wire            */.udp_tx_clk      (rgmii_clk),
    /*output  reg     [7:0]   */.udp_tx_data     (udp_tx_data ),//udp数据包：ip首部、udp首部、udp数据
    /*output  reg             */.udp_tx_valid    (udp_tx_valid),//udp数据包有效信号
    //-------------rx---------------------  
    /*output  reg     [7:0]   */.udp_idata       (udp_idata  ),//udp接收的数据
    /*output  reg             */.udp_rx_en       (udp_rx_en  ),
    /*output  wire            */.udp_rx_done     (udp_rx_done),
    //rgmii                                 
    /*input   wire            */.udp_rx_clk      (rgmii_clk  ),
    /*input   wire            */.udp_rx_valid    (mac_rx_valid),
    /*input   wire    [7:0]   */.udp_rx_data     (mac_rx_data )
    );
//------------------------------协议控制--------------------------------
protocol_ctrl #(
	.FORMAT   (FORMAT ),//图像格式 04:(RGB565)
    .H_PIXEL  (H_PIXEL),//行像素个数：1280
    .V_PIXEL  (V_PIXEL)//场像素个数：720
)protocol_ctrl_u(
    /*input   wire            */.rst_n           (rst_n) ,

    /*output  reg             */.read_req        ( read_req        ) , // Start reading a frame of data     
    /*input   wire            */.read_req_ack    ( read_req_ack    ) , // Read request response
    /*output  wire            */.read_en         ( read_en         ) , // Read data enable
    /*input   wire    [15:0]  */.read_data       ( read_data       ) , // Read data

    //arp                                   
    /*input   wire            */.arp_tx_valid    (arp_tx_valid) ,
    /*input   wire            */.arp_tx_en       (arp_tx_en   ) ,
    /*input   wire            */.arp_rx_op       (arp_rx_op   ) ,
    /*input   wire            */.arp_rx_done     (arp_rx_done ) ,
    /*input   wire    [7:0]   */.arp_tx_data     (arp_tx_data ) ,
    //udp                                   
    /*input   wire    [7:0]   */.udp_tx_data     (udp_tx_data ) ,
    /*input   wire            */.udp_tx_valid    (udp_tx_valid) ,
    /*input   wire            */.udp_tx_done     (udp_tx_done ) ,
	/*input   wire            */.udp_data_valid  (udp_data_valid),//udp数据有效信号
    /*output  wire    [7:0]   */.udp_odata       (udp_odata) ,//udp发送的数据
    /*output  wire            */.udp_tx_en       (udp_tx_en) ,//以太网传输数据开始信号
    /*output  wire    [15:0]  */.udp_tx_data_num (udp_tx_data_num) ,
    //rgmii                                 
    /*input   wire            */.clk             (rgmii_clk  ) ,
    /*output  wire            */.mac_tx_valid    (mac_tx_valid) ,
    /*output  wire    [7:0]   */.mac_tx_data     (mac_tx_data ) 
    );

rgmii_interface rgmii_interface_inst(
    /*input   wire            */.rst                ( ~rst_n       ) ,
    /*output  wire            */.rgmii_clk          ( rgmii_clk    ) ,

    /*input   wire            */.mac_tx_data_valid  ( mac_tx_valid ) ,
    /*input   wire    [7:0]   */.mac_tx_data        ( mac_tx_data  ) ,

    /*output  wire            */.mac_rx_data_valid  ( mac_rx_valid ) ,
    /*output  wire    [7:0]   */.mac_rx_data        ( mac_rx_data  ) ,

    /*input   wire            */.rgmii_rxc          ( eth_rx_clk   ) ,
    /*input   wire            */.rgmii_rx_ctl       ( eth_rx_valid ) ,
    /*input   wire    [3:0]   */.rgmii_rxd          ( eth_rx_data  ) ,
    
    /*output  wire            */.rgmii_txc          ( eth_tx_clk   )  ,
    /*output  wire            */.rgmii_tx_ctl       ( eth_tx_valid ) ,
    /*output  wire    [3:0]   */.rgmii_txd          ( eth_tx_data  )
);

endmodule
