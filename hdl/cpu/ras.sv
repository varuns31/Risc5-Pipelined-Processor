module ras
import rv32i_types::*;
#(
    parameter RAS_SIZE = 8
)
(
    input logic clk, rst,
    input logic push, pop,
    input logic [31:0] addr_in,
    output logic [31:0] addr_out,
    output logic empty
);
`define RAS_INDEX $clog2(RAS_SIZE)

logic [31:0] stack[RAS_SIZE];
logic [`RAS_INDEX:0] top, bot; //one extra bit for wrap-around

always_ff @ (posedge clk) begin : STACK
    top <= top;
    bot <= bot;
    stack <= stack;
    if (rst) begin
        top <= '0;
        bot <= '0;
        for (int i = 0; i < RAS_SIZE; ++i) begin
            stack[i] <= '0;
        end
    end
    else begin
        if (push && pop) begin //popping while empty is UB
            stack[top-1] <= addr_in;
        end
        else if (push) begin
            stack[top] <= addr_in;
            top <= top + 1;
            if (top[`RAS_INDEX] != bot[`RAS_INDEX] && top[`RAS_INDEX-1:0] == bot[`RAS_INDEX-1:0]) bot <= bot + 1;
        end
        else if (pop) begin //popping while empty is UB
            top <= top - 1;
        end
    end
end

assign empty = (top == bot);
assign addr_out = stack[top-1];

`undef RAS_INDEX
endmodule