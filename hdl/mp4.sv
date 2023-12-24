module mp4
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    // // Use these for CP1 (magic memory)
    // output  logic   [31:0]  imem_address,
    // output  logic           imem_read,
    // input   logic   [31:0]  imem_rdata,
    // input   logic           imem_resp,
    // output  logic   [31:0]  dmem_address,
    // output  logic           dmem_read,
    // output  logic           dmem_write,
    // output  logic   [3:0]   dmem_wmask,
    // input   logic   [31:0]  dmem_rdata,
    // output  logic   [31:0]  dmem_wdata,
    // input   logic           dmem_resp

    // Use these for CP2+ (with caches and burst memory)
    output  logic   [31:0]  bmem_address,
    output  logic           bmem_read,
    output  logic           bmem_write,
    input   logic   [63:0]  bmem_rdata,
    output  logic   [63:0]  bmem_wdata,
    input   logic           bmem_resp
);

            logic           monitor_valid;
            logic   [63:0]  monitor_order;
            logic   [31:0]  monitor_inst;
            logic   [4:0]   monitor_rs1_addr;
            logic   [4:0]   monitor_rs2_addr;
            logic   [31:0]  monitor_rs1_rdata;
            logic   [31:0]  monitor_rs2_rdata;
            logic   [4:0]   monitor_rd_addr;
            logic   [31:0]  monitor_rd_wdata;
            logic   [31:0]  monitor_pc_rdata;
            logic   [31:0]  monitor_pc_wdata;
            logic   [31:0]  monitor_mem_addr;
            logic   [3:0]   monitor_mem_rmask;
            logic   [3:0]   monitor_mem_wmask;
            logic   [31:0]  monitor_mem_rdata;
            logic   [31:0]  monitor_mem_wdata;


    // Fill this out
    // Only use hierarchical references here for verification
    // **DO NOT** use hierarchical references in the actual design!

    MEM_WB mem_wb;

    logic [31:0] imem_address, dmem_address;
    logic imem_read, imem_write, dmem_read, dmem_write;
    logic imem_resp, dmem_resp;
    logic [31:0] imem_rdata, dmem_rdata, dmem_wdata;
    logic [3:0] dmem_wmask;
    logic [31:0] dp_regfilemux_out;

    cp2_cache cache(
        .clk(clk),
        .rst(rst),
        .imem_address(imem_address),
        .imem_read(imem_read),
        .imem_rdata(imem_rdata),
        .imem_resp(imem_resp),
        .dmem_address(dmem_address),
        .dmem_read(dmem_read),
        .dmem_write(dmem_write),
        .dmem_wmask(dmem_wmask),
        .dmem_rdata(dmem_rdata),
        .dmem_wdata(dmem_wdata),
        .dmem_resp(dmem_resp),
        .bmem_address(bmem_address),
        .bmem_read(bmem_read),
        .bmem_write(bmem_write),
        .bmem_rdata(bmem_rdata),
        .bmem_wdata(bmem_wdata),
        .bmem_resp(bmem_resp)
    );

    datapath datapath(
        .clk(clk),
        .rst(rst),
        .imem_address(imem_address),
        .imem_read(imem_read),
        .imem_rdata(imem_rdata),
        .imem_resp(imem_resp),
        .dmem_address(dmem_address),
        .dmem_read(dmem_read),
        .dmem_write(dmem_write),
        .dmem_wmask(dmem_wmask),
        .dmem_rdata(dmem_rdata),
        .dmem_wdata(dmem_wdata),
        .dmem_resp(dmem_resp),
        .mem_wb_cur(mem_wb), 
        .dp_regfilemux_out(dp_regfilemux_out)
        
    );
    /* Helper signals */
    logic commit;
    assign commit = mem_wb.done & mem_wb.valid;

    logic [63:0] order;
    always_ff @(posedge clk ) begin
        order <= order;
        if(rst) order <= '0;
        else if(commit) order <= order + 1;
    end

    /* An instruction is retired when it leaves the write_back stage */

    assign monitor_valid     = commit;
    assign monitor_order     = order;
    assign monitor_inst      = mem_wb.imem_rdata;
    assign monitor_rs1_addr  = mem_wb.rs1;
    assign monitor_rs2_addr  = mem_wb.rs2;
    assign monitor_rs1_rdata = monitor_rs1_addr ? mem_wb.rs1_out : 0; //reg0 always 0
    assign monitor_rs2_rdata = monitor_rs2_addr ? mem_wb.rs2_out : 0; //reg0 always 0
    assign monitor_rd_addr   = mem_wb.control_word.load_regfile ? mem_wb.rd : 5'h0; //don't always touch regfile
    assign monitor_rd_wdata  = monitor_rd_addr ? dp_regfilemux_out : 0;
    assign monitor_pc_rdata  = mem_wb.pc_rdata;
    assign monitor_pc_wdata  = mem_wb.pc_wdata; //this should intially be pc+4, but change on branch in exe stage
    //Load/store signals
    assign monitor_mem_addr  = {mem_wb.dmem_addr[31:2], 2'b00}; //load/store mem address, not pc address
    assign monitor_mem_rmask = mem_wb.control_word.dmem_rmask;
    assign monitor_mem_wmask = mem_wb.control_word.dmem_wmask;
    assign monitor_mem_rdata = mem_wb.dmem_rdata;
    assign monitor_mem_wdata = mem_wb.dmem_wdata;


endmodule : mp4
