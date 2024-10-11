module mycpu_top ( 
    input   [5 :0]  int_in ,
    input           aclk ,
    input           aresetn ,
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
    output          bready ,

    // trace debug interface
    output [31:0]   debug_wb_pc,
    output [ 3:0]   debug_wb_rf_wen,
    output [ 4:0]   debug_wb_rf_wnum,
    output [31:0]   debug_wb_rf_wdata
);

wire        inst_sram_req ;
wire        inst_sram_wr ;
wire [ 3:0] inst_sram_wstrb ;
wire [31:0] inst_sram_addr ;
wire [31:0] inst_sram_wdata ;
wire [31:0] inst_sram_rdata ;
wire [1:0]  inst_sram_size ;
wire        inst_sram_addr_ok ;
wire        inst_sram_data_ok ;
wire        icache_index_invalid ;
wire        icache_index_store ;
wire        icache_hit_invalid ;
    
wire        data_sram_req ;
wire        data_sram_wr ;
wire [ 3:0] data_sram_wstrb ;
wire [31:0] data_sram_addr ;
wire [31:0] data_sram_wdata ;
wire [1:0]  data_sram_size ;
wire [31:0] data_sram_rdata ;
wire        data_sram_addr_ok ;
wire        data_sram_data_ok ;
wire        dcache_index_invalid ;
wire        dcache_index_store ;
wire        dcache_hit_nowb ;
wire        dcache_hit_wb ;

wire            inst_cache_en ;
wire            inst_rd_req ;
wire [ 2:0]     inst_rd_type ;
wire [31:0]     inst_rd_addr ;
wire            inst_rd_rdy ;
wire            inst_ret_valid ;
wire            inst_ret_last ;
wire [31:0]     inst_ret_data ;

wire        data_cache_en ;
wire        data_rd_req ;
wire [ 2:0] data_rd_type ;
wire [31:0] data_rd_addr ;
wire        data_rd_rdy ;
wire        data_ret_valid ;
wire        data_ret_last ;
wire [31:0] data_ret_data ;
wire        data_wr_req ;
wire [ 2:0] data_wr_type ;
wire [31:0] data_wr_addr ;
wire [ 3:0] data_wr_wstrb ;
wire [127:0] data_wr_data ;
wire        data_wr_rdy ;

//cpu
cpu cpu(
    .clk                (aclk               ),
    .resetn             (aresetn            ),  //low active
    .ex_int_in          (int_in             ),

    .inst_sram_req      (inst_sram_req      ),
    .inst_sram_wr       (inst_sram_wr       ),
    .inst_sram_size     (inst_sram_size     ),
    .inst_sram_wstrb    (inst_sram_wstrb    ),
    .inst_sram_addr     (inst_sram_addr     ),
    .inst_sram_wdata    (inst_sram_wdata    ),
    .inst_sram_addr_ok  (inst_sram_addr_ok  ),
    .inst_sram_data_ok  (inst_sram_data_ok  ),
    .inst_sram_rdata    (inst_sram_rdata    ),
    .inst_cache_en      (inst_cache_en      ),
    .icache_index_invalid(icache_index_invalid),
    .icache_index_store(icache_index_store),
    .icache_hit_invalid(icache_hit_invalid),
                                            
    .data_sram_req      (data_sram_req      ),
    .data_sram_wr       (data_sram_wr       ),
    .data_sram_size     (data_sram_size     ),
    .data_sram_wstrb    (data_sram_wstrb    ),
    .data_sram_addr     (data_sram_addr     ),
    .data_sram_wdata    (data_sram_wdata    ),
    .data_sram_addr_ok  (data_sram_addr_ok  ),
    .data_sram_data_ok  (data_sram_data_ok  ),
    .data_sram_rdata    (data_sram_rdata    ),
    .data_cache_en      (data_cache_en      ),
    .dcache_index_invalid(dcache_index_invalid),
    .dcache_index_store (dcache_index_store),
    .dcache_hit_nowb    (dcache_hit_nowb),
    .dcache_hit_wb      (dcache_hit_wb),
    
    //debug interface
    .debug_wb_pc        (debug_wb_pc        ),
    .debug_wb_rf_wen    (debug_wb_rf_wen    ),
    .debug_wb_rf_wnum   (debug_wb_rf_wnum   ),
    .debug_wb_rf_wdata  (debug_wb_rf_wdata  )
);

