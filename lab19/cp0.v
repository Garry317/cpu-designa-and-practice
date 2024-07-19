`include "mycpu.h"

module cp0 (
    input           clk ,
    input           rst ,
    input   [5:0]   ex_int_in,
    input [`WS_TO_CP0_BUS_WS-1:0]   ws_to_cp0_bus,
    output  [31:0]  c0_rdata ,
    output          c0_int ,
    output          status_exl ,
    output  [31:0]  c0_epc ,
    output  [18:0]  c0_vpn2 ,
    output  [7:0]   s0_asid ,
    output  [7:0]   s1_asid ,
// read tlb
    output  [`IDX_W-1:0] r_index ,
    input   [18:0]  r_vpn2 ,
    input   [7:0]   r_asid ,
    input           r_g ,
    input   [19:0]  r_pfn0 ,
    input   [2:0]   r_c0 ,
    input           r_d0 ,
    input           r_v0 ,
    input   [19:0]  r_pfn1 ,
    input   [2:0]   r_c1 ,
    input           r_d1 ,
    input           r_v1 ,
// write tlb
    output          tlb_wr ,
    output  [`IDX_W-1:0] w_index ,
    output  [18:0]  w_vpn2 ,
    output  [7:0]   w_asid ,
    output          w_g ,
    output  [19:0]  w_pfn0 ,
    output  [2:0]   w_c0 ,
    output          w_d0 ,
    output          w_v0 ,
    output  [19:0]  w_pfn1 ,
    output  [2:0]   w_c1 ,
    output          w_d1 ,
    output          w_v1 ,
    output  [2:0]   cfg_k0 

);

