module image_top(
    input   wire            clk          ,
    input   wire            rst_n        ,
    //  
    input   wire            hsync_i      ,//行信号
    input   wire            vsync_i      ,//场信号
    input   wire            de_i         ,
    input   wire    [23:0]  data_i       ,//

    output  wire            hsync_o      ,
    output  wire            vsync_o      ,
    output  wire            de_o         ,
    output  wire    [15:0]  data_o               
);

wire        hs_reg;
wire        vs_reg;
wire        de_reg;

wire        hs_reg1;
wire        vs_reg1;
wire 		de_reg1;

wire        hs_reg2;
wire        vs_reg2;
wire 		de_reg2;

wire [7:0]  data_y ;
wire [7:0]  data_cb;
wire [7:0]  data_cr;
wire [7:0]	data_mid;
wire [7:0]	data_gauss;

rgb2ycrcb rgb2ycrcb_inst(
    /*input   wire        */.clk       (clk  ),
    /*input   wire        */.rst_n     (rst_n),
    //输入                             
    /*input   wire        */.hsync_i   (hsync_i),//行信号
    /*input   wire        */.vsync_i   (vsync_i),//场信号
    /*input   wire        */.de_i      (de_i   ),
    /*input   wire [23:0] */.data_i    (data_i),//
    //输出                            
    /*output  wire        */.hsync_o   (hs_reg),
    /*output  wire        */.vsync_o   (vs_reg),
    /*output  wire        */.de_o      (de_reg),
	/*output  wire [7:0]  */.data_y    (data_y ), 
	/*output  wire [7:0]  */.data_cb   (data_cb), 
    /*output  wire [7:0]  */.data_cr   (data_cr) 
    );
	
image_midian image_midian_inst(
    /*input   wire        */.clk         (clk  ),
    /*input   wire        */.rst_n       (rst_n),
    /*//                  */
    /*input   wire        */.hsync_i     (hs_reg),
    /*input   wire        */.vsync_i     (vs_reg),
    /*input   wire        */.de_i        (de_reg),
	/*input	wire [7:0]    */.data_i		 (data_y), 
	/*//                  */
    /*output  wire        */.hsync_o     (hs_reg1),
    /*output  wire        */.vsync_o     (vs_reg1),
    /*output  wire        */.de_o        (de_reg1),
    /*output  wire [7:0]  */.data_mid    (data_mid)   
    );
	
image_gauss image_gauss_inst(
    /*input   wire        */.clk        (clk  ) ,
    /*input   wire        */.rst_n      (rst_n) ,
    /*                    */         
    /*input   wire        */.hsync_i    (hs_reg1) ,
    /*input   wire        */.vsync_i    (vs_reg1) ,
    /*input   wire        */.de_i       (de_reg1) ,
    /*input	  wire [7:0]  */.data_i		(data_mid),
    /*                    */           
    /*output  wire        */.hsync_o    (hsync_o) ,
    /*output  wire        */.vsync_o    (vsync_o) ,
    /*output  wire        */.de_o       (de_o   ) ,
    /*output  reg  [7:0]  */.data_o     (data_gauss ) 
);

assign data_o = {data_gauss,8'b0};

endmodule
