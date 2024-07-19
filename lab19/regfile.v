module regfile(
    input         clk,
    // READ PORT 1
    input  [ 4:0] raddr1,
    output [31:0] rdata1,
    // READ PORT 2
    input  [ 4:0] raddr2,
    output [31:0] rdata2,
    // WRITE PORT
    input  [3:0]       we,       //write enable, HIGH valid
    input  [ 4:0] waddr,
    input  [3:0][7:0] wdata
);
reg [0:31][3:0][7:0] rf;

//WRITE
genvar i ;
generate for(i=0;i<4;i++)
    always @(posedge clk) begin
        if (we[i]) rf[waddr][i]<= wdata[i];
    end
endgenerate

//READ OUT 1
assign rdata1 = (raddr1==5'b0) ? 32'b0 : rf[raddr1];

//READ OUT 2
assign rdata2 = (raddr2==5'b0) ? 32'b0 : rf[raddr2];

endmodule
