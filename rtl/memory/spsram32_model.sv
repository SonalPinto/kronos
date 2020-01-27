// Single Port 32b SRAM model

module spsram32_model #(
    parameter DEPTH = 256
)(
    input  logic                        clk,
    input  logic                        rstz,
    input  logic [31:0]                 addr,
    output logic [31:0]                 data,
    input  logic                        req,
    output logic                        gnt
);

logic [31:0] MEM [DEPTH];

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        data <= '1;
        gnt <= '0;
    end
    else if (req) begin
        gnt <= 1'b1;
        data <= MEM[addr[$clog2(DEPTH)-1:0]];
    end
    else gnt <= 1'b0;
end
endmodule