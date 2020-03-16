// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_kronos_WB_ut;

import kronos_types::*;

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

spsram32_model #(.DEPTH(256)) u_dmem (
    .clk    (clk                      ),
    .addr   (data_addr[2+:10]         ),
    .wdata  (data_wr_data             ),
    .rdata  (data_rd_data             ),
    .en     ((data_rd_req|data_wr_req)),
    .wr_en  (data_wr_req              ),
    .wr_mask(data_wr_mask             )
);

always_ff @(posedge clk) begin
    if (data_rd_req | data_wr_req) begin
        data_gnt <= 1;
        // Confirm that access is always 4B aligned
        assert(data_addr[1:0] == 2'b00);
    end
    else data_gnt <= 0;
end

default clocking cb @(posedge clk);
    default input #10ps output #10ps;
    input negedge execute_rdy;
    output execute_vld, execute;
endclocking


// ============================================================
`define MEM u_dmem.MEM

logic [31:0] expected_regwr_data;
logic [4:0] expected_regwr_sel;

logic [31:0] store_addr;
logic [7:0][7:0] expected_store_data;

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        execute = '0;
        execute_vld = 0;

        for(int i=0; i<256; i++)
            `MEM[i] = $urandom;

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("load") begin
        string optype;
        pipeEXWB_t texecute;

        repeat (2**10) begin
            fork 
                // Drive stimulus
                begin
                    rand_load(texecute, optype);
                    $display("OPTYPE=%s", optype);
                    $display("Expected: ");
                    $display("  regwr_data: %h", expected_regwr_data);
                    $display("  regwr_sel: %h", expected_regwr_sel);
                    @(cb);
                    cb.execute <= texecute;
                    cb.execute_vld <= 1;
                    repeat (16) begin
                        @(cb) if (cb.execute_rdy) begin
                            cb.execute_vld <= 0;
                            break;
                        end
                    end
                end

                // REG write back checker
                forever @(cb) begin
                    if (regwr_en) begin
                        $display("GOT");
                        $display("  regwr_data: %h", regwr_data);
                        $display("  regwr_sel: %h", regwr_sel);
                        assert(expected_regwr_data == regwr_data);
                        assert(expected_regwr_sel == regwr_sel);
                        break;
                    end
                end
            join

            $display("-----------------\n\n");
        end

        ##64;
    end

    `TEST_CASE("store") begin
        string optype;
        pipeEXWB_t texecute;
        logic [7:0][7:0] mem_data;

        repeat (2**10) begin
            fork 
                // Drive stimulus
                begin
                    rand_store(texecute, optype);
                    $display("OPTYPE=%s", optype);
                    $display("Expected: ");
                    $display("  store_data: %h", expected_store_data);
                    $display("  store_addr: %h", store_addr);
                    @(cb);
                    cb.execute <= texecute;
                    cb.execute_vld <= 1;
                    repeat (16) begin
                        @(cb) if (cb.execute_rdy) begin
                            cb.execute_vld <= 0;
                            break;
                        end
                    end
                end

                // Store checker
                forever @(cb) begin
                    if (u_wb.lsu_done) begin
                        mem_data = {`MEM[store_addr+1], `MEM[store_addr]};
                        $display("GOT");
                        $display("  store_data: %h", mem_data);
                        assert(expected_store_data == mem_data);
                        break;
                    end
                end
            join

            $display("-----------------\n\n");
        end

        ##64;
    end
end

`WATCHDOG(1ms);

// ============================================================
// METHODS
// ============================================================

task automatic rand_load(output pipeEXWB_t execute, output string optype);
    int op;
    logic [4:0] rd;
    int maddr;

    logic [7:0][7:0] mem_word;
    int offset;
    logic [7:0] dbyte;
    logic [15:0] dhalf;
    logic [31:0] dword;

    int aligned_addr;


    // generate scenario
    op = $urandom_range(0,4);
    rd = $urandom_range(1,31);
    maddr = $urandom_range(0,252);

    // clear out execute
    execute = '0;

    // Fetch 4B word and next word from the memory
    aligned_addr = maddr>>2;
    offset = maddr & 3;
    mem_word = {`MEM[aligned_addr+1], `MEM[aligned_addr]};
    $display("MEMADDR: %h",maddr);
    $display("MEMWORD: %h",mem_word);

    case(op)
        0: begin
            optype = "LB";

            execute.result1 = maddr;
            execute.rd = rd;
            execute.rd_write = 1;
            execute.ld = 1;
            execute.funct3 = {1'b0, BYTE};

            dbyte = mem_word[offset];
            expected_regwr_data = signed'(dbyte);
            expected_regwr_sel = rd;
        end

        1: begin
            optype = "LBU";

            execute.result1 = maddr;
            execute.rd = rd;
            execute.rd_write = 1;
            execute.ld = 1;
            execute.funct3 = {1'b1, BYTE};

            dbyte = mem_word[offset];
            expected_regwr_data = {24'b0, dbyte};
            expected_regwr_sel = rd;
        end

        2: begin
            optype = "LH";

            execute.result1 = maddr;
            execute.rd = rd;
            execute.rd_write = 1;
            execute.ld = 1;
            execute.funct3 = {1'b0, HALF};

            expected_regwr_sel = rd;

            dhalf = {mem_word[offset+1], mem_word[offset]};
            expected_regwr_data = signed'(dhalf);
            expected_regwr_sel = rd;
        end

        3: begin
            optype = "LHU";

            execute.result1 = maddr;
            execute.rd = rd;
            execute.rd_write = 1;
            execute.ld = 1;
            execute.funct3 = {1'b1, HALF};

            expected_regwr_sel = rd;

            dhalf = {mem_word[offset+1], mem_word[offset]};
            expected_regwr_data = {16'b0, dhalf};
            expected_regwr_sel = rd;
        end

        4: begin
            optype = "LW";

            execute.result1 = maddr;
            execute.rd = rd;
            execute.rd_write = 1;
            execute.ld = 1;
            execute.funct3 = {1'b0, WORD};

            expected_regwr_sel = rd;

            dword = {mem_word[offset+3], mem_word[offset+2],
                    mem_word[offset+1], mem_word[offset]};
            expected_regwr_data = dword;
            expected_regwr_sel = rd;
        end
    endcase // op
endtask

task automatic rand_store(output pipeEXWB_t execute, output string optype);
    int op;
    int maddr;

    logic [7:0][7:0] mem_word;
    int offset;
    logic [7:0] dbyte;
    logic [15:0] dhalf;
    logic [31:0] dword;

    int aligned_addr;

    // generate scenario
    op = $urandom_range(0,2);
    maddr = $urandom_range(0,252);
    dbyte = $urandom;
    dhalf = $urandom;
    dword = $urandom;

    // clear out execute
    execute = '0;

    // Fetch 4B word and next word from the memory
    aligned_addr = maddr>>2;
    offset = maddr & 3;
    mem_word = {`MEM[aligned_addr+1], `MEM[aligned_addr]};
    $display("MEMADDR: %h",maddr);
    $display("MEMWORD: %h",mem_word);

    case(op)
        0: begin
            optype = "SB";

            execute.result1 = maddr;
            execute.result2 = dbyte;
            execute.st = 1;
            execute.funct3 = {1'b0, BYTE};

            mem_word[offset] = dbyte;
        end

        1: begin
            optype = "SH";

            execute.result1 = maddr;
            execute.result2 = dhalf;
            execute.st = 1;
            execute.funct3 = {1'b0, HALF};

            {mem_word[offset+1], mem_word[offset]} = dhalf;
        end

        2: begin
            optype = "SW";

            execute.result1 = maddr;
            execute.result2 = dword;
            execute.st = 1;
            execute.funct3 = {1'b0, WORD};

            {mem_word[offset+3], mem_word[offset+2],
                mem_word[offset+1], mem_word[offset]} = dword;
        end
    endcase

    // Setup expected stored data at word-aligned address
    store_addr = aligned_addr;
    expected_store_data = mem_word;
endtask

endmodule
