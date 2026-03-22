
module diff_pic(
    input    wire              sys_clk      ,
    input    wire              sys_rst_n    ,
      
    output   reg               read_req     , // Start reading a frame of data     
    input    wire              read_req_ack , // Read request response
    output   wire              read_en      , // Read data enable
    input    wire    [15:0]    read_data    , // Read data
  
    input    wire              hsync_i      ,
	input    wire              vsync_i      ,
	input    wire              de_i         ,

    output   reg    [11:0]     pixle_x      ,
    output   reg    [11:0]     pixle_y      ,
	      
    input    wire    [7:0]     new_pic      ,
    input    wire    [7:0]     last_pic     ,
    input    wire    [7:0]     DIFF_THR     ,
    output   wire              hsync_o      ,
    output   wire              vsync_o      ,
	output   wire              de_o         ,
        
    output   wire    [7:0]     diff_data  
);

reg [7:0] last_pic_d1;
reg [7:0] new_pic_d1;
reg [7:0] new_pic_d2;
reg       de_i_d1;
reg       de_i_d2;

reg [2:0] hsync_reg_pl;
reg [2:0] vsync_reg_pl;
reg [2:0] de_reg_pl;

reg       diff_flag;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        hsync_reg_pl <= 3'b0;
        vsync_reg_pl <= 3'b0;
        de_reg_pl    <= 3'b0;
    end
    else begin
        hsync_reg_pl <= {hsync_reg_pl[1:0], hsync_i};
        vsync_reg_pl <= {vsync_reg_pl[1:0], vsync_i};
        de_reg_pl    <= {de_reg_pl[1:0],    de_i};
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        read_req <= 1'b0;
    // 使用打过拍子的同步信号触发
    else if(vsync_reg_pl[1] == 1'b0 & vsync_reg_pl[0] == 1'b1) //rising edge
        read_req <= 1'b1;
    else if(read_req_ack == 1'b1)
        read_req <= 1'b0;
end

assign read_en = de_i;

//*将当前数据打一拍，
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)begin
        last_pic_d1  <= 8'b0;
        new_pic_d1   <= 8'b0;
        new_pic_d2   <= 8'b0;
        de_i_d1      <= 1'b0;
        de_i_d2      <= 1'b0;
    end
    else begin
        last_pic_d1 <= read_data[15:8];
        
        // 把当前新进来的像素也塞进流水线故意慢走 2 拍，去陪等 DDR
        new_pic_d1   <= new_pic;
        new_pic_d2   <= new_pic_d1;
        de_i_d1      <= de_i;
        de_i_d2      <= de_i_d1;
    end
end

//*差分计算
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        diff_flag <= 1'b0;
    else if(de_i_d2) begin
        if(last_pic_d1 >= new_pic_d2) begin
            if((last_pic_d1 - new_pic_d2) >= DIFF_THR)
                diff_flag <= 1'b0;//*输出黑色，显示区域
            else
                diff_flag <= 1'b1;
        end
        else if(new_pic_d2 > last_pic_d1) begin
            if((new_pic_d2 - last_pic_d1) >= DIFF_THR)
                diff_flag <= 1'b0;
            else
                diff_flag <= 1'b1;
        end
    end
    else begin
        // de 非法区间不比较，直接给黑屏
        diff_flag <= 1'b1;
    end
end


wire [7:0] diff_data_reg;
//*rgb_data
assign diff_data_reg = diff_flag ? 8'hff : 8'h00;

wire diff_hs_out;
wire diff_vs_out;
wire diff_de_out;

// 将同步信号推出到流水线最后 1 极，与出差分结果同步输出
assign diff_hs_out = hsync_reg_pl[2];
assign diff_vs_out = vsync_reg_pl[2];
assign diff_de_out = de_reg_pl[2];

//===========================================================================
// 膨胀
//===========================================================================
wire       dilate_hs_out;
wire       dilate_vs_out;
wire       dilate_de_out;
wire [7:0] dilate_data  ;

image_dilation image_dilation_inst(
    /*input   wire        */.clk         ( sys_clk       ) ,
    /*input   wire        */.rst_n       ( sys_rst_n     ) ,
    //   
    /*input   wire        */.hsync_i     ( diff_hs_out   ) ,
    /*input   wire        */.vsync_i     ( diff_vs_out   ) ,
    /*input   wire        */.de_i        ( diff_de_out   ) ,
    /*input   wire [7:0]  */.data_i      ( diff_data_reg ) , 
    //输出行场信号   
    /*output  wire        */.hsync_o     ( dilate_hs_out ) ,
    /*output  wire        */.vsync_o     ( dilate_vs_out ) ,
    /*output  wire        */.de_o        ( dilate_de_out ) ,
    /*output  wire [7:0]  */.data_dilate ( dilate_data   ) 
);

