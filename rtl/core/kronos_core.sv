// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos 
    4-stage RV32I RISC-V Core
*/

module kronos_core 
    import kronos_types::*; 
(
    input  logic        clk,
    input  logic        rstz,
    output logic [31:0] instr_addr,
    input  logic [31:0] instr_data,
    output logic        instr_req,
    input  logic        instr_gnt
);

logic [31:0] branch_target;
logic branch;

logic [31:0] regwr_data;
logic [4:0] regwr_sel;
logic regwr_en;

logic [31:0] fwd_data;
logic fwd_vld;

pipeIFID_t fetch;
pipeIDEX_t decode;
pipeEXWB_t execute;
hazardEX_t ex_hazard;

logic fetch_vld, fetch_rdy;
logic decode_vld, decode_rdy;
logic execute_vld, execute_rdy;

// ============================================================
// Fetch
// ============================================================
kronos_IF u_if (
    .clk          (clk          ),
    .rstz         (rstz         ),
    .instr_addr   (instr_addr   ),
    .instr_data   (instr_data   ),
    .instr_req    (instr_req    ),
    .instr_gnt    (instr_gnt    ),
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
    .fetch       (fetch     ),
    .pipe_in_vld (fetch_vld ),
    .pipe_in_rdy (fetch_rdy ),
    .decode      (decode    ),
    .ex_hazard   (ex_hazard ),
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
    .decode      (decode     ),
    .ex_hazard   (ex_hazard  ),
    .pipe_in_vld (decode_vld ),
    .pipe_in_rdy (decode_rdy ),
    .execute     (execute    ),
    .pipe_out_vld(execute_vld),
    .pipe_out_rdy(execute_rdy),
    .fwd_data    (fwd_data   ),
    .fwd_vld     (fwd_vld    )
);

// ============================================================
// Write Back
// ============================================================
kronos_WB u_wb (
    .clk        (clk        ),
    .rstz       (rstz       ),
    .execute    (execute    ),
    .pipe_in_vld(execute_vld),
    .pipe_in_rdy(execute_rdy),
    .regwr_data (regwr_data ),
    .regwr_sel  (regwr_sel  ),
    .regwr_en   (regwr_en   )
);

assign fwd_vld = regwr_en;
assign fwd_data = regwr_data;

// assign branch = 1'b0;
// assign branch_target = '0;

assign branch = regwr_en;
assign branch_target = regwr_data;

endmodule