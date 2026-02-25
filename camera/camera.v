module camera (
    input   wire            clk             ,
    input   wire            rst_n           ,
    output  wire            SCL             ,  
    output  wire            SDA             ,  
    input   wire            camera_clk      ,
    input   wire    [7:0]   camera_data     ,
    input   wire            camera_herf     ,
    input   wire            camera_vsync    ,
    input   wire            ddr_init        ,
    output  wire    [15:0]  wf_wr_data      ,   //RGB565
    output  wire            wf_wr_en        ,
    output  wire            sop             ,
    output  wire            eop 
);

wire            sccb_done   ;
wire            sccb_start  ;
wire [23:0]     data_in     ;  
wire            init_done   ;

data_init(
    /*input   wire            */.sys_clk   (clk      ) ,    // 系统时钟
    /*input   wire            */.sys_rst_n (rst_n    ) ,  // 系统复位，低有效
    /*input   wire            */.cfg_end   (sccb_done) ,    // 单个寄存器配置完成
    /*                        */     
    /*output  reg             */.cfg_start (sccb_start) ,  // 单个寄存器配置触发
    /*output  wire    [23:0]  */.cfg_data  (data_in   ) ,   // {REG_ADDR[15:0], REG_VAL[7:0]}
    /*output  reg             */.cfg_done  (init_done )  // 全部配置完成
);

SCCB SCCB_u(
    .clk         (clk         ),   //时钟
    .rst_n       (rst_n       ),   //复位
    .sccb_start  (sccb_start  ),   //开始信号
    .data_in     (data_in     ),   //高位地址 + 低位地址 + 数据
    .SCL         (SCL         ),   //
    .SDA         (SDA         ),   //
    .sccb_done   (sccb_done   )    //结束信号
);

camera_data camera_data_u( 
    /*input   wire            */.clk           (camera_clk      )      ,
    /*input   wire            */.rst_n         (rst_n           )      ,
    /*input   wire            */.vsync         (camera_vsync    )      ,//表示新一帧到来
    /*input   wire            */.href          (camera_herf     )      ,//有效信号
    /*input   wire    [7:0]   */.din           (camera_data     )      ,
    /*input   wire            */.cfg_done      (init_done       )      ,//摄像头配置完成标准信号
    /*input   wire            */.ddr_init      (ddr_init        )      ,
    /*output  reg     [15:0]  */.pixel_data    (wf_wr_data      )      ,//像素数据rgb565
    /*output  wire            */.wf_wr_en      (wf_wr_en        )      ,
    /*output  reg             */.sop           (sop             )      ,// 帧头
    /*output  reg             */.eop           (eop             )       //帧尾在最后一行最后一个计数器结束
);			
    
endmodule