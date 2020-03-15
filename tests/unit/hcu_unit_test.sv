// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0


`include "vunit_defines.svh"

module tb_hcu_ut;

import kronos_types::*;
import rv32_assembler::*;

logic clk;
logic rstz;
pipeIFID_t fetch;
logic pipe_in_vld;
logic pipe_in_rdy;
pipeIDEX_t decode;
logic pipe_out_vld;
logic pipe_out_rdy;
logic [31:0] regwr_data;
logic [4:0] regwr_sel;
logic regwr_en;

kronos_ID u_id (
    .clk         (clk         ),
    .rstz        (rstz        ),
    .flush       (1'b0        ),
    .fetch       (fetch       ),
    .pipe_in_vld (pipe_in_vld ),
    .pipe_in_rdy (pipe_in_rdy ),
    .decode      (decode      ),
    .pipe_out_vld(pipe_out_vld),
    .pipe_out_rdy(pipe_out_rdy),
    .regwr_data  (regwr_data  ),
    .regwr_sel   (regwr_sel   ),
    .regwr_en    (regwr_en    )
);

`define hcu u_id.u_hcu 

default clocking cb @(posedge clk);
    default input #10ps output #10ps;
    input pipe_out_vld, decode;
    input negedge pipe_in_rdy;
    output pipe_in_vld, fetch, regwr_en;
    output negedge pipe_out_rdy;
endclocking

// ============================================================

logic [31:0] REG [32];

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        fetch = '0;
        pipe_in_vld = 0;
        pipe_out_rdy = 0;
        regwr_data = '0;
        regwr_en = 0;
        regwr_sel = 0;

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


    `TEST_CASE("hazard") begin
        pipeIFID_t instr;
        logic [1:0] hazard;
        logic [4:0] rs1, rs2, rd;

        instr.pc = 0;

        // Fill up hazard trackers, by executing two writes per register
        repeat (2) begin
            for(int i=1; i<31; i++) begin
                // x[i] = 0
                instr.ir = rv32_add(x0+i, x0, x0);
                $display("INSTR=%h //add x%0d = 0", instr.ir, i);
                fork 
                    begin
                        @(cb);
                        cb.fetch <= instr;
                        cb.pipe_in_vld <= 1;
                        repeat (16) begin
                            @(cb) if (cb.pipe_in_rdy) begin
                                cb.pipe_in_vld <= 0;
                                break;
                            end
                        end
                    end

                    begin
                        @(cb iff pipe_out_vld) begin
                            // drain and check
                            $display("Got Decode:");
                            print_decode(decode);
                            cb.pipe_out_rdy <= 1;
                            ##1 cb.pipe_out_rdy <= 0;
                        end
                    end
                join
                $display("-----------------\n\n");
            end
        end

        // Check that the hazard tracker is full
        for(int i=0; i<31; i++) begin
            hazard = `hcu.rpend[i];
            $display("HCU.rpend[%0d] = %b", i, hazard);
            if (i==0) assert(hazard == 0);
            else assert(hazard == 2'b11);
        end
        $display("-----------------\n\n");

        // Pick any 2 registers and setup an instruction that reads them
        rs1 = $urandom_range(2,15);
        rs2 = $urandom_range(16,31);
        rd = 1;
        
        instr.ir = rv32_add(rd, rs1, rs2);
        $display("INSTR=%h //add x%0d = 0", instr.ir, rd);

        @(cb);
        cb.fetch <= instr;
        cb.pipe_in_vld <= 1;
        repeat (16) begin
            // confirm that decode doesn't accept the instr
            // adn that stall is high
            @(cb) begin
                assert(~cb.pipe_in_rdy);
                assert(`hcu.stall);
            end
        end
        $display("-----------------\n\n");

        // Write back rs1 twice and check hazard status
        repeat(2) begin
            regwr_data = $urandom();
            regwr_sel = rs1;
            $display("WriteBack: x%0d = %h", rs1, regwr_data);
            REG[rs1] = regwr_data;
            @(cb) cb.regwr_en <= 1;
            ##1 cb.regwr_en <= 0;
        end
        $display("-----------------\n\n");

        hazard = `hcu.rpend[rs1];
        $display("HCU.rpend[%0d] = %b", rs1, hazard);
        assert(hazard == 0);
        assert(`hcu.stall);
        $display("-----------------\n\n");

        // Write back rs1 twice and check hazard status
        repeat(2) begin
            regwr_data = $urandom();
            regwr_sel = rs2;
            REG[rs2] = regwr_data;
            $display("WriteBack: x%0d = %h", rs2, regwr_data);
            @(cb) cb.regwr_en <= 1;
            ##1 cb.regwr_en <= 0;
        end
        $display("-----------------\n\n");

        hazard = `hcu.rpend[rs2];
        $display("HCU.rpend[%0d] = %b", rs2, hazard);
        assert(~`hcu.stall);
        $display("-----------------\n\n");

        // Finally, check that decode is registered, now that hazard is cleared
        // for this instruction
        ##1;
        assert(pipe_out_vld)
        $display("Got Decode:");
        print_decode(decode);
        assert(decode.op1 == REG[rs1]);
        assert(decode.op2 == REG[rs2]);

        ##64;
    end
end

`WATCHDOG(1ms);

// ============================================================
// METHODS
// ============================================================

task automatic print_decode(input pipeIDEX_t d);
    $display("---- OP --------");
    $display("  op1: %h",           d.op1);
    $display("  op2: %h",           d.op2);
    $display("  op3: %h",           d.op3);
    $display("  op4: %h",           d.op4);
    $display("---- EXCTRL ----");
    $display("  cin: %b",           d.cin);
    $display("  rev: %b",           d.rev);
    $display("  uns: %b",           d.uns);
    $display("  eq: %b",            d.eq);
    $display("  inv: %b",           d.inv);
    $display("  align: %b",         d.align);
    $display("  sel: %h",           d.sel);
    $display("---- WBCTRL ----");
    $display("  rd: %d",            d.rd);
    $display("  rd_write: %h",      d.rd_write);
    $display("  branch: %h",        d.branch);
    $display("  branch_cond: %h",   d.branch_cond);
    $display("  ld: %h",            d.ld);
    $display("  st: %h",            d.st);
    $display("  data_size: %h",     d.data_size);    
    $display("  data_uns: %h",      d.data_uns);
    $display("---- CLICCTRL ----");
    $display("  except: %h",        d.except);
    $display("  excause: %h",       d.excause);
endtask

endmodule
