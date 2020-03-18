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
    // Instruction interface
    output logic [31:0] instr_addr,
    input  logic [31:0] instr_data,
    output logic        instr_req,
    input  logic        instr_gnt,
    // Data interface
    output logic [31:0] data_addr,
    input  logic [31:0] data_rd_data,
    output logic [31:0] data_wr_data,
    output logic [3:0]  data_wr_mask,
    output logic        data_rd_req,
    output logic        data_wr_req,
    input  logic        data_gnt
);

logic [31:0] branch_target;
logic branch;

logic [31:0] regwr_data;
logic [4:0] regwr_sel;
logic regwr_en;

logic [11:0] csr_addr;
logic [1:0] csr_op;
logic [31:0] csr_rd_data;
logic [31:0] csr_wr_data;
logic csr_rd_req;
logic csr_wr_req;
logic csr_gnt;
logic instret;

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

// Flush pipeline on branch
assign flush = branch;

endmodule