// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_kronos_WB_ut;

import kronos_types::*;
import rv32_assembler::*;
import common::*;

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
logic [11:0] csr_addr;
logic [1:0] csr_op;
logic [31:0] csr_rd_data;
logic [31:0] csr_wr_data;
logic csr_rd_req;
logic csr_wr_req;
logic csr_gnt;

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
    .data_gnt     (data_gnt     ),
    .csr_addr     (csr_addr     ),
    .csr_op       (csr_op       ),
    .csr_rd_data  (csr_rd_data  ),
    .csr_wr_data  (csr_wr_data  ),
    .csr_rd_req   (csr_rd_req   ),
    .csr_wr_req   (csr_wr_req   ),
    .csr_gnt      (csr_gnt      ),
    .instret      (instret      )
);

kronos_csr u_csr (
    .clk    (clk        ),
    .rstz   (rstz       ),
    .addr   (csr_addr   ),
    .op     (csr_op     ),
    .rd_data(csr_rd_data),
    .wr_data(csr_wr_data),
    .rd_req (csr_rd_req ),
    .wr_req (csr_wr_req ),
    .gnt    (csr_gnt    ),
    .instret(instret    )
);

default clocking cb @(posedge clk);
    default input #10ps output #10ps;
    input negedge execute_rdy, csr_rd_req, csr_wr_req, csr_gnt;
    input regwr_en, regwr_data, regwr_sel;
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

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("mcycle") begin
        string optype;
        pipeEXWB_t texecute;
        logic [1:0] op;
        logic [4:0] rd, rs1;
        logic [31:0] wdata;
        logic [31:0] count, expected;

        u_csr.u_hpmcounter0.count_low = $urandom();
        #1;

        repeat(128) begin
            // coin toss for delay
            if ($urandom_range(0,1) == 0) ##($urandom_range(1,32));

            // snapshot the mcycle
            count = u_csr.mcycle[31:0];

            // Setup command and drive stimulus
            rand_csr(MCYCLE, texecute, optype);
            op = texecute.funct3[1:0];
            rd = texecute.rd;
            rs1 = texecute.result1[19:15];
            wdata = texecute.result2;
            $display("OPTYPE: %s", optype);
            print_execute(texecute);

            @(cb);
            cb.execute <= texecute;
            cb.execute_vld <= 1;
                
            // check the WB accepts
            @(cb iff cb.execute_rdy);
            cb.execute_vld <= 0;

            // check that the CSR read request goes high for the right CSR
            @(cb iff cb.csr_rd_req);
            assert(csr_addr == MCYCLE);

            //On GNT, confirm that it is the same ballpark as the count
            @(cb iff cb.csr_gnt);
            $display("EXP CSR Read Data: %h", count);
            $display("GOT CSR Read Data: %h", csr_rd_data);
            assert(csr_rd_data - count < 4);

            // setup expected write data as per OP
            case(op)
                CSR_RW: expected = texecute.result2;
                CSR_RS: expected = csr_rd_data | wdata;
                CSR_RC: expected = csr_rd_data & ~wdata;
            endcase

            fork
                begin
                    // there won't be a CSR write attempt for Set/Clr register-source ops if rs1=0
                    if (!((op == CSR_RS || op == CSR_RC) && rs1 == 0)) begin
                        // Check correct operation was setup on write request
                        @(cb iff cb.csr_wr_req);
                        $display("EXP CSR Write Data: %h", expected);
                        $display("GOT CSR Write Data: %h", u_csr.csr_wr_data);
                        assert(csr_op == op);
                        assert(u_csr.csr_wr_data == expected);

                        // One-cycle later, the CSR should be updated flawlessly
                        // Note the previous @(cb) got us a cycle ahead
                        assert(u_csr.mcycle[31:0] == expected);
                    end
                    else begin
                        repeat(8) @(cb) assert(~csr_wr_req);
                    end
                end

                begin
                    if (rd!=0) begin
                        @(cb iff cb.regwr_en);
                        // the register write back is valid now
                        assert(cb.regwr_data == csr_rd_data);
                        assert(cb.regwr_sel == rd);
                    end
                    else begin
                        repeat(8) @(cb) assert(~regwr_en);
                    end
                end
            join

            $display("-----------------\n\n");
        end

        ##64;
    end

    `TEST_CASE("mcycleh") begin
        string optype;
        pipeEXWB_t texecute;
        logic [1:0] op;
        logic [4:0] rd, rs1;
        logic [31:0] wdata;
        logic [31:0] count, expected;

        u_csr.u_hpmcounter0.count_high = $urandom();
        #1;

        repeat(128) begin
            // coin toss for delay
            if ($urandom_range(0,1) == 0) ##($urandom_range(1,32));

            // snapshot the mcycle
            count = u_csr.mcycle[63:32];

            // Setup command and drive stimulus
            rand_csr(MCYCLEH, texecute, optype);
            op = texecute.funct3[1:0];
            rd = texecute.rd;
            rs1 = texecute.result1[19:15];
            wdata = texecute.result2;
            $display("OPTYPE: %s", optype);
            print_execute(texecute);

            @(cb);
            cb.execute <= texecute;
            cb.execute_vld <= 1;
                
            // check the WB accepts
            @(cb iff cb.execute_rdy);
            cb.execute_vld <= 0;

            // check that the CSR read request goes high for the right CSR
            @(cb iff cb.csr_rd_req);
            assert(csr_addr == MCYCLEH);

            //On GNT, confirm that it is the same ballpark as the count
            @(cb iff cb.csr_gnt);
            $display("EXP CSR Read Data: %h", count);
            $display("GOT CSR Read Data: %h", csr_rd_data);
            assert(csr_rd_data - count < 2);

            // setup expected write data as per OP
            case(op)
                CSR_RW: expected = texecute.result2;
                CSR_RS: expected = csr_rd_data | wdata;
                CSR_RC: expected = csr_rd_data & ~wdata;
            endcase

            fork
                begin
                    // there won't be a CSR write attempt for Set/Clr register-source ops if rs1=0
                    if (!((op == CSR_RS || op == CSR_RC) && rs1 == 0)) begin
                        // Check correct operation was setup on write request
                        @(cb iff cb.csr_wr_req);
                        $display("EXP CSR Write Data: %h", expected);
                        $display("GOT CSR Write Data: %h", u_csr.csr_wr_data);
                        assert(csr_op == op);
                        assert(u_csr.csr_wr_data == expected);

                        // One-cycle later, the CSR should be updated flawlessly
                        // Note the previous @(cb) got us a cycle ahead
                        assert(u_csr.mcycle[63:32] == expected);
                    end
                    else begin
                        repeat(8) @(cb) assert(~csr_wr_req);
                    end
                end

                begin
                    // there won't be a write back if rd == 0
                    if (rd!=0) begin
                        @(cb iff cb.regwr_en);
                        // the register write back is valid now
                        assert(cb.regwr_data == csr_rd_data);
                        assert(cb.regwr_sel == rd);
                    end
                    else begin
                        repeat(8) @(cb) assert(~regwr_en);
                    end
                end
            join

            $display("-----------------\n\n");
        end

        ##64;
    end

    `TEST_CASE("mcycle_stagger") begin
        string optype;
        pipeEXWB_t texecute;
        logic [31:0] count, expected; 

        // setup a CSRRW on mcycleh
        execute = '0;
        execute.system = 1;
        execute.rd = 1;
        execute.result1 = rv32_csrrs(1, 0, MCYCLEH);
        execute.result2 = 0;
        execute.funct3 = CSR_RS;
        print_execute(execute);

        repeat(128) begin
            count = $urandom();
            expected = count + 1;

            @(cb);
            cb.execute_vld <= 1;
            // Setup for rollover at the right moment
            u_csr.u_hpmcounter0.count_low = '1;
            u_csr.u_hpmcounter0.count_high = count;
                
            // check the WB accepts
            @(cb iff cb.execute_rdy);
            cb.execute_vld <= 0;

            // check that the CSR read request goes high for the right CSR
            @(cb iff cb.csr_rd_req);
            assert(csr_addr == MCYCLEH);

            //On GNT, confirm that it is the same ballpark as the count
            @(cb iff cb.csr_gnt);
            $display("EXP CSR Read Data: %h", expected);
            $display("GOT CSR Read Data: %h", csr_rd_data);
            assert(csr_rd_data == expected);

            $display("-----------------\n\n");
        end

        ##64;
    end

    `TEST_CASE("minstret") begin
        string optype;
        logic [63:0] count, expected;
        logic skip;

        u_csr.u_hpmcounter1.count_low = '1 - $urandom_range(0,31);
        u_csr.u_hpmcounter1.count_high = $urandom();

        #1;
        expected = u_csr.minstret + 2;

        repeat(128) fork
            begin
                // setup a blank CSRRS on minstret/h
                // higher, then lower
                execute = '0;
                execute.system = 1;
                execute.rd = 1;
                execute.result1 = rv32_csrrs(1, 0, MINSTRETH);
                execute.result2 = 0;
                execute.funct3 = CSR_RS;

                @(cb);
                cb.execute_vld <= 1;

                @(cb iff cb.execute_rdy);
                execute = '0;
                execute.system = 1;
                execute.rd = 1;
                execute.result1 = rv32_csrrs(1, 0, MINSTRET);
                execute.result2 = 0;
                execute.funct3 = CSR_RS;

                @(cb iff cb.execute_rdy);
                execute = '0;
                execute.system = 1;
                execute.rd = 1;
                execute.result1 = rv32_csrrs(1, 0, MINSTRETH);
                execute.result2 = 0;
                execute.funct3 = CSR_RS;

                @(cb iff cb.execute_rdy);
                cb.execute_vld <= 0;
            end

            begin
                /*
                again:
                    rdcycleh    x3
                    rdcycle     x2
                    rdcycleh    x4
                    bne         x3, x4, again
                */

                // check 3 CSR read requests back to back
                @(cb iff cb.csr_rd_req);
                assert(csr_addr == MINSTRETH);
                @(cb iff cb.csr_gnt);
                $display("INSTRETH %h", csr_rd_data);

                count[32+:32] = csr_rd_data;
                

                @(cb iff cb.csr_rd_req);
                assert(csr_addr == MINSTRET);
                @(cb iff cb.csr_gnt);
                $display("INSTRET %h", csr_rd_data);

                count[0+:32] = csr_rd_data;
                

                @(cb iff cb.csr_rd_req);
                assert(csr_addr == MINSTRETH);
                @(cb iff cb.csr_gnt);
                $display("INSTRETH %h", csr_rd_data);
                if (count[32+:32] != csr_rd_data) begin
                    skip = 1;
                    $display("!!! ROLLOVER !!!");
                end

                count[32+:32] = csr_rd_data;

                $display("EXP: %h", expected);
                $display("GOT: %h", count);

                if (~skip) assert(expected == count);
                expected += 3;

                $display("-----------------\n\n");
            end
        join
        ##64;
    end
end

`WATCHDOG(1ms);

// ============================================================
// METHODS
// ============================================================

task automatic rand_csr(logic [11:0] csr, output pipeEXWB_t execute, output string optype);
    logic [4:0] rs1, rd;
    logic [4:0] zimm;

    rs1 = $urandom();
    rd = $urandom();
    zimm = $urandom();

    // generate random CSR operartion
    execute = '0;
    execute.system = 1;
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

endmodule
