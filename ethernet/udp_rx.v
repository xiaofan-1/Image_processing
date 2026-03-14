`timescale 1ns / 1ps
/*
1、前导码，         7byt，8'h55
2、sfd帧起始界定符，1byt，8'hd5
3、目的mac，        6byt，8'hff
4、源mac，          6byt，{8'h11,8'h22,8'h33,8'h44,8'h55,8'h66}
5、长度/类型，      2byt，arp：0x0806，ip：0x0800
----------udp协议---------
6、版本+IP首部长度，1byt，IPV4，固定为4；
                          IPV4首部长度为20byte，但是这里是以4byte作为一个单位，该值为5。
7、区分服务，       1byt，自设，8'h05---一般是不使用
8、总长度，         2byt，ip首部+udp长度+数据长度：20+8+20
9、标识，           2byt，计数器，初始值可随机
10、标志+片偏移，   2byt，最高位无效为0，只有低两位有效；第二位表示是否分片，1表示不能分片，0 表示可以分片；最低位表示是否是最后一个分片数据。
                          16'h4000
11、生存时间，      1byt，大于1即可，8'h40
12、协议类型，      1byt，TCP协议：8'd6；UDP协议：8'd17，8'h11;ICMP协议：8'd2
13、首部校验和，    2byt，计算得出
14、源ip地址，      4byt，{8'hc0,8'ha8,8'h0,8'h02},192.168.0.2---pc
15、目的ip地址，    4byt，{8'hc0,8'ha8,8'h0,8'h08},192.168.0.8---fpga
------udp数据
16、源端口，        2byt，{8'h11,8'h22}
17、目的端口，      2byt，{8'h33,8'h44}
18、udp数据长度，   2byt，udp长度+数据长度：20+8
19、udp校验和，     2byt，0
20、udp数据发送，   至少18byt，最多1472byt
------------crc校验------------
21、crc校验         4byt
*/
module udp_rx #(
	parameter	fpga_mac = 48'h11_22_33_44_55_66,//源mac
	parameter	fpga_ip  = 32'hc0_a8_00_08		 //源ip--192.168.0.8
)(
    input   wire            clk             ,
    input   wire            rst_n           ,
    input   wire            udp_rx_valid    ,
    input   wire    [7:0]   udp_rx_data     ,
    output  reg     [7:0]   udp_idata       ,//udp接收的数据
    output  reg             udp_rx_en       ,
    output  wire            udp_rx_done     
    );
    

            
localparam
    IDLE                 = 5'd1  ,
    PREAMBLE             = 5'd2  ,//前导码
    SFD                  = 5'd3  ,//帧起始界定符
    DES_MAC              = 5'd4  ,//目的mac地址--fpga
    SOURCE_MAC           = 5'd5  ,//源mac地址--pc
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

reg             error;//错误信号
reg     [15:0]  protocol_type;//协议类型
reg     [47:0]  des_mac;
reg     [31:0]  des_ip;

reg     [15:0]  total_len;//总长度 

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
                if(udp_rx_valid && udp_rx_data == 8'h55)
                    next_state = PREAMBLE;
                else
                    next_state = IDLE;
            end
            PREAMBLE            :begin//前导码   
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = SFD;
                else
                    next_state = PREAMBLE;
            end
            SFD                 :begin//帧起始界定符        
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = DES_MAC;
                else
                    next_state = SFD;
            end 
            DES_MAC             :begin//目的mac地址--pc    
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = SOURCE_MAC;
                else
                    next_state = curr_state;
            end
            SOURCE_MAC          :begin//源mac地址--fpga   
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = LEN_TYPE;
                else
                    next_state = SOURCE_MAC;
            end
            LEN_TYPE            :begin//长度/类型          
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = UDP_VERSION_CHECKSUM;
                else
                    next_state = LEN_TYPE;
            end
            UDP_VERSION_CHECKSUM:begin//版本+IP首部长度      
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = UDP_TOS;
                else
                    next_state = UDP_VERSION_CHECKSUM;
            end
            UDP_TOS             :begin//区分服务           
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = UDP_TOTAL_LEN;
                else
                    next_state = UDP_TOS;
            end
            UDP_TOTAL_LEN       :begin//总长度            
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = UDP_IDENTIFIER;
                else
                    next_state = UDP_TOTAL_LEN;
            end
            UDP_IDENTIFIER      :begin//标识             
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = UDP_FLAG_OFFSET;
                else
                    next_state = UDP_IDENTIFIER;
            end
            UDP_FLAG_OFFSET     :begin//标志+片偏移         
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = UDP_TTL;
                else
                    next_state = UDP_FLAG_OFFSET;
            end
            UDP_TTL             :begin//生存时间           
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = UDP_PROTOCOL;
                else
                    next_state = UDP_TTL;
            end
            UDP_PROTOCOL        :begin//协议类型           
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = UDP_HEAD_CHECKSUM;
                else
                    next_state = UDP_PROTOCOL;
            end
            UDP_HEAD_CHECKSUM   :begin//首部校验和          
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = UDP_SOURCE_IP;
                else
                    next_state = UDP_HEAD_CHECKSUM;
            end
            UDP_SOURCE_IP       :begin//源ip            
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = UDP_DES_IP;
                else
                    next_state = UDP_SOURCE_IP;
            end
            UDP_DES_IP          :begin//目的ip           
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = UDP_SOURCE_PORT;
                else
                    next_state = UDP_DES_IP;
            end
            UDP_SOURCE_PORT     :begin//源端口            
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = UDP_DES_PORT;
                else
                    next_state = UDP_SOURCE_PORT;
            end
            UDP_DES_PORT        :begin//目的端口           
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = UDP_DATA_LEN;
                else
                    next_state = UDP_DES_PORT;
            end
            UDP_DATA_LEN        :begin//数据长度           
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = UDP_DATA_CHECKSUM;
                else
                    next_state = UDP_DATA_LEN;
            end
            UDP_DATA_CHECKSUM   :begin//校验和            
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = UDP_DATA;
                else
                    next_state = UDP_DATA_CHECKSUM;
            end
            UDP_DATA            :begin//udp数据          
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = CRC_CHECK;
                else
                    next_state = UDP_DATA;
            end
            CRC_CHECK           :begin//crc校验          
                if(error)
                    next_state = IDLE;
                else if(udp_cnt_end)
                    next_state = IDLE;
                else
                    next_state = CRC_CHECK;
            end
            default:next_state = IDLE;
        endcase
    end
end
//---------------------------------计数器----------------------------
always @(posedge clk) begin
    if(!rst_n)
        cnt_byte <= 0;
    else if(cnt_byte == cnt_max || curr_state == IDLE)
        cnt_byte <= 0;
    else
        cnt_byte <= cnt_byte + 1;
end

always @(*) begin
    case(curr_state)
        IDLE                :cnt_max = 0;
        PREAMBLE            :cnt_max = 5;
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
        UDP_DATA            :cnt_max = total_len - 16'd28 - 16'd1;
        CRC_CHECK           :cnt_max = 3;
        default:cnt_max = 0;
    endcase
end

assign udp_cnt_end = (cnt_byte == cnt_max && curr_state != IDLE) ? 1 : 0;

//---------------------------------错误信息----------------------------
always @(posedge clk) begin
    if(!rst_n)
        error <= 0;
    else begin
        case(curr_state)
            IDLE                :error <= 0;
            PREAMBLE            :begin//前导码
                if(cnt_byte < cnt_max && udp_rx_data != 8'h55)
                    error <= 1;
                else
                    error <= 0;
            end           
            SFD                 :begin//帧起始界定符     
                if(cnt_byte == cnt_max && udp_rx_data != 8'hd5)
                    error <= 1;
                else
                    error <= 0;
            end              
            DES_MAC             :error <= 0;//目的mac地址--fpga
            SOURCE_MAC          :begin//源mac地址--pc    
                if(cnt_byte == 0 && des_mac != fpga_mac)
                    error <= 1;
                else
                    error <= 0;
            end              
            LEN_TYPE            :begin//长度/类型
                if((cnt_byte == 0 && udp_rx_data != 8'h08) || (cnt_byte == 1 && udp_rx_data != 8'h00))
                    error <= 1;
                else
                    error <= 0;
            end      
            UDP_VERSION_CHECKSUM:begin//版本+IP首部长度          
                if(cnt_byte == cnt_max && udp_rx_data != 8'h45)
                    error <= 1;
                else
                    error <= 0;
            end              
            UDP_TOS             :error <= 0;//区分服务          
            UDP_TOTAL_LEN       :begin//总长度    
                error <= 0;
                case(cnt_byte)
                    0:total_len[15:8] <= udp_rx_data;
                    1:total_len[7:0]  <= udp_rx_data;
                    default:total_len <= 0;
                endcase
            end          
            UDP_IDENTIFIER      :error <= 0;//标识            
            UDP_FLAG_OFFSET     :error <= 0;//标志+片偏移        
            UDP_TTL             :error <= 0;//生存时间          
            UDP_PROTOCOL        :begin//协议类型                    
                if(cnt_byte == cnt_max && udp_rx_data != 8'h11)
                    error <= 1;
                else
                    error <= 0;
            end              
            UDP_HEAD_CHECKSUM   :error <= 0;//首部校验和         
            UDP_SOURCE_IP       :error <= 0;//源ip           
            UDP_DES_IP          :error <= 0;//目的ip 
            UDP_SOURCE_PORT     :error <= 0;//begin;//源端口                           
//                if(cnt_byte == 0 && des_ip != fpga_ip)
//                    error <= 1;
//                else
//                    error <= 0;
//            end                        
            UDP_DES_PORT        :error <= 0;//目的端口          
            UDP_DATA_LEN        :error <= 0;//数据长度          
            UDP_DATA_CHECKSUM   :error <= 0;//校验和           
            UDP_DATA            :error <= 0;//udp数据         
            CRC_CHECK           :error <= 0;//crc校验         
            default:error <= 0;
        endcase
    end 
end
//---------------------------------协议类型----------------------------
always @(posedge clk) begin
    if(!rst_n)
        protocol_type <= 0;
    else if(curr_state == UDP_PROTOCOL)
        protocol_type <= {protocol_type[7:0], udp_rx_data};
    else
        protocol_type <= protocol_type;
end
//---------------------------------目的地址----------------------------
always @(posedge clk) begin
    if(!rst_n)
        des_mac <= 0;
    else if(curr_state == DES_MAC)
        des_mac <= {des_mac[39:0], udp_rx_data};
    else
        des_mac <= des_mac;
end

always @(posedge clk) begin
    if(!rst_n)
        des_ip <= 0;
    else if(curr_state == UDP_DES_IP)
        des_ip <= {des_ip[23:0], udp_rx_data};
    else
        des_ip <= des_ip;
end
//---------------------------------接收结束----------------------------
assign udp_rx_done = (curr_state == CRC_CHECK && cnt_byte == cnt_max) ? 1 : 0;
//---------------------------------udp接收数据----------------------------
always @(posedge clk) begin
    if(!rst_n)
        udp_idata <= 0;
    else if(curr_state == UDP_DATA)
        udp_idata <= udp_rx_data;
    else
        udp_idata <= udp_idata;
end
//---------------------------------udp数据有效信号----------------------------
always @(posedge clk) begin
   if(!rst_n)
       udp_rx_en <= 0;
   else if(curr_state == UDP_DATA)
       udp_rx_en <= 1;
   else
       udp_rx_en <= 0;
end

// assign udp_rx_en = (curr_state == UDP_DATA) ? 1 : 0;

endmodule
