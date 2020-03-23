// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Basic System Bus, designed to work with icebreaker_memory_lite
*/

module icebreaker_system_bus_lite (
    input  logic        clk,
    input  logic        rstz,
    // Core.instr interface
    input  logic [31:0] instr_addr,
    output logic [31:0] instr_data,
    input  logic        instr_req,
    output logic        instr_gnt,
    // Core.data interface
    input  logic [31:0] data_addr,
    output logic [31:0] data_rd_data,
    input  logic [31:0] data_wr_data,
    input  logic [3:0]  data_wr_mask,
    input  logic        data_rd_req,
    input  logic        data_wr_req,
    output logic        data_gnt,
    // Main Memory interface
    output logic [31:0] mem_addr,
    input  logic [31:0] mem_rd_data,
    output logic [31:0] mem_wr_data,
    output logic        mem_en,
    output logic        mem_wr_en,
    output logic [3:0]  mem_wr_mask,
    // GPIO interface
    output logic [31:0] gpio_addr,
    input  logic [31:0] gpio_rd_data,
    output logic [31:0] gpio_wr_data,
    output logic        gpio_en,
    output logic        gpio_wr_en
);

parameter GPIO = 4'h0;

logic mem_instr_rd_req;
logic mem_data_rd_req;
logic mem_data_wr_req;
logic gpio_data_rd_req;
logic gpio_data_wr_req;

logic is_mem_data_access;
logic is_gpio_data_access;

logic is_system;
logic [3:0] system_mask;

logic mem_instr_gnt;
logic mem_data_gnt;
logic gpio_data_gnt;

// ============================================================
// Main Memory
// 4KB: 0x0000 - 0x1000

assign is_system = data_addr[12];

assign mem_instr_rd_req = instr_req;
assign mem_data_rd_req  = data_rd_req && ~is_system;
assign mem_data_wr_req  = data_wr_req && ~is_system;

assign is_mem_data_access = mem_data_rd_req | mem_data_wr_req;

// Data has Priority
always_comb begin
    mem_en      = |{mem_instr_rd_req, mem_data_rd_req, mem_data_wr_req};
    mem_wr_en   = mem_data_wr_req;

    mem_addr    = is_mem_data_access ? data_addr : instr_addr;

    mem_wr_data = data_wr_data;
    mem_wr_mask = data_wr_mask;
end

// ============================================================
// System
// 4KB: 0x1000 - 0x2000

assign system_mask = data_addr[11:8];

// GPIO: 0x1000 - 0x1000 - 0x10FF
// 64 words
assign gpio_data_rd_req  = data_rd_req && is_system && system_mask == GPIO;
assign gpio_data_wr_req  = data_wr_req && is_system && system_mask == GPIO;

assign is_gpio_data_access = gpio_data_rd_req | gpio_data_wr_req;

always_comb begin
    gpio_en      = is_gpio_data_access;
    gpio_wr_en   = gpio_data_wr_req;
    gpio_addr    = data_addr;
    gpio_wr_data = data_wr_data;
end


// ============================================================
// Grant
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        mem_instr_gnt <= 1'b0;
        mem_data_gnt <= 1'b0;
        gpio_data_gnt <= 1'b0;
    end
    else begin
        mem_instr_gnt <= mem_instr_rd_req & ~is_mem_data_access;
        mem_data_gnt <= is_mem_data_access;
        gpio_data_gnt <= is_gpio_data_access;
    end
end

// Select grant source for read-data
always_comb begin
    instr_data = mem_rd_data;
    data_rd_data = mem_rd_data;
    instr_gnt = 1'b0;
    data_gnt= 1'b0;

    if (mem_instr_gnt) begin
        instr_gnt = 1'b1;
    end
    
    if (mem_data_gnt) begin
        data_gnt = 1'b1;
    end
    else if (gpio_data_gnt) begin
        data_gnt = 1'b1;
        data_rd_data = gpio_rd_data;
    end
end

endmodule
