`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    // to ds
    output  [`MS_TO_RF_BUS_WD-1:0] ms_to_rf_bus ,
    // 
    input                          ws_ex ,
    output                         ms_ex ,
    output                          ms_eret ,
    output                          ws_eret ,
    //from data-sram
    input                          data_sram_data_ok ,
    input  [31                 :0] data_sram_rdata
);

reg [31:0]  hi_reg ;
reg [31:0]  lo_reg ;

reg         ms_valid;
wire        ms_ready_go;
wire        ms_flush ;

wire        ms_wr_en ;
wire        ms_ex_ades;
wire        ms_ex_adel;
wire        ms_ex_ov;
wire [4:0]  ms_excode;
wire        ms_break;
wire        ms_syscall;
wire        ms_eret;
wire        ms_mtc0;
wire        ms_mfc0;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_left_algn ;
wire        ms_right_algn ;
wire        ms_lh ;
wire        ms_lb ;
wire        ms_ext_sign ;
wire [31:0] ms_alu_result2 ;
wire        ms_dst_hi ;
wire        ms_src_hi ;
wire        ms_dst_lo ;
wire        ms_src_lo ;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 3:0] ms_to_ws_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
wire [31:0] ms_badaddr;
wire        ms_bd;
wire        ex_status;
wire        es_to_ms_eret ;
wire        ms_ex_keep ;
wire        ms_mem_en ;

assign {ms_mem_en ,
        ms_ex_keep ,
        ms_bd,
        ms_badaddr,
        ms_break,
        ms_syscall,
        es_to_ms_eret,
        ms_mtc0,
        ms_mfc0,
        ms_ex_ades,
        ms_ex_adel,
        ms_ex_ov,
        ms_left_algn ,
        ms_right_algn ,
        ms_lh ,
        ms_lb ,
        ms_ext_sign ,
        ms_alu_result2 ,
        ms_src_hi ,
        ms_dst_hi ,
        ms_src_lo ,
        ms_dst_lo ,
        ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } =  es_to_ms_bus_r;

wire [31:0] mem_result;
wire [31:0] ms_final_result;

wire [4:0]  ms_to_rf_dest ;
assign ms_to_rf_dest = ms_dest & {5{ms_valid}} ;
assign ms_to_rf_bus = {ms_ready_go ,
                       ms_mfc0 ,
                       ms_to_ws_we ,
                       ms_to_rf_dest ,
                       ms_final_result
                      };
assign ms_to_ws_bus = {ms_ex_keep ,
                       ms_bd,
                       ms_badaddr,
                       ms_break,
                       ms_syscall,
                       ms_eret,
                       ms_mtc0,
                       ms_mfc0,
                       ms_ex_ades,
                       ms_ex_adel,
                       ms_ex_ov,
                       ms_to_ws_we    ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

assign ms_ready_go    = ms_valid && (!ms_mem_en || data_sram_data_ok || ms_flush);
assign ms_allowin     = !ms_valid || (ms_ready_go && ws_allowin);
assign ms_to_ws_valid = ms_valid && ms_ready_go && !(ws_ex|ws_eret);
assign ms_wr_en       = ms_valid && !(ws_ex|ws_eret);
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end
    
    if(reset)
        es_to_ms_bus_r <= 0 ;
    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end

always @(posedge clk) 
    if(ms_dst_hi && ms_wr_en) 
        hi_reg <= ms_alu_result ;

always @(posedge clk) begin 
    if(ms_dst_hi&ms_dst_lo&ms_wr_en) // 2'b11 mean div or mult
        lo_reg <= ms_alu_result2 ;
    else if(ms_dst_lo&ms_wr_en) // only dst_lo mean mtlo
        lo_reg <= ms_alu_result ;
end

wire   [1:0]        ms_l2bit ;
wire   [0:1][31:0]  res_lh ;
wire   [0:3][31:0]  res_lb ;
wire   [3:0]        left_gr_wen ;
wire   [3:0]        right_gr_wen ;
wire   [31:0]       left_wdata ;
wire   [31:0]       right_wdata ;

assign ms_l2bit     = ms_alu_result[1:0] ;
assign left_gr_wen  = ms_l2bit==0 ? 4'b1000 :
                      ms_l2bit==1 ? 4'b1100 :
                      ms_l2bit==2 ? 4'b1110 
                                  : 4'b1111 ;
assign left_wdata   = ms_l2bit==0 ? {data_sram_rdata[7:0],24'b0} :
                      ms_l2bit==1 ? {data_sram_rdata[16:0],16'b0} :
                      ms_l2bit==2 ? {data_sram_rdata[23:0],8'b0} 
                                  : data_sram_rdata[31:0] ;
assign right_gr_wen = ms_l2bit==0 ? 4'b1111 :
                      ms_l2bit==1 ? 4'b0111 :
                      ms_l2bit==2 ? 4'b0011 
                                  : 4'b0001 ;
assign right_wdata  = ms_l2bit==0 ? data_sram_rdata[31:0] :
                      ms_l2bit==1 ? {8'b0,data_sram_rdata[31:8]} :
                      ms_l2bit==2 ? {16'b0,data_sram_rdata[31:16]} 
                                  : {8'b0,data_sram_rdata[31:24]} ;
assign ms_to_ws_we = ms_left_algn ? left_gr_wen : 
                    ms_right_algn ? right_gr_wen 
                                  : {4{ms_gr_we}} ;                             
assign res_lh[1] = {{16{data_sram_rdata[31]&ms_ext_sign}},data_sram_rdata[31:16]} ;
assign res_lh[0] = {{16{data_sram_rdata[15]&ms_ext_sign}},data_sram_rdata[15:0]} ;
assign res_lb[3] = {{24{data_sram_rdata[31]&ms_ext_sign}},data_sram_rdata[31:24]} ;
assign res_lb[2] = {{24{data_sram_rdata[23]&ms_ext_sign}},data_sram_rdata[23:16]} ;
assign res_lb[1] = {{24{data_sram_rdata[15]&ms_ext_sign}},data_sram_rdata[15:8]} ;
assign res_lb[0] = {{24{data_sram_rdata[7]&ms_ext_sign}} ,data_sram_rdata[7:0]} ;
assign mem_result = ms_lh           ? res_lh[ms_l2bit[1]] : 
                    ms_lb           ? res_lb[ms_l2bit[1:0]] :
                    ms_left_algn    ? left_wdata : 
                    ms_right_algn   ? right_wdata 
                                    : data_sram_rdata;

assign ms_final_result = ms_src_hi       ? hi_reg :
                         ms_src_lo       ? lo_reg :
                         ms_res_from_mem ? mem_result 
                                         : ms_alu_result;
assign ms_ex = (ms_break|ms_syscall|ms_ex_ades|ms_ex_adel|ms_ex_ov|ms_ex_keep) & ms_valid;
assign ms_eret = es_to_ms_eret & ms_valid ;
assign ms_flush = ms_ex | ws_ex | ws_eret ;
endmodule
