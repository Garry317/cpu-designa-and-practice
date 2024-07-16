module sram2axi #(
) (
    input           clk ,
    input           resetn ,
    // sram interface 
    input           inst_req,
    input           inst_wr ,
    input  [ 3:0]   inst_wstrb,
    input  [31:0]   inst_addr,
    input  [31:0]   inst_wdata,
    output [31:0]   inst_rdata,
    output          inst_addr_ok ,
    output          inst_data_ok ,
    input  [1:0]    inst_size ,

    input           data_sram_req,
    input           data_sram_wr ,
    input  [ 3:0]   data_sram_wstrb,
    input  [31:0]   data_sram_addr,
    input  [31:0]   data_sram_wdata,
    output [31:0]   data_sram_rdata,
    output          data_sram_addr_ok ,
    output          data_sram_data_ok ,
    input  [1:0]    data_sram_size ,
    // ar 
    output [3 :0]   arid   , 
    output [31:0]   araddr ,
    output [7 :0]   arlen  ,
    output [2 :0]   arsize ,
    output [1 :0]   arburst,
    output [1 :0]   arlock , 
    output [3 :0]   arcache,
    output [2 :0]   arprot ,
    output          arvalid,
    input           arready,
    //r
    input  [3 :0]   rid    ,
    input  [31:0]   rdata  ,
    input  [1 :0]   rresp  ,
    input           rlast  ,
    input           rvalid ,
    output          rready ,
    //aw
    output [3 :0]   awid   ,
    output [31:0]   awaddr ,
    output [7 :0]   awlen  ,
    output [2 :0]   awsize ,
    output [1 :0]   awburst,
    output [1 :0]   awlock ,
    output [3 :0]   awcache,
    output [2 :0]   awprot ,
    output          awvalid,
    input           awready,
    //w
    output [3 :0]   wid    ,
    output [31:0]   wdata  ,
    output [3 :0]   wstrb  ,
    output          wlast  ,
    output          wvalid ,
    input           wready ,
    //b
    input  [3 :0]   bid    ,
    input  [1 :0]   bresp  ,
    input           bvalid ,
    output          bready 
);

    localparam IDLE         = 0 ;
    localparam WAIT_REQ     = 1 ;
    localparam WAIT_DRSP    = 2 ;
    localparam WAIT_IRSP    = 3 ;
    
    wire    inst_rd ;
    wire    data_rd ;
    wire    data_wr ;
   
    reg [2:0]   ar_st ;
    reg [2:0]   ar_nst ;
    reg [3:0]   arid_r ;
    reg [31:0]  araddr_r ;
    reg         arvalid_r ;
    reg [2:0]   arsize_r ;

    reg         rready_r ;
    reg [31:0]  awaddr_r ;
    reg [3:0]   awsize_r ;
    reg         awvalid_r ;         
    reg [31:0]  wdata_r ;
    reg [3:0]   wstrb_r ;
    reg         wvalid_r ;
    reg         bready_r ;

    assign inst_rd  = inst_req && !inst_wr ;
    assign data_rd  = data_sram_req && !data_sram_wr ;
    assign data_wr  = data_sram_req && data_sram_wr ;

    // ar control 
    
    always @(*) begin
        case(ar_st)
            IDLE        : ar_nst = resetn ? WAIT_REQ : IDLE ;
            WAIT_REQ    : ar_nst = data_rd ? WAIT_DRSP : inst_rd ? WAIT_IRSP : WAIT_REQ ;
            WAIT_DRSP   : ar_nst = arready ? inst_rd ? WAIT_IRSP : WAIT_REQ : WAIT_DRSP ;
            WAIT_IRSP   : ar_nst = arready ? data_rd ? WAIT_DRSP : WAIT_REQ : WAIT_IRSP ;
        default : ar_nst  = IDLE ;
        endcase 
    end

    always @(posedge clk) 
        if(!resetn)
            ar_st   <= IDLE ;
        else 
            ar_st   <= ar_nst ;

    always @(posedge clk) 
        if(ar_nst==WAIT_DRSP && ar_st!=WAIT_DRSP) begin
            arid_r  <= 1 ;
            araddr_r<= data_sram_addr ;
            arsize_r<= data_sram_size ;
        end
        else if(ar_nst==WAIT_IRSP && ar_st!=WAIT_IRSP) begin
            arid_r <= 0 ;
            araddr_r<= inst_sram_addr ;
            arsize_r <= inst_sram_size ;
        end

    always @(posedge clk) 
        if(!resetn)
            arvalid_r <= 0 ;
        else if(ar_nst==IDLE || ar_nst==WAIT_REQ) 
            arvalid_r <= 0 ;
        else if(ar_nst==WAIT_IRSP||ar_nst==WAIT_DRSP)
            arvalid_r <= 1 ;
    // read control 

    always @(posedge clk) 
        if(!resetn)
            rready_r <= 0 ;
        else 
            rready_r <= 1 ;
    
    always @(posedge clk) 
        if(!resetn) 
            awvalid_r <= 0 ;
        else  if(awready)
            awvalid_r <= 0 ;
        else if(data_wr) 
            awvalid_r <= 1 ;

    always @(posedge clk) 
        if(data_wr) begin
            awaddr_r <= data_sram_addr ;
            awsize_r <= data_sram_size ;
        end
         
    always @(posedge clk) 
        if(!resetn)
            wvalid_r    <= 0 ;
        else if(wready)
            wvalid_r    <= 0 ;
        else if(data_wr)
            wvalid_r    <= 1 ;
    
    always @(posedge clk) 
        if(data_wr) begin
            wdata_r <= data_sram_wdata ;
            wstrb_r <= data_sram_wstrb ;
        end

    always @(posedge clk) 
        if(!resetn)
            bready_r <= 0 ;
        else 
            bready_r <= 1 ;

    // output 
    assign arid = arid_r ;
    assign araddr   = araddr_r ;
    assign arsize   = arsize_r ;
    assign arlen    = 8'd0 ;
    assign arburst  = 2'b01 ;
    assign arlock   = 2'd0 ;
    assign arcache  = 4'd0 ;
    assign arprot   = 3'd0 ;
    assign arvalid  = arvalid_r ;

    assign rready   = rready_r ;
    
    assign awid     = 4'd1 ;
    assign awaddr   = awaddr_r ;
    assign awvalid  = awvalid_r ;
    assign awlen    = 8'd0 ;
    assign awburst  = 2'b01 ;
    assign awlock   = 2'd0 ;
    assign awcache  = 4'd0 ;
    assign awprot   = 3'd0 ;
    
    assign wid      = 4'd1 ;
    assign wlast    = 4'd1 ;
    assign wstrb    = wstrb_r ;
    assign wvalid   = wvalid_r ;
    assign wdata    = wdata_r ;

    assign bready   = bready_r ;
    
    // sram interface 
    assign inst_sram_addr_ok = arready && !arid && araddr==inst_sram_addr;
    assign inst_sram_data_ok = rvalid && rready && !rid ;
    assign inst_sram_rdata   = rdata ;

    assign data_sram_addr_ok = awready && awid || (arready && arid && araddr==data_sram_addr);
    assign data_sram_data_ok = (wvalid && wready && wid) || (rvalid && rready && rid) ;
    assign data_sram_rdata   = rdata ;

endmodule 
