module pipeline_buffer(
    parameter WIDTH = 32,
    parameter logic PASS_THRU = 1
)(
    input  logic                clk,
    input  logic                rstz,
    input  logic [WIDTH-1:0]    din,
    input  logic                din_vld,
    output logic                din_rdy,
    output logic [WIDTH-1:0]    dout,
    output logic                dout_vld,
    input  logic                dout_rdy
);

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        dout <= '0;
        dout_vld <= '0;
    end
    else begin
        if (din_vld && din_rdy) begin
            dout <= din;
            dout_vld <= 1'b1;
        end
        else if (dout_vld && dout_rdy) begin
            dout_vld <= 1'b0;
        end
    end
end

generate
if(PASS_THRU == 1) begin
    // combinational path from dout_rdy to din_rdy, i.e. across the stages
    // WARNING: Can become the critical path if used recklessly
    assign din_rdy = ~dout_vld | (dout_rdy);
end
else begin
    // The buffer cannot be dequeued/enqueued on the same cycle
    assign din_rdy = ~dout_vld;
end 
endgenerate 

endmodule