module mem_write
import rv32i_types::*;
(
    input EX_MEM ex_mem,
    input MEM_WB mem_wb_prev,
    output MEM_WB mem_wb_next,
    input rv32i_word dmem_rdata,

    //TO mem
    output logic dmem_read, dmem_write,
    output logic [3:0] dmem_wmask,
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    input  logic dmem_resp
);

// assign mem_wb struct signals

always_comb begin 
    if (ex_mem.done && ex_mem.valid) begin
        dmem_read = ex_mem.control_word.dmem_read;
        dmem_write = ex_mem.control_word.dmem_write;
        dmem_wdata = ex_mem.rs2_out << (8 * ex_mem.alu_out[1:0]);
        dmem_addr =  {ex_mem.alu_out[31:2], 2'b00};
        dmem_wmask = ex_mem.control_word.dmem_wmask << ex_mem.alu_out[1:0];
    end else begin
        dmem_read = '0;
        dmem_write = '0;
        dmem_wdata = '0;
        dmem_addr = '0;
        dmem_wmask = '0;
    end

    mem_wb_next.pc_rdata = ex_mem.pc_rdata;
    mem_wb_next.pc_wdata = ex_mem.pc_wdata;
    mem_wb_next.rs1 = ex_mem.rs1;
    mem_wb_next.rs2 = ex_mem.rs2;
    mem_wb_next.imem_rdata = ex_mem.imem_rdata;

    mem_wb_next.control_word = ex_mem.control_word;
    mem_wb_next.control_word.dmem_wmask = ex_mem.control_word.dmem_wmask << ex_mem.alu_out[1:0];
    mem_wb_next.control_word.dmem_rmask = ex_mem.control_word.dmem_rmask << ex_mem.alu_out[1:0];
    mem_wb_next.dmem_addr = ex_mem.alu_out;
    mem_wb_next.dmem_wdata = dmem_wdata;
    mem_wb_next.dmem_rdata = dmem_rdata;
    mem_wb_next.alu_out = ex_mem.alu_out;
    mem_wb_next.valid = ex_mem.valid;
    mem_wb_next.cmp_out = ex_mem.cmp_out;
    mem_wb_next.done = ex_mem.done & ((~dmem_read && ~dmem_write) || ((dmem_read || dmem_write) & dmem_resp)); //done is 'freshness' of data
    mem_wb_next.rs1_out = ex_mem.rs1_out;
    mem_wb_next.rs2_out = ex_mem.rs2_out;
    mem_wb_next.rd = ex_mem.rd;

    unique case (ex_mem.control_word.regfilemux_sel)
        regfilemux::alu_out: mem_wb_next.regfilemux_out = ex_mem.alu_out;
        regfilemux::br_en: mem_wb_next.regfilemux_out = {31'b0,ex_mem.cmp_out};
        regfilemux::pc_plus4: mem_wb_next.regfilemux_out = ex_mem.pc_rdata + 4;
        default: mem_wb_next.regfilemux_out = 32'h0000;
    endcase
    
end

endmodule : mem_write