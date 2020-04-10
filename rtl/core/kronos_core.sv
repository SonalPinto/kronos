// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos 
    4-stage RISC-V RV32I_Zicsr_Zifencei Core
*/

module kronos_core 
    import kronos_types::*;
#(
    parameter logic [31:0]  BOOT_ADDR = 32'h0,
    parameter logic         MCYCLE_IS_32BIT = 1'b0,
    parameter logic         MINSTRET_IS_32BIT = 1'b0
)(
    input  logic        clk,
    input  logic        rstz,
    // Instruction interface
    output logic [31:0] instr_addr,
    input  logic [31:0] instr_data,
    output logic        instr_req,
    input  logic        instr_ack,
    // Data interface
    output logic [31:0] data_addr,
    input  logic [31:0] data_rd_data,
    output logic [31:0] data_wr_data,
    output logic [3:0]  data_mask,
    output logic        data_wr_en,
    output logic        data_req,
    input  logic        data_ack,
    // Interrupt sources
    input  logic        software_interrupt,
    input  logic        timer_interrupt,
    input  logic        external_interrupt
);

logic [31:0] branch_target;
logic branch;

logic [31:0] regwr_data;
logic [4:0] regwr_sel;
logic regwr_en;

logic flush;

pipeIFID_t fetch;
pipeIDEX_t decode;
pipeEXWB_t execute;

logic fetch_vld, fetch_rdy;
logic decode_vld, decode_rdy;
logic execute_vld, execute_rdy;

// ============================================================
// Fetch
// ============================================================
kronos_IF #(
    .BOOT_ADDR(BOOT_ADDR)
) u_if (
    .clk          (clk          ),
    .rstz         (rstz         ),
    .instr_addr   (instr_addr   ),
    .instr_data   (instr_data   ),
    .instr_req    (instr_req    ),
    .instr_ack    (instr_ack    ),
    .fetch        (fetch        ),
    .pipe_out_vld (fetch_vld    ),
    .pipe_out_rdy (fetch_rdy    ),
    .branch_target(branch_target),
    .branch       (branch       )
);

// ============================================================
// Decode
// ============================================================

kronos_ID u_id (
    .clk         (clk       ),
    .rstz        (rstz      ),
    .flush       (flush     ),
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

// ============================================================
// Execute
// ============================================================

kronos_EX u_ex (
    .clk         (clk        ),
    .rstz        (rstz       ),
    .flush       (flush      ),
    .decode      (decode     ),
    .pipe_in_vld (decode_vld ),
    .pipe_in_rdy (decode_rdy ),
    .execute     (execute    ),
    .pipe_out_vld(execute_vld),
    .pipe_out_rdy(execute_rdy)
);

// ============================================================
// Write Back
// ============================================================

kronos_WB #(
    .BOOT_ADDR        (BOOT_ADDR        ),
    .MCYCLE_IS_32BIT  (MCYCLE_IS_32BIT  ),
    .MINSTRET_IS_32BIT(MINSTRET_IS_32BIT)
) u_wb (
    .clk               (clk               ),
    .rstz              (rstz              ),
    .execute           (execute           ),
    .pipe_in_vld       (execute_vld       ),
    .pipe_in_rdy       (execute_rdy       ),
    .regwr_data        (regwr_data        ),
    .regwr_sel         (regwr_sel         ),
    .regwr_en          (regwr_en          ),
    .branch_target     (branch_target     ),
    .branch            (branch            ),
    .data_addr         (data_addr         ),
    .data_rd_data      (data_rd_data      ),
    .data_wr_data      (data_wr_data      ),
    .data_mask         (data_mask         ),
    .data_wr_en        (data_wr_en        ),
    .data_req          (data_req          ),
    .data_ack          (data_ack          ),
    .software_interrupt(software_interrupt),
    .timer_interrupt   (timer_interrupt   ),
    .external_interrupt(external_interrupt)
);

// Flush pipeline on branch
assign flush = branch;

endmodule