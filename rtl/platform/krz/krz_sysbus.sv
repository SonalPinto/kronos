// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*

KRZ System Peripheral Bus

- Multiplex access to the system peripherals.
- Address needs to be word aligned so the core will read the data from 
the lowest byte of the word

For system address map, see: krz_map

Crossbar facing: Wishbone slave interface
    - Registered Feedback Bus Cycle, Classic
*/

module krz_sysbus #(
    parameter N = 3
)(
    input  logic                clk,
    input  logic                rstz,
    // Crossbar
    input  logic [23:0]         sys_adr_i,
    input  logic [31:0]         sys_dat_i,
    output logic [31:0]         sys_dat_o,
    input  logic                sys_we_i,
    input  logic                sys_stb_i,
    output logic                sys_ack_o,
    // Peripheral Bus
    output logic [5:0]          perif_adr_o,
    input  logic [N-1:0][31:0]  perif_dat_i,
    output logic [31:0]         perif_dat_o,
    output logic                perif_we_o,
    output logic [N-1:0]        perif_stb_o,
    input  logic [N-1:0]        perif_ack_o
);

logic ack;

// Register grant and peripheral bus IO
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        perif_stb_o <= '0;
    end
    else if (perif_stb_o == '0 && sys_stb_i && ~sys_ack_o) begin

        for (int i=0; i<N; i++) begin
            perif_stb_o[i] <= sys_adr_i[11:8] == i[3:0];
        end

        perif_adr_o <= sys_adr_i[7:2];
        perif_dat_o <= sys_dat_i;
        perif_we_o  <= sys_we_i;
    end
    else if (perif_stb_o != '0 && ack) begin
        perif_stb_o <= '0;
    end
end

// accumulate ACK from all peripherals
assign ack = |{perif_ack_o};

// ============================================================
// Crossbar Wiring
// Register an ACK and read data signal for the crossbar
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        sys_ack_o <= 1'b0;
    end
    else if (perif_stb_o != '0 && ack) begin
        sys_ack_o <= 1'b1;

        for (int i=N-1; i>=0; i--) begin
            if (perif_stb_o[i]) sys_dat_o <= perif_dat_i[i];
        end
    end
    else begin
        sys_ack_o <= 1'b0;
    end
end

// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
    , sys_adr_i[23:12]
    , sys_adr_i[1:0]
    , sys_dat_i[31:8]
};
`endif

endmodule