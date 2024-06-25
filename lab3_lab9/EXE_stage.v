`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // to rf
    output  [`ES_TO_RF_BUS_WD:0]   es_to_rf_bus ,
    input                          ws_ex ,
    input                          ms_ex ,
    input                          ms_eret ,
    input                          ws_eret ,
    // data sram interface
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata
);

wire        es_flush ;

wire        es_ex_ades ;
wire        es_ex_ov ;

reg [31:0]  hi_reg ;
reg [31:0]  lo_reg ;

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire [14:0] es_alu_op     ;
wire        es_load_op    ;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_mem_we     ;
wire        es_mem_en     ;
wire        es_src2_ext0  ;
wire        es_dst_hi ;
wire        es_src_hi ;
wire        es_dst_lo ;
wire        es_src_lo ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;
wire        es_memh ;
wire        es_memb ;
wire        es_ext_sign ;
wire        es_left_algn;
wire        es_right_algn;
wire        es_ex_ov_en;
wire        ex_adel0;
wire        ex_adel1;
wire        es_ex_adel;
wire        es_break;
wire        es_syscall;
wire        es_eret;
wire        es_mtc0;
wire        es_mfc0;
wire [31:0] es_inst_addr;
wire [31:0] es_badaddr;
wire        es_bd;
wire        es_ex_keep ;

assign {es_ex_keep ,
        es_bd,
        es_inst_addr,
        es_break,
        es_syscall,
        es_eret,
        es_mtc0,
        es_mfc0,
        ex_adel0,
        es_ex_ov_en,
        es_left_algn,
        es_right_algn,
        es_memh ,
        es_memb ,
        es_ext_sign ,
        es_src_hi ,
        es_dst_hi ,
        es_src_lo ,
        es_dst_lo ,
        es_src2_ext0 ,
        es_mem_en ,
        es_alu_op      ,  //135:124
        es_load_op     ,  //123:123
        es_src1_is_sa  ,  //122:122
        es_src1_is_pc  ,  //121:121
        es_src2_is_imm ,  //120:120
        es_src2_is_8   ,  //119:119
        es_gr_we       ,  //118:118
        es_mem_we      ,  //117:117
        es_dest        ,  //116:112
        es_imm         ,  //111:96
        es_rs_value    ,  //95 :64
        es_rt_value    ,  //63 :32
        es_pc             //31 :0
       } =  ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_alu_result2 ;
wire        es_alu_ov ;

wire [4:0]  es_to_rf_dest ;
wire        es_res_from_mem;
wire        es_res_from_hilo ;
wire        ex_status ;

assign es_to_rf_dest = es_dest & {5{es_valid}} ;
assign es_to_rf_bus  = {es_mfc0 ,
                        es_res_from_hilo ,
                        es_res_from_mem ,
                        es_to_rf_dest , 
                        es_alu_result
                        };
assign es_res_from_mem = es_load_op;
assign es_res_from_hilo = es_src_hi|es_src_lo ;
assign es_to_ms_bus = {es_ex_keep ,
                       es_bd,
                       es_badaddr,
                       es_break,
                       es_syscall,
                       es_eret,
                       es_mtc0,
                       es_mfc0,
                       es_ex_ades,
                       es_ex_adel,
                       es_ex_ov,
                       es_left_algn ,
                       es_right_algn ,
                       es_memh ,
                       es_memb ,
                       es_ext_sign ,
                       es_alu_result2 ,
                       es_src_hi ,
                       es_dst_hi ,
                       es_src_lo ,
                       es_dst_lo ,
                       es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_alu_result  ,  //63:32
                       es_pc             //31:0
                      };

assign es_ready_go    = 1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go && !(ws_ex|ws_eret);
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm ? {{16{es_imm[15] & ~es_src2_ext0}}, es_imm[15:0]} : 
                     es_src2_is_8   ? 32'd8 :
                                      es_rt_value;

alu u_alu(
    .alu_op     (es_alu_op     ),
    .alu_src1   (es_alu_src1   ),
    .alu_src2   (es_alu_src2   ),
    .ov_flag    (es_alu_ov     ),
    .alu_result (es_alu_result ),
    .alu_result2(es_alu_result2)
    );

