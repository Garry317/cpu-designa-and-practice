module SRAM_MDL #(
    parameter   DEPTH   = 256 ,
    parameter   AW      = $clog2(DEPTH) ,
    parameter   BW      = 32 ,
    parameter   NUM     = 4 ,
    parameter   DW      = BW/NUM
)(
    input   clk ,
    input   resetn ,
    input   cen ,
    input   wen , 
    input   [NUM-1:0]           wemn ,
    input   [NUM-1:0][DW-1:0]   d ,
    input   [AW-1:0]            addr ,
    output  [NUM-1:0][DW-1:0]   q 
) ;
    genvar i ;
    
    reg [0:DEPTH-1][NUM-1:0][DW-1:0] mem ;

    reg [BW-1:0]  q ;

    always @(posedge clk) 
        if(!cen & wen)
            q <= mem[addr] ;
        else 
            q <= 'hX ;

    generate 
        for(i=0;i<NUM;i++) begin
            always @(posedge clk)
                if(!resetn && i==0)
                    mem <= 0 ;
                else if(!cen & !wen & wemn[i])
                    mem[addr][i] <= d[i] ;
        end
    endgenerate

endmodule
