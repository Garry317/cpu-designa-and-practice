module cpu #(
    parameter TLB_NUM   = 16 ,
    parameter IDX_W     = $clog2(TLB_NUM)
)(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_req,
    output        inst_sram_wr ,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    // icache
    output        icache_index_invalid ,
    output        icache_index_store ,
    output        icache_hit_invalid ,
    // new
    input         inst_sram_addr_ok ,
    input         inst_sram_data_ok ,
    output [1:0]  inst_sram_size ,
    output        inst_cache_en ,
    // data sram interface
    output        data_sram_req,
    output         data_sram_wr ,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input  [31:0] data_sram_rdata,
    // dcache
    output        dcache_index_invalid ,
    output        dcache_index_store ,
    output        dcache_hit_nowb ,
    output        dcache_hit_wb ,
    // new
    input         data_sram_addr_ok ,
    input         data_sram_data_ok ,
    output [1:0]  data_sram_size ,
    output        data_cache_en ,
    // interrupt
    input  [5:0]  ex_int_in ,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
assign  inst_sram_size = 2 ;
//assign  data_sram_size = 2 ;
assign  inst_sram_wr = |inst_sram_wstrb;
assign  data_sram_wr = |data_sram_wstrb;

reg         reset;
always @(posedge clk) reset <= ~resetn;

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire         ms_ex;
wire         ms_eret;
wire         ws_ex;
wire         ws_ex_refill;
wire         ws_eret;
wire [31:0]  c0_epc;
wire [31:0]  c0_rdata;
wire         c0_int;
wire [18:0]  c0_vpn2 ;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [`ES_TO_RF_BUS_WD -1:0] es_to_rf_bus ;
wire [`MS_TO_RF_BUS_WD -1:0] ms_to_rf_bus ;
wire [`WS_TO_CP0_BUS_WS-1:0] ws_to_cp0_bus;
// tlb 
// search port 0
wire [18:0] s0_vpn2;
wire        s0_odd_page;
wire [7:0]  s0_asid;
wire        s0_found;
wire [IDX_W-1:0]s0_index;
wire [19:0] s0_pfn;
wire [2:0]  s0_c;
wire        s0_d;
wire        s0_v;
// search port 1
wire [18:0] s1_vpn2;
wire        s1_tlbp;
wire        s1_odd_page;
wire [7:0]  s1_asid;
wire        s1_found;
wire [IDX_W-1:0] s1_index;
wire [19:0] s1_pfn;
wire [2:0]  s1_c;
wire        s1_d;
wire        s1_v;
// write port
wire        tlb_wr;
wire [IDX_W-1:0] w_index;
wire [18:0] w_vpn2;
wire [7:0]  w_asid;
wire        w_g;
wire [19:0] w_pfn0;
wire [2:0]  w_c0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_pfn1;
wire [2:0]  w_c1;
wire        w_d1;
wire        w_v1;
// read port
wire [IDX_W-1:0] r_index;
wire [18:0] r_vpn2;
wire [7:0]  r_asid;
wire        r_g;
wire [19:0] r_pfn0;
wire [2:0]  r_c0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_pfn1;
wire [2:0]  r_c1;
wire        r_d1;
wire        r_v1;
wire [2:0]  cfg_k0 ;
// refetch
wire        ms_refetch ;
wire [31:0]       ms_pc ;
wire        ws_refetch ;
wire [31:0] ws_refetch_pc ;
wire        ms_src_entry_hi;


// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    .ws_ex          (ws_ex          ),
    .ws_ex_refill   (ws_ex_refill   ),
    .ws_eret        (ws_eret        ),
    .epc            (c0_epc         ),
    //tlb interface 
    .s0_vpn2        (s0_vpn2        ),
    .s0_odd_page    (s0_odd_page    ),
    .s0_found       (s0_found       ),
    .s0_pfn         (s0_pfn         ),
    .s0_c           (s0_c           ),
    .s0_d           (s0_d           ),
    .s0_v           (s0_v           ),
    // refetch 
    .ws_refetch     (ws_refetch  ),
    .ws_refetch_pc  (ws_refetch_pc  ),
    .ms_refetch     (ms_refetch  ),
    .ms_pc  (ms_pc  ),
    // icache inst
    .icache_index_invalid(icache_index_invalid),
    .icache_index_store(icache_index_store),
    .icache_hit_invalid(icache_hit_invalid),
    // inst sram interface
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_en   (inst_sram_req   ),
    .inst_sram_wen  (inst_sram_wstrb  ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata)
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    // from es
    .es_to_rf_bus   (es_to_rf_bus        ),
    // from ms      
    .ms_to_rf_bus   (ms_to_rf_bus        ),
    .ws_ex          (ws_ex          ),
    .ws_eret        (ws_eret        ),
    .ws_refetch     (ws_refetch  ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   )
);
// EXE stage
exe_stage exe_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    // to ds
    .es_to_rf_bus   (es_to_rf_bus        ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    .ws_ex          (ws_ex          ),
    .ms_ex          (ms_ex          ),
    .ws_eret        (ws_eret        ),
    .ms_eret        (ms_eret        ),
    .ws_refetch     (ws_refetch  ),
    .ms_refetch     (ms_refetch  ),
    .ms_src_entry_hi(ms_src_entry_hi),
    //tlb interface 
    .c0_vpn2        (c0_vpn2        ),
    .s1_vpn2        (s1_vpn2        ),
    .s1_tlbp(s1_tlbp),
    .s1_odd_page    (s1_odd_page    ),
    .s1_found       (s1_found       ),
    .s1_index       (s1_index       ),
    .s1_pfn         (s1_pfn         ),
    .s1_c           (s1_c           ),
    .s1_d           (s1_d           ),
    .s1_v           (s1_v           ),
    // dcache inst
    .es_dcache_index_invalid(dcache_index_invalid),
    .es_dcache_index_store(dcache_index_store),
    .es_dcache_hit_nowb(dcache_hit_nowb),
    .es_dcache_hit_wb(dcache_hit_wb),
    // data sram interface
    .data_sram_en   (data_sram_req   ),
    .data_sram_wen  (data_sram_wstrb  ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_size (data_sram_size ),
    .data_sram_addr_ok (data_sram_addr_ok ),
    .data_sram_wdata(data_sram_wdata)
);
// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // to ds
    .ms_to_rf_bus        (ms_to_rf_bus        ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    .ws_ex          (ws_ex          ),
    .ms_ex          (ms_ex          ),
    .ws_eret        (ws_eret        ),
    .ms_eret        (ms_eret        ),
    .ws_refetch     (ws_refetch  ),
    .ms_refetch     (ms_refetch  ),
    .ms_src_entry_hi(ms_src_entry_hi),
    .ms_pc  (ms_pc  ),
    //from data-sram
    .data_sram_data_ok (data_sram_data_ok ),
    .data_sram_rdata(data_sram_rdata)
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    .ws_ex          (ws_ex          ),
    .ws_ex_refill   (ws_ex_refill   ),
    .ws_eret        (ws_eret        ),
    .ws_to_cp0_bus  (ws_to_cp0_bus  ),
    .c0_int         (c0_int         ),
    .c0_rdata         (c0_rdata         ),
    // refetch
    .ws_refetch     (ws_refetch     ),
    .ws_refetch_pc  (ws_refetch_pc  ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

// CP0
cp0 cp0(
    .clk            (clk            ),
    .rst            (reset          ),
    .ws_to_cp0_bus  (ws_to_cp0_bus  ),
    .ex_int_in      (ex_int_in      ),
    .c0_rdata       (c0_rdata        ),
    .c0_int         (c0_int         ),
    .c0_epc         (c0_epc         ),
    .c0_vpn2        (c0_vpn2        ),
    .s0_asid        (s0_asid        ),
    .s1_asid        (s1_asid        ),
    .tlb_wr(tlb_wr),
    .w_index(w_index),
    .w_vpn2(w_vpn2),
    .w_asid(w_asid),
    .w_g(w_g),
    .w_pfn0(w_pfn0),
    .w_c0(w_c0),
    .w_d0(w_d0),
    .w_v0(w_v0),
    .w_pfn1(w_pfn1),
    .w_c1(w_c1),
    .w_d1(w_d1),
    .w_v1(w_v1),
    .r_index(r_index),
    .r_vpn2(r_vpn2),
    .r_asid(r_asid),
    .r_g(r_g),
    .r_pfn0(r_pfn0),
    .r_c0(r_c0),
    .r_d0(r_d0),
    .r_v0(r_v0),
    .r_pfn1(r_pfn1),
    .r_c1(r_c1),
    .r_d1(r_d1),
    .r_v1(r_v1),
    .cfg_k0(cfg_k0)
);

// TLB
tlb #(.TLB_NUM(16)) tlb
(
    .clk(clk),
    .rst(reset),
    .s0_vpn2(s0_vpn2),
    .s0_store_tag(icache_index_store),
    .s0_odd_page(s0_odd_page),
    .s0_asid(s0_asid),
    .s0_found(s0_found),
    .s0_index(s0_index),
    .s0_pfn(s0_pfn),
    .s0_cache(inst_cache_en),
    .s0_c(s0_c),
    .s0_d(s0_d),
    .s0_v(s0_v),
    .s1_vpn2(s1_vpn2),
    .s1_tlbp(s1_tlbp),
    .s1_store_tag(dcache_index_store),
    .s1_odd_page(s1_odd_page),
    .s1_asid(s1_asid),
    .s1_found(s1_found),
    .s1_index(s1_index),
    .s1_pfn(s1_pfn),
    .s1_cache(data_cache_en),
    .s1_c(s1_c),
    .s1_d(s1_d),
    .s1_v(s1_v),
    .wr(tlb_wr),
    .w_index(w_index),
    .w_vpn2(w_vpn2),
    .w_asid(w_asid),
    .w_g(w_g),
    .w_pfn0(w_pfn0),
    .w_c0(w_c0),
    .w_d0(w_d0),
    .w_v0(w_v0),
    .w_pfn1(w_pfn1),
    .w_c1(w_c1),
    .w_d1(w_d1),
    .w_v1(w_v1),
    .r_index(r_index),
    .r_vpn2(r_vpn2),
    .r_asid(r_asid),
    .r_g(r_g),
    .r_pfn0(r_pfn0),
    .r_c0(r_c0),
    .r_d0(r_d0),
    .r_v0(r_v0),
    .r_pfn1(r_pfn1),
    .r_c1(r_c1),
    .r_d1(r_d1),
    .r_v1(r_v1),
    .cfg_k0(cfg_k0)
);

endmodule