wire            op_mtc0 ;
wire   [ 4:0]   c0_addr ;
wire   [31:0]   c0_wdata ;
wire            wb_ex ;
wire            wb_bd ;
wire   [ 4:0]   wb_excode ;
wire   [31:0]   wb_pc ;
wire   [31:0]   wb_badaddr ;
wire            wb_valid ;
wire            eret_flush ;
wire            mtc0_wr ;
wire            op_tlbp ;
wire            op_tlbr ;
wire            op_tlbwi ;
wire            c0_tlbp ;
wire            c0_tlbr ;
wire            c0_tlbwi ;
wire [`IDX_W-1:0]   c0_tlbp_index ;
wire        c0_tlbp_found ;

assign     {
            c0_tlbp_index ,
            c0_tlbp_found ,
            op_tlbp ,
            op_tlbr ,
            op_tlbwi ,
            c0_addr,
            c0_wdata,
            op_mtc0,
            wb_valid,
            wb_ex,
            wb_bd,
            wb_excode,
            wb_pc,
            wb_badaddr,
            eret_flush} = ws_to_cp0_bus ;      

assign  mtc0_wr  = op_mtc0 & !wb_ex & wb_valid ;
assign  c0_tlbp  = op_tlbp & !wb_ex & wb_valid ;
assign  c0_tlbr  = op_tlbr & !wb_ex & wb_valid ;
assign  c0_tlbwi = op_tlbwi & !wb_ex & wb_valid ;

wire sel_status   ; 
wire sel_cause    ;
wire sel_compare  ;
wire sel_count    ;
wire sel_epc      ;
wire sel_badvaddr ;
wire sel_entryhi ;
wire sel_entrylo0 ;
wire sel_entrylo1 ;
wire sel_index ;
wire sel_config0 ;
assign sel_status   = c0_addr==`CR_STATUS;
assign sel_cause    = c0_addr==`CR_CAUSE;
assign sel_compare  = c0_addr==`CR_COMPARE;
assign sel_count    = c0_addr==`CR_COUNT;
assign sel_epc      = c0_addr==`CR_EPC;
assign sel_badvaddr = c0_addr==`CR_BADVADDR;
assign sel_entryhi  = c0_addr==`CR_ENTRYHI;
assign sel_entrylo0 = c0_addr==`CR_ENTRYLO0;
assign sel_entrylo1 = c0_addr==`CR_ENTRYLO1;
assign sel_index    = c0_addr==`CR_INDEX ;
assign sel_config0  = c0_addr==`CR_CONFIG ;

wire            c0_int ;

reg         status_ie ;
reg         status_exl ;
reg [ 7:0]  status_im ;
reg         cause_bd ;
reg         cause_ti ;
reg [ 7:0]  cause_ip ;
reg [ 4:0]  cause_excode ;
reg [31:0]  count ;
reg         time_tick ;
reg [31:0]  compare ;
reg [31:0]  epc ;
reg [31:0]  badvaddr ;
reg [18:0]  c0_vpn2 ;
reg [ 7:0]  c0_asid ;
reg [19:0]  c0_pfn0 ;
reg [2:0]   c0_c0 ;
reg         c0_d0 ;
reg         c0_v0 ;
reg         c0_g0 ;
reg [19:0]  c0_pfn1 ;
reg [2:0]   c0_c1 ;
reg         c0_d1 ;
reg         c0_v1 ;
reg         c0_g1 ;
reg [ 3:0]  c0_tlb_index ;
reg         c0_tlb_p ;
reg [2:0]   c0_k0 ;
wire        c0_g ;
wire        count_eq_compare ;

wire [31:0] c0_status;
wire [31:0] c0_cause;
wire [31:0] c0_compare;
wire [31:0] c0_count ;
wire [31:0] c0_epc ;
wire [31:0] c0_badvaddr;
wire [31:0] c0_entry_hi ;
wire [31:0] c0_entry_lo0 ;
wire [31:0] c0_entry_lo1 ;
wire [31:0] c0_index ;

assign count_eq_compare = count==compare;


assign c0_badvaddr  = badvaddr ;
assign c0_count     = count ;
assign c0_compare   = compare ;
assign c0_status[31:23] = 9'd0;
assign c0_status[22]    = 1'b1;
assign c0_status[21:16] = 6'd0;
assign c0_status[15:8]  = status_im;
assign c0_status[7:2]   = 6'd0;
assign c0_status[1]     = status_exl;
assign c0_status[0]     = status_ie;
assign c0_cause[31]     = cause_bd;
assign c0_cause[30]     = cause_ti;
assign c0_cause[29:16]  = 14'd0;
assign c0_cause[15:8]   = cause_ip;
assign c0_cause[7]      = 1'b0;
assign c0_cause[6:2]    = cause_excode;
assign c0_cause[1:0]    = 2'd0 ;
assign c0_epc           = epc ;
assign c0_index[31]     = c0_tlb_p ;
assign c0_index[30:`IDX_W] = 0 ;
assign c0_index[`IDX_W-1:0] = c0_tlb_index ;
assign c0_entry_hi[31:13]   = c0_vpn2 ;
assign c0_entry_hi[12:8]    = 5'd0 ;
assign c0_entry_hi[7:0]     = c0_asid ;
assign c0_entry_lo0[31:26]  = 6'd0 ;
assign c0_entry_lo0[25:6]   = c0_pfn0 ;
assign c0_entry_lo0[5:3]    = c0_c0 ;
assign c0_entry_lo0[2]      = c0_d0 ;
assign c0_entry_lo0[1]      = c0_v0 ;
assign c0_entry_lo0[0]      = c0_g0 ;
assign c0_entry_lo1[31:26]  = 6'd0 ;
assign c0_entry_lo1[25:6]   = c0_pfn1 ;
assign c0_entry_lo1[5:3]    = c0_c1 ;
assign c0_entry_lo1[2]      = c0_d1 ;
assign c0_entry_lo1[1]      = c0_v1 ;
assign c0_entry_lo1[0]      = c0_g1 ;


assign  c0_rdata = sel_status   ? c0_status :
                   sel_cause    ? c0_cause :
                   sel_compare  ? c0_compare :
                   sel_count    ? c0_count :
                   sel_epc      ? c0_epc :
                   sel_badvaddr ? c0_badvaddr :
                   sel_index    ? c0_index :
                   sel_entryhi  ? c0_entry_hi :
                   sel_entrylo0 ? c0_entry_lo0 :
                   sel_entrylo1 ? c0_entry_lo1 :
                                  32'd0 ;

always @(posedge clk) 
    if(rst)
        status_ie <= 0 ;
    else if(mtc0_wr & sel_status)
        status_ie <= c0_wdata[0] ;

always @(posedge clk) 
    if(rst)
        status_exl <= 0 ;
    else if(wb_ex)
        status_exl <= 1 ;
    else if(eret_flush)
        status_exl <= 0 ;
    else if(mtc0_wr & sel_status)
        status_exl <= c0_wdata[1] ;

always @(posedge clk) 
    if(rst)
        status_im <= 8'd0 ;
    else if(mtc0_wr & sel_status)
        status_im <= c0_wdata[15:8] ;

always @(posedge clk) 
    if(rst)
        cause_bd <= 0 ;
    else if(wb_ex & ~status_exl)
        cause_bd <= wb_bd ;

always @(posedge clk) 
    if(rst)
        cause_ti <= 0 ;
    else if(mtc0_wr & sel_compare)
        cause_ti <= 0 ;
    else if(count_eq_compare)
        cause_ti <= 1 ;

always @(posedge clk) 
    if(rst)
        cause_ip[7:2] <= 6'd0 ;
    else 
        cause_ip[7:2] <= ex_int_in | {cause_ti,5'd0} ;

always @(posedge clk) 
    if(rst)
        cause_ip[1:0] <= 2'd0 ;
    else if(mtc0_wr & sel_cause)
        cause_ip[1:0] <= c0_wdata[9:8] ;

always @(posedge clk) 
    if(rst)
        cause_excode <= 5'd0 ;
    else if(wb_ex)
        cause_excode <= wb_excode ;

always @(posedge clk) 
    if(rst)
        time_tick <= 0 ;
    else 
        time_tick <= ~time_tick ;

always @(posedge clk) 
    if(mtc0_wr & sel_count)
        count <= c0_wdata ;
    else if(time_tick)
        count <= count + 1 ;

always @(posedge clk) 
    if(mtc0_wr & sel_compare)
        compare <= c0_wdata ;

always @(posedge clk) 
    if(wb_ex & !status_exl)
        epc <= wb_bd ? wb_pc - 4 : wb_pc ;
    else if(mtc0_wr & sel_epc)
        epc <= c0_wdata ;

wire bd_updt_en ;
wire vpn2_updt_en ;
assign bd_updt_en = wb_excode==`EX_ADEL || wb_excode==`EX_ADES || wb_excode==`EX_TLBL ||
                    wb_excode==`EX_TLBS || wb_excode==`EX_MOD ;
assign vpn2_updt_en =wb_excode==`EX_TLBL || wb_excode==`EX_TLBS || wb_excode==`EX_MOD ;
always @(posedge clk) 
    if(wb_ex && bd_updt_en)
        badvaddr <= wb_badaddr ;

always @(posedge clk) 
    if(c0_tlbp) begin
        c0_tlb_index <= c0_tlbp_index ;
        c0_tlb_p     <= !c0_tlbp_found ;
    end
    else if(mtc0_wr & sel_index) begin
        c0_tlb_index <= c0_wdata[`IDX_W-1:0] ;
//        c0_tlb_p     <= c0_wdata[31] ;
    end

always @(posedge clk) 
    if(wb_ex && vpn2_updt_en)
        c0_vpn2 <= wb_badaddr[31:13] ;
    else if(c0_tlbr) 
        c0_vpn2 <= r_vpn2 ;
    else if(mtc0_wr & sel_entryhi) 
        c0_vpn2 <= c0_wdata[31:13] ;

always @(posedge clk)
    if(rst)
        c0_asid <= 0 ;
    else if(c0_tlbr) 
        c0_asid <= r_asid ;
    else if(mtc0_wr & sel_entryhi) 
        c0_asid <= c0_wdata[7:0] ;
        
always @(posedge clk)
    if(rst) begin
        c0_pfn0 <= 0 ;
        c0_c0   <= 0 ;
        c0_d0   <= 0 ;
        c0_v0   <= 0 ;
        c0_g0   <= 0 ;
    end
    else if(c0_tlbr) begin
        c0_pfn0 <= r_pfn0 ;
        c0_c0   <= r_c0   ;
        c0_d0   <= r_d0   ;
        c0_v0   <= r_v0   ;
        c0_g0   <= r_g    ;
    end
    else if(mtc0_wr & sel_entrylo0) begin
        c0_pfn0 <= c0_wdata[25:6] ;
        c0_c0   <= c0_wdata[5:3] ;
        c0_d0   <= c0_wdata[2] ;
        c0_v0   <= c0_wdata[1] ;
        c0_g0   <= c0_wdata[0] ;
    end

always @(posedge clk) 
    if(rst) begin
        c0_pfn1 <= 0 ;
        c0_c1   <= 0 ;
        c0_d1   <= 0 ;
        c0_v1   <= 0 ;
        c0_g1   <= 0 ;
    end
    else if(c0_tlbr) begin
        c0_pfn1 <= r_pfn1 ;
        c0_c1   <= r_c1 ;
        c0_d1   <= r_d1 ;
        c0_v1   <= r_v1 ;
        c0_g1   <= r_g ;
    end
    else if(mtc0_wr & sel_entrylo1) begin
        c0_pfn1 <= c0_wdata[25:6] ;
        c0_c1   <= c0_wdata[5:3] ;
        c0_d1   <= c0_wdata[2] ;
        c0_v1   <= c0_wdata[1] ;
        c0_g1   <= c0_wdata[0] ;
    end
    
    always @(posedge clk) 
        if(rst)
            c0_k0 <= 3'd2 ;
        else if(mtc0_wr & sel_config0) 
            c0_k0 <= c0_wdata[2:0] ;

assign c0_c = epc ;
assign c0_int = |(cause_ip[7:0] & status_im[7:0]) & status_ie & !status_exl ;
assign c0_g = c0_g0 & c0_g1 ;

assign s0_asid  = c0_asid ;
assign s1_asid  = c0_asid ;
// tlbr
assign r_index  = c0_tlb_index ;
// tlbwi
assign tlb_wr  = op_tlbwi ;
assign w_index = c0_tlb_index ;
assign w_vpn2  = c0_vpn2  ;  
assign w_asid  = c0_asid  ; 
assign w_g     = c0_g     ; 
assign w_pfn0  = c0_pfn0  ; 
assign w_c0    = c0_c0    ;
assign w_d0    = c0_d0    ;
assign w_v0    = c0_v0    ;
assign w_pfn1  = c0_pfn1  ;
assign w_c1    = c0_c1    ;
assign w_d1    = c0_d1    ; 
assign w_v1    = c0_v1    ; 
assign cfg_k0   = c0_k0 ;

endmodule
