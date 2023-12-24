module cmp
import rv32i_types::*;
(
    input branch_funct3_t cmpop,
    input rv32i_word rs1_out, cmp_in,
    output logic br_en
);

always_comb
begin
    unique case (cmpop)
        beq:  br_en = (rs1_out == cmp_in);
        bne:  br_en = (rs1_out != cmp_in);
        blt:  br_en = ($signed(rs1_out) < $signed(cmp_in));
        bge:  br_en = ($signed(rs1_out) >= $signed(cmp_in));
        bltu: br_en = (rs1_out < cmp_in);
        bgeu: br_en = (rs1_out >= cmp_in);
        default: br_en = '0;
    endcase
end

endmodule : cmp