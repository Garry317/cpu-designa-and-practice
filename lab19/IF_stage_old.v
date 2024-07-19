`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // from ws
    input                          ws_ex ,
    input                          ws_ex_refill ,
    input                          ws_eret ,
    input  [31:0]                  epc ,
    input                          ws_refetch ,
    input  [31:0]                  ws_refetch_pc ,
    input   ms_refetch ,
    input  [31:0] ms_pc ,
    // tlb interface 
    output [18:0] s0_vpn2 ,
    output        s0_odd_page ,
    input         s0_found ,
    input  [19:0] s0_pfn ,
    input  [2:0]  s0_c ,
    input         s0_d ,
    input         s0_v ,
    // 
    output        icache_index_invalid,
    output        icache_index_store,
    output        icache_hit_invalid,
    // inst sram interface
    input         inst_sram_addr_ok ,
    input         inst_sram_data_ok ,
    output        inst_sram_en   ,
    output [ 3:0] inst_sram_wen  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata
);
wire        fs_ex_adel;
wire        sram_req ;
wire        pre_tlbl_refill;
wire        pre_tlbl_invalid;
wire [31:0] fs_badaddr;
wire        hand_addr_ok ;
wire        hand_data_ok ;

wire        pre_ready_go;
reg         pre_to_fs_valid ;
reg [31:0]  br_pc ;
reg         br_valid ;// br target not done 
reg         bd_done ; // br delay done,br target not done 
wire        sel_lat_target ;
wire        sel_br_target ;
wire        br_pc_updt_en ;

// ex sta
reg         ex_st ;
reg         ex_refill_st ;
reg         eret_st ;
reg         inst_drop_en ;
wire        if_flush ;
reg         refetch_st ;
wire        refresh_st ;
wire        pre_tlb_ex ;
wire        fs_tlb_ex ;
reg         fs_tlbl_refill;
reg         fs_tlbl_invalid;

wire        fs_ex_flag ;
wire        fs_eret_flag ;
wire        fs_refetch_flag ;
wire        fs_ex_refill ;

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;
reg [31:0]  fs_inst_lat ;
reg         fs_inst_valid ;

wire [31:0] seq_pc;
wire [31:0] nextpc;
wire [31:0] ex_normal_pc;
wire [31:0] ex_refill_pc;

wire         br_taken;
wire [ 31:0] br_target;
wire         bd_inst;
wire         fs_bd ;
wire         inst_pc_maped_flag ;
wire         icache_op ;
reg          icache_op_req ;
reg          icache_op_st ;
reg          icache_pc_refetch ;
reg          ic_index_invalid_lat ;
reg          ic_index_store_lat ;
reg          ic_hit_invalid_lat ;

assign {ic_index_invalid,
        ic_index_store,
        ic_hit_invalid,
        bd_inst,
        br_taken,
        br_target
        } = br_bus;
assign icache_op = ic_index_invalid|ic_index_store|ic_hit_invalid ;

assign fs_bd    = bd_inst && !(ws_ex|ws_eret) ;

wire [31:0] fs_inst;
wire [31:0] fs_to_ds_inst ;
reg  [31:0] fs_pc;
assign fs_to_ds_inst = fs_inst_valid ? fs_inst_lat : fs_inst ;
assign fs_to_ds_bus = {
                       fs_tlbl_refill ,  //98
                       fs_tlbl_invalid , //97
                       fs_bd,            //96
                       fs_badaddr,       //95:64
                       fs_to_ds_inst ,   //63:32
                       fs_pc   };        //31:0

// pre-IF stage
assign pre_ready_go = hand_addr_ok || pre_tlb_ex ;
assign to_fs_valid  = ~reset  ;
assign pre_to_fs_valid = to_fs_valid && pre_ready_go ;
assign seq_pc       = fs_pc + 3'h4;
assign ex_normal_pc = 32'hbfc00380;
assign ex_refill_pc = 32'hbfc00200;
assign sel_lat_target   = br_valid && bd_done && !fs_valid ; // fs pc not update 
assign sel_br_target    = (br_taken || br_valid && bd_done) && fs_valid ; // 1.ID is branch,IF is branch delay
assign fs_ex_flag   = ws_ex | ex_st ;
assign fs_eret_flag = ws_eret | eret_st ;
assign fs_refetch_flag   = ws_refetch | refetch_st ;
assign fs_ex_refill = ws_ex_refill | ex_refill_st ;

assign nextpc       = fs_eret_flag ? epc : 
        fs_ex_flag & !fs_ex_refill ? ex_normal_pc :
        fs_ex_flag &  fs_ex_refill ? ex_refill_pc :
                   fs_refetch_flag ? seq_pc :       //ws_refetch_pc +4 : 
                    sel_lat_target ? br_pc :
                    icache_op      ? br_target :
                   icache_op_req   ? br_pc : 
                 icache_pc_refetch ? fs_pc :
              br_taken & !fs_valid ? seq_pc : 
                     sel_br_target ? br_target : 
                                     seq_pc; 

assign hand_addr_ok = inst_sram_addr_ok && inst_sram_en ;
assign hand_data_ok = inst_sram_data_ok ;

// IF stage
assign fs_ready_go    = (hand_data_ok || fs_inst_valid || fs_tlb_ex) && !inst_drop_en && !icache_op ;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin || refresh_st || icache_op;
assign fs_to_ds_valid = (fs_valid && fs_ready_go) && !refresh_st && !icache_op_st;
assign if_flush       = ws_ex | ws_eret | ws_refetch ;
assign refresh_st     = fs_eret_flag | fs_ex_flag | fs_refetch_flag ;
assign pre_tlb_ex     = pre_tlbl_refill|pre_tlbl_invalid ;
assign fs_tlb_ex      = fs_tlbl_refill|fs_tlbl_invalid ;

always @(posedge clk) 
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= pre_to_fs_valid ;
    end

always @(posedge clk) 
    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if(ms_refetch)
        fs_pc <= ms_pc ;
    else if (pre_to_fs_valid && fs_allowin && !(icache_op|icache_op_req)) 
        fs_pc <= nextpc;
    else if((!fs_valid|pre_to_fs_valid) && fs_allowin && icache_op) 
        fs_pc <= seq_pc;
    

always @(posedge clk) 
    if(reset) begin
        fs_tlbl_refill <= 0 ;
        fs_tlbl_invalid <= 0 ;
    end
    else if(pre_to_fs_valid && fs_allowin) begin
        fs_tlbl_refill <= pre_tlbl_refill ;
        fs_tlbl_invalid <= pre_tlbl_invalid ;
    end

assign br_pc_updt_en = br_taken && !(fs_valid && pre_to_fs_valid) ||
                       bd_done && br_valid && fs_valid ||
                       icache_op ;
                   // br_taken conditon :
                   // 1. fs_valid=0 , br delay addr not ok
                   // 2. pre_to_fs_valid , br addr not ok
                   // bd done && br_valid conditon :
                   // 1. fs_valid=1 , fs_pc update , br_target may up

always @(posedge clk) 
    if(br_pc_updt_en)
        br_pc <= br_target ;

always @(posedge clk) 
    if(reset)
        br_valid <= 0 ;
    else if(if_flush)
        br_valid <= 0 ;
    else if(bd_done && br_valid && pre_to_fs_valid)
        br_valid <= 0 ;
    else if(br_taken && !(fs_valid & pre_to_fs_valid))
        br_valid <= 1 ;

always @(posedge clk) 
    if(reset)
        bd_done <= 0 ;
    else if(if_flush)
        bd_done <= 0 ;
    else if(bd_done && br_valid && pre_to_fs_valid)
        bd_done <= 0 ;
    else if(br_taken && (fs_valid ^ pre_to_fs_valid))
        bd_done <= 1 ;
    else if(br_valid && pre_to_fs_valid)
        bd_done <= 1 ;

always @(posedge clk) 
    if(reset)
        fs_inst_valid <= 0 ;
    else if(if_flush)
        fs_inst_valid <= 0 ;
    else if(fs_inst_valid && ds_allowin)
        fs_inst_valid <= 0 ;
    else if(fs_to_ds_valid && !ds_allowin)
        fs_inst_valid <= 1 ;

always @(posedge clk) 
    if(fs_to_ds_valid && !ds_allowin && !fs_inst_valid) 
        fs_inst_lat <= fs_inst ;

always @(posedge clk) 
    if(reset)
        ex_st   <= 0 ;
    else if(ws_ex && !pre_to_fs_valid )
        ex_st   <= 1 ;
    else if(pre_to_fs_valid)
        ex_st   <= 0 ;

always @(posedge clk) 
    if(reset)
        ex_refill_st   <= 0 ;
    else if(ws_ex && ws_ex_refill && !pre_to_fs_valid )
        ex_refill_st   <= 1 ;
    else if(pre_to_fs_valid)
        ex_refill_st   <= 0 ;

always @(posedge clk) 
    if(reset)
        eret_st   <= 0 ;
    else if(ws_eret && !pre_to_fs_valid )
        eret_st   <= 1 ;
    else if(pre_to_fs_valid)
        eret_st   <= 0 ;

always @(posedge clk) 
    if(reset)
        refetch_st   <= 0 ;
    else if(ws_refetch && !pre_to_fs_valid )
        refetch_st   <= 1 ;
    else if(pre_to_fs_valid)
        refetch_st   <= 0 ;
/*
always @(posedge clk) 
    if(reset)
        pre_tlb_ex_1d <= 0 ;
    else if(if_flush)
        pre_tlb_ex_1d <= 0 ;
    else if(pre_tlb_ex)
        pre_tlb_ex_1d <= 1 ;
    else if(pre_tlb_ex_1d && fs_valid) 
        pre_tlb_ex_1d <= 0 ;
*/
/*    
assign inst_drop_one = ws_ex && (!fs_valid && pre_to_fs_valid ||
                                 fs_valid && hand_data_ok && pre_to_fs_valid ||
                                 fs_valid && !hand_data_ok && !pre_to_fs_valid
                             );
assign inst_drop_two = ws_ex && (fs_valid && !hand_data_ok && pre_to_fs_valid) ;
always @(posedge clk) 
    if(reset)
        inst_drop_num <= 0 ;
    else if(inst_drop_one)
        inst_drop_num <= 1 ;
    else if(inst_drop_two)
        inst_drop_num <= 2 ;
    else if(hand_data_ok)
        inst_drop_num <= inst_drop_num>>1 ;
*/

always @(posedge clk) 
    if(reset)
        inst_drop_en <= 0 ;
    else if((if_flush) && fs_valid && !(hand_data_ok|fs_inst_valid) && !fs_tlb_ex) // tlb_ex no data_ok
        inst_drop_en <= 1 ;
    else if(icache_op && fs_valid && !hand_data_ok)
        inst_drop_en <= 1 ;
    else if(hand_data_ok)
        inst_drop_en <= 0 ;

always @(posedge clk) 
    if(reset)
        icache_op_st <= 0 ;
    else if(icache_op)
        icache_op_st <= 1 ;
    else if(hand_data_ok && !inst_drop_en)
        icache_op_st <= 0 ;

always @(posedge clk) 
    if(reset)
        icache_pc_refetch <= 0 ;
    else if(icache_op|icache_op_req)
        icache_pc_refetch <= 1 ;
    else if(hand_addr_ok)
        icache_pc_refetch <= 0 ;

always @(posedge clk) 
    if(reset) begin
        icache_op_req <= 0 ;
        ic_index_invalid_lat <= 0 ;
        ic_index_store_lat <= 0 ;
        ic_hit_invalid_lat <= 0 ;
    end
    else if(icache_op & !pre_to_fs_valid) begin
        icache_op_req <= 1 ;
        ic_index_invalid_lat <= ic_index_invalid ;
        ic_index_store_lat <= ic_index_store ;
        ic_hit_invalid_lat <= ic_hit_invalid ;
    end
    else if(pre_to_fs_valid) begin
        icache_op_req <= 0 ;
        ic_index_invalid_lat <= 0 ;
        ic_index_store_lat <= 0 ;
        ic_hit_invalid_lat <= 0 ;
    end

assign s0_vpn2      = nextpc[31:13] ;
assign s0_odd_page  = nextpc[12] ;
//assign inst_pc_maped_flag    = (nextpc[31:28]<4'h8)||(nextpc[31:28]>4'hC) ;

assign sram_req        = to_fs_valid && fs_allowin;
assign inst_sram_en    = sram_req && (!(pre_tlbl_refill || pre_tlbl_invalid) || refresh_st);
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = icache_hit_invalid ? {s0_pfn[19:0],nextpc[11:1],s0_v} : {s0_pfn[19:0],nextpc[11:0]}  ; //
assign inst_sram_wdata = 32'b0;
assign fs_inst         = inst_sram_rdata;
assign fs_ex_adel      = inst_sram_en && |inst_sram_addr[1:0] ;
assign pre_tlbl_refill  = !icache_op && fs_valid && sram_req && !s0_found ;
assign pre_tlbl_invalid = !icache_op && fs_valid && sram_req && s0_found && !s0_v ; 
assign fs_badaddr      = fs_pc ;  // pc is virtual addr

assign icache_index_invalid = ic_index_invalid_lat|ic_index_invalid ;
assign icache_index_store   = ic_index_store|ic_index_store_lat ;
assign icache_hit_invalid   = ic_hit_invalid | ic_hit_invalid_lat ;

endmodule
