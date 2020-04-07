// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
System Bus for the KRZ SoC

- Presents dual wishbone slave buses to the Kronos Instruction and Data interface.
- Arbitrates access to the all resources, at the individual resource level.
- Multiplexes peripheral interfaces to the Kronos Data interface.

The instr and data interface can access the system resources 
individually and concurrently. 

When they both access the same resource arbitration is required.
Data interface has priority, else the system will deadlock.

The main memory of is split into two banks of 64K each. If all of the text is 
located in Bank0 and the data and stack in Bank1, then there's almost never any 
contention between the two interfaces. The system can run at its peak performance.


0x1000000    24b/16MB Address Space
+----------+------------+           ^
0xffffff   |            |           |
           |            |           |
           |   SYSTEM   |           | 8MB
           |      8MB   |           |
           |            |           |
0x800000   |            |           v
+-----------------------+           ^
0x7fffff   |            |           |
           |  reserved  |           |
           |            |           |
+-----------------------+           |
0x02ffff   |            |           |
           |    RAM     |           |
           |     2x64K  |           |
0x010000   |            |           |
+-----------------------+           |
0x00ffff   |            |   ^       |  8MB
           |  reserved  |   |       |
           |            |   |       |
+-----------------------+   |       |
           |            |   | 64K   |
           |  BOOT ROM  |   |       |
           |        1K  |   |       |
0x000000   |            |   |       |
+----------+------------+   v       v

*/

module krz_intercon (
    input  logic        clk,
    input  logic        rstz,
    // Core.instr interface
    input  logic [23:0] instr_addr,
    output logic [31:0] instr_data,
    input  logic        instr_req,
    output logic        instr_ack,
    // Core.data interface
    input  logic [23:0] data_addr,
    output logic [31:0] data_rd_data,
    input  logic [31:0] data_wr_data,
    input  logic [3:0]  data_wr_mask,
    input  logic        data_wr_en,
    input  logic        data_req,
    output logic        data_ack,
    // Boot ROM interface
    output logic [23:0] bootrom_addr,
    input  logic [31:0] bootrom_rd_data,
    output logic        bootrom_en,
    // Main Memory Bank0 interface
    output logic [23:0] mem0_addr,
    input  logic [31:0] mem0_rd_data,
    output logic [31:0] mem0_wr_data,
    output logic        mem0_en,
    output logic        mem0_wr_en,
    output logic [3:0]  mem0_wr_mask,
    // Main Memory Bank1 interface
    output logic [23:0] mem1_addr,
    input  logic [31:0] mem1_rd_data,
    output logic [31:0] mem1_wr_data,
    output logic        mem1_en,
    output logic        mem1_wr_en,
    output logic [3:0]  mem1_wr_mask,
    // System interface
    output logic [23:0] sys_adr_o,
    input  logic [31:0] sys_dat_i,
    output logic [31:0] sys_dat_o,
    output logic        sys_stb_o,
    output logic        sys_we_o,
    input  logic        sys_ack_i
);

logic instr_addr_in_bootrom;
logic data_addr_in_bootrom;
logic instr_addr_in_mem0;
logic data_addr_in_mem0;
logic instr_addr_in_mem1;
logic data_addr_in_mem1;
logic data_addr_in_sys;

logic bootrom_instr_req;
logic bootrom_data_req;
logic mem0_instr_req;
logic mem0_data_req;
logic mem1_instr_req;
logic mem1_data_req;
logic sys_data_req;

enum logic [2:0] {
    NONE,
    BOOTROM,
    MEM0,
    MEM1,
    SYS
} instr_gnt, data_gnt;


// ============================================================
// Address filters
// ============================================================
// Filter address by looking at as few bits as possible
// Warning & FIXME: illegal address aren't caught, this is left to the code

