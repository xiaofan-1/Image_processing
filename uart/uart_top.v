`timescale 1ns / 1ps

module uart_top(
    //input ports
    input   wire            clk              ,
    input   wire            rst_n            ,
         
    input   wire            uart_rx          ,
    output  wire            uart_tx          ,
    input   wire    [3:0]   target_num       ,
    
    // --- 新增：外部传来的初始化信号 ---
    input   wire            ddr3_init_done   ,
    input   wire            cam_init_done0   ,
    input   wire            cam_init_done1   ,
    input   wire            cam_init_done2   ,
    input   wire            hdmi_init_done   ,
    input   wire            eth_init_done    ,

    // --- 保留你原有的所有输出端口 ---
    output  reg     [7:0]   diff_value       ,
    output  reg     [11:0]  cur_frame_top    ,
    output  reg     [11:0]  cur_frame_bottom ,
    output  reg     [11:0]  cur_frame_left   ,
    output  reg     [11:0]  cur_frame_right  ,
    output  reg     [11:0]  cur_color_top    ,
    output  reg     [11:0]  cur_color_bottom ,
    output  reg     [11:0]  cur_color_left   ,
    output  reg     [11:0]  cur_color_right  ,
    output  reg     [11:0]  min_dist         
);

parameter BPS_NUM = 16'd645; // 115200 at 27MHz

//===========================================================================
// 1. 跨时钟域 (CDC) 同步阵列："打两拍"消除亚稳态
//===========================================================================
reg ddr3_sync1;
reg ddr3_sync2;
reg cam0_sync1;
reg cam0_sync2;
reg cam1_sync1;
reg cam1_sync2;
reg cam2_sync1;
reg cam2_sync2;
reg hdmi_sync1;
reg hdmi_sync2;
reg eth_sync1;
reg eth_sync2;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        ddr3_sync1 <= 0; ddr3_sync2 <= 0;
        cam0_sync1 <= 0; cam0_sync2 <= 0;
        cam1_sync1 <= 0; cam1_sync2 <= 0;
        cam2_sync1 <= 0; cam2_sync2 <= 0;
        hdmi_sync1 <= 0; hdmi_sync2 <= 0;
        eth_sync1  <= 0; eth_sync2  <= 0;
    end else begin
        ddr3_sync1 <= ddr3_init_done; ddr3_sync2 <= ddr3_sync1;
        cam0_sync1 <= cam_init_done0; cam0_sync2 <= cam0_sync1;
        cam1_sync1 <= cam_init_done1; cam1_sync2 <= cam1_sync1;
        cam2_sync1 <= cam_init_done2; cam2_sync2 <= cam2_sync1;
        hdmi_sync1 <= hdmi_init_done; hdmi_sync2 <= hdmi_sync1;
        eth_sync1  <= eth_init_done;  eth_sync2  <= eth_sync1;
    end
end

wire ddr3_ready;
wire cam0_ready;
wire cam1_ready;
wire cam2_ready;
wire hdmi_ready;
wire eth_ready ;

assign ddr3_ready = ddr3_sync2;
assign cam0_ready = cam0_sync2;
assign cam1_ready = cam1_sync2;
assign cam2_ready = cam2_sync2;
assign hdmi_ready = hdmi_sync2;
assign eth_ready  = eth_sync2 ;

//===========================================================================
// 2. 底层 UART 物理层收发
//===========================================================================
wire       rx_done;
wire [7:0] rx_data;
wire       tx_busy;
reg        engine_tx_en;
reg  [7:0] engine_tx_data;

uart_rx #(.BPS_NUM(BPS_NUM)) u_uart_rx (
    .clk          (clk),
    .rst_n        (rst_n),
    .uart_rx      (uart_rx),
    .rx_data      (rx_data),
    .rx_finish    (rx_done)
);

uart_tx #(.BPS_NUM(BPS_NUM)) u_uart_tx (
    .clk          (clk),
    .rst_n        (rst_n),
    .tx_data      (engine_tx_data),
    .tx_pluse     (engine_tx_en),
    .uart_tx      (uart_tx),
    .tx_busy      (tx_busy)
);

// 边缘检测器！将长达波特率周期的 rx_done 转换为只有 1 个周期的超短脉冲
reg rx_done_d1;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) rx_done_d1 <= 1'b0;
    else rx_done_d1 <= rx_done;
end
wire rx_done_pulse = rx_done && !rx_done_d1;


//===========================================================================
// 🌟 终极多目标防抖：峰值包络保持滤波器 (Peak Hold Envelope Filter) 🌟
//===========================================================================
reg [3:0]  smooth_target_num;
reg [23:0] target_hold_cnt;
parameter HOLD_TIME_MAX = 24'd13_500_000; // 0.5秒 @ 27MHz 时钟

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        smooth_target_num <= 4'd0;
        target_hold_cnt   <= 24'd0;
    end else begin
        // 核心：只要底层读到的数字 大于等于 当前平滑输出的数字
        if (target_num >= smooth_target_num) begin
            smooth_target_num <= target_num;
            target_hold_cnt   <= 24'd0;
        end 
        else begin
            // 目标数量变少了 (比如从 3 瞬间掉到 2 或 1)
            // 开启耐心等待计时！
            if (target_hold_cnt < HOLD_TIME_MAX) begin
                target_hold_cnt <= target_hold_cnt + 1'b1;
            end else begin
                // 如果超过了 0.5秒 还没跳回 3，才无奈承认它真的少了一个目标
                smooth_target_num <= target_num;
                target_hold_cnt   <= 24'd0;
            end
        end
    end
end

//===========================================================================
// 3. 词典库 (String ROM) 
//===========================================================================
reg  [31:0] input_ascii_reg; 

reg  [9:0] rom_addr;
reg  [7:0] rom_data;

reg [3:0]  last_target_num;

// 使用平滑锁定后的数值进行转换打印
wire [7:0] target_tens = 8'h30 + (last_target_num / 10);
wire [7:0] target_ones = 8'h30 + (last_target_num % 10);

always @(*) begin
    case(rom_addr)
        // 00-21: ====================\r\n
        10'd0:rom_data="="; 10'd1:rom_data="="; 10'd2:rom_data="="; 10'd3:rom_data="="; 10'd4:rom_data="=";
        10'd5:rom_data="="; 10'd6:rom_data="="; 10'd7:rom_data="="; 10'd8:rom_data="="; 10'd9:rom_data="=";
        10'd10:rom_data="="; 10'd11:rom_data="="; 10'd12:rom_data="="; 10'd13:rom_data="="; 10'd14:rom_data="=";
        10'd15:rom_data="="; 10'd16:rom_data="="; 10'd17:rom_data="="; 10'd18:rom_data="="; 10'd19:rom_data="=";
        10'd20:rom_data=8'h0D; 10'd21:rom_data=8'h0A;

        // 22-43: "  FPGA Vision CLI   \r\n" 
        10'd22:rom_data=" "; 10'd23:rom_data=" "; 10'd24:rom_data="F"; 10'd25:rom_data="P"; 10'd26:rom_data="G";
        10'd27:rom_data="A"; 10'd28:rom_data=" "; 10'd29:rom_data="V"; 10'd30:rom_data="i"; 10'd31:rom_data="s";
        10'd32:rom_data="i"; 10'd33:rom_data="o"; 10'd34:rom_data="n"; 10'd35:rom_data=" "; 10'd36:rom_data="C";
        10'd37:rom_data="L"; 10'd38:rom_data="I"; 10'd39:rom_data=" "; 10'd40:rom_data=" "; 10'd41:rom_data=" ";
        10'd42:rom_data=8'h0D; 10'd43:rom_data=8'h0A;

        // 44-65: ====================\r\n
        10'd44:rom_data="="; 10'd45:rom_data="="; 10'd46:rom_data="="; 10'd47:rom_data="="; 10'd48:rom_data="=";
        10'd49:rom_data="="; 10'd50:rom_data="="; 10'd51:rom_data="="; 10'd52:rom_data="="; 10'd53:rom_data="=";
        10'd54:rom_data="="; 10'd55:rom_data="="; 10'd56:rom_data="="; 10'd57:rom_data="="; 10'd58:rom_data="=";
        10'd59:rom_data="="; 10'd60:rom_data="="; 10'd61:rom_data="="; 10'd62:rom_data="="; 10'd63:rom_data="=";
        10'd64:rom_data=8'h0D; 10'd65:rom_data=8'h0A;

        // 70-98: DDR3 Init Completed...\r\n 
        10'd70:rom_data="["; 10'd71:rom_data="O"; 10'd72:rom_data="K"; 10'd73:rom_data="]"; 10'd74:rom_data=" "; 10'd75:rom_data="D"; 10'd76:rom_data="D"; 10'd77:rom_data="R"; 10'd78:rom_data="3"; 10'd79:rom_data=" "; 10'd80:rom_data="I"; 10'd81:rom_data="n"; 10'd82:rom_data="i"; 10'd83:rom_data="t"; 10'd84:rom_data=" "; 10'd85:rom_data="C"; 10'd86:rom_data="o"; 10'd87:rom_data="m"; 10'd88:rom_data="p"; 10'd89:rom_data="l"; 10'd90:rom_data="e"; 10'd91:rom_data="t"; 10'd92:rom_data="e"; 10'd93:rom_data="d"; 10'd94:rom_data="."; 10'd95:rom_data="."; 10'd96:rom_data="."; 10'd97:rom_data=8'h0D; 10'd98:rom_data=8'h0A;

        // 100-128: Cam0
        10'd100:rom_data="["; 10'd101:rom_data="O"; 10'd102:rom_data="K"; 10'd103:rom_data="]"; 10'd104:rom_data=" "; 10'd105:rom_data="C"; 10'd106:rom_data="a"; 10'd107:rom_data="m"; 10'd108:rom_data="0"; 10'd109:rom_data=" "; 10'd110:rom_data="I"; 10'd111:rom_data="n"; 10'd112:rom_data="i"; 10'd113:rom_data="t"; 10'd114:rom_data=" "; 10'd115:rom_data="C"; 10'd116:rom_data="o"; 10'd117:rom_data="m"; 10'd118:rom_data="p"; 10'd119:rom_data="l"; 10'd120:rom_data="e"; 10'd121:rom_data="t"; 10'd122:rom_data="e"; 10'd123:rom_data="d"; 10'd124:rom_data="."; 10'd125:rom_data="."; 10'd126:rom_data="."; 10'd127:rom_data=8'h0D; 10'd128:rom_data=8'h0A;

        // 130-158: Cam1
        10'd130:rom_data="["; 10'd131:rom_data="O"; 10'd132:rom_data="K"; 10'd133:rom_data="]"; 10'd134:rom_data=" "; 10'd135:rom_data="C"; 10'd136:rom_data="a"; 10'd137:rom_data="m"; 10'd138:rom_data="1"; 10'd139:rom_data=" "; 10'd140:rom_data="I"; 10'd141:rom_data="n"; 10'd142:rom_data="i"; 10'd143:rom_data="t"; 10'd144:rom_data=" "; 10'd145:rom_data="C"; 10'd146:rom_data="o"; 10'd147:rom_data="m"; 10'd148:rom_data="p"; 10'd149:rom_data="l"; 10'd150:rom_data="e"; 10'd151:rom_data="t"; 10'd152:rom_data="e"; 10'd153:rom_data="d"; 10'd154:rom_data="."; 10'd155:rom_data="."; 10'd156:rom_data="."; 10'd157:rom_data=8'h0D; 10'd158:rom_data=8'h0A;

        // 160-188: Cam2
        10'd160:rom_data="["; 10'd161:rom_data="O"; 10'd162:rom_data="K"; 10'd163:rom_data="]"; 10'd164:rom_data=" "; 10'd165:rom_data="C"; 10'd166:rom_data="a"; 10'd167:rom_data="m"; 10'd168:rom_data="2"; 10'd169:rom_data=" "; 10'd170:rom_data="I"; 10'd171:rom_data="n"; 10'd172:rom_data="i"; 10'd173:rom_data="t"; 10'd174:rom_data=" "; 10'd175:rom_data="C"; 10'd176:rom_data="o"; 10'd177:rom_data="m"; 10'd178:rom_data="p"; 10'd179:rom_data="l"; 10'd180:rom_data="e"; 10'd181:rom_data="t"; 10'd182:rom_data="e"; 10'd183:rom_data="d"; 10'd184:rom_data="."; 10'd185:rom_data="."; 10'd186:rom_data="."; 10'd187:rom_data=8'h0D; 10'd188:rom_data=8'h0A;

        // 190-218: HDMI
        10'd190:rom_data="["; 10'd191:rom_data="O"; 10'd192:rom_data="K"; 10'd193:rom_data="]"; 10'd194:rom_data=" "; 10'd195:rom_data="H"; 10'd196:rom_data="D"; 10'd197:rom_data="M"; 10'd198:rom_data="I"; 10'd199:rom_data=" "; 10'd200:rom_data="I"; 10'd201:rom_data="n"; 10'd202:rom_data="i"; 10'd203:rom_data="t"; 10'd204:rom_data=" "; 10'd205:rom_data="C"; 10'd206:rom_data="o"; 10'd207:rom_data="m"; 10'd208:rom_data="p"; 10'd209:rom_data="l"; 10'd210:rom_data="e"; 10'd211:rom_data="t"; 10'd212:rom_data="e"; 10'd213:rom_data="d"; 10'd214:rom_data="."; 10'd215:rom_data="."; 10'd216:rom_data="."; 10'd217:rom_data=8'h0D; 10'd218:rom_data=8'h0A;

        // 220-247: ETH
        10'd220:rom_data="["; 10'd221:rom_data="O"; 10'd222:rom_data="K"; 10'd223:rom_data="]"; 10'd224:rom_data=" "; 10'd225:rom_data="E"; 10'd226:rom_data="T"; 10'd227:rom_data="H"; 10'd228:rom_data=" "; 10'd229:rom_data="I"; 10'd230:rom_data="n"; 10'd231:rom_data="i"; 10'd232:rom_data="t"; 10'd233:rom_data=" "; 10'd234:rom_data="C"; 10'd235:rom_data="o"; 10'd236:rom_data="m"; 10'd237:rom_data="p"; 10'd238:rom_data="l"; 10'd239:rom_data="e"; 10'd240:rom_data="t"; 10'd241:rom_data="e"; 10'd242:rom_data="d"; 10'd243:rom_data="."; 10'd244:rom_data="."; 10'd245:rom_data="."; 10'd246:rom_data=8'h0D; 10'd247:rom_data=8'h0A;

        // 250-269: Please enter value: 
        10'd250:rom_data="P"; 10'd251:rom_data="l"; 10'd252:rom_data="e"; 10'd253:rom_data="a"; 10'd254:rom_data="s"; 10'd255:rom_data="e"; 10'd256:rom_data=" "; 10'd257:rom_data="e"; 10'd258:rom_data="n"; 10'd259:rom_data="t"; 10'd260:rom_data="e"; 10'd261:rom_data="r"; 10'd262:rom_data=" "; 10'd263:rom_data="v"; 10'd264:rom_data="a"; 10'd265:rom_data="l"; 10'd266:rom_data="u"; 10'd267:rom_data="e"; 10'd268:rom_data=":"; 10'd269:rom_data=" ";

        // 280-314: [Error] Invalid Value or Command!\r\n
        10'd280:rom_data="["; 10'd281:rom_data="E"; 10'd282:rom_data="r"; 10'd283:rom_data="r"; 10'd284:rom_data="o"; 10'd285:rom_data="r"; 10'd286:rom_data="]"; 10'd287:rom_data=" "; 10'd288:rom_data="I"; 10'd289:rom_data="n"; 10'd290:rom_data="v"; 10'd291:rom_data="a"; 10'd292:rom_data="l"; 10'd293:rom_data="i"; 10'd294:rom_data="d"; 10'd295:rom_data=" "; 10'd296:rom_data="V"; 10'd297:rom_data="a"; 10'd298:rom_data="l"; 10'd299:rom_data="u"; 10'd300:rom_data="e"; 10'd301:rom_data=" "; 10'd302:rom_data="o"; 10'd303:rom_data="r"; 10'd304:rom_data=" "; 10'd305:rom_data="C"; 10'd306:rom_data="o"; 10'd307:rom_data="m"; 10'd308:rom_data="m"; 10'd309:rom_data="a"; 10'd310:rom_data="n"; 10'd311:rom_data="d"; 10'd312:rom_data="!"; 10'd313:rom_data=8'h0D; 10'd314:rom_data=8'h0A;

        // 320-352: [Success] Threshold Set to xxxx\r\n
        10'd320:rom_data="["; 10'd321:rom_data="S"; 10'd322:rom_data="u"; 10'd323:rom_data="c"; 10'd324:rom_data="c"; 10'd325:rom_data="e"; 10'd326:rom_data="s"; 10'd327:rom_data="s"; 10'd328:rom_data="]"; 10'd329:rom_data=" "; 10'd330:rom_data="T"; 10'd331:rom_data="h"; 10'd332:rom_data="r"; 10'd333:rom_data="e"; 10'd334:rom_data="s"; 10'd335:rom_data="h"; 10'd336:rom_data="o"; 10'd337:rom_data="l"; 10'd338:rom_data="d"; 10'd339:rom_data=" "; 10'd340:rom_data="S"; 10'd341:rom_data="e"; 10'd342:rom_data="t"; 10'd343:rom_data=" "; 10'd344:rom_data="t"; 10'd345:rom_data="o"; 10'd346:rom_data=" ";
        10'd347:rom_data=input_ascii_reg[31:24]; 
        10'd348:rom_data=input_ascii_reg[23:16]; 
        10'd349:rom_data=input_ascii_reg[15:8];  
        10'd350:rom_data=input_ascii_reg[7:0];   
        10'd351:rom_data=8'h0D; 10'd352:rom_data=8'h0A;

        // 360-384: [Success] Screen Area x\r\n
        10'd360:rom_data="["; 10'd361:rom_data="S"; 10'd362:rom_data="u"; 10'd363:rom_data="c"; 10'd364:rom_data="c"; 10'd365:rom_data="e"; 10'd366:rom_data="s"; 10'd367:rom_data="s"; 10'd368:rom_data="]"; 10'd369:rom_data=" "; 10'd370:rom_data="S"; 10'd371:rom_data="c"; 10'd372:rom_data="r"; 10'd373:rom_data="e"; 10'd374:rom_data="e"; 10'd375:rom_data="n"; 10'd376:rom_data=" "; 10'd377:rom_data="A"; 10'd378:rom_data="r"; 10'd379:rom_data="e"; 10'd380:rom_data="a"; 10'd381:rom_data=" ";
        10'd382:rom_data=input_ascii_reg[7:0];   
        10'd383:rom_data=8'h0D; 10'd384:rom_data=8'h0A;

        // 390-405: Target Num: XX\r\n
        10'd390:rom_data="T"; 10'd391:rom_data="a"; 10'd392:rom_data="r"; 10'd393:rom_data="g"; 10'd394:rom_data="e"; 10'd395:rom_data="t"; 10'd396:rom_data=" "; 10'd397:rom_data="N"; 10'd398:rom_data="u"; 10'd399:rom_data="m"; 10'd400:rom_data=":"; 10'd401:rom_data=" "; 
        10'd402:rom_data=target_tens; 
        10'd403:rom_data=target_ones; 
        10'd404:rom_data=8'h0D; 10'd405:rom_data=8'h0A;

        // 410-447: \r\n==================================\r\n (34个等号)
        10'd410:rom_data=8'h0D; 10'd411:rom_data=8'h0A;
        10'd412:rom_data="="; 10'd413:rom_data="="; 10'd414:rom_data="="; 10'd415:rom_data="="; 10'd416:rom_data="="; 10'd417:rom_data="="; 10'd418:rom_data="="; 10'd419:rom_data="=";
        10'd420:rom_data="="; 10'd421:rom_data="="; 10'd422:rom_data="="; 10'd423:rom_data="="; 10'd424:rom_data="="; 10'd425:rom_data="="; 10'd426:rom_data="="; 10'd427:rom_data="=";
        10'd428:rom_data="="; 10'd429:rom_data="="; 10'd430:rom_data="="; 10'd431:rom_data="="; 10'd432:rom_data="="; 10'd433:rom_data="="; 10'd434:rom_data="="; 10'd435:rom_data="=";
        10'd436:rom_data="="; 10'd437:rom_data="="; 10'd438:rom_data="="; 10'd439:rom_data="="; 10'd440:rom_data="="; 10'd441:rom_data="="; 10'd442:rom_data="="; 10'd443:rom_data="=";
        10'd444:rom_data="="; 10'd445:rom_data="="; 10'd446:rom_data=8'h0D; 10'd447:rom_data=8'h0A;

        // 448-483: || System Ready! Command List   ||\r\n
        10'd448:rom_data="|"; 10'd449:rom_data="|"; 10'd450:rom_data=" "; 10'd451:rom_data="S"; 10'd452:rom_data="y"; 10'd453:rom_data="s"; 10'd454:rom_data="t"; 10'd455:rom_data="e"; 10'd456:rom_data="m"; 10'd457:rom_data=" ";
        10'd458:rom_data="R"; 10'd459:rom_data="e"; 10'd460:rom_data="a"; 10'd461:rom_data="d"; 10'd462:rom_data="y"; 10'd463:rom_data="!"; 10'd464:rom_data=" "; 10'd465:rom_data="C"; 10'd466:rom_data="o"; 10'd467:rom_data="m";
        10'd468:rom_data="m"; 10'd469:rom_data="a"; 10'd470:rom_data="n"; 10'd471:rom_data="d"; 10'd472:rom_data=" "; 10'd473:rom_data="L"; 10'd474:rom_data="i"; 10'd475:rom_data="s"; 10'd476:rom_data="t"; 10'd477:rom_data=" ";
        10'd478:rom_data=" "; 10'd479:rom_data=" "; 10'd480:rom_data="|"; 10'd481:rom_data="|"; 10'd482:rom_data=8'h0D; 10'd483:rom_data=8'h0A;

        // 484-519: || FA01: Diff Thresh   (0~255)  ||\r\n
        10'd484:rom_data="|"; 10'd485:rom_data="|"; 10'd486:rom_data=" "; 10'd487:rom_data="F"; 10'd488:rom_data="A"; 10'd489:rom_data="0"; 10'd490:rom_data="1"; 10'd491:rom_data=":"; 10'd492:rom_data=" "; 10'd493:rom_data="D";
        10'd494:rom_data="i"; 10'd495:rom_data="f"; 10'd496:rom_data="f"; 10'd497:rom_data=" "; 10'd498:rom_data="T"; 10'd499:rom_data="h"; 10'd500:rom_data="r"; 10'd501:rom_data="e"; 10'd502:rom_data="s"; 10'd503:rom_data="h";
        10'd504:rom_data=" "; 10'd505:rom_data=" "; 10'd506:rom_data=" "; 10'd507:rom_data="("; 10'd508:rom_data="0"; 10'd509:rom_data="~"; 10'd510:rom_data="2"; 10'd511:rom_data="5"; 10'd512:rom_data="5"; 10'd513:rom_data=")";
        10'd514:rom_data=" "; 10'd515:rom_data=" "; 10'd516:rom_data="|"; 10'd517:rom_data="|"; 10'd518:rom_data=8'h0D; 10'd519:rom_data=8'h0A;

        // 520-555: || FA02: Min Dist      (0~1280) ||\r\n
        10'd520:rom_data="|"; 10'd521:rom_data="|"; 10'd522:rom_data=" "; 10'd523:rom_data="F"; 10'd524:rom_data="A"; 10'd525:rom_data="0"; 10'd526:rom_data="2"; 10'd527:rom_data=":"; 10'd528:rom_data=" "; 10'd529:rom_data="M";
        10'd530:rom_data="i"; 10'd531:rom_data="n"; 10'd532:rom_data=" "; 10'd533:rom_data="D"; 10'd534:rom_data="i"; 10'd535:rom_data="s"; 10'd536:rom_data="t"; 10'd537:rom_data=" "; 10'd538:rom_data=" "; 10'd539:rom_data=" ";
        10'd540:rom_data=" "; 10'd541:rom_data=" "; 10'd542:rom_data=" "; 10'd543:rom_data="("; 10'd544:rom_data="0"; 10'd545:rom_data="~"; 10'd546:rom_data="1"; 10'd547:rom_data="2"; 10'd548:rom_data="8"; 10'd549:rom_data="0";
        10'd550:rom_data=")"; 10'd551:rom_data=" "; 10'd552:rom_data="|"; 10'd553:rom_data="|"; 10'd554:rom_data=8'h0D; 10'd555:rom_data=8'h0A;

        // 556-591: || FA03: Move Area     (0~5)    ||\r\n
        10'd556:rom_data="|"; 10'd557:rom_data="|"; 10'd558:rom_data=" "; 10'd559:rom_data="F"; 10'd560:rom_data="A"; 10'd561:rom_data="0"; 10'd562:rom_data="3"; 10'd563:rom_data=":"; 10'd564:rom_data=" "; 10'd565:rom_data="M";
        10'd566:rom_data="o"; 10'd567:rom_data="v"; 10'd568:rom_data="e"; 10'd569:rom_data=" "; 10'd570:rom_data="A"; 10'd571:rom_data="r"; 10'd572:rom_data="e"; 10'd573:rom_data="a"; 10'd574:rom_data=" "; 10'd575:rom_data=" ";
        10'd576:rom_data=" "; 10'd577:rom_data=" "; 10'd578:rom_data=" "; 10'd579:rom_data="("; 10'd580:rom_data="0"; 10'd581:rom_data="~"; 10'd582:rom_data="5"; 10'd583:rom_data=")"; 10'd584:rom_data=" "; 10'd585:rom_data=" ";
        10'd586:rom_data=" "; 10'd587:rom_data=" "; 10'd588:rom_data="|"; 10'd589:rom_data="|"; 10'd590:rom_data=8'h0D; 10'd591:rom_data=8'h0A;

        // 592-627: || FA04: Color Area    (0~4)    ||\r\n
        10'd592:rom_data="|"; 10'd593:rom_data="|"; 10'd594:rom_data=" "; 10'd595:rom_data="F"; 10'd596:rom_data="A"; 10'd597:rom_data="0"; 10'd598:rom_data="4"; 10'd599:rom_data=":"; 10'd600:rom_data=" "; 10'd601:rom_data="C";
        10'd602:rom_data="o"; 10'd603:rom_data="l"; 10'd604:rom_data="o"; 10'd605:rom_data="r"; 10'd606:rom_data=" "; 10'd607:rom_data="A"; 10'd608:rom_data="r"; 10'd609:rom_data="e"; 10'd610:rom_data="a"; 10'd611:rom_data=" ";
        10'd612:rom_data=" "; 10'd613:rom_data=" "; 10'd614:rom_data=" "; 10'd615:rom_data="("; 10'd616:rom_data="0"; 10'd617:rom_data="~"; 10'd618:rom_data="5"; 10'd619:rom_data=")"; 10'd620:rom_data=" "; 10'd621:rom_data=" ";
        10'd622:rom_data=" "; 10'd623:rom_data=" "; 10'd624:rom_data="|"; 10'd625:rom_data="|"; 10'd626:rom_data=8'h0D; 10'd627:rom_data=8'h0A;

        // 628-663: || FA05: Monitor SW    (0~1)    ||\r\n (修改这里：终端菜单变为0~1切换)
        10'd628:rom_data="|"; 10'd629:rom_data="|"; 10'd630:rom_data=" "; 10'd631:rom_data="F"; 10'd632:rom_data="A"; 10'd633:rom_data="0"; 10'd634:rom_data="5"; 10'd635:rom_data=":"; 10'd636:rom_data=" "; 10'd637:rom_data="M";
        10'd638:rom_data="o"; 10'd639:rom_data="n"; 10'd640:rom_data="i"; 10'd641:rom_data="t"; 10'd642:rom_data="o"; 10'd643:rom_data="r"; 10'd644:rom_data=" "; 10'd645:rom_data="S"; 10'd646:rom_data="W"; 10'd647:rom_data=" ";
        10'd648:rom_data=" "; 10'd649:rom_data=" "; 10'd650:rom_data=" "; 10'd651:rom_data=" "; 10'd652:rom_data="("; 10'd653:rom_data="0"; 10'd654:rom_data="~"; 10'd655:rom_data="1"; 10'd656:rom_data=")"; 10'd657:rom_data=" ";
        10'd658:rom_data=" "; 10'd659:rom_data=" "; 10'd660:rom_data="|"; 10'd661:rom_data="|"; 10'd662:rom_data=8'h0D; 10'd663:rom_data=8'h0A;

        // 664-699: || FA00: Print Init Status      ||\r\n  (🌟新增的 FA00 菜单提示)
        10'd664:rom_data="|"; 10'd665:rom_data="|"; 10'd666:rom_data=" "; 10'd667:rom_data="F"; 10'd668:rom_data="A"; 10'd669:rom_data="0"; 10'd670:rom_data="0"; 10'd671:rom_data=":"; 10'd672:rom_data=" "; 10'd673:rom_data="P";
        10'd674:rom_data="r"; 10'd675:rom_data="i"; 10'd676:rom_data="n"; 10'd677:rom_data="t"; 10'd678:rom_data=" "; 10'd679:rom_data="I"; 10'd680:rom_data="n"; 10'd681:rom_data="i"; 10'd682:rom_data="t"; 10'd683:rom_data=" ";
        10'd684:rom_data="S"; 10'd685:rom_data="t"; 10'd686:rom_data="a"; 10'd687:rom_data="t"; 10'd688:rom_data="u"; 10'd689:rom_data="s"; 10'd690:rom_data=" "; 10'd691:rom_data=" "; 10'd692:rom_data=" "; 10'd693:rom_data=" ";
        10'd694:rom_data=" "; 10'd695:rom_data=" "; 10'd696:rom_data="|"; 10'd697:rom_data="|"; 10'd698:rom_data=8'h0D; 10'd699:rom_data=8'h0A;

        // 700-735: ==================================\r\n (将底部的等号往后推移到这里)
        10'd700:rom_data="="; 10'd701:rom_data="="; 10'd702:rom_data="="; 10'd703:rom_data="="; 10'd704:rom_data="="; 10'd705:rom_data="="; 10'd706:rom_data="="; 10'd707:rom_data="="; 10'd708:rom_data="="; 10'd709:rom_data="=";
        10'd710:rom_data="="; 10'd711:rom_data="="; 10'd712:rom_data="="; 10'd713:rom_data="="; 10'd714:rom_data="="; 10'd715:rom_data="="; 10'd716:rom_data="="; 10'd717:rom_data="="; 10'd718:rom_data="="; 10'd719:rom_data="=";
        10'd720:rom_data="="; 10'd721:rom_data="="; 10'd722:rom_data="="; 10'd723:rom_data="="; 10'd724:rom_data="="; 10'd725:rom_data="="; 10'd726:rom_data="="; 10'd727:rom_data="="; 10'd728:rom_data="="; 10'd729:rom_data="=";
        10'd730:rom_data="="; 10'd731:rom_data="="; 10'd732:rom_data="="; 10'd733:rom_data="="; 10'd734:rom_data=8'h0D; 10'd735:rom_data=8'h0A;

        default: rom_data = 8'h20;
    endcase
end

//===========================================================================
// 4. 自动打字员 (Print Engine FSM)
//===========================================================================
reg        print_req;
reg  [9:0] print_start;
reg  [9:0] print_end;
reg        print_done;
reg  [2:0] print_state;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        print_state    <= 3'd0;
        rom_addr       <= 10'd0;
        engine_tx_en   <= 1'b0;
        print_done     <= 1'b0;
    end else begin
        case(print_state)
            3'd0: begin // IDLE
                print_done   <= 1'b0;
                engine_tx_en <= 1'b0;
                if(print_req) begin 
                    rom_addr    <= print_start; 
                    print_state <= 3'd1;
                end
            end
            3'd1: begin // FETCH
                engine_tx_data <= rom_data; 
                print_state    <= 3'd2; 
            end
            3'd2: begin // SEND
                engine_tx_en <= 1'b1;
                if(tx_busy) begin
                    engine_tx_en <= 1'b0;
                    print_state  <= 3'd3;
                end
            end
            3'd3: begin // WAIT
                if(!tx_busy) begin
                    if(rom_addr == print_end) begin
                        print_done  <= 1'b1;
                        print_state <= 3'd0;
                    end else begin
                        rom_addr    <= rom_addr + 1'b1;
                        print_state <= 3'd1;
                    end
                end
            end
        endcase
    end
end

//===========================================================================
// 5. 终端主控大脑 (Main CLI FSM) 
//===========================================================================
reg [5:0]  cli_state; 
reg [31:0] rx_cmd_reg;
reg [15:0] input_value;
reg        monitor_en;
reg [2:0]  active_cmd_id;
reg [7:0]  move_area_sel;
reg [7:0]  color_area_sel;

reg [23:0] power_delay_cnt; 
reg [23:0] auto_print_cnt; 

localparam S_POWER_DELAY = 6'd0;

localparam S_BOOT        = 6'd1;
localparam S_WAIT_BOOT_D = 6'd2;
localparam S_WAIT_DDR    = 6'd3;  
localparam S_PRINT_DDR   = 6'd4;
localparam S_WAIT_DDR_D  = 6'd5;
localparam S_WAIT_CAM0   = 6'd6;  
localparam S_PRINT_CAM0  = 6'd7;
localparam S_WAIT_CAM0_D = 6'd8;
localparam S_WAIT_CAM1   = 6'd9;  
localparam S_PRINT_CAM1  = 6'd10;
localparam S_WAIT_CAM1_D = 6'd11;
localparam S_WAIT_CAM2   = 6'd12;  
localparam S_PRINT_CAM2  = 6'd13;
localparam S_WAIT_CAM2_D = 6'd14;
localparam S_WAIT_HDMI   = 6'd15;  
localparam S_PRINT_HDMI  = 6'd16;
localparam S_WAIT_HDMI_D = 6'd17;
localparam S_WAIT_ETH    = 6'd18; 
localparam S_PRINT_ETH   = 6'd19;
localparam S_WAIT_ETH_D  = 6'd20;

localparam S_IDLE           = 6'd21;
localparam S_ASK_VAL        = 6'd22;
localparam S_WAIT_VAL_PRINT = 6'd23;
localparam S_CHECK          = 6'd24;
localparam S_PRINT_ERR      = 6'd25;
localparam S_WAIT_ERR_PRINT = 6'd26;
localparam S_PRINT_OK       = 6'd27;
localparam S_WAIT_OK_PRINT  = 6'd28;
localparam S_PRINT_TGT      = 6'd29;
localparam S_WAIT_TGT_PRINT = 6'd30;

localparam S_PRINT_HELP     = 6'd31;
localparam S_WAIT_HELP_D    = 6'd32;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cli_state       <= S_POWER_DELAY; 
        power_delay_cnt <= 24'd0;         
        auto_print_cnt  <= 24'd0;         
        
        rx_cmd_reg      <= 32'd0;
        input_value     <= 16'd0;
        input_ascii_reg <= 32'h30_30_30_30; 
        print_req       <= 1'b0;
        monitor_en      <= 1'b0;
        last_target_num <= 4'd15; 
        active_cmd_id   <= 3'd0;
        
        diff_value      <= 8'd30;
        min_dist        <= 12'd60;
        move_area_sel   <= 8'd5;
        color_area_sel  <= 8'd2;
    end else begin
        print_req <= 1'b0;

        case(cli_state)
            S_POWER_DELAY: begin
                if(power_delay_cnt == 24'd2_700_000) begin
                    cli_state <= S_IDLE; // 🌟修改：上电延迟结束后，直接进入待机，不再强制触发 S_BOOT
                end else begin
                    power_delay_cnt <= power_delay_cnt + 1'b1;
                end
            end

            S_BOOT:        begin print_start <= 10'd0; print_end <= 10'd65; print_req <= 1'b1; cli_state <= S_WAIT_BOOT_D; end
            S_WAIT_BOOT_D: if(print_done) cli_state <= S_WAIT_DDR; 

            S_WAIT_DDR:    if(ddr3_ready) cli_state <= S_PRINT_DDR; 
            S_PRINT_DDR:   begin print_start <= 10'd70; print_end <= 10'd98; print_req <= 1'b1; cli_state <= S_WAIT_DDR_D; end
            S_WAIT_DDR_D:  if(print_done) cli_state <= S_WAIT_CAM0;

            S_WAIT_CAM0:   if(cam0_ready) cli_state <= S_PRINT_CAM0;
            S_PRINT_CAM0:  begin print_start <= 10'd100; print_end <= 10'd128; print_req <= 1'b1; cli_state <= S_WAIT_CAM0_D; end
            S_WAIT_CAM0_D: if(print_done) cli_state <= S_WAIT_CAM1;

            S_WAIT_CAM1:   if(cam1_ready) cli_state <= S_PRINT_CAM1;
            S_PRINT_CAM1:  begin print_start <= 10'd130; print_end <= 10'd158; print_req <= 1'b1; cli_state <= S_WAIT_CAM1_D; end
            S_WAIT_CAM1_D: if(print_done) cli_state <= S_WAIT_CAM2;

            S_WAIT_CAM2:   if(cam2_ready) cli_state <= S_PRINT_CAM2;
            S_PRINT_CAM2:  begin print_start <= 10'd160; print_end <= 10'd188; print_req <= 1'b1; cli_state <= S_WAIT_CAM2_D; end
            S_WAIT_CAM2_D: if(print_done) cli_state <= S_WAIT_HDMI;

            S_WAIT_HDMI:   if(hdmi_ready) cli_state <= S_PRINT_HDMI;
            S_PRINT_HDMI:  begin print_start <= 10'd190; print_end <= 10'd218; print_req <= 1'b1; cli_state <= S_WAIT_HDMI_D; end
            S_WAIT_HDMI_D: if(print_done) cli_state <= S_WAIT_ETH;

            S_WAIT_ETH:    if(eth_ready) cli_state <= S_PRINT_ETH;
            S_PRINT_ETH:   begin print_start <= 10'd220; print_end <= 10'd247; print_req <= 1'b1; cli_state <= S_WAIT_ETH_D; end
            
            S_WAIT_ETH_D:  if(print_done) cli_state <= S_PRINT_HELP;

            S_PRINT_HELP:  begin print_start <= 10'd410; print_end <= 10'd735; print_req <= 1'b1; cli_state <= S_WAIT_HELP_D; end // 🌟修改：由于加入了 FA00 菜单，结束地址延长到 735
            S_WAIT_HELP_D: if(print_done) cli_state <= S_IDLE; 

            // --- 待机与连续输入统一处理池 ---
            S_IDLE: begin
                if(rx_done_pulse) begin
                    auto_print_cnt <= 24'd0; // 如果收到你的按键指令，立刻重置心跳计时器
                    rx_cmd_reg     <= {rx_cmd_reg[23:0], rx_data};
                    
                    if({rx_cmd_reg[23:0], rx_data} == 32'h46_41_30_30) begin  // 🌟新增：收到 FA00 后，主动跳到 S_BOOT 发起全套打印！
                        active_cmd_id <= 3'd0; monitor_en <= 1'b0; rx_cmd_reg <= 0; cli_state <= S_BOOT; 
                    end
                    else if({rx_cmd_reg[23:0], rx_data} == 32'h46_41_30_31) begin 
                        active_cmd_id <= 3'd2; monitor_en <= 1'b0; rx_cmd_reg <= 0; cli_state <= S_ASK_VAL; 
                    end
                    else if({rx_cmd_reg[23:0], rx_data} == 32'h46_41_30_33) begin 
                        active_cmd_id <= 3'd3; monitor_en <= 1'b0; rx_cmd_reg <= 0; cli_state <= S_ASK_VAL; 
                    end
                    else if({rx_cmd_reg[23:0], rx_data} == 32'h46_41_30_34) begin 
                        active_cmd_id <= 3'd4; monitor_en <= 1'b0; rx_cmd_reg <= 0; cli_state <= S_ASK_VAL; 
                    end
                    // 🌟 修改处：进入 FA05 后，不再是一次性切换状态，而是进入提示输入值的环节 S_ASK_VAL
                    else if({rx_cmd_reg[23:0], rx_data} == 32'h46_41_30_35) begin 
                        active_cmd_id <= 3'd5; monitor_en <= 1'b0; rx_cmd_reg <= 0; cli_state <= S_ASK_VAL; 
                    end
                    else if({rx_cmd_reg[23:8]} == 16'h46_41) begin
                        active_cmd_id <= 3'd0; rx_cmd_reg <= 0; input_value <= 16'd0; 
                        input_ascii_reg <= 32'h30_30_30_30; cli_state <= S_PRINT_ERR;
                    end
                    else if(rx_data == 8'h0D || rx_data == 8'h0A) begin
                        rx_cmd_reg <= 32'd0; 
                        if(rx_cmd_reg[7:0] != 8'h0D && rx_cmd_reg[7:0] != 8'h0A && rx_cmd_reg[7:0] != 8'h00) begin
                            if(active_cmd_id != 3'd0) begin
                                if(rx_cmd_reg[7:0] >= 8'h30 && rx_cmd_reg[7:0] <= 8'h39) begin
                                    cli_state <= S_CHECK;
                                end else begin
                                    cli_state <= S_PRINT_ERR; 
                                end
                            end else begin
                                cli_state <= S_PRINT_ERR;
                            end
                        end
                    end
                    else begin
                        if(active_cmd_id != 3'd0) begin
                            if(rx_data >= 8'h30 && rx_data <= 8'h39) begin 
                                input_value <= (input_value << 3) + (input_value << 1) + (rx_data - 8'h30);
                                input_ascii_reg <= {input_ascii_reg[23:0], rx_data}; 
                            end
                        end
                    end
                end
                
                // 🌟 连续心跳式打印逻辑！(基于峰值保持后的平滑数值 smooth_target_num)
                else if((print_state == 3'd0) && monitor_en) begin
                    if (smooth_target_num != last_target_num) begin
                        last_target_num <= smooth_target_num;
                        auto_print_cnt  <= 24'd0;
                        cli_state       <= S_PRINT_TGT;
                    end 
                    else if (auto_print_cnt >= 24'd6_750_000) begin 
                        auto_print_cnt  <= 24'd0;
                        cli_state       <= S_PRINT_TGT;
                    end 
                    else begin
                        auto_print_cnt  <= auto_print_cnt + 1'b1;
                    end
                end
                
                else begin
                    auto_print_cnt <= 24'd0;
                end
            end
            
            S_ASK_VAL: begin
                print_start <= 10'd250; print_end <= 10'd269; print_req <= 1'b1; 
                input_value <= 16'd0; input_ascii_reg <= 32'h30_30_30_30; cli_state <= S_WAIT_VAL_PRINT; 
            end
            
            S_WAIT_VAL_PRINT: begin
                if(print_done) cli_state <= S_IDLE; 
            end
            
            S_CHECK: begin
                if(active_cmd_id == 3'd1 && input_value > 16'd255) begin
                    cli_state <= S_PRINT_ERR;
                end 
                else if(active_cmd_id == 3'd2 && input_value > 16'd1280) begin
                    cli_state <= S_PRINT_ERR;
                end 
                else if(active_cmd_id == 3'd3 && input_value > 16'd5) begin
                    cli_state <= S_PRINT_ERR;
                end 
                else if(active_cmd_id == 3'd4 && input_value > 16'd5) begin
                    cli_state <= S_PRINT_ERR;
                end 
                // 🌟 修改处：新增对 FA05 输入范围的校验（只能输入 0 或 1）
                else if(active_cmd_id == 3'd5 && input_value > 16'd1) begin
                    cli_state <= S_PRINT_ERR;
                end
                else begin
                    case(active_cmd_id)
                        3'd1: diff_value     <= input_value[7:0];
                        3'd2: min_dist       <= input_value[11:0];
                        3'd3: move_area_sel  <= input_value[7:0];
                        3'd4: color_area_sel <= input_value[7:0];
                        // 🌟 修改处：如果是 FA05，输入 0 (开始接收) -> monitor_en 置 1，输入 1 (停止接收) -> 置 0
                        3'd5: monitor_en     <= (input_value == 16'd0) ? 1'b1 : 1'b0; 
                    endcase
                    cli_state <= S_PRINT_OK;
                end
            end
            
            S_PRINT_ERR: begin 
                print_start <= 10'd280; print_end <= 10'd314; print_req <= 1'b1; 
                cli_state <= S_WAIT_ERR_PRINT; 
            end
            
            S_WAIT_ERR_PRINT: begin
                if(print_done) begin
                    input_value <= 16'd0; input_ascii_reg <= 32'h30_30_30_30; cli_state <= S_IDLE; 
                end
            end
            
            S_PRINT_OK: begin 
                // 🌟 修改处：让 FA05 也使用和前面相同的 "[Success]" 确认打印
                if(active_cmd_id == 3'd1 || active_cmd_id == 3'd2 || active_cmd_id == 3'd5) begin
                    print_start <= 10'd320; print_end <= 10'd352; 
                end else begin
                    print_start <= 10'd360; print_end <= 10'd384; 
                end
                print_req <= 1'b1; cli_state <= S_WAIT_OK_PRINT; 
            end
            
            S_WAIT_OK_PRINT: begin
                // 打印完成后回到 IDLE，但 active_cmd_id 没有清空，所以可以在 FA05 模式下一直连续输入！
                if(print_done) begin
                    input_value <= 16'd0; input_ascii_reg <= 32'h30_30_30_30; cli_state <= S_IDLE; 
                end
            end
            
            S_PRINT_TGT: begin 
                print_start <= 10'd390; print_end <= 10'd405; print_req <= 1'b1; 
                cli_state <= S_WAIT_TGT_PRINT; 
            end
            
            S_WAIT_TGT_PRINT: begin
                if(print_done) cli_state <= S_IDLE; 
            end
            
            default: cli_state <= S_POWER_DELAY; 
        endcase
    end
end

//===========================================================================
// 动态识别区域控制逻辑 (Move Area)
//===========================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cur_frame_top    <= 12'd5;
        cur_frame_bottom <= 12'd354;
        cur_frame_left   <= 12'd5;
        cur_frame_right  <= 12'd634;
    end
    else begin
        case(move_area_sel)
            8'd1: begin cur_frame_top <= 12'd5;   cur_frame_bottom <= 12'd354; cur_frame_left <= 12'd5;   cur_frame_right <= 12'd634;  end
            8'd2: begin cur_frame_top <= 12'd5;   cur_frame_bottom <= 12'd354; cur_frame_left <= 12'd645; cur_frame_right <= 12'd1274; end
            8'd3: begin cur_frame_top <= 12'd365; cur_frame_bottom <= 12'd714; cur_frame_left <= 12'd5;   cur_frame_right <= 12'd634;  end
            8'd4: begin cur_frame_top <= 12'd365; cur_frame_bottom <= 12'd714; cur_frame_left <= 12'd645; cur_frame_right <= 12'd1274; end
            8'd5: begin cur_frame_top <= 12'd5;   cur_frame_bottom <= 12'd714; cur_frame_left <= 12'd5;   cur_frame_right <= 12'd1274; end
            default: begin cur_frame_top <= 12'd5; cur_frame_bottom <= 12'd354; cur_frame_left <= 12'd5;   cur_frame_right <= 12'd634;  end
        endcase
    end
end

//===========================================================================
// 颜色识别区域控制逻辑 (Color Area)
//===========================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cur_color_top    <= 12'd5;
        cur_color_bottom <= 12'd354;
        cur_color_left   <= 12'd5;
        cur_color_right  <= 12'd634;
    end
    else begin
        case(color_area_sel)
            8'd1: begin cur_color_top <= 12'd5;   cur_color_bottom <= 12'd354; cur_color_left <= 12'd5;   cur_color_right <= 12'd634;  end
            8'd2: begin cur_color_top <= 12'd5;   cur_color_bottom <= 12'd354; cur_color_left <= 12'd645; cur_color_right <= 12'd1274; end
            8'd3: begin cur_color_top <= 12'd365; cur_color_bottom <= 12'd714; cur_color_left <= 12'd5;   cur_color_right <= 12'd634;  end
            8'd4: begin cur_color_top <= 12'd365; cur_color_bottom <= 12'd714; cur_color_left <= 12'd645; cur_color_right <= 12'd1274; end
            8'd5: begin cur_color_top <= 12'd5;   cur_color_bottom <= 12'd714; cur_color_left <= 12'd5;   cur_color_right <= 12'd1274; end
            default: begin cur_color_top <= 12'd5; cur_color_bottom <= 12'd354; cur_color_left <= 12'd5;   cur_color_right <= 12'd634;  end
        endcase
    end
end

endmodule