icache icache(
    .clk        (aclk                   ),
    .resetn     (aresetn                ),
    .valid      (inst_sram_req          ),
    .op         (inst_sram_wr           ),
    .index      (inst_sram_addr[11:4]   ),
    .tag        (inst_sram_addr[31:12]  ),
    .offset     (inst_sram_addr[3:0]    ),
    .wstrb      (inst_sram_wstrb        ),
    .wdata      (inst_sram_wdata        ),
    .addr_ok    (inst_sram_addr_ok      ),
    .data_ok    (inst_sram_data_ok      ),
    .rdata      (inst_sram_rdata        ),
    .idx_invalid(icache_index_invalid   ),
    .idx_store_tag(icache_index_store   ),
    .hit_invalid(icache_hit_invalid     ),
    .cache_en   (inst_cache_en          ),
    .rd_req     (inst_rd_req            ),
    .rd_type    (inst_rd_type           ),
    .rd_addr    (inst_rd_addr           ),
    .rd_rdy     (inst_rd_rdy            ),
    .ret_valid  (inst_ret_valid         ),
    .ret_last   (inst_ret_last          ),
    .ret_data   (inst_ret_data          ),
    .wr_req     (                       ),
    .wr_type    (                       ),
    .wr_addr    (                       ),
    .wr_wstrb   (                       ),
    .wr_data    (                       ),
    .wr_rdy     (1'b1)
);


dcache dcache(
    .clk            (aclk                   ),
    .resetn         (aresetn                ),
    .valid          (data_sram_req          ),
    .op             (data_sram_wr           ),
    .index          (data_sram_addr[11:4]   ),
    .tag            (data_sram_addr[31:12]  ),
    .offset         (data_sram_addr[3:0]    ),
    .wstrb          (data_sram_wstrb        ),
    .wdata          (data_sram_wdata        ),
    .addr_ok        (data_sram_addr_ok      ),
    .data_ok        (data_sram_data_ok      ),
    .rdata          (data_sram_rdata        ),
    .idx_invalid    (dcache_index_invalid   ),
    .idx_store_tag  (dcache_index_store     ),
    .hit_invalid_nowb(dcache_hit_nowb       ),
    .hit_invalid_wb (dcache_hit_wb          ),
    .cache_en       (data_cache_en          ),
    .rd_req         (data_rd_req            ),
    .rd_type        (data_rd_type           ),
    .rd_addr        (data_rd_addr           ),
    .rd_rdy         (data_rd_rdy            ),
    .ret_valid      (data_ret_valid         ),
    .ret_last       (data_ret_last          ),
    .ret_data       (data_ret_data          ),
    .wr_req         (data_wr_req            ),
    .wr_type        (data_wr_type           ),
    .wr_addr        (data_wr_addr           ),
    .wr_wstrb       (data_wr_wstrb          ),
    .wr_data        (data_wr_data           ),
    .wr_rdy         (data_wr_rdy            )
);


c2a c2a_u (
    .clk                (aclk               ),
    .resetn             (aresetn            ),  //low active
    .inst_rd_req        (inst_rd_req        ),
    .inst_rd_type       (inst_rd_type       ),
    .inst_rd_addr       (inst_rd_addr       ),
    .inst_rd_rdy        (inst_rd_rdy        ),
    .inst_ret_valid     (inst_ret_valid     ),
    .inst_ret_last      (inst_ret_last      ),
    .inst_ret_data      (inst_ret_data      ),
                                                 
    .data_rd_req        (data_rd_req        ),
    .data_rd_type       (data_rd_type       ),
    .data_rd_addr       (data_rd_addr       ),
    .data_rd_rdy        (data_rd_rdy        ),
    .data_ret_valid     (data_ret_valid     ),
    .data_ret_last      (data_ret_last      ),
    .data_ret_data      (data_ret_data      ),
    .data_wr_req        (data_wr_req        ),
    .data_wr_type       (data_wr_type       ),
    .data_wr_addr       (data_wr_addr       ),
    .data_wr_wstrb      (data_wr_wstrb      ),
    .data_wr_data       (data_wr_data       ),
    .data_wr_rdy        (data_wr_rdy        ),
    // ar
    .arid               (arid               ),
    .araddr             (araddr             ),
    .arlen              (arlen              ),
    .arsize             (arsize             ),
    .arburst            (arburst            ),
    .arlock             (arlock             ),
    .arcache            (arcache            ),
    .arprot             (arprot             ),
    .arvalid            (arvalid            ),
    .arready            (arready            ),
    // r                          
    .rid                (rid                ),
    .rdata              (rdata              ),
    .rresp              (rresp              ),
    .rlast              (rlast              ),
    .rvalid             (rvalid             ),
    .rready             (rready             ),
    // aw                                
    .awid               (awid               ),
    .awaddr             (awaddr             ),
    .awlen              (awlen              ),
    .awsize             (awsize             ),
    .awburst            (awburst            ),
    .awlock             (awlock             ),
    .awcache            (awcache            ),
    .awprot             (awprot             ),
    .awvalid            (awvalid            ),
    .awready            (awready            ),
    // wr                               
    .wid                (wid                ),
    .wdata              (wdata              ),
    .wstrb              (wstrb              ),
    .wlast              (wlast              ),
    .wvalid             (wvalid             ),
    .wready             (wready             ),
    // b channel                        
    .bid                (bid                ),
    .bresp              (bresp              ),
    .bvalid             (bvalid             ),
    .bready             (bready             )
    );


endmodule 
