module datapath
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    // Use these for CP1 (magic memory)
    output  logic   [31:0]  imem_address,
    output  logic           imem_read,
    input   logic   [31:0]  imem_rdata,
    input   logic           imem_resp,
    output  logic   [31:0]  dmem_address,
    output  logic           dmem_read,
    output  logic           dmem_write,
    output  logic   [3:0]   dmem_wmask,
    input   logic   [31:0]  dmem_rdata,
    output  logic   [31:0]  dmem_wdata,
    input   logic           dmem_resp,
    output  MEM_WB          mem_wb_cur,
    output logic    [31:0]  dp_regfilemux_out
);

IF_ID if_id_cur, if_id_next;
ID_EX id_ex_cur, id_ex_next;
EX_MEM ex_mem_cur, ex_mem_next;
MEM_WB mem_wb_next;

logic load_regfile;
logic bubble_prop;
logic mul_div_bubble;
rv32i_reg rs1, rs2, rd;
rv32i_word regfilemux_out, rs1_out, rs2_out;
logic ras_push, ras_pop, ras_empty;
logic [31:0] ras_addr_in, ras_addr_out;

logic btb_write;
logic [31:0] btb_rdata;
logic branch_mispredicted;
rv32i_word ex_pc_wdata;
rv32i_word ex_pc;
logic btb_miss;
logic pc_stall;

assign dp_regfilemux_out = regfilemux_out;

regfile regfile(.clk(clk),.rst(rst),.load(load_regfile),.in(regfilemux_out),.reg_a(rs1_out),.reg_b(rs2_out),.src_a(rs1),.src_b(rs2),.dest(rd));
ras RAS(.clk(clk), .rst(rst), .push(ras_push), .pop(ras_pop), .addr_in(ras_addr_in), .addr_out(ras_addr_out), .empty(ras_empty));


btb BTB(  
    .clk(clk), .rst(rst),
    .fetch_pc(if_id_next.pc_rdata), .ex_pc(ex_pc),
         .btb_write(btb_write),  .btb_wdata(ex_pc_wdata), .btb_rdata(btb_rdata),.btb_miss(btb_miss),.pc_stall(pc_stall)
);

logic [31:0] ex_alu_out;
logic dmem_stall;
assign dmem_stall = (dmem_read || dmem_write) & ~dmem_resp;

logic imem_stall;
assign imem_stall = (imem_read & ~imem_resp);

assign pc_stall = bubble_prop | mul_div_bubble | dmem_stall | imem_stall;


fetch FETCH(.clk(clk), .rst(rst), .alu_out(ras_pop ? ras_addr_out : ex_alu_out), .imem_resp(imem_resp), .imem_address(imem_address), .imem_rdata(imem_rdata), .imem_read(imem_read), .struct_out(if_id_next), .pc_stall(pc_stall),.br_taken(br_taken),.jalr_br_taken(jalr_br_taken || ras_pop),.branch_mispredicted(branch_mispredicted),.btb_miss(btb_miss),.btb_rdata(btb_rdata),.ex_pc_wdata(ex_pc_wdata));
Decode DECODE(.fetch_input(if_id_next), .decode_output(id_ex_next),.branch_mispredicted(branch_mispredicted), .any_stall(dmem_stall || imem_stall || bubble_prop || mul_div_bubble), .ras_empty(ras_empty), .ras_pop(ras_pop), .ras_push(ras_push), .ras_addr_in(ras_addr_in), .ras_addr_out(ras_addr_out));
execute EXECUTE(.clk(clk), .rst(rst), .rs1(rs1), .rs2(rs2), .rs1_out(rs1_out), .rs2_out(rs2_out), .struct_in(id_ex_cur), .struct_out(ex_mem_next), .alu_out(ex_alu_out),.fwd_mem_wb(mem_wb_cur),.fwd_ex_mem(ex_mem_cur),.bubble_prop(bubble_prop),.regfilemux_out(regfilemux_out), .mul_div_bubble(mul_div_bubble),.btb_write(btb_write),.ex_pc_wdata(ex_pc_wdata),.branch_mispredicted(branch_mispredicted),.ex_pc(ex_pc));
mem_write MEM_WRITE(.ex_mem(ex_mem_cur), .mem_wb_next(mem_wb_next), .dmem_read(dmem_read), .dmem_write(dmem_write), .dmem_wmask(dmem_wmask), .dmem_addr(dmem_address), .dmem_wdata(dmem_wdata), .mem_wb_prev(mem_wb_cur), .dmem_rdata(dmem_rdata), .dmem_resp(dmem_resp));
write_back WRITE_BACK(.mem_wb(mem_wb_cur), .rd(rd), .regfilemux_out(regfilemux_out), .load_regfile(load_regfile));

always_ff @ (posedge clk) begin
    if (rst) begin
        if_id_cur <= '{default: '0};
        id_ex_cur <= '{default: '0};
        ex_mem_cur <= '{default: '0};
        mem_wb_cur <= '{default: '0};
    end
    // MEM_WB stall
    else if (dmem_stall || imem_stall) begin
        mem_wb_cur.done <= 1'b0;
    end
    else if(bubble_prop || mul_div_bubble) begin
        if_id_cur <= if_id_cur;
        id_ex_cur <= id_ex_cur;
        ex_mem_cur <= ex_mem_next;
        mem_wb_cur <= mem_wb_next;
    end
    else begin
        if_id_cur <= if_id_next;
        id_ex_cur <= id_ex_next;
        ex_mem_cur <= ex_mem_next;
        mem_wb_cur <= mem_wb_next;
    end
end


endmodule