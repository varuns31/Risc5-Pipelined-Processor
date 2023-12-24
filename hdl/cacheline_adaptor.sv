module cacheline_adaptor
(
    input clk,
    input reset_n,

    // Port to LLC (Lowest Level Cache)
    input logic [255:0] line_i,
    output logic [255:0] line_o,
    input logic [31:0] address_i,
    input read_i,
    input write_i,
    output logic resp_o,

    // Port to memory
    input logic [63:0] burst_i,
    output logic [63:0] burst_o,
    output logic [31:0] address_o,
    output logic read_o,
    output logic write_o,
    input resp_i
);



enum int unsigned {
    /* List of states */
    idle, r1, r2, r3, r4, w1, w2, w3, w4, rdone, wdone
} state, next_states;


/************************* Function Definitions *******************************/

function void set_defaults();
        resp_o = 1'b0;
        read_o = 1'b0;
        write_o = 1'b0;
        address_o = {address_i[31:5], 5'b00000};
        burst_o = '0;
endfunction

/*****************************************************************************/

    /* Remember to deal with rst signal */
always_comb
begin : state_actions
    /* Default output assignments */
    set_defaults();
    /* Actions for each state */
    case(state)
        idle : begin
               
            end
        // Read actions
        r1: begin
            read_o = 1'b1;
        end
        r2: begin
            read_o = 1'b1;
        end
        r3: begin
            read_o = 1'b1;
        end
        r4: begin
            read_o = 1'b1;
        end
        rdone : begin
            resp_o = 1'b1;
        end


        // Write Actions
        w1: begin
            burst_o = line_i[63:0];
            write_o = 1'b1;
        end
        w2: begin
            burst_o = line_i[127:64];
            write_o = 1'b1;
        end
        w3: begin
            burst_o = line_i[191:128];
            write_o = 1'b1;
        end
        w4: begin
            burst_o = line_i[255:192];
            write_o = 1'b1;
        end
        wdone : begin
            resp_o = 1'b1;
        end

        default: ;
    endcase
end



/* Remember to deal with rst signal */
always_ff @(posedge clk)
begin : state_actions_ff
    /* Actions for each state */
    if(~reset_n) begin
        line_o <= '0;
    end
    case(state)
        // Read actions
        idle: line_o <= '0;
        r1: begin
            if(resp_i)
                line_o[63:0] <= burst_i;
        end
        r2: begin
            line_o[127:64] <= burst_i;
        end
        r3: begin
            line_o[191:128] <= burst_i;
        end
        r4: begin
            line_o[255:192] <= burst_i;
        end
        default: ;
    endcase
end


always_comb
begin : next_state_logic
    /* Next state information and conditions (if any)
     * for transitioning between states */
    next_states = idle;
    case (state)
        // write all the next state logic based on this
        idle : begin if (read_i)
                        next_states = r1;
                    if (write_i)
                        next_states = w1;
                end

        r1: begin if(resp_i)
                    next_states = r2;
                else 
                    next_states = r1;
            end
        r2: next_states = r3;
        r3: next_states = r4;
        r4: next_states = rdone;

        w1: begin if(resp_i)
                    next_states = w2;
                else 
                    next_states = w1;
            end
        w2: next_states = w3;
        w3: next_states = w4;
        w4: next_states = wdone;

        rdone : next_states = idle;
        wdone : next_states = idle;
        default: ;
     endcase

end

always_ff @(posedge clk)
begin: next_state_assignment
    /* Assignment of next state on clock edge */
    if(~reset_n) begin
        state <= idle;
    end else begin 
        state <= next_states;
    end
end


endmodule : cacheline_adaptor
