module btb 
import rv32i_types::*;
#(
            parameter       s_offset = 2,
            parameter       s_index  = 2,
            parameter       s_tag    = 32 - s_offset - s_index,
            parameter       s_mask   = 2**s_offset,
            parameter       s_line   = 8*s_mask,
            parameter       num_sets = 2**s_index
)
(
    input                   clk,
    input                   rst,
    /* CPU side signals */
    input   logic   [31:0]  fetch_pc,
    input   rv32i_word  ex_pc,
    output   logic btb_miss,
    input   logic btb_write,
    output  logic   [31:0]  btb_rdata,
    input   logic   [31:0]  btb_wdata,
    input logic pc_stall
);
    logic   [31:0] data_d;

    logic [31:0] data_dout;
    logic [s_tag - 1:0] tag_dout;

    logic [s_index - 1:0] index_addr_rd , index_addr_w;
    logic [s_tag - 1:0] tag_addr_rd , tag_addr_w;
    
    logic hit_rd;
    logic hit_w;

    logic [31:0] data_array [num_sets];
    logic [s_tag - 1:0] tag_array [num_sets];

    assign btb_miss = ~hit_rd;

    assign index_addr_rd = fetch_pc[s_offset+s_index-1:s_offset];
    assign tag_addr_rd = fetch_pc[31:s_offset+s_index];
    assign index_addr_w = ex_pc[s_offset+s_index-1:s_offset];
    assign tag_addr_w = ex_pc[31:s_offset+s_index];
  
    // Read Logic
    always_comb begin
        btb_rdata = '0;
        hit_rd = '0;
        if(tag_array[index_addr_rd] == tag_addr_rd) begin 
            hit_rd = 1'b1;
            btb_rdata = data_dout;
        end
    end

    always_comb begin
        hit_w = '0;
        if(tag_dout[index_addr_w] == tag_addr_w) begin 
            hit_w = 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        
        if(btb_write & ~pc_stall) begin
            data_array[index_addr_w] <=  btb_wdata;
            tag_array[index_addr_w] <= tag_addr_w;
        end

        for(int i=0; i<num_sets ;i++)begin
            if(rst)begin
                data_array[i] <= '0;
                tag_array[i] <= '0;
            end
        end
    end


    always_comb begin
        data_dout = data_array[index_addr_rd];
        tag_dout =  tag_array[index_addr_rd];
    end

endmodule : btb