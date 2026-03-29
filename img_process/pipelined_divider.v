`timescale 1ps/1ps

module pipelined_divider #(
    parameter W = 16
)(
    input wire clk,
    input wire rst_n,
    input wire [W-1:0] dividend,
    input wire [W-1:0] divisor,
    output wire [W-1:0] quotient
);
    reg [W-1:0] q_pipe [0:W];
    reg [W-1:0] d_pipe [0:W];
    reg [2*W-1:0] r_pipe [0:W];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0; i<=W; i=i+1) begin
                q_pipe[i] <= 0;
                d_pipe[i] <= 0;
                r_pipe[i] <= 0;
            end
        end else begin
            // Stage 0: 载入数据
            q_pipe[0] <= 0;
            d_pipe[0] <= divisor;
            r_pipe[0] <= {{W{1'b0}}, dividend};

            // Stage 1 to W: 移位相减
            for (i=0; i<W; i=i+1) begin
                d_pipe[i+1] <= d_pipe[i];
                if ( {r_pipe[i][2*W-2:0], 1'b0} >= {d_pipe[i], {W{1'b0}}} ) begin
                    r_pipe[i+1] <= {r_pipe[i][2*W-2:0], 1'b0} - {d_pipe[i], {W{1'b0}}};
                    q_pipe[i+1] <= {q_pipe[i][W-2:0], 1'b1};
                end else begin
                    r_pipe[i+1] <= {r_pipe[i][2*W-2:0], 1'b0};
                    q_pipe[i+1] <= {q_pipe[i][W-2:0], 1'b0};
                end
            end
        end
    end
    assign quotient = q_pipe[W];
endmodule