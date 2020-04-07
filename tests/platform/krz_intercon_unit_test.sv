// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_krz_intercon_ut;

logic clk;
logic rstz;
logic [23:0] instr_addr;
logic [31:0] instr_data;
logic instr_req;
logic instr_ack;
logic [23:0] data_addr;
logic [31:0] data_rd_data;
logic [31:0] data_wr_data;
logic [3:0] data_wr_mask;
logic data_wr_en;
logic data_req;
logic data_ack;
logic [23:0] bootrom_addr;
logic [31:0] bootrom_rd_data;
logic bootrom_en;
logic [23:0] mem0_addr;
logic [31:0] mem0_rd_data;
logic [31:0] mem0_wr_data;
logic mem0_en;
logic mem0_wr_en;
logic [3:0] mem0_wr_mask;
logic [23:0] mem1_addr;
logic [31:0] mem1_rd_data;
logic [31:0] mem1_wr_data;
logic mem1_en;
logic mem1_wr_en;
logic [3:0] mem1_wr_mask;
logic [23:0] sys_adr_o;
logic [31:0] sys_dat_i;
logic [31:0] sys_dat_o;
logic sys_stb_o;
logic sys_we_o;
logic sys_ack_i;

krz_intercon u_dut (
    .clk            (clk            ),
    .rstz           (rstz           ),
    .instr_addr     (instr_addr     ),
    .instr_data     (instr_data     ),
    .instr_req      (instr_req      ),
    .instr_ack      (instr_ack      ),
    .data_addr      (data_addr      ),
    .data_rd_data   (data_rd_data   ),
    .data_wr_data   (data_wr_data   ),
    .data_wr_mask   (data_wr_mask   ),
    .data_wr_en     (data_wr_en     ),
    .data_req       (data_req       ),
    .data_ack       (data_ack       ),
    .bootrom_addr   (bootrom_addr   ),
    .bootrom_rd_data(bootrom_rd_data),
    .bootrom_en     (bootrom_en     ),
    .mem0_addr      (mem0_addr      ),
    .mem0_rd_data   (mem0_rd_data   ),
    .mem0_wr_data   (mem0_wr_data   ),
    .mem0_en        (mem0_en        ),
    .mem0_wr_en     (mem0_wr_en     ),
    .mem0_wr_mask   (mem0_wr_mask   ),
    .mem1_addr      (mem1_addr      ),
    .mem1_rd_data   (mem1_rd_data   ),
    .mem1_wr_data   (mem1_wr_data   ),
    .mem1_en        (mem1_en        ),
    .mem1_wr_en     (mem1_wr_en     ),
    .mem1_wr_mask   (mem1_wr_mask   ),
    .sys_adr_o      (sys_adr_o      ),
    .sys_dat_i      (sys_dat_i      ),
    .sys_dat_o      (sys_dat_o      ),
    .sys_stb_o      (sys_stb_o      ),
    .sys_we_o       (sys_we_o       ),
    .sys_ack_i      (sys_ack_i      )
);

spsram32_model #(.WORDS(256), .AWIDTH(24)) u_bootrom (
    .clk    (~clk           ),
    .addr   (bootrom_addr   ),
    .wdata  (32'b0          ),
    .rdata  (bootrom_rd_data),
    .en     (bootrom_en     ),
    .wr_en  (1'b0           ),
    .wr_mask(4'b0           )
);

spsram32_model #(.WORDS(1024), .AWIDTH(24)) u_mem0 (
    .clk    (~clk        ),
    .addr   (mem0_addr   ),
    .wdata  (mem0_wr_data),
    .rdata  (mem0_rd_data),
    .en     (mem0_en     ),
    .wr_en  (mem0_wr_en  ),
    .wr_mask(mem0_wr_mask)
);

spsram32_model #(.WORDS(1024), .AWIDTH(24)) u_mem1 (
    .clk    (~clk        ),
    .addr   (mem1_addr   ),
    .wdata  (mem1_wr_data),
    .rdata  (mem1_rd_data),
    .en     (mem1_en     ),
    .wr_en  (mem1_wr_en  ),
    .wr_mask(mem1_wr_mask)
);

default clocking cb @(posedge clk);
    default input #10ps output #10ps;
    input instr_ack, instr_data;
    input data_ack, data_rd_data;
    output instr_req, instr_addr;
    output data_req, data_addr, data_wr_data, data_wr_mask, data_wr_en;
    output sys_ack_i, sys_dat_i;
endclocking


