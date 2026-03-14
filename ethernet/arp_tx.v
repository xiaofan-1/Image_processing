`timescale 1ns / 1ps
/*
1、前导码，         7byt，8'h55
2、sfd帧起始界定符，1byt，8'hd5
3、目的mac，        6byt，8'hff
4、源mac，          6byt，{8'h11,8'h22,8'h33,8'h44,8'h55,8'h66}
5、长度/类型，      2byt，arp：0x0806，ip：0x0800
----------arp协议数据---------
6、 硬件类型，       2byt，以太网固定为0x0001
7、 协议类型，       2byt，arp上层协议为IP协议0x0800
8、 mac地址长度，    1byt，8'h06
9、 ip地址长度，     1byt，ipv4：8'h04，ipv6：8'h06
10、op操作码，      2byt，arp请求包：1，arp应答包：2
11、源mac地址，     6byt，{8'h11,8'h22,8'h33,8'h44,8'h55,8'h66}
12、源ip地址，      4byt，{8'hc0,8'ha8,8'h0,8'h08},192.168.0.8
13、目的mac地址，   6byt，广播地址（FF_FF_FF_FF_FF_FF）
14、目的ip地址，    4byt，{8'hc0,8'ha8,8'h0,8'h02},192.168.0.2
15、填充数据，     18byt，
------------crc校验------------
16、crc校验，       4byt，        
*/
module arp_tx#(
	parameter	fpga_mac = 48'h11_22_33_44_55_66,//源mac
	parameter	fpga_ip  = 32'hc0_a8_00_08		,//源ip--192.168.0.8
	parameter	pc_mac   = 48'hff_ff_ff_ff_ff_ff,//目的mac，不知道pc的mac，以广播的形式发送
	parameter	pc_ip    = 32'hc0_a8_00_02		 //目的ip--192.168.0.2
)(
    input   wire            clk             ,
    input   wire            rst_n           ,
    input   wire            arp_tx_en       ,//arp开始发送使能
    input   wire            arp_tx_op       ,//arp发送数据包的类型，请求包：1，应答包：0
    //当arp接收到请求包，发送应答包时：
    input   wire    [47:0]  des_mac         ,//目的mac ：源mac接收到请求包，发送应答包（目的mac）到pc
    input   wire    [31:0]  des_ip          ,//目的ip
    
    output  reg     [7:0]   arp_tx_data     ,
    output  reg             arp_tx_valid    ,
    output  wire            arp_tx_done     ,
    //crc校验
    input   wire    [31:0]  crc_data        ,
    output  wire            crc_en          ,//CRC校验开始信号
    output  wire            crc_done         //CRC校验结束信号
    );
    
localparam
    IDLE              = 5'd1  ,
    PREAMBLE          = 5'd2  ,    //前导码
    SFD               = 5'd3  ,    //帧起始界定符
    DES_MAC           = 5'd4  ,    //目的mac地址--pc
    SOURCE_MAC        = 5'd5  ,    //源mac地址--fpga
    LEN_TYPE          = 5'd6  ,    //长度/类型
    ARP_HARDWARE_TYPE = 5'd7  ,    //硬件类型-----------arp-----------
    ARP_PROTOCOL_TYPE = 5'd8  ,    //软件类型
    ARP_MAC_LEN       = 5'd9  ,    //mac地址长度
    ARP_IP_LEN        = 5'd10 ,    //ip地址长度
    ARP_OP            = 5'd11 ,    //类型选择
    ARP_SOURCE_MAC    = 5'd12 ,    //源mac地址--fpga
    ARP_SOURCE_IP     = 5'd13 ,    //源ip地址--fpga
    ARP_DES_MAC       = 5'd14 ,    //目的mac地址--pc
    ARP_DES_IP        = 5'd15 ,    //目的ip地址--pc
    ARP_PADDING_DATA  = 5'd16 ,    //填充数据
    CRC_CHECK         = 5'd17 ;    //crc32校验
    
reg [4:0]   curr_state;
reg [4:0]   next_state;
reg [4:0]   cnt_byte;
reg [4:0]   cnt_max;
wire        arp_cnt_end;

//---------------------------------state one----------------------------
always @(posedge clk) begin
    if(!rst_n)
        curr_state <= IDLE;
    else
        curr_state <= next_state;
end

//---------------------------------state two----------------------------
always @(*) begin
    if(!rst_n)
        next_state = IDLE;
    else begin
        case(curr_state)
            IDLE             :begin
                if(arp_tx_en)
                    next_state = PREAMBLE;
                else
                    next_state = curr_state;
            end
            PREAMBLE         :begin
                if(arp_cnt_end)
                    next_state = SFD;
                else
                    next_state = curr_state;
            end
            SFD              :begin
                if(arp_cnt_end)
                    next_state = DES_MAC;
                else
                    next_state = curr_state;
            end
            DES_MAC          :begin
                if(arp_cnt_end)
                    next_state = SOURCE_MAC;
                else
                    next_state = curr_state;
            end
            SOURCE_MAC       :begin
                if(arp_cnt_end)
                    next_state = LEN_TYPE;
                else
                    next_state = curr_state;
            end
            LEN_TYPE         :begin
                if(arp_cnt_end)
                    next_state = ARP_HARDWARE_TYPE;
                else
                    next_state = curr_state;
            end
            ARP_HARDWARE_TYPE:begin
                if(arp_cnt_end)
                    next_state = ARP_PROTOCOL_TYPE;
                else
                    next_state = curr_state;
            end
            ARP_PROTOCOL_TYPE:begin
                if(arp_cnt_end)
                    next_state = ARP_MAC_LEN;
                else
                    next_state = curr_state;
            end
            ARP_MAC_LEN      :begin
                if(arp_cnt_end)
                    next_state = ARP_IP_LEN;
                else
                    next_state = curr_state;
            end
            ARP_IP_LEN       :begin
                if(arp_cnt_end)
                    next_state = ARP_OP;
                else
                    next_state = curr_state;
            end
            ARP_OP           :begin
                if(arp_cnt_end)
                    next_state = ARP_SOURCE_MAC;
                else
                    next_state = curr_state;
            end
            ARP_SOURCE_MAC   :begin
                if(arp_cnt_end)
                    next_state = ARP_SOURCE_IP;
                else
                    next_state = curr_state;
            end
            ARP_SOURCE_IP    :begin
                if(arp_cnt_end)
                    next_state = ARP_DES_MAC;
                else
                    next_state = curr_state;
            end
            ARP_DES_MAC      :begin
                if(arp_cnt_end)
                    next_state = ARP_DES_IP;
                else
                    next_state = curr_state;
            end
            ARP_DES_IP       :begin
                if(arp_cnt_end)
                    next_state = ARP_PADDING_DATA;
                else
                    next_state = curr_state;
            end
            ARP_PADDING_DATA :begin
                if(arp_cnt_end)
                    next_state = CRC_CHECK;
                else
                    next_state = curr_state;
            end
            CRC_CHECK        :begin
                if(arp_cnt_end)
                    next_state = IDLE;
                else
                    next_state = curr_state;
            end
            default:next_state = IDLE;
        endcase
    end
end

//---------------------------------byte计数----------------------------
always @(posedge clk) begin
    if(!rst_n)
        cnt_byte <= 0;
    else if(curr_state != IDLE ) begin 
        if(cnt_byte == cnt_max)
            cnt_byte <= 0;
        else
            cnt_byte <= cnt_byte + 1;
    end
end

always @(*) begin
    case(curr_state)
        IDLE             :cnt_max = 0;
        PREAMBLE         :cnt_max = 6;
        SFD              :cnt_max = 0;
        DES_MAC          :cnt_max = 5;
        SOURCE_MAC       :cnt_max = 5;
        LEN_TYPE         :cnt_max = 1;
        ARP_HARDWARE_TYPE:cnt_max = 1;
        ARP_PROTOCOL_TYPE:cnt_max = 1;
        ARP_MAC_LEN      :cnt_max = 0;
        ARP_IP_LEN       :cnt_max = 0;
        ARP_OP           :cnt_max = 1;
        ARP_SOURCE_MAC   :cnt_max = 5;
        ARP_SOURCE_IP    :cnt_max = 3;
        ARP_DES_MAC      :cnt_max = 5;
        ARP_DES_IP       :cnt_max = 3;
        ARP_PADDING_DATA :cnt_max = 17;
        CRC_CHECK        :cnt_max = 3;
        default:cnt_max = 0;
    endcase
end

assign arp_cnt_end = (cnt_byte == cnt_max && curr_state != IDLE) ? 1 : 0;

//---------------------------------传输数据----------------------------
always @(posedge clk) begin
    if(!rst_n)  
        arp_tx_data <= 0;
    else begin
        case(curr_state)
            IDLE             :arp_tx_data <= 0;
            PREAMBLE         :arp_tx_data <= 8'h55;
            SFD              :arp_tx_data <= 8'hd5;
            DES_MAC          :begin
                if(arp_tx_op)
                    arp_tx_data <= 8'hff;
                else begin
                    case(cnt_byte)
                        0 : arp_tx_data <= des_mac[47:40];
                        1 : arp_tx_data <= des_mac[39:32];
                        2 : arp_tx_data <= des_mac[31:24];
                        3 : arp_tx_data <= des_mac[23:16];
                        4 : arp_tx_data <= des_mac[15:8] ;
                        5 : arp_tx_data <= des_mac[7:0]  ;
                        default : arp_tx_data <= 0;
                    endcase
                end
            end
            SOURCE_MAC       :begin
                case(cnt_byte)
                    0 : arp_tx_data <= fpga_mac[47:40];
                    1 : arp_tx_data <= fpga_mac[39:32];
                    2 : arp_tx_data <= fpga_mac[31:24];
                    3 : arp_tx_data <= fpga_mac[23:16];
                    4 : arp_tx_data <= fpga_mac[15:8] ;
                    5 : arp_tx_data <= fpga_mac[7:0]  ;
                    default:arp_tx_data <= 0;
                endcase
            end
            LEN_TYPE         :begin
                case(cnt_byte)
                    0 : arp_tx_data <= 8'h08;
                    1 : arp_tx_data <= 8'h06;
                    default:arp_tx_data <= 0;
                endcase
            end
            ARP_HARDWARE_TYPE:begin
                case(cnt_byte)
                    0 : arp_tx_data <= 8'h00;
                    1 : arp_tx_data <= 8'h01;
                    default:arp_tx_data <= 0;
                endcase
            end
            ARP_PROTOCOL_TYPE:begin
                case(cnt_byte)
                    0 : arp_tx_data <= 8'h08;
                    1 : arp_tx_data <= 8'h00;
                    default:arp_tx_data <= 0;
                endcase
            end
            ARP_MAC_LEN      :arp_tx_data <= 8'h06;
            ARP_IP_LEN       :arp_tx_data <= 8'h04;
            ARP_OP           :begin
                if(arp_tx_op) begin
                    case(cnt_byte)
                        0 : arp_tx_data <= 8'h00;
                        1 : arp_tx_data <= 8'h01;
                        default:arp_tx_data <= 0;
                    endcase
                end
                else begin
                    case(cnt_byte)
                        0 : arp_tx_data <= 8'h00;
                        1 : arp_tx_data <= 8'h02;
                        default:arp_tx_data <= 0;
                    endcase
                end
            end
            ARP_SOURCE_MAC   :begin
                case(cnt_byte)
                    0 : arp_tx_data <= fpga_mac[47:40];
                    1 : arp_tx_data <= fpga_mac[39:32];
                    2 : arp_tx_data <= fpga_mac[31:24];
                    3 : arp_tx_data <= fpga_mac[23:16];
                    4 : arp_tx_data <= fpga_mac[15:8] ;
                    5 : arp_tx_data <= fpga_mac[7:0]  ;
                    default:arp_tx_data <= 0;
                endcase
            end
            ARP_SOURCE_IP    :begin
                case(cnt_byte)
                    0 : arp_tx_data <= fpga_ip[31:24];
                    1 : arp_tx_data <= fpga_ip[23:16];
                    2 : arp_tx_data <= fpga_ip[15:8] ;
                    3 : arp_tx_data <= fpga_ip[7:0]  ;
                    default:arp_tx_data <= 0;
                endcase
            end
            ARP_DES_MAC      :begin
                if(arp_tx_op)
                    arp_tx_data <= 8'hff;
                else begin
                    case(cnt_byte)
                        0 : arp_tx_data <= des_mac[47:40];
                        1 : arp_tx_data <= des_mac[39:32];
                        2 : arp_tx_data <= des_mac[31:24];
                        3 : arp_tx_data <= des_mac[23:16];
                        4 : arp_tx_data <= des_mac[15:8] ;
                        5 : arp_tx_data <= des_mac[7:0]  ;
                        default : arp_tx_data <= 0;
                    endcase
                end
            end
            ARP_DES_IP       :begin
                case(cnt_byte)
                    0 : arp_tx_data <= pc_ip[31:24];
                    1 : arp_tx_data <= pc_ip[23:16];
                    2 : arp_tx_data <= pc_ip[15:8] ;
                    3 : arp_tx_data <= pc_ip[7:0]  ;
                    default:arp_tx_data <= 0;
                endcase
            end
            ARP_PADDING_DATA :arp_tx_data <= 0;
            CRC_CHECK        :begin
                case(cnt_byte)
                    0 : arp_tx_data <= crc_data[7:0]  ;
                    1 : arp_tx_data <= crc_data[15:8] ;
                    2 : arp_tx_data <= crc_data[23:16];
                    3 : arp_tx_data <= crc_data[31:24];
                    default:arp_tx_data <= 0;
                endcase
            end
            default:arp_tx_data <= 8'h00;
        endcase
    end
end
//---------------------------------数据有效----------------------------
always @(posedge clk) begin
    if(!rst_n)
        arp_tx_valid <= 0;
    else if(curr_state == IDLE)
        arp_tx_valid <= 0;
    else
        arp_tx_valid <= 1;
end
//---------------------------------数据结束----------------------------
assign arp_tx_done = (curr_state == CRC_CHECK && cnt_byte == cnt_max) ? 1 : 0;
//---------------------------------crc开始信号----------------------------
assign crc_en = (curr_state == IDLE || curr_state == PREAMBLE || curr_state == SFD || curr_state == CRC_CHECK) ? 0 : 1;
//---------------------------------crc结束信号----------------------------
assign crc_done = (curr_state == IDLE) ? 1 : 0;

endmodule
