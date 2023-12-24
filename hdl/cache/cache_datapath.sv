module cache_datapath #(
            parameter       s_offset = 5,
            parameter       s_index  = 4,
            parameter       s_tag    = 32 - s_offset - s_index,
            parameter       s_mask   = 2**s_offset,
            parameter       s_line   = 8*s_mask,
            parameter       num_sets = 2**s_index
)(
    input clk,
    input rst,
    input [31:0] mem_address,
    input logic  mem_read,
    input logic  mem_write,
    input   logic   [31:0]  mem_byte_enable,
    input   logic   [255:0] pmem_rdata,
    input logic pmem_resp,
    input logic writetomem,
    output  logic   [255:0] mem_rdata,
    input   logic   [255:0] mem_wdata,
    input logic data_mux,
    input logic write_masked,
    input logic index_change,
    output logic hit,
    output logic hit_arr[2],
    output  logic   [31:0]  pmem_address,
    output   logic   [255:0] pmem_wdata,
    output logic dirty
);
    logic   [255:0] data_d;

    logic [255:0] data_dout [2];
    logic [22:0] tag_dout [2];

    logic [3:0] index_addr;
    logic [22:0] tag_addr;
    logic dirty_select;
    logic dirty_in,valid_in[2];
    logic dirty_out[2],valid_out[2];
    logic [1:0] way_choice;
    logic lru_in;
    logic lru_out;
    logic [31:0] mask;
    logic write_allow[2];

    always_comb begin
        write_allow = {0,0};
        for(int i=0;i<2;i++)begin
            write_allow[i] = ((mem_write & hit_arr[i] & write_masked) | (pmem_resp & way_choice[i] & data_mux));
        end
    end

    always_comb begin  
        if(mem_write & write_masked & hit) mask = mem_byte_enable;
        else mask = 32'hFFFFFFFF;
    end

    assign index_addr = mem_address[8:5];
    assign tag_addr = mem_address[31:9];

    always_comb begin : mem_return_data
        mem_rdata = pmem_rdata;
        for(int i=0;i<2;i++)begin
            if(hit_arr[i] == 1) mem_rdata = data_dout[i];
        end   
    end 

    always_comb begin : write_back
        pmem_wdata = 0;
        for(int i=0; i<2 ; i++)begin
            if(way_choice[i] == 1) pmem_wdata = data_dout[i];
        end
    end

    always_comb begin : data_in_block
        if(mem_write & write_masked & hit) data_d = mem_wdata;
        else data_d = pmem_rdata;
    end
    
    always_comb begin : lrublock
        lru_in = lru_out;
        if(hit_arr[0] & write_masked & (mem_read || mem_write))begin
            lru_in = 0;
        end
        else if(hit_arr[1] & write_masked & (mem_read || mem_write))begin
            lru_in = 1;
        end
    end

    always_comb begin : way
        case(lru_out)
        1'b0: way_choice = 2'b10;
        1'b1: way_choice = 2'b01;
        default: way_choice = 2'b00;
        endcase
    end
    
    genvar i;
    generate for (i = 0; i < 2; i++) begin : dirty_valid_arrays
    ff_array dirty_array(.clk0(clk),.rst0(rst),.csb0(1'b0),.web0(!write_allow[i]),.addr0(index_addr),.din0(dirty_in),.dout0(dirty_out[i]));
    ff_array valid(.clk0(clk),.rst0(rst),.csb0(1'b0),.web0(!write_allow[i]),.addr0(index_addr),.din0(1'b1),.dout0(valid_out[i]));
    end
    endgenerate

    ff_array lru(.clk0(clk),.rst0(rst),.csb0(1'b0),.web0(~hit),.addr0(index_addr),.din0(lru_in),.dout0(lru_out));

    always_comb begin
        hit_arr = {0,0};
        for(int i = 0; i < 2 ; i++) begin
            if(tag_dout[i] == tag_addr && valid_out[i] == 1) hit_arr[i] = 1;
            else hit_arr[i] = 0;    
        end
        hit = hit_arr[0] | hit_arr[1];
    end

    always_comb begin : dirty_check
        dirty = 0;
        for(int i=0 ; i < 2 ;i++)begin
            if(way_choice[i] & dirty_out[i] & valid_out[i]) dirty = 1;
        end
    end

    always_comb begin
        if(mem_write)dirty_in = 1'b1;
        else dirty_in = 1'b0;
    end 

    always_comb begin
        pmem_address =  {mem_address[31:5], 5'b00000};
        for(int i=0; i<2 ;i++)begin
            if(way_choice[i] & writetomem) pmem_address = {tag_dout[i], index_addr, 5'b00000};
        end
    end

    generate for (i = 0; i < 2; i++) begin : arrays
        mp3_data_array data_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       (!write_allow[i]),
            .wmask0     (mask),
            .addr0      (index_addr),
            .din0       (data_d),
            .dout0      (data_dout[i])
        );
        mp3_tag_array tag_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       (!write_allow[i]),
            .addr0      (index_addr),
            .din0       (tag_addr),
            .dout0      (tag_dout[i])
        );
    end endgenerate

endmodule : cache_datapath