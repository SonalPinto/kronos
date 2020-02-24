// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_branch_ut;

import kronos_types::*;
import rv32_assembler::*;

logic clk, rstz;

logic [31:0] branch_target;
logic branch;

logic [31:0] regwr_data;
logic [4:0] regwr_sel;
logic regwr_en;

logic [31:0] data_addr;
logic [31:0] data_rd_data;
logic [31:0] data_wr_data;
logic data_rd_req;
logic data_wr_req;
logic data_gnt;

pipeIFID_t fetch;
pipeIDEX_t decode;
pipeEXWB_t execute;

logic fetch_vld, fetch_rdy;
logic decode_vld, decode_rdy;
logic execute_vld, execute_rdy;

kronos_ID u_id (
    .clk         (clk       ),
    .rstz        (rstz      ),
    .fetch       (fetch     ),
    .pipe_in_vld (fetch_vld ),
    .pipe_in_rdy (fetch_rdy ),
    .decode      (decode    ),
    .pipe_out_vld(decode_vld),
    .pipe_out_rdy(decode_rdy),
    .regwr_data  (regwr_data),
    .regwr_sel   (regwr_sel ),
    .regwr_en    (regwr_en  )
);

kronos_EX u_ex (
    .clk         (clk        ),
    .rstz        (rstz       ),
    .decode      (decode     ),
    .pipe_in_vld (decode_vld ),
    .pipe_in_rdy (decode_rdy ),
    .execute     (execute    ),
    .pipe_out_vld(execute_vld),
    .pipe_out_rdy(execute_rdy)
);

kronos_WB u_wb (
    .clk          (clk),
    .rstz         (rstz         ),
    .execute      (execute      ),
    .pipe_in_vld  (execute_vld  ),
    .pipe_in_rdy  (execute_rdy  ),
    .regwr_data   (regwr_data   ),
    .regwr_sel    (regwr_sel    ),
    .regwr_en     (regwr_en     ),
    .branch_target(branch_target),
    .branch       (branch       ),
    .data_addr    (data_addr    ),
    .data_rd_data (data_rd_data ),
    .data_wr_data (data_wr_data ),
    .data_rd_req  (data_rd_req  ),
    .data_wr_req  (data_wr_req  ),
    .data_gnt     (data_gnt     )
);

default clocking cb @(posedge clk);
    default input #10ps output #10ps;
    input negedge fetch_rdy;
    output fetch_vld, fetch;
endclocking

// ============================================================
logic [31:0] REG [32];

struct {
    logic [31:0] regwr_data;
    logic [4:0] regwr_sel;
    logic regwr_en;
    logic [31:0] branch_target;
    logic branch;
} expected_wb;


`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        // init regfile with random values
        for(int i=0; i<32; i++) begin
            u_id.REG1[i] = $urandom;
            u_id.REG2[i] = u_id.REG1[i];
            REG[i] = u_id.REG1[i];
        end
        // Zero out TB's REG[0] (x0)
        REG[0] = 0;

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("typical") begin
        pipeIFID_t tinstr;
        string optype;

        repeat(2**10) begin
            // Setup instruction and expected output
            rand_instr(tinstr, optype);

            $display("OPTYPE=%s", optype);
            $display("IFID: PC=%h, IR=%h", tinstr.pc, tinstr.ir);
            $display("Expected: ");
            $display("  regwr_data: %h", expected_wb.regwr_data);
            $display("  regwr_sel: %h", expected_wb.regwr_sel);
            $display("  regwr_en: %h", expected_wb.regwr_en);
            $display("  branch_target: %h", expected_wb.branch_target);
            $display("  branch: %h", expected_wb.branch);

            
            @(cb);
            cb.fetch <= tinstr;
            cb.fetch_vld <= 1;
            ##1 cb.fetch_vld <= 0;

            // Wait until WB stage has a valid output, and check against expected
            repeat (8) begin
                @(cb) if (execute_vld) begin
                    ##1;
                    $display("Got: ");
                    $display("  regwr_data: %h", regwr_data);
                    $display("  regwr_sel: %h", regwr_sel);
                    $display("  regwr_en: %h", regwr_en);
                    $display("  branch_target: %h", branch_target);
                    $display("  branch: %h", branch);

                    assert(regwr_data == expected_wb.regwr_data);
                    assert(regwr_sel == expected_wb.regwr_sel);
                    assert(regwr_en == expected_wb.regwr_en);
                    assert(branch_target == expected_wb.branch_target);
                    assert(branch == expected_wb.branch);

                    // Update test's REG as required
                    if (regwr_en) REG[regwr_sel] = regwr_data;

                    break;
                end
            end

            $display("-----------------\n\n");
        end

        ##64;
    end
end
`WATCHDOG(1ms);


