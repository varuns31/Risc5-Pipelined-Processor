module cp2_cache(
    input logic clk,
    input logic rst,
    input  logic   [31:0]  imem_address,
    input  logic           imem_read,
    output   logic   [31:0]  imem_rdata,
    output   logic           imem_resp,
    input  logic   [31:0]  dmem_address,
    input  logic           dmem_read,
    input  logic           dmem_write,
    input  logic   [3:0]   dmem_wmask,
    output   logic   [31:0]  dmem_rdata,
    input  logic   [31:0]  dmem_wdata,
    output   logic           dmem_resp,
    output  logic   [31:0]  bmem_address,
    output  logic           bmem_read,
    output  logic           bmem_write,
    input   logic   [63:0]  bmem_rdata,
    output  logic   [63:0]  bmem_wdata,
    input   logic           bmem_resp
);

logic [255:0] imem_rdata256, dmem_rdata256, dmem_wdata256;
logic [31:0] dmem_byte_enable256;

logic [31:0] ipmem_address, dpmem_address;
logic ipmem_read, ipmem_write, dpmem_read, dpmem_write;
logic [255:0] ipmem_rdata256, ipmem_wdata256, dpmem_rdata256, dpmem_wdata256;
logic ipmem_resp, dpmem_resp;

bus_adapter ibus(
    .address(imem_address),
    .mem_rdata256(imem_rdata256),
    .mem_rdata(imem_rdata),
    .mem_wdata(32'b0),
    .mem_byte_enable(4'b1111)
);

bus_adapter dbus(
    .address(dmem_address),
    .mem_rdata256(dmem_rdata256),
    .mem_wdata256(dmem_wdata256),
    .mem_rdata(dmem_rdata),
    .mem_wdata(dmem_wdata),
    .mem_byte_enable(dmem_wmask),
    .mem_byte_enable256(dmem_byte_enable256)
);

logic hit_i;
logic hit_arr_i [2];
logic data_mux_i;
logic dirty_i;
logic writetomem_i;
logic write_masked_i;
logic hit_d;
logic hit_arr_d [2];
logic data_mux_d;
logic dirty_d;
logic writetomem_d;
logic write_masked_d;
logic index_change_i;
logic index_change_d;


cache_datapath icache(
    .clk(clk),
    .rst(rst),
    /* CPU side signals */
    .mem_address(imem_address),
    .mem_read(imem_read),
    .mem_write(1'b0),
    .mem_byte_enable(32'hFFFFFFFF),
    .pmem_rdata(ipmem_rdata256),
    .pmem_resp(ipmem_resp),
    .writetomem(writetomem_i),
    .mem_rdata(imem_rdata256),
    .mem_wdata(256'b0),
    .data_mux(data_mux_i),
    .write_masked(write_masked_i),
    .hit(hit_i),
    .index_change(index_change_i),
    .hit_arr(hit_arr_i),
    .pmem_address(ipmem_address),
    .pmem_wdata(ipmem_wdata256),
    .dirty(dirty_i)
);

cache_control icachecontrol(
    .clk(clk),
    .rst(rst),
    /* CPU side signals */
    .mem_address(imem_address),
    .mem_read(imem_read),
    .mem_write(1'b0),
    .hit(hit_i),
    .pmem_resp(ipmem_resp),
    .hit_arr(hit_arr_i),
    .dirty(dirty_i),
    .index_change(index_change_i),
    .pmem_read(ipmem_read),
    .pmem_write(ipmem_write),
    .mem_resp(imem_resp),
    .data_mux(data_mux_i),
    .writetomem(writetomem_i),
    .write_masked(write_masked_i)
);

cache_datapath dcache(
    .clk(clk),
    .rst(rst),
    /* CPU side signals */
    .mem_address(dmem_address),
    .mem_read(dmem_read),
    .mem_write(dmem_write),
    .mem_byte_enable(dmem_byte_enable256),
    .pmem_rdata(dpmem_rdata256),
    .index_change(index_change_d),
    .pmem_resp(dpmem_resp),
    .writetomem(writetomem_d),
    .mem_rdata(dmem_rdata256),
    .mem_wdata(dmem_wdata256),
    .data_mux(data_mux_d),
    .write_masked(write_masked_d),
    .hit(hit_d),
    .hit_arr(hit_arr_d),
    .pmem_address(dpmem_address),
    .pmem_wdata(dpmem_wdata256),
    .dirty(dirty_d)
);

cache_control dcachecontrol(
    .clk(clk),
    .rst(rst),
    /* CPU side signals */
    .mem_address(dmem_address),
    .mem_read(dmem_read),
    .mem_write(dmem_write),
    .hit(hit_d),
    .pmem_resp(dpmem_resp),
    .hit_arr(hit_arr_d),
    .dirty(dirty_d),
    .index_change(index_change_d),
    .pmem_read(dpmem_read),
    .pmem_write(dpmem_write),
    .mem_resp(dmem_resp),
    .data_mux(data_mux_d),
    .writetomem(writetomem_d),
    .write_masked(write_masked_d)
);

logic [31:0] bmem_address_linear;
logic bmem_read_linear, bmem_write_linear;
logic [255:0] bmem_rdata256, bmem_wdata256;
logic bmem_resp_linear;

arbiter arb(
    .clk(clk),
    .rst(rst),

    .imem_address(ipmem_address),
    .imem_read(ipmem_read),
    .imem_write(ipmem_write),
    .imem_rdata(ipmem_rdata256),
    .imem_wdata(ipmem_wdata256),
    .imem_resp(ipmem_resp),

    .dmem_address(dpmem_address),
    .dmem_read(dpmem_read),
    .dmem_write(dpmem_write),
    .dmem_rdata(dpmem_rdata256),
    .dmem_wdata(dpmem_wdata256),
    .dmem_resp(dpmem_resp),

    .bmem_address(bmem_address_linear),
    .bmem_read(bmem_read_linear),
    .bmem_write(bmem_write_linear),
    .bmem_rdata(bmem_rdata256),
    .bmem_wdata(bmem_wdata256),
    .bmem_resp(bmem_resp_linear)
);

cacheline_adaptor ca(
    .clk(clk),
    .reset_n(~rst),

    // Port to LLC (Lowest Level Cache)
    .line_i(bmem_wdata256),
    .line_o(bmem_rdata256),
    .address_i(bmem_address_linear),
    .read_i(bmem_read_linear),
    .write_i(bmem_write_linear),
    .resp_o(bmem_resp_linear),

    // Port to memory
    .burst_i(bmem_rdata),
    .burst_o(bmem_wdata),
    .address_o(bmem_address),
    .read_o(bmem_read),
    .write_o(bmem_write),
    .resp_i(bmem_resp)
);

endmodule