`timescale 1ns / 1ps
/*
1、前导码，         7byt，8'h55
2、sfd帧起始界定符，1byt，8'hd5
3、目的mac，        6byt，pc---mac
4、源mac，          6byt，{8'h11,8'h22,8'h33,8'h44,8'h55,8'h66}
5、长度/类型，      2byt，arp：0x0806，ip：0x0800
----------IP首部---------
6、版本+IP首部长度，1byt，IPV4，固定为4;
                          IPV4首部长度为20byte，但是这里是以4byte作为一个单位，该值为5。
7、区分服务，       1byt，自设，8'h05---一般是不使用
8、总长度，         2byt，ip首部+udp长度+数据长度：20+8+20
9、标识，           2byt，计数器，初始值可随机
10、标志+片偏移，   2byt，最高位无效为0，只有低两位有效；第二位表示是否分片，1表示不能分片，0 表示可以分片；最低位表示是否是最后一个分片数据。
                          16'h4000
11、生存时间，      1byt，大于1即可，8'h40
12、协议类型，      1byt，TCP协议：8'd6；UDP协议：8'd17，8'h11;ICMP协议：8'd2
13、首部校验和，    2byt，计算得出
14、源ip地址，      4byt，{8'hc0,8'ha8,8'h0,8'h08},192.168.0.8
15、目的ip地址，    4byt，{8'hc0,8'ha8,8'h0,8'h02},192.168.0.2
------udp首部--------------
16、源端口，        2byt，16'd1234
17、目的端口，      2byt，16'd5678
18、udp数据长度，   2byt，udp长度+数据长度：20+8
19、udp校验和，     2byt，0
------udp数据--------------
20、udp数据发送，   至少18byt，最多1472byt
------------crc校验------------
21、crc校验         4byt
===============================状态机(可选)======================================
首部校验和             4byte,高16位+低16位
前导码 + 帧起始界定符  8byte
以太网帧头            14byte
IP头部                20byte
UDP头部                8byte
UDP数据               20byte,udp发送数据长度，16bit*10 = 20byte
CRC校验                4byte
*/
module udp_tx#(
	parameter	fpga_mac 	= 48'h11_22_33_44_55_66	,//源mac
	parameter	fpga_ip  	= 32'hc0_a8_00_08		,//源ip--192.168.0.8
	parameter	source_port = 16'd1234				,//源端口
	parameter	des_port    = 16'd5678			 	 //目的端口
)(
    input   wire            clk             ,
    input   wire            rst_n           ,
    input   wire    [15:0]  udp_tx_data_num ,
    input   wire            udp_tx_en       ,//udp开始信号
    input   wire    [7:0]   udp_odata       ,//udp发送的数据
    input   wire    [47:0]  des_mac         ,
    input   wire    [31:0]  des_ip          ,
   
    output  reg     [7:0]   udp_tx_data     ,//udp数据包：ip首部、udp首部、udp数据
    output  reg             udp_tx_valid    ,//udp数据包有效信号
    output  wire            udp_tx_done     ,//udp结束信号
    output  wire            udp_data_valid  ,//udp数据有效信号
    // output  wire            udp_data_req    ,//数据发送2字节后，请求信号    
    //crc校验
    input   wire    [31:0]  crc_data        ,
    output  wire            crc_en          ,//CRC校验开始信号
    output  wire            crc_done         //CRC校验结束信号
    );
    


localparam
    IDLE                 = 5'd1  ,
    PREAMBLE             = 5'd2  ,//前导码
    SFD                  = 5'd3  ,//帧起始界定符
    DES_MAC              = 5'd4  ,//目的mac地址--pc
    SOURCE_MAC           = 5'd5  ,//源mac地址--fpga
    LEN_TYPE             = 5'd6  ,//长度/类型
    UDP_VERSION_CHECKSUM = 5'd7  ,//版本+IP首部长度
    UDP_TOS              = 5'd8  ,//区分服务
    UDP_TOTAL_LEN        = 5'd9  ,//总长度
    UDP_IDENTIFIER       = 5'd10 ,//标识
    UDP_FLAG_OFFSET      = 5'd11 ,//标志+片偏移
    UDP_TTL              = 5'd12 ,//生存时间
    UDP_PROTOCOL         = 5'd13 ,//协议类型
    UDP_HEAD_CHECKSUM    = 5'd14 ,//首部校验和
    UDP_SOURCE_IP        = 5'd15 ,//源ip
    UDP_DES_IP           = 5'd16 ,//目的ip
    UDP_SOURCE_PORT      = 5'd17 ,//源端口
    UDP_DES_PORT         = 5'd18 ,//目的端口
    UDP_DATA_LEN         = 5'd19 ,//数据长度
    UDP_DATA_CHECKSUM    = 5'd20 ,//校验和
    UDP_DATA             = 5'd21 ,//udp数据
    CRC_CHECK            = 5'd22 ;//crc校验
    
reg     [4:0]   curr_state;
reg     [4:0]   next_state;
//计数器
reg     [15:0]  cnt_byte;
reg     [15:0]  cnt_max;
wire            udp_cnt_end;
// reg     [15:0]  cnt_byte_data;

//标识
reg     [15:0]  udp_id;
//校验和
wire    [15:0]  head_checksum;
wire    [31:0]  checksum;

wire    [15:0]  udp_len;
wire    [15:0]  ip_len ;

assign udp_len = 16'd8 + udp_tx_data_num;//udp长度：udp头部 + 数据包长度
assign ip_len = 16'd20 + 16'd8 + udp_tx_data_num;//ip长度：ip头部 + udp头部 + 数据包长度

assign checksum = 16'h4500 + ip_len + udp_id + 16'h4000 + 16'h4011 + 16'h0000 + 
                  fpga_ip[31:16] + fpga_ip[15:0] + des_ip[31:16] + des_ip[15:0];
assign head_checksum = ~(checksum[31:16] + checksum[15:0]);

//标识
always @(posedge clk) begin
    if(!rst_n)
        udp_id <= 0;
    else if(curr_state == UDP_SOURCE_IP && cnt_byte == cnt_max)
        udp_id <= udp_id + 1;
end
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
            IDLE                :begin
                if(udp_tx_en)
                    next_state = PREAMBLE;
                else
                    next_state = curr_state;
            end
            PREAMBLE            :begin//前导码   
                if(udp_cnt_end)
                    next_state = SFD;
                else
                    next_state = curr_state;
            end
            SFD                 :begin//帧起始界定符        
                if(udp_cnt_end)
                    next_state = DES_MAC;
                else
                    next_state = curr_state;
            end 
            DES_MAC             :begin//目的mac地址--pc    
                if(udp_cnt_end)
                    next_state = SOURCE_MAC;
                else
                    next_state = curr_state;
            end
            SOURCE_MAC          :begin//源mac地址--fpga   
                if(udp_cnt_end)
                    next_state = LEN_TYPE;
                else
                    next_state = curr_state;
            end
            LEN_TYPE            :begin//长度/类型          
                if(udp_cnt_end)
                    next_state = UDP_VERSION_CHECKSUM;
                else
                    next_state = curr_state;
            end
            UDP_VERSION_CHECKSUM:begin//版本+IP首部长度      
                if(udp_cnt_end)
                    next_state = UDP_TOS;
                else
                    next_state = curr_state;
            end
            UDP_TOS             :begin//区分服务           
                if(udp_cnt_end)
                    next_state = UDP_TOTAL_LEN;
                else
                    next_state = curr_state;
            end
            UDP_TOTAL_LEN       :begin//总长度            
                if(udp_cnt_end)
                    next_state = UDP_IDENTIFIER;
                else
                    next_state = curr_state;
            end
            UDP_IDENTIFIER      :begin//标识             
                if(udp_cnt_end)
                    next_state = UDP_FLAG_OFFSET;
                else
                    next_state = curr_state;
            end
            UDP_FLAG_OFFSET     :begin//标志+片偏移         
                if(udp_cnt_end)
                    next_state = UDP_TTL;
                else
                    next_state = curr_state;
            end
            UDP_TTL             :begin//生存时间           
                if(udp_cnt_end)
                    next_state = UDP_PROTOCOL;
                else
                    next_state = curr_state;
            end
            UDP_PROTOCOL        :begin//协议类型           
                if(udp_cnt_end)
                    next_state = UDP_HEAD_CHECKSUM;
                else
                    next_state = curr_state;
            end
            UDP_HEAD_CHECKSUM   :begin//首部校验和          
                if(udp_cnt_end)
                    next_state = UDP_SOURCE_IP;
                else
                    next_state = curr_state;
            end
            UDP_SOURCE_IP       :begin//源ip            
                if(udp_cnt_end)
                    next_state = UDP_DES_IP;
                else
                    next_state = curr_state;
            end
            UDP_DES_IP          :begin//目的ip           
                if(udp_cnt_end)
                    next_state = UDP_SOURCE_PORT;
                else
                    next_state = curr_state;
            end
            UDP_SOURCE_PORT     :begin//源端口            
                if(udp_cnt_end)
                    next_state = UDP_DES_PORT;
                else
                    next_state = curr_state;
            end
            UDP_DES_PORT        :begin//目的端口           
                if(udp_cnt_end)
                    next_state = UDP_DATA_LEN;
                else
                    next_state = curr_state;
            end
            UDP_DATA_LEN        :begin//数据长度           
                if(udp_cnt_end)
                    next_state = UDP_DATA_CHECKSUM;
                else
                    next_state = curr_state;
            end
            UDP_DATA_CHECKSUM   :begin//校验和            
                if(udp_cnt_end)
                    next_state = UDP_DATA;
                else
                    next_state = curr_state;
            end
            UDP_DATA            :begin//udp数据          
                if(udp_cnt_end)
                    next_state = CRC_CHECK;
                else
                    next_state = curr_state;
            end
            CRC_CHECK           :begin//crc校验          
                if(udp_cnt_end)
                    next_state = IDLE;
                else
                    next_state = curr_state;
            end
            default:next_state = IDLE;
        endcase
    end
end
//---------------------------------计数器----------------------------
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

// always @(posedge clk) begin
    // if(!rst_n)
        // cnt_byte_data <= 0;
    // else if(curr_state == UDP_DATA ) begin 
        // if(cnt_byte == cnt_max || cnt_byte_data == 1)
            // cnt_byte_data <= 0;
        // else
            // cnt_byte_data <= cnt_byte_data + 1;
    // end
// end

always @(*) begin
    case(curr_state)
        IDLE                :cnt_max = 0;
        PREAMBLE            :cnt_max = 6;
        SFD                 :cnt_max = 0;   
        DES_MAC             :cnt_max = 5;   
        SOURCE_MAC          :cnt_max = 5;   
        LEN_TYPE            :cnt_max = 1;   
        UDP_VERSION_CHECKSUM:cnt_max = 0;   
        UDP_TOS             :cnt_max = 0;   
        UDP_TOTAL_LEN       :cnt_max = 1;   
        UDP_IDENTIFIER      :cnt_max = 1;   
        UDP_FLAG_OFFSET     :cnt_max = 1;   
        UDP_TTL             :cnt_max = 0;   
        UDP_PROTOCOL        :cnt_max = 0;
        UDP_HEAD_CHECKSUM   :cnt_max = 1;
        UDP_SOURCE_IP       :cnt_max = 3;
        UDP_DES_IP          :cnt_max = 3;
        UDP_SOURCE_PORT     :cnt_max = 1;
        UDP_DES_PORT        :cnt_max = 1;
        UDP_DATA_LEN        :cnt_max = 1;
        UDP_DATA_CHECKSUM   :cnt_max = 1;
        UDP_DATA            :cnt_max = udp_tx_data_num - 1;
        CRC_CHECK           :cnt_max = 3;
        default:cnt_max = 0;
    endcase
end

assign udp_cnt_end = (cnt_byte == cnt_max && curr_state != IDLE) ? 1 : 0;
//---------------------------------传输数据----------------------------
always @(posedge clk) begin
    if(!rst_n)  
        udp_tx_data <= 0;
    else begin
        case(curr_state)
            IDLE                :udp_tx_data <= 8'h0;
            PREAMBLE            :udp_tx_data <= 8'h55;
            SFD                 :udp_tx_data <= 8'hd5;
            DES_MAC             :begin
                case(cnt_byte)
                    0 : udp_tx_data <= des_mac[47:40];
                    1 : udp_tx_data <= des_mac[39:32];
                    2 : udp_tx_data <= des_mac[31:24];
                    3 : udp_tx_data <= des_mac[23:16];
                    4 : udp_tx_data <= des_mac[15:8] ;
                    5 : udp_tx_data <= des_mac[7:0]  ;
                    default:udp_tx_data <= des_mac[47:40];
                endcase
            end
            SOURCE_MAC          :begin
                case(cnt_byte)
                    0 : udp_tx_data <= fpga_mac[47:40];
                    1 : udp_tx_data <= fpga_mac[39:32];
                    2 : udp_tx_data <= fpga_mac[31:24];
                    3 : udp_tx_data <= fpga_mac[23:16];
                    4 : udp_tx_data <= fpga_mac[15:8] ;
                    5 : udp_tx_data <= fpga_mac[7:0]  ;
                    default:udp_tx_data <= fpga_mac[47:40];
                endcase
            end
            LEN_TYPE            :begin
                case(cnt_byte)
                    0 : udp_tx_data <= 8'h08;
                    1 : udp_tx_data <= 8'h00;
                    default:udp_tx_data <= 8'h0;
                endcase
            end
            UDP_VERSION_CHECKSUM:udp_tx_data <= 8'h45;
            UDP_TOS             :udp_tx_data <= 8'h00;
            UDP_TOTAL_LEN       :begin
                case(cnt_byte)
                    0 : udp_tx_data <= ip_len[15:8];
                    1 : udp_tx_data <= ip_len[7:0];
                    default:udp_tx_data <= 8'h0;
                endcase
            end
            UDP_IDENTIFIER      :begin
                case(cnt_byte)
                    0:udp_tx_data <= udp_id[15:8];
                    1:udp_tx_data <= udp_id[7:0]; 
                    default:udp_tx_data <= 8'h0;
                endcase
            end
            UDP_FLAG_OFFSET     :begin
                case(cnt_byte)
                    0 : udp_tx_data <= 8'h40;
                    1 : udp_tx_data <= 8'h00;
                    default:udp_tx_data <= 8'h0;
                endcase
            end
            UDP_TTL             :udp_tx_data <= 8'h40;
            UDP_PROTOCOL        :udp_tx_data <= 8'h11;
            UDP_HEAD_CHECKSUM   :begin
                case(cnt_byte)
                    0 : udp_tx_data <= head_checksum[15:8];
                    1 : udp_tx_data <= head_checksum[7:0];
                    default:udp_tx_data <= 8'h0;
                endcase
            end
            UDP_SOURCE_IP       :begin
                case(cnt_byte)
                    0 : udp_tx_data <= fpga_ip[31:24];
                    1 : udp_tx_data <= fpga_ip[23:16];
                    2 : udp_tx_data <= fpga_ip[15:8] ;
                    3 : udp_tx_data <= fpga_ip[7:0]  ;
                    default:udp_tx_data <= 8'h0;
                endcase
            end
            UDP_DES_IP          :begin
                case(cnt_byte)
                    0 : udp_tx_data <= des_ip[31:24];
                    1 : udp_tx_data <= des_ip[23:16];
                    2 : udp_tx_data <= des_ip[15:8] ;
                    3 : udp_tx_data <= des_ip[7:0]  ;
                    default:udp_tx_data <= 8'h0;
                endcase
            end
            UDP_SOURCE_PORT     :begin
                case(cnt_byte)
                    0 : udp_tx_data <= source_port[15:8];
                    1 : udp_tx_data <= source_port[7:0] ;
                    default:udp_tx_data <= 8'd0;
                endcase
            end
            UDP_DES_PORT        :begin
                case(cnt_byte)
                    0 : udp_tx_data <= des_port[15:8];
                    1 : udp_tx_data <= des_port[7:0] ;
                    default:udp_tx_data <= 8'd0;
                endcase
            end
            UDP_DATA_LEN        :begin
                case(cnt_byte)
                    0 : udp_tx_data <= udp_len[15:8];
                    1 : udp_tx_data <= udp_len[7:0] ;
                    default:udp_tx_data <= 8'h0;
                endcase
            end
            UDP_DATA_CHECKSUM   :udp_tx_data <= 8'h00;
			UDP_DATA            :udp_tx_data <= udp_odata;
            // UDP_DATA            :begin
                // case(cnt_byte_data)
                    // 0 : udp_tx_data <= udp_odata[15:8];
                    // 1 : udp_tx_data <= udp_odata[7:0] ;
                    // default:udp_tx_data <= 8'h0;
                // endcase
            // end
            CRC_CHECK           :begin
                case(cnt_byte)
                    0 : udp_tx_data <= crc_data[7:0]  ;
                    1 : udp_tx_data <= crc_data[15:8] ;
                    2 : udp_tx_data <= crc_data[23:16];
                    3 : udp_tx_data <= crc_data[31:24];
                    default:udp_tx_data <= 8'h0;
                endcase
            end
            default:udp_tx_data <= 8'h0;
        endcase
    end
end
//---------------------------------udp数据包有效信号---------------------------
always @(posedge clk) begin
    if(!rst_n)
        udp_tx_valid <= 0;
    else if(curr_state == IDLE)
        udp_tx_valid <= 0;
    else
        udp_tx_valid <= 1;
end
//---------------------------------udp数据有效信号---------------------------
assign udp_data_valid = (curr_state == UDP_DATA || (curr_state == UDP_DATA_CHECKSUM && cnt_byte == 1)) ? 1 : 0;
//---------------------------------udp数据请求信号---------------------------
// assign udp_data_req = (curr_state == UDP_DATA) ? 1 : 0;
//---------------------------------udp结束信号---------------------------
assign udp_tx_done = (curr_state == CRC_CHECK && cnt_byte == cnt_max) ? 1 : 0;
//---------------------------------crc开始信号----------------------------
assign crc_en = (curr_state == IDLE || curr_state == PREAMBLE || curr_state == SFD || curr_state == CRC_CHECK) ? 0 : 1;
//---------------------------------crc结束信号----------------------------
assign crc_done = (curr_state == IDLE) ? 1 : 0;

endmodule