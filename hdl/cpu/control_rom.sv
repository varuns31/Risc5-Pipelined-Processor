module control_rom
import rv32i_types::*;
(   

    input rv32i_opcode opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input rv32i_word data,
    output rv32i_control_word control_word
);
branch_funct3_t branch_funct3;
store_funct3_t store_funct3;
load_funct3_t load_funct3;
arith_funct3_t arith_funct3;
logic [31:0] i_imm;
logic [31:0] s_imm;
logic [31:0] b_imm;
logic [31:0] u_imm;
logic [31:0] j_imm;

assign arith_funct3 = arith_funct3_t'(funct3);
assign branch_funct3 = branch_funct3_t'(funct3);
assign load_funct3 = load_funct3_t'(funct3);
assign store_funct3 = store_funct3_t'(funct3);
assign control_word.opcode = opcode;
assign control_word.funct3 = funct3;
assign control_word.funct7 = funct7;
assign i_imm = {{21{data[31]}}, data[30:20]};
assign s_imm = {{21{data[31]}}, data[30:25], data[11:7]};
assign b_imm = {{20{data[31]}}, data[7], data[30:25], data[11:8], 1'b0};
assign u_imm = {data[31:12], 12'h000};
assign j_imm = {{12{data[31]}}, data[19:12], data[20], data[30:21], 1'b0};

function void set_defaults();

    // ID
    control_word.alumux1_sel = alumux::rs1_out;
    control_word.alumux2_sel = alumux::i_imm;
    control_word.cmpmux_sel = cmpmux::rs2_out;
    control_word.load_data_out = 1'b0;

    // EX
    control_word.aluop = alu_ops'(funct3);
    control_word.mulop = mul_ops'(funct3[1:0]);
    control_word.divop = div_ops'(funct3[1:0]);
    control_word.cmpop = branch_funct3_t'(funct3);

    // MEM
    control_word.dmem_read = 1'b0;
    control_word.dmem_write = 1'b0;
    control_word.dmem_wmask = 4'b0000;
    control_word.dmem_rmask = 4'b0000;

    // WB
    control_word.regfilemux_sel = regfilemux::alu_out;
    control_word.load_regfile = 1'b0;
    control_word.marmux_sel = marmux::pc_out;
    control_word.load_mar = 1'b0;

endfunction

function void setALU(alumux::alumux1_sel_t sel1, alumux::alumux2_sel_t sel2, logic setop, alu_ops op);
    /* Student code here */
    if (setop)
	begin
        control_word.aluop = op; // else default value
		control_word.alumux1_sel = sel1;
		control_word.alumux2_sel = sel2;
	end
    else
    begin
        control_word.aluop = alu_add;
        control_word.alumux1_sel = alumux::rs1_out;
        control_word.alumux2_sel = alumux::i_imm;
    end

endfunction

function void setCMP(cmpmux::cmpmux_sel_t sel, branch_funct3_t op);
    control_word.cmpmux_sel = sel;
    control_word.cmpop = op;
endfunction

function void loadRegfile(regfilemux::regfilemux_sel_t sel);
    control_word.regfilemux_sel = sel;
    control_word.load_regfile = 1'b1;
endfunction

function void loadDataout();
	control_word.load_data_out = 1'b1;
endfunction

function void loadMAR(marmux::marmux_sel_t sel);
    control_word.load_mar = 1'b1;
    control_word.marmux_sel = sel;
endfunction

always_comb
begin
    set_defaults();
    case(opcode)
        op_auipc: begin
            setALU(alumux::pc_out, alumux::u_imm, 1'b1, alu_add);
            loadRegfile(regfilemux::alu_out);
        end
        op_lui: begin
            loadRegfile(regfilemux::u_imm);
        end
        op_jal: begin 
            loadRegfile(regfilemux::pc_plus4);
            setALU(alumux::pc_out, alumux::j_imm, 1'b1, alu_add);
        end
        op_jalr: begin 
            loadRegfile(regfilemux::pc_plus4);
            setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_add);
        end
        op_load: begin
            setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_add);
            loadMAR(marmux::alu_out);
            control_word.dmem_read = 1'b1;
            case (load_funct3)
                lb:begin loadRegfile(regfilemux::lb); control_word.dmem_rmask = 4'b0001; end
                lh:begin loadRegfile(regfilemux::lh); control_word.dmem_rmask = 4'b0011; end
                lw:begin loadRegfile(regfilemux::lw); control_word.dmem_rmask = 4'b1111; end
                lbu:begin loadRegfile(regfilemux::lbu); control_word.dmem_rmask = 4'b0001; end
                lhu:begin loadRegfile(regfilemux::lhu); control_word.dmem_rmask = 4'b0011; end
                default:begin loadRegfile(regfilemux::lw); control_word.dmem_rmask = 4'b1111; end
            endcase

        end

        op_store: begin
            control_word.dmem_write = 1'b1; 
            setALU(alumux::rs1_out, alumux::s_imm, 1'b1, alu_add);
            loadMAR(marmux::alu_out);
            loadDataout();
            case (store_funct3)
                sb:control_word.dmem_wmask = 4'b0001;
                sh:control_word.dmem_wmask = 4'b0011;
                sw:control_word.dmem_wmask = 4'b1111;
                default:  control_word.dmem_wmask = 4'b0000;
            endcase
        end

        op_imm: begin  // arith ops with register/immediate operands (I type)
            case(arith_funct3)
                slt: begin
                        loadRegfile(regfilemux::br_en);
                        setCMP(cmpmux::i_imm, blt);
                    end
                sltu: begin
                        loadRegfile(regfilemux::br_en);
                        setCMP(cmpmux::i_imm, bltu);
                        end
                sr: begin
                        if(funct7[5]) begin
                            loadRegfile(regfilemux::alu_out);
                            setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_sra);
                        end
                        else begin
                            loadRegfile(regfilemux::alu_out);
                            setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_srl);
                        end
                    end
                default: begin
                            loadRegfile(regfilemux::alu_out);
                            setALU(alumux::rs1_out, alumux::i_imm, 1'b1,funct3);										
                        end
            endcase
        end
        op_reg: begin  // arith ops with register operands (R type)
            if (funct7 == 7'b0000001) loadRegfile(regfilemux::alu_out); //M-extension takes priority over compares
            else case(arith_funct3)
                slt: begin
                        loadRegfile(regfilemux::br_en);
                        setCMP(cmpmux::rs2_out, blt);
                    end
                sltu: begin
                        loadRegfile(regfilemux::br_en);
                        setCMP(cmpmux::rs2_out, bltu);
                        end
                sr: begin
                        if(funct7[5]) begin
                            loadRegfile(regfilemux::alu_out);
                            setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_sra);
                        end
                        else begin
                            loadRegfile(regfilemux::alu_out);
                            setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_srl);
                        end
                    end
                add: begin
                        if(funct7[5]) begin
                            loadRegfile(regfilemux::alu_out);
                            setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_sub);
                        end
                        else begin
                            loadRegfile(regfilemux::alu_out);
                            setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_add);
                        end
                    end
                default: begin
                            loadRegfile(regfilemux::alu_out);
                            setALU(alumux::rs1_out, alumux::rs2_out, 1'b1,funct3);										
                        end
            endcase
        end
        op_br: begin
            setALU(alumux::pc_out, alumux::b_imm, 1'b1, alu_add);
            setCMP(cmpmux::rs2_out, branch_funct3);
        end
        default: ; 
    endcase
end

endmodule