/*
Boot ROM, 1KB: 0x000000 - 0x0003ff
Both the Instr and Data interfaces can access this segment
Filter in address when addr[17:16] == 00
*/
assign instr_addr_in_bootrom = instr_addr[17:16] == 2'b00;
assign data_addr_in_bootrom = (data_addr[17:16] == 2'b00) && ~data_addr[23];

/*
Main Memory (RAM), 128KB: 0x010000 - 0x02ffff
Both the Instr and Data interfaces can access this segment
Filter in address when addr[17:16] == 01 or 10
Bank0: 01
Bank1: 10
*/
assign instr_addr_in_mem0 = instr_addr[17:16] == 2'b01;
assign data_addr_in_mem0 = (data_addr[17:16] == 2'b01) && ~data_addr[23];

assign instr_addr_in_mem1 = instr_addr[17:16] == 2'b10;
assign data_addr_in_mem1 = (data_addr[17:16] == 2'b10) && ~data_addr[23];

/*
System, 8M: 0x800000 - 0xffffff
Only the Data interfaces can access this segment
*/
assign data_addr_in_sys = data_addr[23];

// ============================================================
// Arbitration
// ============================================================

// Boot ROM
always_comb begin
    bootrom_instr_req = instr_req & instr_addr_in_bootrom;
    bootrom_data_req = data_req & data_addr_in_bootrom;

    bootrom_en =  bootrom_instr_req | bootrom_data_req;
    bootrom_addr = (bootrom_data_req) ? data_addr : instr_addr;
end

// Main Memory Bank0
always_comb begin
    mem0_instr_req = instr_req & instr_addr_in_mem0;
    mem0_data_req = data_req & data_addr_in_mem0;

    mem0_en =  mem0_instr_req | mem0_data_req;
    mem0_addr = (mem0_data_req) ? data_addr : instr_addr;

    mem0_wr_mask = data_wr_mask;
    mem0_wr_data = data_wr_data;
    mem0_wr_en = data_wr_en;
end

// Main Memory Bank1, same routing as Bank0
always_comb begin
    mem1_instr_req = instr_req & instr_addr_in_mem1;
    mem1_data_req = data_req & data_addr_in_mem1;

    mem1_en =  mem1_instr_req | mem1_data_req;
    mem1_addr = (mem1_data_req) ? data_addr : instr_addr;

    mem1_wr_mask = data_wr_mask;
    mem1_wr_data = data_wr_data;
    mem1_wr_en = data_wr_en;
end

// System access - data interface only
always_comb begin
    sys_data_req = data_req & data_addr_in_sys;

    // wishbone pass-thru
    sys_stb_o = sys_data_req;
    sys_adr_o = data_addr;
    sys_we_o = data_wr_en;
    sys_dat_o = data_wr_data;
end 

// ============================================================
// Grant Mux
// ============================================================

// Instruction Grant Mux
always_ff @(negedge clk or negedge rstz) begin
    if (~rstz) begin
        instr_gnt <= NONE;
    end
    else begin
        if (bootrom_instr_req && ~bootrom_data_req) instr_gnt <= BOOTROM;
        else if (mem0_instr_req && ~mem0_data_req) instr_gnt <= MEM0;
        else if (mem1_instr_req && ~mem1_data_req) instr_gnt <= MEM1;
        else instr_gnt <= NONE;
    end
end

// Data Grant Mux
always_ff @(negedge clk or negedge rstz) begin
    if (~rstz) begin
        data_gnt <= NONE;
    end
    else begin
        // if in a bus cycle for the system, then wait for the ack
        // memory access are single cycle
        if (bootrom_data_req) data_gnt <= BOOTROM;
        else if (mem0_data_req) data_gnt <= MEM0;
        else if (mem1_data_req) data_gnt <= MEM1;
        else if (sys_data_req && sys_ack_i) data_gnt <= SYS;
        else data_gnt <= NONE;
    end
end

// Select grant source for instr read-data
always_comb begin
    instr_ack = instr_gnt != NONE;

    case (instr_gnt)
        MEM0    : instr_data = mem0_rd_data;
        MEM1    : instr_data = mem1_rd_data;
        default : instr_data = bootrom_rd_data;
    endcase // instr_gnt
end

// Select grant source for data read-data
always_comb begin
    data_ack = data_gnt != NONE;

    case (data_gnt)
        MEM0    : data_rd_data = mem0_rd_data;
        MEM1    : data_rd_data = mem1_rd_data;
        SYS     : data_rd_data = sys_dat_i;
        default : data_rd_data = bootrom_rd_data;
    endcase // instr_gnt
end

endmodule 