//===========================================================================
// 腐蚀
//===========================================================================
wire       erode_hs_out;
wire       erode_vs_out;
wire       erode_de_out;
wire [7:0] erode_data  ;

image_erosion image_erosion_inst1(
    /*input   wire        */.clk        ( sys_clk       ) ,
    /*input   wire        */.rst_n      ( sys_rst_n     ) ,
    //  
    /*input   wire        */.hsync_i    ( dilate_hs_out ) ,
    /*input   wire        */.vsync_i    ( dilate_vs_out ) ,
    /*input   wire        */.de_i       ( dilate_de_out ) ,
    /*input   wire [7:0]  */.data_i     ( dilate_data   ) ,
    //输出行场信号  
    /*output  wire        */.hsync_o    ( erode_hs_out  ) ,
    /*output  wire        */.vsync_o    ( erode_vs_out  ) ,
    /*output  wire        */.de_o       ( erode_de_out  ) ,
    /*output  wire [7:0]  */.data_erode ( erode_data    ) 
);

//===========================================================================
// 膨胀
//===========================================================================
wire       dilate_hs_out1;
wire       dilate_vs_out1;
wire       dilate_de_out1;
wire [7:0] dilate_data1  ;

image_dilation image_dilation_inst1(
    /*input   wire        */.clk         ( sys_clk        ) ,
    /*input   wire        */.rst_n       ( sys_rst_n      ) ,
    //    
    /*input   wire        */.hsync_i     ( erode_hs_out   ) ,
    /*input   wire        */.vsync_i     ( erode_vs_out   ) ,
    /*input   wire        */.de_i        ( erode_de_out   ) ,
    /*input   wire [7:0]  */.data_i      ( erode_data     ) , 
    //输出行场信号   
    /*output  wire        */.hsync_o     ( dilate_hs_out1 ) ,
    /*output  wire        */.vsync_o     ( dilate_vs_out1 ) ,
    /*output  wire        */.de_o        ( dilate_de_out1 ) ,
    /*output  wire [7:0]  */.data_dilate ( dilate_data1   ) 
);

//===========================================================================
// 腐蚀
//===========================================================================
wire       erode_hs_out1;
wire       erode_vs_out1;
wire       erode_de_out1;
wire [7:0] erode_data1;

image_erosion image_erosion_inst(
    /*input   wire        */.clk        ( sys_clk        ) ,
    /*input   wire        */.rst_n      ( sys_rst_n      ) ,
    //  
    /*input   wire        */.hsync_i    ( dilate_hs_out1 ) ,
    /*input   wire        */.vsync_i    ( dilate_vs_out1 ) ,
    /*input   wire        */.de_i       ( dilate_de_out1 ) ,
    /*input   wire [7:0]  */.data_i     ( dilate_data1   ) ,
    //输出行场信号  
    /*output  wire        */.hsync_o    ( hsync_o        ) ,
    /*output  wire        */.vsync_o    ( vsync_o        ) ,
    /*output  wire        */.de_o       ( de_o           ) ,
    /*output  wire [7:0]  */.data_erode ( diff_data      ) 
);



// reg     [11:0] pixle_x;
// reg     [11:0] pixle_y;

// ================= 标准“打两拍”边沿检测 =================
reg     vsync_reg0;
reg     vsync_reg1;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        vsync_reg0 <= 1'b0;
        vsync_reg1 <= 1'b0;
    end
    else begin
        vsync_reg0 <= vsync_o;      // 第一拍：同步/采样
        vsync_reg1 <= vsync_reg0;   // 第二拍：打拍延时
    end
end

wire    vsync_edge;
assign  vsync_edge = ~vsync_reg0 & vsync_reg1; 

//============== 工业级 X 坐标生成 ====================
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pixle_x <= 12'b0;
    else if(vsync_edge)        // 每一帧开头，绝对权威的强制清零！
        pixle_x <= 12'b0;
    else if(de_o) begin
        if(pixle_x == 12'd1279)
            pixle_x <= 12'b0;
        else
            pixle_x <= pixle_x + 1;
    end
    else begin
        pixle_x <= 12'b0;      // de_o 拉低时强制为0，保证下一行开头绝对是0
    end
end

//============== 工业级 Y 坐标生成 ====================
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pixle_y <= 12'b0;
    else if(vsync_edge)        // 每一帧开头，绝对权威的强制清零！
        pixle_y <= 12'b0;
    else if(pixle_x == 12'd1279 && de_o) begin
        if(pixle_y == 12'd719)
            pixle_y <= 12'b0;
        else
            pixle_y <= pixle_y + 1;
    end
end

endmodule