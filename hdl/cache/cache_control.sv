module cache_control (
    input clk,
    input rst,
    input [31:0] mem_address,
    input logic mem_read,
    input logic mem_write,
    input logic hit,
    input logic pmem_resp,
    input logic hit_arr [2],
    input logic dirty,
    output logic pmem_read,
    output logic pmem_write,
    output logic mem_resp,
    output logic data_mux,
    output logic writetomem,
    output logic write_masked,
    output logic index_change
);

logic [3:0] index_curr;
logic [3:0] index_prev;

assign index_curr = mem_address[8:5];

enum int unsigned {
    compare_tag,write_allocate,write_back,delay
    /* List of states */
} state, next_state;


function void set_defaults();
    mem_resp = 0;
    pmem_read = 0;
    pmem_write = 0;
    data_mux = 0;
    writetomem = 0;
    write_masked = 0;
endfunction

always_comb
begin : state_actions
    /* Default output assignments */
    set_defaults();
    case(state)
        compare_tag:begin 
            if(hit && index_change);
            else if(hit && (mem_read || mem_write)) mem_resp = 1;
            if(~index_change) write_masked = 1;
        end
        write_allocate:begin
            pmem_read = 1;
            data_mux = 1;
        end 
        write_back:begin
            pmem_write = 1;
            writetomem = 1;
        end
        delay:begin
            if(hit) mem_resp = 1;
            write_masked = 1;
        end
        default:;
    endcase
end

always_comb
begin : next_state_logic
    
    next_state = compare_tag;
    case(state)
        compare_tag:begin
            if (index_change && (mem_write || mem_read))
                next_state = delay;
            else if(~hit && (mem_write || mem_read)) begin
				if(dirty)
                    next_state = write_back;
                else
                    next_state = write_allocate;
			end
            else  
                next_state = compare_tag;
        end
        write_allocate:begin
            if(pmem_resp) begin
                next_state = compare_tag;
            end
            else begin
                next_state = write_allocate;
            end
        end
        write_back:begin
            if(pmem_resp)begin
                next_state = write_allocate;
            end
            else begin
                next_state = write_back;
            end
        end
        delay:begin
            if(~hit && (mem_write || mem_read)) begin
				if(dirty)
                    next_state = write_back;
                else
                    next_state = write_allocate;
			end
            else  
                next_state = compare_tag;
        end
        default:begin
            next_state = compare_tag;
        end
    endcase
end

always_ff @(posedge clk)
begin: next_state_assignment
    /* Assignment of next state on clock edge */
    state <= next_state;
end

always_ff @(posedge clk)
begin
    index_prev <= index_curr;
end

always_comb begin
    if(index_curr != index_prev)
        index_change = 1'b1;
    else    
        index_change = 1'b0;
end

endmodule : cache_control