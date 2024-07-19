module c2a #(
)(
    input           clk ,
    input           resetn ,
    // inst interface 
    input  logic          inst_rd_req,
    input  logic [ 2:0]   inst_rd_type,
    input  logic [31:0]   inst_rd_addr,
    output logic [31:0]   inst_ret_data,
    output logic          inst_ret_valid,
    output logic          inst_ret_last,
    output logic          inst_rd_rdy ,
    
    input  logic          data_rd_req,
    input  logic [ 2:0]   data_rd_type,
    input  logic [31:0]   data_rd_addr,
    output logic [31:0]   data_ret_data,
    output logic          data_ret_valid,
    output logic          data_ret_last,
    output logic          data_rd_rdy,
    
    input  logic          data_wr_req,
    input  logic [ 2:0]   data_wr_type,
    input  logic [ 3:0]   data_wr_wstrb,
    input  logic [31:0]   data_wr_addr,
    input  logic [127:0]  data_wr_data,
    output logic          data_wr_rdy,
    
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

localparam  INST_ID = 0 ;
localparam  DATA_ID = 1 ;

enum reg [2:0]  {
    AR_IDLE = 0 ,
    AR_IRD  = 1 ,
    AR_DRD  = 2 ,
    AR_DRD_IWAIT = 3 , 
    AR_IRD_DWAIT = 4
} ar_st , ar_nst ;

enum reg [1:0]  {
    R_IDLE  = 0 ,
    R_SINGLE  = 1 ,
    R_BURST  = 2 ,
    R_BURST_LAST = 3
} r_st , r_nst ;

enum reg [1:0]  {
    W_IDLE  = 0 ,
    W_AW_WAIT  = 1 ,
    W_SINGLE  = 2 ,
    W_BURST = 3
} w_st , w_nst ;

    reg [3:0]   arid_r ;
    reg [31:0]  araddr_r ;
    reg         arvalid_r ;
    reg [2:0]   arsize_r ;
    reg [7:0]   arlen_r ;
    reg [1:0]   arburst_r ;

    reg         rready_r ;

    reg [31:0]  awaddr_r ;
    reg [2:0]   awsize_r ;
    reg         awvalid_r ;         
    reg [7:0]   awlen_r ;
    reg [1:0]   awburst_r ;

    reg [31:0]  wdata_r ;
    reg [3:0]   wstrb_r ;
    reg         wvalid_r ;
    reg         wlast_r ;

    reg         bready_r ;
// ----------- 

    reg [ 3:0][31:0]    wdata_buf ;
    reg [ 1:0]          write_cnt ;
    wire                write_last ;
    wire                wr_sta ;
    reg [0:1][32:0]     wr_req_buf ;
    reg                 wr_up_ptr ;
    reg                 wr_clr_ptr ; 

    wire                inst_rd_addr_conflict ;
    wire                data_rd_addr_conflict ;
    wire [3:0]          rchn_type ;
    wire                inst_rd_vld ;
    wire                data_rd_vld ;
    wire                inst_rd_conflict ;
    wire                data_rd_conflict ;
    wire                inst_rd_todo_vld ;
    wire                data_rd_todo_vld ;
    reg  inst_rd_todo ;
    reg  data_rd_todo ;
    reg [ 1:0]          read_cnt ;

assign rchn_type = rid ? data_rd_type : inst_rd_type ;
assign inst_rd_addr_conflict = (inst_rd_addr==wr_req_buf[0][31:0] && wr_req_buf[0][32]) ||
                          (inst_rd_addr==wr_req_buf[1][31:0] && wr_req_buf[1][32]) ;
assign data_rd_addr_conflict = (data_rd_addr==wr_req_buf[0][31:0] && wr_req_buf[0][32]) ||
                          (data_rd_addr==wr_req_buf[1][31:0] && wr_req_buf[1][32]) ;
assign inst_rd_vld      = inst_rd_rdy && inst_rd_req && !inst_rd_addr_conflict ;
assign data_rd_vld      = data_rd_rdy && data_rd_req && !data_rd_addr_conflict ;
assign inst_rd_conflict = inst_rd_rdy && inst_rd_req && inst_rd_addr_conflict ;
assign data_rd_conflict = data_rd_rdy && data_rd_req && data_rd_addr_conflict ;
assign inst_rd_todo_vld = inst_rd_todo && !inst_rd_addr_conflict ;
assign data_rd_todo_vld = data_rd_todo && !data_rd_addr_conflict ;

always @(*) begin
    case(ar_st)
        AR_IDLE : ar_nst = data_rd_todo_vld ? inst_rd_vld ? AR_DRD_IWAIT : AR_DRD :
                           inst_rd_todo_vld ? data_rd_vld ? AR_IRD_DWAIT : AR_IRD : 
                 data_rd_vld && inst_rd_vld ? AR_DRD_IWAIT : 
                                data_rd_vld ? AR_DRD :
                                inst_rd_vld ? AR_IRD :
                           data_rd_todo_vld ? AR_DRD :
                           inst_rd_todo_vld ? AR_IRD :
                                              AR_IDLE ;
        AR_IRD  : ar_nst = arready ? (data_rd_todo_vld ? AR_DRD : AR_IDLE) : AR_IRD ;
        AR_DRD  : ar_nst = arready ? (inst_rd_todo_vld ? AR_IRD : AR_IDLE) : AR_DRD ;
   AR_DRD_IWAIT : ar_nst = arready ? AR_IRD : AR_DRD_IWAIT ;
   AR_IRD_DWAIT : ar_nst = arready ? AR_DRD : AR_IRD_DWAIT ;
        default : ar_nst = AR_IDLE ;
    endcase
end

always @(posedge clk) 
    if(!resetn)
        ar_st <= AR_IDLE ;
    else 
        ar_st <= ar_nst ;

always @(posedge clk) 
    if(ar_nst==AR_IRD) begin
        arid_r <= INST_ID ;
        araddr_r <= inst_rd_addr ;
        arsize_r <= 2 ;
        arburst_r <= inst_rd_type[2] ? 2'b01 : 2'b00 ;
        arlen_r <= inst_rd_type[2] ? 8'd3 : 8'd0 ;
    end
    else if(ar_nst==AR_DRD | ar_nst==AR_DRD_IWAIT) begin 
        arid_r <= DATA_ID ;
        araddr_r <= data_rd_addr ;
        arsize_r <= 2 ;
        arburst_r <= data_rd_type[2] ? 2'b01 : 2'b00 ;
        arlen_r <= data_rd_type[2] ? 8'd3 : 8'd0 ;
    end
    
    always @(posedge clk) 
        if(!resetn)
            arvalid_r <= 0 ;
        else if(ar_nst!=AR_IDLE)
            arvalid_r <= 1 ;
        else
            arvalid_r <= 0 ;

    always @(posedge clk) 
        if(!resetn)
            inst_rd_todo <= 0 ;
        else if(ar_nst==AR_IRD | ar_nst==AR_IRD_DWAIT)
            inst_rd_todo <= 0 ;
        else if(inst_rd_conflict)
            inst_rd_todo <= 1 ;

    always @(posedge clk) 
        if(!resetn)
            data_rd_todo <= 0 ;
        else if(ar_nst==AR_DRD | ar_nst==AR_DRD_IWAIT)
            data_rd_todo <= 0 ;
        else if(data_rd_conflict)
            data_rd_todo <= 1 ;

// ------------- read channel control ------------- //

always @(*) begin
    case(r_st)
        R_IDLE : r_nst = rvalid & rready ? rchn_type[3] ? R_BURST : R_SINGLE : 
                                           R_IDLE;
        R_SINGLE : r_nst = rvalid & rready ? rchn_type[3] ? R_BURST : R_SINGLE : 
                                           R_IDLE ;
        R_BURST : r_nst = rvalid && rready && read_cnt==3 ? R_BURST_LAST : R_BURST;
   R_BURST_LAST : r_nst = rvalid & rready ? (rchn_type[3] ? R_BURST : R_SINGLE) : 
                                           R_IDLE ; 
        default : r_nst = R_IDLE ;
    endcase
end

always @(posedge clk) 
    if(!resetn)
        r_st <= R_IDLE ;
    else 
        r_st <= r_nst ;
    
always @(posedge clk) 
    if(!resetn)
        rready_r <= 1 ;

//always ready to receive data

// ------ write response & data channel control ------- //

always @(*) begin
    case(w_st)
        W_IDLE : w_nst = data_wr_req && data_wr_rdy ? W_AW_WAIT : W_IDLE ;
        W_AW_WAIT : w_nst = awready ? data_wr_type[2] ? W_BURST : W_SINGLE :
                                     W_AW_WAIT ;
        W_SINGLE : w_nst = wready ? W_IDLE : W_SINGLE ;
        W_BURST  : w_nst = wready & write_last ? W_IDLE : W_BURST ;
        default : w_nst = W_IDLE ;
    endcase
end

assign wr_sta = w_nst==W_SINGLE || w_nst==W_BURST ;

always @(posedge clk) 
    if(!resetn)
        w_st <= W_IDLE ;
    else 
        w_st <= w_nst ;

always @(posedge clk) 
    if(!resetn)
        awvalid_r <= 0 ;
    else if(w_nst!=W_AW_WAIT)
        awvalid_r <= 0 ;
    else if(w_nst==W_AW_WAIT)
        awvalid_r <= 1 ;

always @(posedge clk) 
    if(w_st==W_IDLE && w_nst==W_AW_WAIT) begin
        awsize_r <= 2 ;
        awaddr_r <= data_wr_addr ;
       awburst_r <= data_wr_type[2] ? 2'b01 : 2'b00 ;
        awlen_r  <= data_wr_type[2] ? 8'd3 : 8'd0 ;
    end

always @(posedge clk) 
    if(!resetn)
        wvalid_r <= 0 ;
    else if(wr_sta)
        wvalid_r <= 1 ;
    else
        wvalid_r <= 0 ;

always @(posedge clk) 
    if(!resetn)
        write_cnt <= 0 ;
    else if(w_st==W_IDLE)
        write_cnt <= 0 ;
    else if(wready & wvalid)
        write_cnt <= write_cnt + 1 ;

assign write_last = write_cnt==awlen_r ;         
assign burst_last = w_st==W_BURST && write_cnt==2 && wready ;

always @(posedge clk) 
    if(w_st==W_IDLE || w_nst==W_IDLE)
        wlast_r <= 0 ;
    else if((write_last||burst_last) && wr_sta)
        wlast_r <= 1 ;

always @(posedge clk) 
    if(w_nst==W_AW_WAIT)
        wstrb_r <= data_wr_wstrb ;

always @(posedge clk) 
    if(w_nst==W_SINGLE||w_nst==W_BURST) begin
        wdata_r <= wdata_buf[write_cnt] ;
    end

always @(posedge clk) 
    if(data_wr_req)
        wdata_buf <= data_wr_data ;

always @(posedge clk)
    for(int i=0;i<2;i++) begin
        if(!resetn)
            wr_req_buf[i][32] <= 0;
        //else if(wvalid & wlast & wready & wr_clr_ptr==i)
        else if(bvalid & bready & wr_clr_ptr==i)
            wr_req_buf[i][32] <= 0 ;
        else if(w_st==W_IDLE &  w_nst==W_AW_WAIT & wr_up_ptr==i)
            wr_req_buf[i][32] <= 1 ;
    end

always @(posedge clk) 
    if(w_st==W_IDLE && w_nst==W_AW_WAIT)
        wr_req_buf[wr_up_ptr][31:0] <= data_wr_addr ;

always @(posedge clk) 
    if(!resetn)
        wr_up_ptr <= 0 ;
    else if(w_st==W_IDLE && w_nst==W_AW_WAIT)
        wr_up_ptr <= wr_up_ptr + 1 ;

always @(posedge clk) 
    if(!resetn)
        wr_clr_ptr <= 0 ;
    //else if(wvalid && wready && wlast)
    else if(bvalid && bready)
        wr_clr_ptr <= wr_clr_ptr + 1 ;

always @(posedge clk) 
    if(!resetn)
        bready_r <= 1 ;

// inst out port

always @(posedge clk) 
    if(!resetn)
        inst_rd_rdy <= 1 ;
    else if(ar_nst!=AR_IDLE)
        inst_rd_rdy <= 0 ;
    else 
        inst_rd_rdy <= 1 ;

assign inst_ret_data   = rdata ;
assign inst_ret_valid  = rvalid & rready & (rid==INST_ID) ;
assign inst_ret_last   = rlast & (rid==INST_ID) ;

// a out port
    assign arid = arid_r ;
    assign araddr   = araddr_r ;
    assign arsize   = arsize_r ;
    assign arlen    = arlen_r ;
    assign arburst  = arburst_r ;
    assign arlock   = 2'd0 ;
    assign arcache  = 4'd0 ;
    assign arprot   = 3'd0 ;
    assign arvalid  = arvalid_r ;

    assign rready   = rready_r ;
    
    assign awid     = DATA_ID ;
    assign awaddr   = awaddr_r ;
    assign awvalid  = awvalid_r ;
    assign awlen    = awlen_r ;
    assign awsize   = awsize_r ;
    assign awburst  = awburst_r ;
    assign awlock   = 2'd0 ;
    assign awcache  = 4'd0 ;
    assign awprot   = 3'd0 ;
    
    assign wid      = DATA_ID ;
    assign wlast    = wlast_r ;
    assign wstrb    = wstrb_r ;
    assign wvalid   = wvalid_r ;
    assign wdata    = wdata_r ;

    assign bready   = bready_r ;
    

// data out port

always @(posedge clk) 
    if(!resetn)
        data_rd_rdy <= 1 ;
    else if(ar_nst!=AR_IDLE)
        data_rd_rdy <= 0 ;
    else 
        data_rd_rdy <= 1 ;

assign data_ret_data   = rdata ;
assign data_ret_valid  = rvalid & rready & (rid==DATA_ID) ;
assign data_ret_last   = rlast & (rid==DATA_ID) ;

always @(posedge clk) 
    if(!resetn)
        data_wr_rdy <= 1 ;
    else if(w_st!=W_IDLE)
        data_wr_rdy <= 0 ;
    else 
        data_wr_rdy <= 1 ;

endmodule 
