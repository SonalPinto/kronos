// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_kronos_WB_ut;

import kronos_types::*;
import rv32_assembler::*;
import utils::*;

logic clk;
logic rstz;
pipeEXWB_t execute;
logic execute_vld;
logic execute_rdy;
logic [31:0] regwr_data;
logic [4:0] regwr_sel;
logic regwr_en;
logic [31:0] branch_target;
logic branch;
logic [31:0] data_addr;
logic [31:0] data_rd_data;
logic [31:0] data_wr_data;
logic [3:0] data_wr_mask;
logic data_rd_req;
logic data_wr_req;
logic data_gnt;

kronos_WB u_wb (
    .clk          (clk          ),
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
    .data_wr_mask (data_wr_mask ),
    .data_rd_req  (data_rd_req  ),
    .data_wr_req  (data_wr_req  ),
    .data_gnt     (data_gnt     )
);

// gray box probes
`define csr u_wb.u_csr

logic csr_rd_en, csr_wr_en;
logic [11:0] csr_addr;
logic [1:0] csr_op;
logic [31:0] csr_rd_data, csr_wr_data, csr_wb_data;

assign csr_rd_en = `csr.csr_rd_en;
assign csr_wr_en = `csr.csr_wr_en;
assign csr_addr = `csr.addr;
assign csr_op = `csr.op;
assign csr_rd_data = `csr.rd_data;
assign csr_wr_data = `csr.csr_wr_data;

default clocking cb @(posedge clk);
    default input #10ps output #10ps;
    input negedge execute_rdy;
    input regwr_en, regwr_data, regwr_sel;
    input csr_rd_en, csr_wr_en;
    input branch, branch_target;
    output execute_vld, execute;
endclocking

// ============================================================

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        execute = '0;
        execute_vld = 0;

        data_gnt = 0;
        data_rd_data = 0;

        // rand init CSR
        `csr.mscratch = $urandom();
        `csr.mepc = $urandom();
        `csr.mcause = $urandom();
        `csr.mtval = $urandom();

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("rw") begin
        string optype, csr_name;
        logic [11:0] csr;
        pipeEXWB_t texecute;
        logic [31:0] exp_rd, exp_wr;
        logic [4:0] rd, rs1;

        repeat (128) begin
            // Select random CSR
            select_csr(csr, csr_name);
            $display("CSR: %s", csr_name);

            // Setup some rw instruction for it
            rand_csr(csr, texecute, optype);
            $display("OPTYPE: %s", optype);
            $display("");
            print_execute(texecute);
            rd = texecute.rd;
            rs1 = texecute.result1[19:15];

            // Setup expected results
            setup_expected(texecute, exp_rd, exp_wr);
            $display("");
            $display("EXP rd_data = %h", exp_rd);
            $display("EXP wr_data = %h", exp_wr);

            @(cb);
            cb.execute <= texecute;
            cb.execute_vld <= 1;
            @(cb iff cb.execute_rdy);
            cb.execute_vld <= 0;
            
            fork
                // register write back monitor
                begin
                    if (rd != 0) begin
                        @(cb iff cb.regwr_en);
                        $display("GOT Register WB: %h", cb.regwr_data);
                        assert(cb.regwr_data == exp_rd);
                        assert(cb.regwr_sel == rd);
                    end
                    else begin
                        repeat(8) @(cb) assert(~regwr_en);
                    end
                end
            join

            // check CSR
            check_csr(csr, exp_wr);

            $display("-----------------\n\n");
        end

        ##64;
    end

    `TEST_CASE("ecall") begin
        logic [31:0] mtvec;
        logic [31:0] mepc;

        repeat (128) begin

            // Setup random mtvec/mepc
            mtvec = $urandom() & ~3;
            mepc = $urandom() & ~3;
            `csr.mtvec = mtvec;
            $display("mtvec = %h", mtvec);
            $display("mepc = %h", mepc);

            // setup ECALL instruction
            execute = '0;
            execute.result1 = rv32_ecall();
            execute.pc = mepc;
            execute.ecall = 1;

            @(cb);
            cb.execute_vld <= 1;
            ##1 cb.execute_vld <= 0;

            // Catch and check the jump to the trap handler
            @(cb iff cb.branch);
            $display("\nTRAP JUMP = %h", cb.branch_target);
            assert(cb.branch_target == mtvec);

            $display("mstatus.mie=%b", `csr.mstatus.mie);
            $display("mstatus.mpie=%b", `csr.mstatus.mpie);
            $display("mepc=%h", `csr.mepc);
            $display("mcause=%h", `csr.mcause);
            $display("mtval=%h", `csr.mtval);

            assert(`csr.mstatus.mie == 1'b0);
            assert(`csr.mstatus.mpie == 1'b0);
            assert(`csr.mepc == execute.pc);
            assert(`csr.mcause == {28'b0, ECALL_MACHINE});
            assert(`csr.mtval == '0);

            // ----------------------------------------------------
            // Setup MRET instruction
            execute = '0;
            execute.result1 = rv32_mret();
            execute.pc = $urandom() & ~3;
            execute.ret = 1;

            @(cb);
            cb.execute_vld <= 1;
            ##1 cb.execute_vld <= 0;

            // Catch and check the jump to the return address
            @(cb iff cb.branch);
            $display("\nRETURN JUMP = %h", cb.branch_target);
            assert(cb.branch_target == mepc);

            $display("mstatus.mie=%b", `csr.mstatus.mie);
            $display("mstatus.mpie=%b", `csr.mstatus.mpie);
            assert(`csr.mstatus.mie == 1'b0);
            assert(`csr.mstatus.mpie == 1'b1);


            $display("-----------------\n\n");
        end

        ##32;
    end


    `TEST_CASE("ebreak") begin
        logic [31:0] mtvec;
        logic [31:0] mepc;

        repeat (128) begin

            // Setup random mtvec/mepc
            mtvec = $urandom() & ~3;
            mepc = $urandom() & ~3;
            `csr.mtvec = mtvec;
            $display("mtvec = %h", mtvec);
            $display("mepc = %h", mepc);

            // setup EBREAK instruction
            execute = '0;
            execute.result1 = rv32_ebreak();
            execute.pc = mepc;
            execute.ebreak = 1;

            @(cb);
            cb.execute_vld <= 1;
            ##1 cb.execute_vld <= 0;

            // Catch and check the jump to the trap handler
            @(cb iff cb.branch);
            $display("\nTRAP JUMP = %h", cb.branch_target);
            assert(cb.branch_target == mtvec);

            $display("mstatus.mie=%b", `csr.mstatus.mie);
            $display("mstatus.mpie=%b", `csr.mstatus.mpie);
            $display("mepc=%h", `csr.mepc);
            $display("mcause=%h", `csr.mcause);
            $display("mtval=%h", `csr.mtval);

            assert(`csr.mstatus.mie == 1'b0);
            assert(`csr.mstatus.mpie == 1'b0);
            assert(`csr.mepc == execute.pc);
            assert(`csr.mcause == {28'b0, BREAKPOINT});
            assert(`csr.mtval == execute.pc);

            // ----------------------------------------------------
            // Setup MRET instruction
            execute = '0;
            execute.result1 = rv32_mret();
            execute.pc = $urandom() & ~3;
            execute.ret = 1;

            @(cb);
            cb.execute_vld <= 1;
            ##1 cb.execute_vld <= 0;

            // Catch and check the jump to the return address
            @(cb iff cb.branch);
            $display("\nRETURN JUMP = %h", cb.branch_target);
            assert(cb.branch_target == mepc);

            $display("mstatus.mie=%b", `csr.mstatus.mie);
            $display("mstatus.mpie=%b", `csr.mstatus.mpie);
            assert(`csr.mstatus.mie == 1'b0);
            assert(`csr.mstatus.mpie == 1'b1);


            $display("-----------------\n\n");
        end

        ##32;
    end
end

`WATCHDOG(1ms);

// ============================================================
// METHODS
// ============================================================

task automatic select_csr(output logic [11:0] csr, output string csr_name);
    int pick;
    pick = $urandom_range(0,7);

    case(pick)
        0: begin 
            csr = MSTATUS;
            csr_name = "mstatus";
        end
        1: begin 
            csr = MIE;
            csr_name = "mie";
        end
        2: begin 
            csr = MTVEC;
            csr_name = "mtvec";
        end
        3: begin 
            csr = MSCRATCH;
            csr_name = "mscratch";
        end
        4: begin 
            csr = MEPC;
            csr_name = "mepc";
        end
        5: begin 
            csr = MCAUSE;
            csr_name = "mcause";
        end
        6: begin 
            csr = MTVAL;
            csr_name = "mtval";
        end
        7: begin 
            csr = MIP;
            csr_name = "mip";
        end
    endcase
endtask

task automatic rand_csr(logic [11:0] csr, output pipeEXWB_t execute, output string optype);
    logic [4:0] rs1, rd;
    logic [4:0] zimm;

    rs1 = $urandom();
    rd = $urandom();
    zimm = $urandom();

    // generate random CSR operartion
    execute = '0;
    execute.csr = 1;
    execute.rd = rd;

    // coin toss for imm or reg source
    case($urandom_range(0,5))
        0: begin
            optype = "CSRRW";
            execute.result1 = rv32_csrrw(rd, rs1, csr);
            execute.result2 = rs1 == 0 ? '0 : $urandom;

        end
        1: begin
            optype = "CSRRS";
            execute.result1 = rv32_csrrs(rd, rs1, csr);
            execute.result2 = rs1 == 0 ? '0 : $urandom;

        end
        2: begin
            optype = "CSRRC";
            execute.result1 = rv32_csrrc(rd, rs1, csr);
            execute.result2 = rs1 == 0 ? '0 : $urandom;

        end
        3: begin
            optype = "CSRRWI";
            execute.result1 = rv32_csrrwi(rd, zimm, csr);
            execute.result2 = zimm;
        end
        4: begin
            optype = "CSRRSI";
            execute.result1 = rv32_csrrsi(rd, zimm, csr);
            execute.result2 = zimm;
        end
        5: begin
            optype = "CSRRCI";
            execute.result1 = rv32_csrrci(rd, zimm, csr);
            execute.result2 = zimm;
        end
    endcase

    execute.funct3 = execute.result1[14:12];
endtask

task automatic setup_expected(input pipeEXWB_t execute, 
    output logic [31:0] rd_data, wr_data);

    logic [11:0] csr;
    logic [31:0] twdata;

    rd_data = '0; // default
    wr_data = '0;

    // Read current value
    csr = execute.result1[31:20];
    case(csr)
        MSTATUS: begin
            rd_data[3] = `csr.mstatus.mie;
            rd_data[7] = `csr.mstatus.mpie;
            rd_data[12:11] = 2'b11;
        end
        MIE : begin
            rd_data[3] = `csr.mie.msie;
            rd_data[7] = `csr.mie.mtie;
            rd_data[11] = `csr.mie.meie;
        end
        MTVEC : rd_data = `csr.mtvec;
        MSCRATCH : rd_data = `csr.mscratch;
        MEPC : rd_data = `csr.mepc;
        MCAUSE : rd_data = `csr.mcause;
        MTVAL : rd_data = `csr.mtval;
        MIP : begin
            rd_data[3] = `csr.mip.msip;
            rd_data[7] = `csr.mip.mtip;
            rd_data[11] = `csr.mip.meip;
        end
    endcase // csr

    // Setup write value as per op
    case(execute.funct3[1:0])
        CSR_RW: twdata = execute.result2;
        CSR_RS: twdata = rd_data | execute.result2;
        CSR_RC: twdata = rd_data & ~execute.result2;
    endcase

    case(csr)
        MSTATUS: begin
            wr_data[3] = twdata[3];
            wr_data[7] = twdata[7];
            wr_data[12:11] = 2'b11;
        end
        MIE : begin
            wr_data[3] = twdata[3];
            wr_data[7] = twdata[7];
            wr_data[11] = twdata[11];
        end
        MTVEC : wr_data = {twdata[31:2], 2'b00};
        MSCRATCH : wr_data = twdata;
        MEPC : wr_data = {twdata[31:2], 2'b00};
        MCAUSE : wr_data = twdata;
        MTVAL : wr_data = twdata;
    endcase // csr
endtask

task automatic check_csr(input logic [11:0] csr, input logic [31:0] check);
    case(csr)
        MSTATUS: begin
            $display("mstatus.mie=%b", `csr.mstatus.mie);
            $display("mstatus.mpie=%b", `csr.mstatus.mpie);
            $display("mstatus.mpp=%b", `csr.mstatus.mpp);

            assert(`csr.mstatus.mie == check[3]);
            assert(`csr.mstatus.mpie == check[7]);
            assert(`csr.mstatus.mpp == check[12:11]);
        end
        MIE : begin
            $display("mie.msie=%b", `csr.mie.msie);
            $display("mie.mtie=%b", `csr.mie.mtie);
            $display("mie.meie=%b", `csr.mie.meie);

            assert(`csr.mie.msie == check[3]);
            assert(`csr.mie.mtie == check[7]);
            assert(`csr.mie.meie == check[11]);
        end
        MTVEC : begin
            $display("mtvec=%h", `csr.mtvec);
            assert(`csr.mtvec == check);
        end
        MSCRATCH : begin
            $display("mscratch=%h", `csr.mscratch);
            assert(`csr.mscratch == check);
        end
        MEPC : begin
            $display("mepc=%h", `csr.mepc);
            assert(`csr.mepc == check);
        end
        MCAUSE : begin
            $display("mcause=%h", `csr.mcause);
            assert(`csr.mcause == check);
        end
        MTVAL : begin 
            $display("mtval=%h", `csr.mtval);
            assert(`csr.mtval == check);
        end
        MIP : begin
            $display("mip.msip=%b", `csr.mip.msip);
            $display("mip.mtip=%b", `csr.mip.mtip);
            $display("mip.meip=%b", `csr.mip.meip);

            assert(`csr.mip.msip == check[3]);
            assert(`csr.mip.mtip == check[7]);
            assert(`csr.mip.meip == check[11]);
        end
    endcase // csr
endtask

endmodule
