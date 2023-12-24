module arbiter(
    input logic clk,
    input logic rst,

    input  logic  [31:0]     imem_address,
    input  logic             imem_read,
    input  logic             imem_write,
    output logic  [255:0]    imem_rdata,
    input  logic  [255:0]    imem_wdata,
    output logic             imem_resp,

    input  logic  [31:0]     dmem_address,
    input  logic             dmem_read,
    input  logic             dmem_write,
    output logic  [255:0]    dmem_rdata,
    input  logic  [255:0]    dmem_wdata,
    output logic             dmem_resp,

    output  logic  [31:0]     bmem_address,
    output  logic             bmem_read,
    output  logic             bmem_write,
    input   logic  [255:0]    bmem_rdata,
    output  logic  [255:0]    bmem_wdata,
    input   logic             bmem_resp
);

enum bit { IMEM, DMEM } state, next_state;

always_ff @ (posedge clk) begin
    state <= next_state;
    if (rst) state <= IMEM;
end

always_comb begin
    next_state = state;
    unique case (state)
        IMEM: begin
            if ((imem_read || imem_write) & ~imem_resp) next_state = IMEM;
            else if (dmem_read || dmem_write) next_state = DMEM;
        end
        DMEM: begin
            if ((dmem_read || dmem_write) & ~dmem_resp) next_state = DMEM;
            else if (imem_read || imem_write) next_state = IMEM;
        end
    endcase
end

always_comb begin
    bmem_address        = '0;
    bmem_read           = '0;
    bmem_write          = '0;
    bmem_wdata          = '0;
    imem_resp           = '0;
    imem_rdata          = '0;
    dmem_resp           = '0;
    dmem_rdata          = '0;
    unique case (state)
        IMEM: begin
            bmem_address        = imem_address;
            bmem_read           = imem_read;
            bmem_write          = imem_write;
            bmem_wdata          = imem_wdata;
            imem_rdata          = bmem_rdata;
            imem_resp           = bmem_resp;
        end
        DMEM: begin
            bmem_address        = dmem_address;
            bmem_read           = dmem_read;
            bmem_write          = dmem_write;
            bmem_wdata          = dmem_wdata;
            dmem_rdata          = bmem_rdata;
            dmem_resp           = bmem_resp;
        end
    endcase
end


endmodule