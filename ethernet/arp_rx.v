`timescale 1ns / 1ps
/*
1、前导码，         7byt，8'h55
2、sfd帧起始界定符，1byt，8'hd5
3、目的mac，        6byt，{8'h11,8'h22,8'h33,8'h44,8'h55,8'h66}
4、源mac，          6byt，{1c:83:41:c5:ca:a6}--pc_mac
5、长度/类型，      2byt，arp：0x0806，ip：0x0800
----------arp协议数据---------
6、 硬件类型，       2byt，以太网固定为0x0001
7、 协议类型，       2byt，arp上层协议为IP协议0x0800
8、 mac地址长度，    1byt，8'h06
9、 ip地址长度，     1byt，ipv4：8'h04，ipv6：8'h06
10、op操作码，      2byt，arp请求包：1，arp应答包：2
11、源mac地址，     6byt，{1c:83:41:c5:ca:a6}--pc_mac
12、源ip地址，      4byt，{8'hc0,8'ha8,8'h0,8'h08},192.168.0.2
13、目的mac地址，   6byt，{8'h11,8'h22,8'h33,8'h44,8'h55,8'h66}
14、目的ip地址，    4byt，{8'hc0,8'ha8,8'h0,8'h02},192.168.0.8
15、填充数据，     18byt，
------------crc校验------------
16、crc校验，       4byt，        
*/
module arp_rx#(
	parameter	fpga_mac = 48'h11_22_33_44_55_66,//源mac
	parameter	fpga_ip  = 32'hc0_a8_00_08		 //源ip--192.168.0.8
)(
    input   wire            clk             ,
    input   wire            rst_n           ,
    input   wire            arp_rx_valid    ,
    input   wire    [7:0]   arp_rx_data     ,
    output  reg     [47:0]  pc_mac          ,
    output  reg     [31:0]  pc_ip           ,
    output  wire            arp_rx_op       ,
    output  wire            arp_rx_done
    );
    

            
localparam
    IDLE              = 5'd1  ,
    PREAMBLE          = 5'd2  ,    //前导码
    SFD               = 5'd3  ,    //帧起始界定符
    DES_MAC           = 5'd4  ,    //目的mac地址---fpga
    SOURCE_MAC        = 5'd5  ,    //源mac地址---pc
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

reg     [4:0]   cnt_byte;
reg     [4:0]   cnt_max;
wire            arp_cnt_end;

reg             error;//错误信号
reg     [15:0]  op;
reg     [47:0]  source_mac;
reg     [31:0]  source_ip;
reg     [47:0]  des_mac;
reg     [31:0]  des_ip;

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
                if(arp_rx_valid && arp_rx_data == 8'h55)
                    next_state = PREAMBLE;
                else
                    next_state = curr_state;
            end
            PREAMBLE         :begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
                    next_state = SFD;
                else
                    next_state = curr_state;
            end
            SFD              :begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
                    next_state = DES_MAC;
                else
                    next_state = curr_state;
            end
            DES_MAC          :begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
                    next_state = SOURCE_MAC;
                else
                    next_state = curr_state;
            end
            SOURCE_MAC       :begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
                    next_state = LEN_TYPE;
                else
                    next_state = curr_state;
            end
            LEN_TYPE         :begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
                    next_state = ARP_HARDWARE_TYPE;
                else
                    next_state = curr_state;
            end
            ARP_HARDWARE_TYPE:begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
                    next_state = ARP_PROTOCOL_TYPE;
                else
                    next_state = curr_state;
            end
            ARP_PROTOCOL_TYPE:begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
                    next_state = ARP_MAC_LEN;
                else
                    next_state = curr_state;
            end
            ARP_MAC_LEN      :begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
                    next_state = ARP_IP_LEN;
                else
                    next_state = curr_state;
            end
            ARP_IP_LEN       :begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
                    next_state = ARP_OP;
                else
                    next_state = curr_state;
            end
            ARP_OP           :begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
                    next_state = ARP_SOURCE_MAC;
                else
                    next_state = curr_state;
            end
            ARP_SOURCE_MAC   :begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
                    next_state = ARP_SOURCE_IP;
                else
                    next_state = curr_state;
            end
            ARP_SOURCE_IP    :begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
                    next_state = ARP_DES_MAC;
                else
                    next_state = curr_state;
            end
            ARP_DES_MAC      :begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
                    next_state = ARP_DES_IP;
                else
                    next_state = curr_state;
            end
            ARP_DES_IP       :begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
                    next_state = ARP_PADDING_DATA;
                else
                    next_state = curr_state;
            end
            ARP_PADDING_DATA :begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
                    next_state = CRC_CHECK;
                else
                    next_state = curr_state;
            end
            CRC_CHECK        :begin
                if(error)
                    next_state = IDLE;
                else if(arp_cnt_end)
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
    else if(curr_state == IDLE || cnt_byte == cnt_max)
        cnt_byte <= 0;
    else
        cnt_byte <= cnt_byte + 1;
end

always @(*) begin
    case(curr_state)
        IDLE             :cnt_max = 0;
        PREAMBLE         :cnt_max = 5;
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
//---------------------------------错误信息----------------------------
always @(*) begin
    if(!rst_n)
        error = 0;
    else begin
        case(curr_state)
            IDLE             :error = 0;
            PREAMBLE         :begin
                if(cnt_byte < cnt_max && arp_rx_data != 8'h55)
                    error = 1;
                else
                    error = 0;
            end
            SFD              :begin
                if(cnt_byte == cnt_max && arp_rx_data != 8'hd5)
                    error = 1;
                else
                    error = 0;
            end
            DES_MAC          :error = 0;
            SOURCE_MAC       :error = 0;
            LEN_TYPE         :begin
                if((cnt_byte == 0 && arp_rx_data != 8'h08) || (cnt_byte == 1 && arp_rx_data != 8'h06))
                    error = 1;
                else
                    error = 0;
            end
            ARP_HARDWARE_TYPE:begin
                if((cnt_byte == 0 && arp_rx_data != 8'h00) || (cnt_byte == 1 && arp_rx_data != 8'h01))
                    error = 1;
                else
                    error = 0;
            end
            ARP_PROTOCOL_TYPE:begin
                if((cnt_byte == 0 && arp_rx_data != 8'h08) || (cnt_byte == 1 && arp_rx_data != 8'h00))
                    error = 1;
                else
                    error = 0;
            end
            ARP_MAC_LEN      :begin
                if(cnt_byte == cnt_max && arp_rx_data != 8'h06)
                    error = 1;
                else
                    error = 0;
            end
            ARP_IP_LEN       :begin
                if(cnt_byte == cnt_max && arp_rx_data != 8'h04)
                    error = 1;
                else
                    error = 0;
            end
            ARP_OP           :begin
                if((cnt_byte == 0 && arp_rx_data != 8'h00) || (cnt_byte == 1 && arp_rx_data != 8'h01 && arp_rx_data != 8'h02))
                    error = 1;
                else
                    error = 0;
            end
            ARP_SOURCE_MAC   :error = 0;
            ARP_SOURCE_IP    :error = 0;
            ARP_DES_MAC      :begin
                if(cnt_byte == cnt_max && op == 16'h0002 && des_mac != fpga_mac)
                    error = 1;
                else
                    error = 0;
            end
            ARP_DES_IP       :error = 0;
            ARP_PADDING_DATA :begin
                if(cnt_byte == 0  && des_ip != fpga_ip)
                    error = 1;
                else
                    error = 0;
            end
            CRC_CHECK        :error = 0;
            default:error = 0;
        endcase
    end 
end

//---------------------------------op----------------------------
always @(posedge clk) begin
    if(!rst_n)
        op <= 0;
    else if(curr_state == ARP_OP)
        op <= {op[7:0], arp_rx_data};
    else
        op <= op;
end
//---------------------------------目的地址----------------------------
always @(posedge clk) begin
    if(!rst_n)
        des_mac <= 48'd0;
    else if(curr_state == DES_MAC)
        des_mac <= {des_mac[39:0], arp_rx_data};
    else
        des_mac <= des_mac;
end

always @(posedge clk) begin
    if(!rst_n)
        des_ip <= 0;
    else if(curr_state == ARP_DES_IP)
        des_ip <= {des_ip[23:0], arp_rx_data};
    else
        des_ip <= des_ip;
end
//---------------------------------源地址----------------------------
always @(posedge clk) begin
    if(!rst_n)
        source_mac <= 0;
    else if(curr_state == ARP_SOURCE_MAC)
        source_mac <= {source_mac[39:0], arp_rx_data};
    else
        source_mac <= source_mac;
end

always @(posedge clk) begin
    if(!rst_n)
        source_ip <= 0;
    else if(curr_state == ARP_SOURCE_IP)
        source_ip <= {source_ip[23:0], arp_rx_data};
    else
        source_ip <= source_ip;
end
//---------------------------------pc接收的地址----------------------------
always @(posedge clk) begin
    if(!rst_n)
        pc_mac <= 0;
    else if(op == 16'h00_02 && curr_state == CRC_CHECK) 
        pc_mac <= source_mac;
end

always @(posedge clk) begin
    if(!rst_n)
        pc_ip <= 0;
    else if(op == 16'h00_02 && curr_state == CRC_CHECK) 
        pc_ip <= source_ip;
end

//---------------------------------数据包类型----------------------------
assign arp_rx_op = op[0]; //8'h0001,8'h0002 ; 01 ,10;1:请求包/0:应答包
//---------------------------------接收结束----------------------------
assign arp_rx_done = (curr_state == CRC_CHECK && cnt_byte == cnt_max) ? 1 : 0;


endmodule