// ============================================================

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        instr_req = 0;
        data_req = 0;
        sys_ack_i = 0;

        for(int i=0; i<256; i++)
            u_bootrom.MEM[i] = $urandom;

        for(int i=0; i<1024; i++) begin
            u_mem0.MEM[i] = $urandom;
            u_mem1.MEM[i] = $urandom;
        end

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("instr_read") begin
        int choice;
        logic [23:0] addr, word;
        logic [31:0] check_data;

        repeat (1024) begin
            $display("\n-----------------------");

            // setup a read from one of the memories
            choice = $urandom_range(0,2);
            case (choice)
                0: begin
                    word = $urandom_range(0, 255);
                    addr = word<<2;
                    check_data = u_bootrom.MEM[word];                    
                end
                1: begin
                    word = $urandom_range(0, 1023);
                    addr = (word<<2) + 24'h10000;
                    check_data = u_mem0.MEM[word];
                end
                2: begin
                    word = $urandom_range(0, 1023);
                    addr = (word<<2) + 24'h20000;
                    check_data = u_mem1.MEM[word];
                end
            endcase // choice

            if (choice == 0) $display("BOOT[%0d]: %h", addr, check_data);
            else if (choice == 1) $display("MEM0[%0d]: %h", addr, check_data);
            else if (choice == 2) $display("MEM1[%0d]: %h", addr, check_data);

            @(cb);
            cb.instr_req <= 1'b1;
            cb.instr_addr <= addr;
            @(cb);
            cb.instr_req <= 1'b0;
            $display("instr_data: %h", cb.instr_data);
            assert(cb.instr_ack);
            assert(cb.instr_data == check_data);
        end

        ##64;
    end

    `TEST_CASE("data_readwrite") begin
        int choice;
        logic write;
        logic [23:0] addr, word;
        logic [31:0] check_data;
        logic [31:0] write_data, written_data;
        logic [3:0] wr_mask;

        repeat (1024) begin
            $display("\n-----------------------");

            // setup a read/write from one of the memories
            choice = $urandom_range(0,2);
            case (choice)
                0: begin
                    word = $urandom_range(0, 255);
                    addr = word<<2;
                end
                1: begin
                    word = $urandom_range(0, 1023);
                    addr = (word<<2) + 24'h10000;
                end
                2: begin
                    word = $urandom_range(0, 1023);
                    addr = (word<<2) + 24'h20000;
                end
            endcase // choice

            // Setup write, bootrom is read-only
            write = (choice == 0) ? 0 : $urandom_range(0,1);
            write_data = $urandom();
            wr_mask = (write) ? $urandom() : '1;

            // mask write data
            if (choice == 0) written_data = u_bootrom.MEM[word];
            else if (choice == 1) written_data = u_mem0.MEM[word];
            else if (choice == 2) written_data = u_mem1.MEM[word];
            for (int i=0; i<4; i++)
                if (wr_mask[i]) written_data[i*8+:8] = write_data[i*8+:8];

            @(cb);
            cb.data_req <= 1'b1;
            cb.data_addr <= addr;
            cb.data_wr_en <= write;
            cb.data_wr_data <= write_data;
            cb.data_wr_mask <= wr_mask;

            @(cb);
            cb.data_req <= 1'b0;
            assert(cb.data_ack);

            if (choice == 0) begin
                check_data = u_bootrom.MEM[word];
                $display("BOOT[%0d]: %h", addr, check_data);
            end
            else if (choice == 1) begin
                check_data = u_mem0.MEM[word];
                $display("MEM0[%0d]: %h", addr, check_data);
            end
            else if (choice == 2) begin
                check_data = u_mem1.MEM[word];
                $display("MEM1[%0d]: %h", addr, check_data);
            end

            if (write) begin
                $display("write_data: %h", write_data);
                $display("write_mask: %b", wr_mask);
                $display("written data: %h", written_data);
                assert(written_data == check_data);
            end
            else begin
                $display("data_rd_data: %h", cb.data_rd_data);
                assert(cb.data_rd_data == check_data);
            end
        end

        ##64;
    end

    `TEST_CASE("arbitrate") begin
        int Ichoice;
        logic [23:0] Iaddr, Iword;

        int Dchoice;
        logic Dwrite;
        logic [23:0] Daddr, Dword;
        logic [31:0] Dwrite_data;
        logic [3:0] Dwr_mask;

        logic arb;
        logic [31:0] Iread_data, Dread_data, Dwritten_data, Dwr_check_data;

        repeat (1024) begin
            $display("\n-----------------------");

            // ----------------------------------------------------
            // Setup a random operation for INSTR
            Ichoice = $urandom_range(0,2);
            case (Ichoice)
                0: begin
                    Iword = $urandom_range(0, 255);
                    Iaddr = Iword<<2;
                end
                1: begin
                    Iword = $urandom_range(0, 1023);
                    Iaddr = (Iword<<2) + 24'h10000;
                end
                2: begin
                    Iword = $urandom_range(0, 1023);
                    Iaddr = (Iword<<2) + 24'h20000;
                end
            endcase // choice

            if (Ichoice == 0) Iread_data = u_bootrom.MEM[Iword];
            else if (Ichoice == 1) Iread_data = u_mem0.MEM[Iword];
            else if (Ichoice == 2) Iread_data = u_mem1.MEM[Iword];

            // ----------------------------------------------------
            // Setup a random operation for DATA
            Dchoice = $urandom_range(0,2);
            case (Dchoice)
                0: begin
                    Dword = $urandom_range(0, 255);
                    Daddr = Dword<<2;
                end
                1: begin
                    Dword = $urandom_range(0, 1023);
                    Daddr = (Dword<<2) + 24'h10000;
                end
                2: begin
                    Dword = $urandom_range(0, 1023);
                    Daddr = (Dword<<2) + 24'h20000;
                end
            endcase // choice

            // Setup data write, bootrom is read-only
            Dwrite = (Dchoice == 0) ? 0 : $urandom_range(0,1);
            Dwrite_data = $urandom();
            Dwr_mask = (Dwrite) ? $urandom() : '1;

            // mask write data
            if (Dchoice == 0) Dread_data = u_bootrom.MEM[Dword];
            else if (Dchoice == 1) Dread_data = u_mem0.MEM[Dword];
            else if (Dchoice == 2) Dread_data = u_mem1.MEM[Dword];
            Dwritten_data = Dread_data;
            for (int i=0; i<4; i++)
                if (Dwr_mask[i]) Dwritten_data[i*8+:8] = Dwrite_data[i*8+:8];

            // ----------------------------------------------------
            // Drive both requests

            @(cb);
            cb.instr_req <= 1'b1;
            cb.instr_addr <= Iaddr;

            cb.data_req <= 1'b1;
            cb.data_addr <= Daddr;
            cb.data_wr_en <= Dwrite;
            cb.data_wr_data <= Dwrite_data;
            cb.data_wr_mask <= Dwr_mask;

            // ----------------------------------------------------
            // Result
            @(cb)
            cb.instr_req <= 1'b0;
            cb.data_req <= 1'b0;

            $display("I choice: %0d", Ichoice);
            $display("D choice: %0d", Dchoice);

            $display("I RD: %h", Iread_data);
            $display("D RD: %h", Dread_data);
            $display("D WR: %h", Dwritten_data);

            if (Dchoice == 0) Dwr_check_data = u_bootrom.MEM[Dword];
            else if (Dchoice == 1) Dwr_check_data = u_mem0.MEM[Dword];
            else if (Dchoice == 2) Dwr_check_data = u_mem1.MEM[Dword];

            // If the I and D interfaces aren't accessing the same resource,
            // then both requests will go through
            if (Ichoice != Dchoice)  begin
                $display("NO CONFLICT");
                assert(cb.instr_ack);
                assert(cb.data_ack);
                arb = 0;
            end
            else begin
                $display("DATA WINS");
                assert(~cb.instr_ack);
                assert(cb.data_ack);
                arb = 1;
            end

            if (!arb) $display("GOT I RD: %h", cb.instr_data);

            if (Dwrite) begin
                $display("GOT D WR: %h", Dwr_check_data);
            end
            else begin
                $display("GOT D RD: %h", cb.data_rd_data);
            end
        end
    end

    `TEST_CASE("system") begin
        logic write;
        logic [23:0] addr;
        logic [31:0] write_data, read_data;

        repeat (1024) begin
            $display("\n-----------------------");

            // setup a read/write of the system
            addr = 24'h800000 + $urandom_range(0,1023);

            write = $urandom_range(0,1);
            write_data = $urandom();

            read_data = $urandom();

            $display("addr: %h", addr);
            if (~write) $display("read: %h", read_data);
            $display("write: %h", write_data);

            @(cb);
            cb.data_req <= 1'b1;
            cb.data_addr <= addr;
            cb.data_wr_en <= write;
            cb.data_wr_data <= write_data;
            cb.data_wr_mask <= 4'hF;

            @(cb);
            $display("sys_adr_o: %h", sys_adr_o);
            $display("sys_dat_o: %h", sys_dat_o);
            $display("sys_we_o: %h", sys_we_o);
            $display("sys_stb_o: %h", sys_stb_o);

            repeat ($urandom_range(1,7)) begin
                $display("-");
                assert(~cb.data_ack);
                assert(sys_stb_o);
                assert(sys_adr_o == addr);
                assert(sys_dat_o == write_data);
                assert(sys_we_o == write);
                @(cb);
            end

            cb.sys_ack_i <= 1;
            if (~write) cb.sys_dat_i <= read_data;
            
            @(cb);
            $display("sys_dat_i: %h", sys_dat_i);
            cb.sys_ack_i <= 0;
            cb.sys_dat_i <= 'x;
            cb.data_req <= 1'b0;
            assert(cb.data_ack);

            if (~write) begin
                $display("Data Read: %h", cb.data_rd_data);
                assert(cb.data_rd_data == read_data);
            end

            @(cb);
            $display("sys_adr_o: %h", sys_adr_o);
            $display("sys_dat_o: %h", sys_dat_o);
            $display("sys_we_o: %h", sys_we_o);
            $display("sys_stb_o: %h", sys_stb_o);
            assert(~sys_stb_o);
        end

        ##64;
    end
end

`WATCHDOG(1ms);

endmodule