wire   [1:0]        addr_l2bit ;
wire   [3:0]        sram_wen ;
wire                es_memw ;
wire                es_sw ;
wire                es_lw ;
wire   [3:0]        es_memw_wen ;
wire   [3:0][7:0]   rt_value ;
wire   [3:0]        left_algn_wen ;
wire   [3:0]        right_algn_wen ;
wire   [31:0]       left_noalgn ;
wire   [31:0]       right_noalgn ;

assign rt_value = es_rt_value ; 

assign es_memw         = es_mem_en & ~es_memb & ~es_memh ;
assign es_sw           = es_mem_we & es_memw ;
assign es_lw           = !es_mem_we & es_memw ;
assign es_memw_wen     = es_left_algn ? left_algn_wen : 
                        es_right_algn ? right_algn_wen 
                                      : 4'b1111 ;
assign addr_l2bit      = es_alu_result[1:0] ;
assign left_algn_wen   = addr_l2bit==0 ? 4'b0001 :
                         addr_l2bit==1 ? 4'b0011 :
                         addr_l2bit==2 ? 4'b0111 
                                       : 4'b1111 ;
assign left_noalgn     = addr_l2bit==0 ? {24'b0,es_rt_value[31:24]} :
                         addr_l2bit==1 ? {16'b0,es_rt_value[31:16]} :
                         addr_l2bit==2 ? {8'b0,es_rt_value[31:8]} 
                                       : es_rt_value[31:0] ;
                        
assign right_algn_wen  = addr_l2bit==0 ? 4'b1111 :
                         addr_l2bit==1 ? 4'b1110 :
                         addr_l2bit==2 ? 4'b1100 
                                       : 4'b1000 ;
assign right_noalgn    = addr_l2bit==0 ? es_rt_value[31:0] :
                         addr_l2bit==1 ? {es_rt_value[23:0],8'b0} :
                         addr_l2bit==2 ? {es_rt_value[15:0],16'b0} 
                                       : {es_rt_value[7:0],24'b0} ;

assign sram_wen[0]     = (addr_l2bit==0&es_memb)||(~addr_l2bit[1]&es_memh)||(es_sw&es_memw_wen[0]);
assign sram_wen[1]     = (addr_l2bit==1&es_memb)||(~addr_l2bit[1]&es_memh)||(es_sw&es_memw_wen[1]);
assign sram_wen[2]     = (addr_l2bit==2&es_memb)||( addr_l2bit[1]&es_memh)||(es_sw&es_memw_wen[2]);
assign sram_wen[3]     = (addr_l2bit==3&es_memb)||( addr_l2bit[1]&es_memh)||(es_sw&es_memw_wen[3]);
assign ex_status = ms_ex|ms_eret|ws_ex|ws_eret|ws_ex|es_ex_ov|es_ex_ades|es_ex_adel ;
assign data_sram_en    = es_mem_en && !ex_status ;
assign data_sram_wen   = es_mem_we&&es_valid ? sram_wen : 4'h0;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = es_memb ? {4{es_rt_value[7:0]}} : 
                         es_memh ? {2{es_rt_value[15:0]}}:
                   es_left_algn  ? left_noalgn :
                   es_right_algn ? right_noalgn 
                                 : es_rt_value;
assign es_ex_ov     = es_ex_ov_en & es_alu_ov ;
assign es_ex_ades   = data_sram_wen && (es_memh&data_sram_addr[0] || 
                                        es_sw&&!es_left_algn&&!es_right_algn&&data_sram_addr[1:0]!=0) ;
assign ex_adel1     = es_mem_en && !data_sram_wen && ((es_memh&data_sram_addr[0]) ||
                                   (es_lw & !(es_left_algn|es_right_algn) & data_sram_addr[1:0]!=0)) ;
assign es_ex_adel   = ex_adel0|ex_adel1 ;
assign es_badaddr   = ({32{(ex_adel1|es_ex_ades)}} & data_sram_addr) 
                     |({32{ex_adel0}} & es_inst_addr);

endmodule
