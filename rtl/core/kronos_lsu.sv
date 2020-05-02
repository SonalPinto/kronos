// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Load Store Unit

Control unit that interfaces with "Data" memory and fulfills
Load/Store instructions

Memory Access needs to be aligned.

*/

module kronos_lsu
  import kronos_types::*;
(
  // ID/EX
  input  pipeIDEX_t   decode,
  input  logic        lsu_vld,
  output logic        lsu_rdy,
  // Register write-back
  output logic [31:0] load_data,
  output logic        regwr_lsu,
  // Memory interface
  output logic [31:0] data_addr,
  input  logic [31:0] data_rd_data,
  output logic [31:0] data_wr_data,
  output logic [3:0]  data_mask,
  output logic        data_wr_en,
  output logic        data_req,
  input  logic        data_ack
);

logic [4:0] rd;
logic [1:0] byte_addr;
logic [1:0] data_size;
logic load_uns;

logic [3:0][7:0] ldata;
logic [31:0] word_data, half_data, byte_data;

// ============================================================
// IR Segments
assign byte_addr = decode.addr[1:0];
assign data_size = decode.ir[13:12];
assign load_uns = decode.ir[14];
assign rd  = decode.ir[11:7];

// ============================================================
// Memory interface
assign data_addr = {decode.addr[31:2], 2'b0};
assign data_wr_data = decode.op2;
assign data_mask = decode.mask;
assign data_wr_en = lsu_vld && decode.store && ~data_ack;
assign data_req = lsu_vld && (decode.load | decode.store) && ~data_ack;

// response controls
assign lsu_rdy = data_ack;
assign regwr_lsu = decode.load && rd != '0;

// ============================================================
// Load

// byte cast read data
assign ldata = data_rd_data;

always_comb begin
  // Barrel Rotate Right read data bytes as per offset
  case(byte_addr)
    2'b00: word_data = ldata;
    2'b01: word_data = {ldata[0]  , ldata[3:1]};
    2'b10: word_data = {ldata[1:0], ldata[3:2]};
    2'b11: word_data = {ldata[2:0], ldata[3]};
  endcase
end

always_comb begin
  // select BYTE data, sign extend if needed
  if (load_uns) byte_data = {24'b0, word_data[7:0]};
  else byte_data = {{24{word_data[7]}}, word_data[7:0]};

  // Select HALF data, sign extend if needed
  if (load_uns) half_data = {16'b0, word_data[15:0]};
  else half_data = {{16{word_data[15]}}, word_data[15:0]};
end

// Finally, mux load data
always_comb begin
  if (data_size == BYTE) load_data = byte_data;
  else if (data_size == HALF) load_data = half_data;
  else load_data = word_data;
end


// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
  , decode
};
`endif

endmodule
