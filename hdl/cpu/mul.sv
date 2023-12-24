module mul
import rv32i_types::*;
(
    input logic clk, rst,
    input logic start,
    input logic [31:0] multiplicand, multiplier, // multiplicand x multiplier
    input mul_ops mulop,
    output logic [63:0] result, //output full 64 bits 
    output logic done
);

enum logic [2:0] {
    IDLE, //duh
    BUSY, //working thru middle bits
    SIGN_BIT, //sign bit (need to negate)
    CLEANUP, //add in two 1s - https://en.wikipedia.org/wiki/Binary_multiplier#Signed_integers
    DONE //signal done
} state, next_state;

/* 
We can avoid separate logic by extending the operands to 33 bits,
either signed or unsigned as appropriate, then truncating to 64
bits at the end, always performing a signed multiply
*/
integer count;
logic [32:0] m1, m2, m2_reg;
logic [65:0] product;
assign m1[31:0] = multiplicand;
assign m2[31:0] = multiplier;
always_comb begin : SIGN_EXTENSION
    unique case (mulop)
        mul_ss: begin m1[32] = multiplier[31]; m2[32] = multiplicand[31]; end
        mul_su: begin m1[32] = multiplier[31]; m2[32] = 1'b0; end
        mul_uu, mul_lo: begin m1[32] = 1'b0; m2[32] = 1'b0; end //sign doesn't matter for lower 32 bits
    endcase
end

always_ff @ (posedge clk) begin : MULTIPLIER_SHIFT_REGISTER
    m2_reg <= m2;
    if (rst) m2_reg <= '0;
    else if (state == BUSY || state == SIGN_BIT) m2_reg <= {1'b0, m2_reg[32:1]};
end




always_ff @ (posedge clk) begin : STATE_ASSIGNMENT
    state <= next_state;
    if (rst) state <= IDLE;
end

always_comb begin : NEXT_STATE_ASSIGNMENT
    next_state = state;
    unique case (state)
        IDLE: if (start) next_state = BUSY;
        BUSY: if (count == 32'd31) next_state = SIGN_BIT;
        SIGN_BIT: next_state = CLEANUP;
        CLEANUP: next_state = DONE;
        DONE: next_state = IDLE;
        default:;
    endcase
end

always_ff @ (posedge clk) begin : COUNTING
    count <= '0;
    if (state == BUSY) count <= count + 1;
end

//Shift-add multiplier
logic [32:0] cur_product;
always_comb begin : CURRENT_PRODUCT
    cur_product = '0;
    if (state == BUSY && m2_reg[0]) cur_product = {~m1[32], m1[31:0]};
    else if (state == SIGN_BIT && m2_reg[0]) cur_product = {m1[32], ~m1[31:0]}; //negation for sign bit
end

//see wikipedia page
`define MAGIC_NUMBER {1'b1, 31'b0, 1'b1, 33'b0}
always_ff @ (posedge clk) begin : PRODUCT_ACCUMULATION
    if (rst) product <= '0;
    else unique case (state)
        IDLE: if (start) product <= '0;
        BUSY, SIGN_BIT: begin
            //shift lower bits
            product[31:0] <= product[32:1];
            //shift upper bits and add current product
            product[65:32] <= {1'b0, product[65:33]} + {1'b0, cur_product}; //need to perserve carry
        end
        CLEANUP: begin
            product <= product + `MAGIC_NUMBER;
        end
        DONE:;
        default:;
    endcase
end
`undef MAGIC_NUMBER

assign result = product[63:0];
assign done = (state == DONE);

endmodule