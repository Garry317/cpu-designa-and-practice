`include "mycpu.h"

module cp0 (
    input           clk ,
    input           rst ,
    input   [5:0]   ex_int_in,
    input [`WS_TO_CP0_BUS_WS-1:0]   ws_to_cp0_bus,
    output  [31:0]  c0_rdata ,
    output          c0_int ,
    output          status_exl ,
    output  [31:0]  c0_epc 
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

assign     {
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

wire sel_status   ; 
wire sel_cause    ;
wire sel_compare  ;
wire sel_count    ;
wire sel_epc      ;
wire sel_badvaddr ;
assign sel_status  = c0_addr==`CR_STATUS;
assign sel_cause   = c0_addr==`CR_CAUSE;
assign sel_compare = c0_addr==`CR_COMPARE;
assign sel_count   = c0_addr==`CR_COUNT;
assign sel_epc     = c0_addr==`CR_EPC;
assign sel_badvaddr= c0_addr==`CR_BADVADDR;

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
wire        count_eq_compare ;

wire [31:0] c0_status;
wire [31:0] c0_cause;
wire [31:0] c0_compare;
wire [31:0] c0_count ;
wire [31:0] c0_epc ;
wire [31:0] c0_badvaddr;

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

assign  c0_rdata = sel_status   ? c0_status :
                   sel_cause    ? c0_cause :
                   sel_compare  ? c0_compare :
                   sel_count    ? c0_count :
                   sel_epc      ? c0_epc :
                   sel_badvaddr ? c0_badvaddr 
                                : 32'd0 ;

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

always @(posedge clk) 
    if(wb_ex && (wb_excode==`EX_ADEL||wb_excode==`EX_ADES))
        badvaddr <= wb_badaddr ;

assign c0_c = epc ;
assign c0_int = |(cause_ip[7:0] & status_im[7:0]) & status_ie & !status_exl ;

endmodule
