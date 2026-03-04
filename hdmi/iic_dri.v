`timescale 1ns / 1ps

module iic_dri #(
    parameter CLK_FRE   = 27'd50_000_000,  // System clock frequency (Hz)
    parameter IIC_FREQ  = 20'd400_000,     // I2C clock frequency (Hz)
    parameter T_WR      = 10'd5,           // I2C transmit delay (ms)
    parameter ADDR_BYTE = 2'd1,            // I2C address byte number
    parameter LEN_WIDTH = 8'd3,            // I2C transmit byte width
    parameter DATA_BYTE = 2'd1             // I2C data byte number
)(                       
    input                clk,              // System clock
    input                rstn,             // Async reset, active low
    input                pluse,            // I2C transmit trigger
    input  [7:0]         device_id,        // I2C device id
    input                w_r,              // I2C R/W direction: 1=write, 0=read
    input  [LEN_WIDTH:0] byte_len,         // I2C transmit data byte length per trigger
               
    input  [15:0]        addr,             // I2C transmit address
    input  [7:0]         data_in,          // I2C send data
                 
    output reg           busy = 0,         // I2C bus status
    output reg           byte_over = 0,    // I2C byte transmit over flag               
    output reg [7:0]     data_out,         // I2C receive data
                         
    output               scl,              // I2C clock output
    input                sda_in,           // I2C data input
    output reg           sda_out = 1'b1,   // I2C data output
    output               sda_out_en        // I2C data output enable
);

//============================================================================
// Local parameters
//============================================================================
localparam CLK_DIV       = CLK_FRE / IIC_FREQ;     // Clock divider count max
localparam ID_ADDR_BYTE  = ADDR_BYTE + 1'b1;       // Address + device ID byte count
localparam DATA_SET      = CLK_DIV >> 2;           // Output data change position
localparam T_WR_CLK      = T_WR * CLK_FRE / 1000;// Write delay in clock cycles
//============================================================================
// Internal signals
//============================================================================
reg  [15:0] clk_cnt;
wire        half_cycle;                // Half cycle flag (rising edge position)
wire        dsu;                       // Data setup point (for data change)
wire        full_cycle;                // Full cycle flag
wire        start_h;                   // Start high flag

assign half_cycle  = (clk_cnt == (CLK_DIV >> 1) - 1'b1);
assign full_cycle  = (clk_cnt == CLK_DIV - 1'b1);
assign start_h     = (clk_cnt == DATA_SET - 1'b1);
assign dsu         = (clk_cnt == (CLK_DIV >> 1) + DATA_SET - 1'b1);

//============================================================================
// Trigger detection registers
//============================================================================
wire   start;
reg    start_en;
reg    pluse_1d, pluse_2d, pluse_3d;
reg    w_r_1d, w_r_2d;
reg    [7:0] device_id_1d;
reg    [15:0] addr_1d, addr_2d;
reg    [7:0] data_in_1d;
reg    [LEN_WIDTH:0] byte_len_1d;
// Pulse edge detection with async reset
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        pluse_1d <= 1'b0;
        pluse_2d <= 1'b0;
        pluse_3d <= 1'b0;
    end
    else begin
        pluse_1d <= pluse;
        pluse_2d <= pluse_1d;
        pluse_3d <= pluse_2d;
    end
end

// Input data latch with async reset
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        w_r_1d       <= 1'b0;
        w_r_2d       <= 1'b0;
        device_id_1d <= 8'd0;
        addr_1d      <= 16'd0;
        addr_2d      <= 16'd0;
        data_in_1d   <= 8'd0;
        byte_len_1d  <= {(LEN_WIDTH+1){1'b0}};
    end
    else begin
        w_r_1d       <= w_r;
        w_r_2d       <= w_r_1d;
        device_id_1d <= device_id;
        addr_1d      <= addr;
        addr_2d      <= addr_1d;
        data_in_1d   <= data_in;
        byte_len_1d  <= byte_len;
    end
end

// Start enable control with async reset
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        start_en <= 1'b0;
    else if (pluse_2d & ~pluse_3d)
        start_en <= 1'b1;
    else if (start)
        start_en <= 1'b0;
    else
        start_en <= start_en;
end

assign start = start_en & (clk_cnt == CLK_DIV - 1'b1);

//============================================================================
// FSM state definitions
//============================================================================
localparam IDLE    = 3'd0;
localparam S_START = 3'd1;
localparam SEND    = 3'd2;
localparam S_ACK   = 3'd3;
localparam RECEIV  = 3'd4;
localparam R_ACK   = 3'd5;
localparam STOP    = 3'd6;

reg [2:0] state;
reg [2:0] state_n;
reg [2:0] trans_bit = 3'd0;
reg [LEN_WIDTH:0] trans_byte = 5'd0;
reg [LEN_WIDTH:0] trans_byte_max = 5'd0;
reg       restart = 1'b0;
reg [7:0] send_data = 8'd0;
reg [7:0] receiv_data = 8'd0;
reg       trans_en = 0;
reg       trans_over = 0;
reg       scl_out = 1'b1;

assign scl = scl_out;

//============================================================================
// Transmit status (busy flag) with async reset
//============================================================================
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        busy <= 1'b0;
    else if (start)
        busy <= 1'b1;
    else if (state == STOP && start_h)
        busy <= 1'b0;
    else
        busy <= busy;
end

//============================================================================
// Write delay control with async reset
//============================================================================
reg        twr_en = 0;
reg [26:0] twr_cnt = 0;

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        twr_en  <= 1'b0;
        twr_cnt <= 27'd0;
    end
    else begin
        if (state == STOP && start_h)
            twr_en <= 1'b1;
        else if (twr_cnt == T_WR_CLK)
            twr_en <= 1'b0;
        else
            twr_en <= twr_en;
        
        if (state == STOP && start_h)
            twr_cnt <= 27'd0;
        else if (twr_en)
            twr_cnt <= twr_cnt + 1'b1;
        else
            twr_cnt <= 27'd0;
    end
end

//============================================================================
// Clock counter with async reset
//============================================================================
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        clk_cnt <= 16'd0;
    else if (clk_cnt == CLK_DIV - 1'b1)
        clk_cnt <= 16'd0;
    else
        clk_cnt <= clk_cnt + 1'b1;
end

//============================================================================
// SCL clock generation with async reset
//============================================================================
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        scl_out <= 1'b1;
    else if (state != IDLE && state != STOP) begin
        if (half_cycle || full_cycle)
            scl_out <= ~scl_out;
        else
            scl_out <= scl_out;
    end
    else
        scl_out <= 1'b1;
end

assign sda_out_en = ((state == S_ACK) || (state == RECEIV)) ? 1'b0 : 1'b1;

//============================================================================
// TX data control with async reset
//============================================================================
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        send_data <= 8'd0;
    else if (start)
        // First byte: device ID + write flag
        send_data <= {device_id[7:1], 1'b0};
    else if (state == S_ACK && dsu && trans_byte < trans_byte_max) begin
        if (ADDR_BYTE == 2'd1) begin
            case (trans_byte)
                5'd0 : send_data <= {device_id[7:1],1'b0};
                5'd1 : send_data <= addr[7:0];
                5'd2 : send_data <= (w_r_2d) ? data_in : {device_id[7:1],1'b1};
                default: send_data <= data_in;
            endcase
        end
        else begin
            case (trans_byte)
                5'd0 : send_data <= {device_id[7:1],1'b0};
                5'd1 : send_data <= addr[ 7:0];
                5'd2 : send_data <= addr[15:8];
                5'd3 : send_data <= (w_r_2d) ? data_in : {device_id[7:1],1'b1};
                default: send_data <= data_in;
            endcase
        end
    end
    else
        send_data <= send_data;
end

//============================================================================
// Transmit byte count max with async reset
//============================================================================
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        trans_byte_max <= 5'd0;
    else if (start) begin
        if (w_r_2d)
            trans_byte_max <= ADDR_BYTE + byte_len + 2'd1;
        else
            trans_byte_max <= ADDR_BYTE + byte_len + 2'd2;
    end
    else
        trans_byte_max <= trans_byte_max;
end

//============================================================================
// SDA output control with async reset
//============================================================================
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        sda_out <= 1'b1;
    else begin
        case (state)
            IDLE: begin
                sda_out <= 1'b1;
            end
            S_START: begin
                if (start_h)
                    sda_out <= 1'b0;
                else if (dsu)
                    sda_out <= send_data[7 - trans_bit];
                else
                    sda_out <= sda_out;
            end
            SEND: begin
                sda_out <= send_data[7 - trans_bit];
            end
            S_ACK: begin
                if (trans_byte == ID_ADDR_BYTE && dsu && !w_r_2d)
                    sda_out <= 1'b1;
                else
                    sda_out <= 1'b0;
            end
            R_ACK: begin
                if (trans_byte < trans_byte_max)
                    sda_out <= 1'b0;
                else begin
                    if (dsu)
                        sda_out <= 1'b0;
                    else
                        sda_out <= 1'b1;
                end
            end
            STOP: begin
                if (start_h)
                    sda_out <= 1'b1;
                else
                    sda_out <= sda_out;
            end
            default: sda_out <= 1'b1;
        endcase
    end
end

//============================================================================
// I2C read data with async reset
//============================================================================
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        receiv_data <= 8'd0;
    else if (state == RECEIV) begin
        if (full_cycle)
            receiv_data <= {receiv_data[6:0], sda_in};
        else
            receiv_data <= receiv_data;
    end
    else
        receiv_data <= 8'd0;
end

// Data output latch with async reset
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        data_out <= 8'd0;
    else if (state == RECEIV && trans_bit == 3'd7 && half_cycle)
        data_out <= receiv_data;
    else
        data_out <= data_out;
end

//============================================================================
// Byte over flag with async reset
//============================================================================
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        byte_over <= 1'b0;
    else if (w_r_2d) begin
        if (trans_byte > ID_ADDR_BYTE - 1'b1 && dsu && trans_bit == 3'd7)
            byte_over <= 1'b1;
        else
            byte_over <= 1'b0;
    end
    else begin
        if (trans_byte > ID_ADDR_BYTE && dsu && trans_bit == 3'd7)
            byte_over <= 1'b1;
        else
            byte_over <= 1'b0;
    end
end

//============================================================================
// Bit counter with async reset
//============================================================================
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        trans_bit <= 3'd0;
    else if (state == SEND || state == RECEIV) begin
        if (dsu)
            trans_bit <= trans_bit + 1'b1;
        else
            trans_bit <= trans_bit;
    end
    else
        trans_bit <= 3'd0;
end

//============================================================================
// Byte counter with async reset
//============================================================================
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        trans_byte <= 5'd0;
    else if (start)
        trans_byte <= 5'd0;
    else if (state == SEND || state == RECEIV) begin
        if (dsu && trans_bit == 3'd7)
            trans_byte <= trans_byte + 1'b1;
        else
            trans_byte <= trans_byte;
    end
    else
        trans_byte <= trans_byte;
end

//============================================================================
// FSM state register with async reset
//============================================================================
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        state <= IDLE;
    else
        state <= state_n;
end

//============================================================================
// FSM next state logic (combinational)
//============================================================================
always @(*) begin
    state_n = state;
    case (state)
        IDLE: begin
            if (start)
                state_n = S_START;
            else
                state_n = state;
        end
        S_START: begin
            if (dsu) 
                state_n = SEND;
            else
                state_n = state;
        end
        SEND: begin
            if (trans_bit == 3'd7 & dsu)
                state_n = S_ACK;
            else
                state_n = state;
        end
        S_ACK: begin
            if (dsu) begin
                if (w_r_2d) begin
                    if (trans_byte < ID_ADDR_BYTE)
                        state_n = SEND;
                    else if (trans_byte < trans_byte_max)
                        state_n = SEND;
                    else
                        state_n = STOP;
                end
                else begin
                    if (trans_byte < ID_ADDR_BYTE)
                        state_n = SEND;
                    else if (trans_byte == ID_ADDR_BYTE)
                        state_n = S_START;
                    else
                        state_n = RECEIV;
                end
            end
            else
                state_n = state;
        end
        RECEIV: begin
            if (trans_bit == 3'd7 & dsu)
                state_n = R_ACK;
            else
                state_n = state;
        end
        R_ACK: begin
            if (dsu) begin
                if (trans_byte < trans_byte_max)
                    state_n = RECEIV;
                else
                    state_n = STOP;
            end
            else
                state_n = state;
        end
        STOP: begin
            if (dsu)
                state_n = IDLE;
            else
                state_n = state;
        end
        default: state_n = IDLE;
    endcase
end

endmodule