// ============================================================
// METHODS
// ============================================================

task automatic rand_instr(output pipeIFID_t instr, output string optype);
    int op;

    logic [6:0] opcode;
    logic [4:0] rs1, rs2, rd;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [31:0] imm;
    int pc, op1, op2;
    logic [31:0] op1_uns, op2_uns;

    // generate scenario
    op = $urandom_range(0, 7);
    imm = $urandom();
    rs1 = $urandom();
    rs2 = $urandom();
    rd = $urandom_range(1,31);

    instr.pc = $urandom;
    pc = int'(instr.pc);
    op1_uns = REG[rs1];
    op2_uns = REG[rs2];
    op1 = int'(op1_uns);
    op2 = int'(op2_uns);

    // clear out expected WB
    expected_wb.regwr_data = '0;
    expected_wb.regwr_sel = '0;
    expected_wb.regwr_en = '0;
    expected_wb.branch_target = '0;
    expected_wb.branch = '0;

    case(op)
        0: begin
            optype = "JAL";
            instr.ir = rv32_jal(rd, imm);

            expected_wb.regwr_data = pc + 4;
            expected_wb.regwr_sel = rd;
            expected_wb.regwr_en = 1;
            expected_wb.branch_target = pc + signed'({imm[20:1], 1'b0});
            expected_wb.branch = 1;
        end

        1: begin
            optype = "JALR";
            instr.ir = rv32_jalr(rd, rs1, imm);

            expected_wb.regwr_data = pc + 4;
            expected_wb.regwr_sel = rd;
            expected_wb.regwr_en = 1;
            expected_wb.branch_target = (op1 + signed'(imm[11:0])) & ~1;
            expected_wb.branch = 1;
        end

        2: begin
            optype = "BEQ";
            instr.ir = rv32_beq(rs1, rs2, imm);

            expected_wb.regwr_data = op1 == op2;
            expected_wb.branch_target = pc + signed'({imm[12:1], 1'b0});
            expected_wb.branch = expected_wb.regwr_data == 1;
        end

        3: begin
            optype = "BNE";
            instr.ir = rv32_bne(rs1, rs2, imm);

            expected_wb.regwr_data = op1 != op2;
            expected_wb.branch_target = pc + signed'({imm[12:1], 1'b0});
            expected_wb.branch = expected_wb.regwr_data == 1;
        end

        4: begin
            optype = "BLT";
            instr.ir = rv32_blt(rs1, rs2, imm);

            expected_wb.regwr_data = op1 < op2;
            expected_wb.branch_target = pc + signed'({imm[12:1], 1'b0});
            expected_wb.branch = expected_wb.regwr_data == 1;
        end

        5: begin
            optype = "BGE";
            instr.ir = rv32_bge(rs1, rs2, imm);

            expected_wb.regwr_data = op1 >= op2;
            expected_wb.branch_target = pc + signed'({imm[12:1], 1'b0});
            expected_wb.branch = expected_wb.regwr_data == 1;
        end

        6: begin
            optype = "BLTU";
            instr.ir = rv32_bltu(rs1, rs2, imm);

            expected_wb.regwr_data = op1_uns < op2_uns;
            expected_wb.branch_target = pc + signed'({imm[12:1], 1'b0});
            expected_wb.branch = expected_wb.regwr_data == 1;
        end

        7: begin
            optype = "BGEU";
            instr.ir = rv32_bgeu(rs1, rs2, imm);

            expected_wb.regwr_data = op1_uns >= op2_uns;
            expected_wb.branch_target = pc + signed'({imm[12:1], 1'b0});
            expected_wb.branch = expected_wb.regwr_data == 1;
        end
    endcase // instr
endtask

endmodule
