`timescale 1ns / 1ps

module uart_data_gen(
    input	wire			clk				,
	input	wire			rst_n			,
    input	wire	[7:0]	read_data		,
    input	wire			tx_busy			,
    input	wire	[7:0]	write_max_num	,
    output	reg		[7:0]	write_data		,
    output	reg				write_en
);

parameter time_1s = 26'd27_000_000 ;

//==============================================================================  
//time counter
//==============================================================================  
reg [25:0] time_cnt;  
reg [ 7:0] data_num;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		time_cnt <= 26'd0 ;
	else if (time_cnt == time_1s - 26'd1)
		time_cnt <= 26'd0 ;
	else
		time_cnt <= time_cnt + 26'd1;
end

//==============================================================================  
//work enable
//==============================================================================  
reg        work_en;
reg        work_en_1d;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)	
		work_en <= 1'b1;
    else if(time_cnt == 26'd2048)
        work_en <= 1'b1;
    else if(data_num == write_max_num - 1'b1)
        work_en <= 1'b0;
end

//==============================================================================  
//work enable 1d
//==============================================================================  
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)	
		work_en_1d <= 1'b0;
	else
		work_en_1d <= work_en;
end

//==============================================================================  
//get the tx_busy  s falling edge    
//==============================================================================  
reg            tx_busy_reg;
wire           tx_busy_f;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)	
		tx_busy_reg <= 1'b0;
	else
		tx_busy_reg <= tx_busy;
end

assign tx_busy_f = (!tx_busy) && (tx_busy_reg);

//==============================================================================  
//write pluse
//==============================================================================  
reg write_pluse;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)	
		write_pluse <= 1'b0;
    else if(work_en) begin
        if(~work_en_1d || tx_busy_f)
            write_pluse <= 1'b1;
        else
            write_pluse <= 1'b0;
    end
    else
        write_pluse <= 1'b0;
end

//==============================================================================  
//data num
//==============================================================================  
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)	
		data_num <= 7'h0;
    else if(~work_en & tx_busy_f)
        data_num <= 7'h0;
    else if(write_pluse)
        data_num <= data_num + 8'h1;
end

//==============================================================================  
//write enable
//==============================================================================  
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)	
		write_en <= 1'b0;
	else
		write_en <= write_pluse;
end

//==============================================================================  
//write data
//==============================================================================  
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)	
		write_data <= 8'h0;
	else begin
		case(data_num)
			8'h0  ,
			8'h1  :	write_data <= 8'h77;// ASCII code is w
			8'h2  :	write_data <= 8'h77;// ASCII code is w
			8'h3  :	write_data <= 8'h77;// ASCII code is w
			8'h4  :	write_data <= 8'h2E;// ASCII code is .
			8'h5  :	write_data <= 8'h6D;// ASCII code is m
			8'h6  :	write_data <= 8'h65;// ASCII code is e
			8'h7  :	write_data <= 8'h79;// ASCII code is y
			8'h8  :	write_data <= 8'h65;// ASCII code is e
			8'h9  :	write_data <= 8'h73;// ASCII code is s
			8'ha  :	write_data <= 8'h65;// ASCII code is e
			8'hb  :	write_data <= 8'h6D;// ASCII code is m
			8'hc  :	write_data <= 8'h69;// ASCII code is i  
			8'hd  :	write_data <= 8'h2E;// ASCII code is .  
			8'he  :	write_data <= 8'h63;// ASCII code is c    
			8'hf  :	write_data <= 8'h6F;// ASCII code is o
			8'h10 :	write_data <= 8'h6D;// ASCII code is m  
			8'h11 ,
			8'h12 :	write_data <= 8'h0d;
			8'h13 :	write_data <= 8'h0a;
			default :	write_data <= read_data;
		endcase
	end
end

endmodule
