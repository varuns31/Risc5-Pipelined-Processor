module div
import rv32i_types::*;
(
    input logic clk, rst,
    input logic [31:0] dividend, divisor, //dividend / divisor
    input div_ops divop,
    input logic start,
    output logic [31:0] quotient, remainder,
    output logic done
);

enum logic [1:0] {
    IDLE,
    BUSY,
    CLEANUP,
    DONE
} state, next_state;

/*
Unsigned division is easy using long division. Signed division is implemented as
(-1) ** (sign(dividend) ^ sign(divisor)) * (abs(dividend) / abs(divisor)). Note that
the 'error' states, divide by zero and -2^31/-1, naturally resolve to the expected
values per the spec without needing special cases in the algorithm
*/
logic [31:0] count;
logic [31:0] numer, denom;
logic numer_sign, denom_sign;
assign numer_sign = dividend[0];
assign denom_sign = divisor[0];
always_comb begin : UNSIGNED_CONVERSION
    unique case (divop)
        div_signed, rem_signed: begin
            numer = (numer_sign) ? (~dividend) + 1 : dividend;
            denom = (denom_sign) ? (~divisor) + 1 : divisor;
        end
        div_unsigned, rem_unsigned: begin
            numer = dividend;
            denom = divisor;
        end
    endcase
end

always_ff @ (posedge clk) begin : STATE_ASSIGNMENT
    state <= next_state;
    if (rst) state <= IDLE;
end

always_comb begin : NEXT_STATE_ASSIGNMENT
    next_state = state;
    unique case (state)
        IDLE: if (start) next_state = BUSY;
        BUSY: if (count == 32'd1) next_state = CLEANUP;
        CLEANUP: next_state = DONE;
        DONE: next_state = IDLE;
    endcase
end

always_ff @ (posedge clk) begin : COUNTING
    count <= 32'd32;
    if (state == BUSY) count <= count - 1;
end

logic [31:0] quo, rem, rem_temp;
assign rem_temp = {rem[30:0], numer[count-1]};
always_ff @ (posedge clk) begin : LONG_DIVISION
    if (rst) begin quo <= '0; rem <= '0; end
    else unique case (state)
        IDLE: if (start) begin quo <= '0; rem <= '0; end
        BUSY: begin
            rem <= rem_temp;
            if (rem_temp >= denom) begin
                rem <= rem_temp- denom;
                quo[count-1] <= 1'b1;
            end
        end
        CLEANUP: begin
            if ((divop == div_signed || divop == rem_signed)) begin
                if (numer_sign ^ denom_sign) quo <= (~quo) + 1;
                if (numer_sign) rem <= (~rem) + 1;
            end
        end
        DONE:;
    endcase
end

assign quotient = quo;
assign remainder = rem;
assign done = (state == DONE);

endmodule