// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Basic System Bus for snowflake platform
*/

module snowflake_system_bus (
    input  logic        clk,
    input  logic        rstz,
    // Core.instr interface
    input  logic [31:0] instr_addr,
    output logic [31:0] instr_data,
    input  logic        instr_req,
    output logic        instr_ack,
    // Core.data interface
    input  logic [31:0] data_addr,
    output logic [31:0] data_rd_data,
    input  logic [31:0] data_wr_data,
    input  logic [3:0]  data_mask,
    input  logic        data_wr_en,
    input  logic        data_req,
    output logic        data_ack,
    // Main Memory interface
    output logic [31:0] mem_addr,
    input  logic [31:0] mem_rd_data,
    output logic [31:0] mem_wr_data,
    output logic        mem_en,
    output logic        mem_wr_en,
    output logic [3:0]  mem_mask,
    // System interface
    output logic [31:0] sys_addr,
    input  logic [31:0] sys_rd_data,
    output logic [31:0] sys_wr_data,
    output logic        sys_en,
    output logic        sys_wr_en
);

parameter SYSTEM = 4'h0;

logic mem_instr_req;
logic mem_data_req;
logic sys_data_req;

logic is_system;
logic [3:0] system_mask;

logic mem_instr_ack;
logic mem_data_ack;
logic sys_data_ack;

// ============================================================
// Main Memory
// 4KB: 0x0000 - 0x1000

assign is_system = data_addr[12];

assign mem_instr_req = instr_req;
assign mem_data_req  = data_req && ~is_system;

// Data has Priority
always_comb begin
    mem_en      = mem_instr_req || mem_data_req;
    mem_wr_en   = mem_data_req && data_wr_en;

    mem_addr    = mem_data_req ? data_addr : instr_addr;

    mem_wr_data = data_wr_data;

    // mask is only used for write
    mem_mask    = data_mask;
end

// ============================================================
// System
// 4KB: 0x1000 - 0x2000

assign system_mask = data_addr[11:8];

// SYS: 0x1000 - 0x1000 - 0x10FF
// 64 words
assign sys_data_req  = data_req && is_system && system_mask == SYSTEM;

always_comb begin
    sys_en      = sys_data_req;
    sys_wr_en   = sys_data_req && data_wr_en;
    sys_addr    = data_addr;
    sys_wr_data = data_wr_data;
end


// ============================================================
// Grant
always_ff @(negedge clk or negedge rstz) begin
    if (~rstz) begin
        mem_instr_ack <= 1'b0;
        mem_data_ack <= 1'b0;
        sys_data_ack <= 1'b0;
    end
    else begin
        mem_instr_ack <= mem_instr_req & ~mem_data_req;
        mem_data_ack <= mem_data_req;
        sys_data_ack <= sys_data_req;
    end
end

// Select grant source for read-data
always_comb begin
    instr_data = mem_rd_data;
    data_rd_data = mem_rd_data;
    instr_ack = 1'b0;
    data_ack = 1'b0;

    if (mem_instr_ack) begin
        instr_ack = 1'b1;
    end
    
    if (mem_data_ack) begin
        data_ack = 1'b1;
    end
    else if (sys_data_ack) begin
        data_ack = 1'b1;
        data_rd_data = sys_rd_data;
    end
end

endmodule
