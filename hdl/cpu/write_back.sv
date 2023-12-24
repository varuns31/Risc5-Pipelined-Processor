module write_back
import rv32i_types::*;
(
    input MEM_WB mem_wb,

    // Regfile signals
    output logic [4:0] rd,
    output logic [31:0] regfilemux_out,
    output load_regfile
);

assign load_regfile = mem_wb.control_word.load_regfile & mem_wb.done & mem_wb.valid;
assign rd = mem_wb.rd;

logic [31:0] i_imm, s_imm, b_imm, u_imm, j_imm;
logic [31:0] data;
rv32i_word dmem_rdata;

assign dmem_rdata = mem_wb.dmem_rdata;
assign data = mem_wb.imem_rdata;
assign i_imm = {{21{data[31]}}, data[30:20]};
assign s_imm = {{21{data[31]}}, data[30:25], data[11:7]};
assign b_imm = {{20{data[31]}}, data[7], data[30:25], data[11:8], 1'b0};
assign u_imm = {data[31:12], 12'h000};
assign j_imm = {{12{data[31]}}, data[19:12], data[20], data[30:21], 1'b0};
always_comb begin

    unique case (mem_wb.control_word.regfilemux_sel)
        regfilemux::u_imm: regfilemux_out = u_imm;
        regfilemux::lw: regfilemux_out = dmem_rdata;
        regfilemux::lb: begin
            case(mem_wb.dmem_addr[1:0])
                2'b00: regfilemux_out = {{24{dmem_rdata[7]}}, dmem_rdata[7:0]};
                2'b01: regfilemux_out = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                2'b10: regfilemux_out = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                2'b11: regfilemux_out = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                default: regfilemux_out = 32'h00000000;
            endcase
        end
        regfilemux::lbu: begin
            case(mem_wb.dmem_addr[1:0])
                2'b00: regfilemux_out = {24'h000000, dmem_rdata[7:0]};
                2'b01: regfilemux_out = {24'h000000, dmem_rdata[15:8]};
                2'b10: regfilemux_out = {24'h000000, dmem_rdata[23:16]};
                2'b11: regfilemux_out = {24'h000000, dmem_rdata[31:24]};
                default: regfilemux_out = 32'h00000000;
            endcase
        end
        regfilemux::lh: begin
            case(mem_wb.dmem_addr[1])
                1'b0: regfilemux_out = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
                1'b1: regfilemux_out = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
                default: regfilemux_out = 32'h00000000;
            endcase
        end
        regfilemux::lhu: begin
            case(mem_wb.dmem_addr[1])
                1'b0: regfilemux_out = {16'h0000, dmem_rdata[15:0]};
                1'b1: regfilemux_out = {16'h0000, dmem_rdata[31:16]};
                default: regfilemux_out = 32'h00000000;
            endcase
        end
        default: regfilemux_out = mem_wb.regfilemux_out;
        // etc.
    endcase

end


endmodule : write_back