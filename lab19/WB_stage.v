`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //to cp0: for ex process
    output [`WS_TO_CP0_BUS_WS-1:0]  ws_to_cp0_bus ,
    output  ws_ex ,
    output  ws_ex_refill ,
    output  ws_eret ,
    output [31:0]   ws_refetch_pc ,
    output    ws_refetch ,
    //from cp0
    //input  [`CP0_TO_WS_BUS_WS-1:0]  cp0_to_ws_bus ,
    input   c0_int ,
    input  [31:0]   c0_rdata ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire [ 3:0] ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;
wire        ws_ex_ades;
wire        ws_ex_adel;
wire        ws_ex_ov;
wire        ws_break;
wire        ws_syscall;
wire        ms_to_ws_eret;
wire        ws_mtc0;
wire        ws_mfc0;
wire [4:0]  c0_addr ;
wire [31:0] c0_wdata ;

wire        ws_ex ;
wire        ws_bd ;
wire [ 4:0] ws_excode ;
wire [31:0] ws_badaddr ;
wire        ws_ex_keep ;
wire        ws_ex_tlbl_refill;
wire        ws_ex_tlbl_invalid;
wire        ws_ex_tlbs_refill ;
wire        ws_ex_tlbs_invalid ;
wire        ws_ex_tlbs_mod ;
wire        ws_tlbp ;
wire        ws_tlbr ;
wire        ws_tlbwi ;
wire        ws_ex_tlbl ;
wire        ws_ex_tlbs ;
wire        ws_ex_mod ;
wire [`IDX_W-1:0]   ws_tlbp_index ;
wire        ws_tlbp_found ;

assign {
        ws_tlbp_index ,
        ws_tlbp_found ,
        ws_tlbp,
        ws_tlbr,
        ws_tlbwi,
        ws_ex_tlbl_refill,
        ws_ex_tlbl_invalid,
        ws_ex_tlbs_refill,
        ws_ex_tlbs_invalid,
        ws_ex_tlbs_mod,
        ws_ex_keep ,
        ws_bd,
        ws_badaddr,
        ws_break,
        ws_syscall,
        ms_to_ws_eret,
        ws_mtc0,
        ws_mfc0,
        ws_ex_ades,
        ws_ex_adel,
        ws_ex_ov,
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

wire [3 :0] rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_ex_tlbl   = ws_ex_tlbl_refill | ws_ex_tlbl_invalid ;                   
assign ws_ex_tlbs   = ws_ex_tlbs_refill | ws_ex_tlbs_invalid ;                   
assign ws_ex_mod  = ws_ex_tlbs_mod ;
assign ws_ex_refill = (ws_ex_tlbl_refill | ws_ex_tlbs_refill) && ws_valid ;
assign ws_ex    = (ws_ex_keep|ws_ex_ades|ws_ex_adel|ws_ex_ov|ws_break|ws_syscall | 
                   ws_ex_tlbl | ws_ex_tlbs | ws_ex_mod | c0_int ) & ws_valid;          
assign ws_excode= ws_ex_mod  ? 5'h1 :
                  ws_ex_tlbl ? 5'h2 :
                  ws_ex_tlbs ? 5'h3 :
                  ws_ex_adel ? 5'h4 :
                  ws_ex_ades ? 5'h5 :
                  ws_ex_ov   ? 5'hc :
                  ws_syscall ? 5'h8 :
                  ws_break   ? 5'h9 : 
                  ws_ex_keep ? 5'ha :
                               5'h0 ;

assign c0_addr = ws_mfc0 ? ws_final_result[4:0] : ws_dest ;
assign c0_wdata= ws_final_result ;
assign ws_eret = ms_to_ws_eret & ws_valid ;

assign ws_to_cp0_bus = {
                        //ws_refetch ,    //116
                        ws_tlbp_index , //118:115
                        ws_tlbp_found , //114
                        ws_tlbp ,   //113
                        ws_tlbr ,   //112
                        ws_tlbwi ,  //111
                        c0_addr  ,   //[110:106]
                        c0_wdata ,   //[105:74]
                        ws_mtc0 ,    //[73]
                        ws_valid  ,   //[72]
                        ws_ex ,      //[71]
                        ws_bd ,      //[70]
                        ws_excode ,  //[69:65]
                        ws_pc ,      //[64:33]
                        ws_badaddr , //[32:1]
                        ws_eret      //[0]
                       };
                        
                      
assign ws_ready_go = ws_valid;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end
end
always @(posedge clk) begin
    if(reset)
        ms_to_ws_bus_r <= 0 ;
    else if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we&{4{ws_valid && !(ws_ex|ws_eret|ws_refetch)}};
assign rf_waddr = ws_dest & {5{ws_valid}};
assign rf_wdata = ws_mfc0 ? c0_rdata : ws_final_result;
assign ws_refetch_pc = ws_pc ;
assign ws_refetch = (ws_tlbr|ws_tlbwi) & ws_valid ; //proc like ex

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = rf_we;
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = rf_wdata;//ws_final_result;

endmodule
