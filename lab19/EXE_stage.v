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
    input                          ws_eret ,
    input                          ws_refetch ,
    input                          ms_ex ,
    input                          ms_eret ,
    input                          ms_refetch ,
    input                          ms_src_entry_hi ,
    // from cp0 
    input  [18:0] c0_vpn2 ,
    input  [ 7:0] c0_asid ,
    // tlb interface 
    output [18:0] s1_vpn2 ,
    output        s1_tlbp ,
    output        s1_odd_page ,
    output [7:0]  s1_asid ,
    input  [`IDX_W-1:0]       s1_index ,
    input         s1_found ,
    input  [19:0] s1_pfn ,
    input  [2:0]  s1_c ,
    input         s1_d ,
    input         s1_v ,
    // 
    output        es_dcache_index_invalid ,
    output        es_dcache_index_store ,
    output        es_dcache_hit_nowb ,
    output        es_dcache_hit_wb ,
    // data sram interface
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [ 1:0] data_sram_size ,
    input         data_sram_addr_ok ,
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
wire        es_ex_tlbl_refill0;
wire        es_ex_tlbl_invalid0;
wire        es_ex_tlbl_refill1;
wire        es_ex_tlbl_invalid1;
wire        es_ex_tlbl_refill;
wire        es_ex_tlbl_invalid;
wire        es_ex_tlbs_refill ;
wire        es_ex_tlbs_invalid ;
wire        es_ex_tlbs_mod ;
wire        es_ex_inst_load ;
wire        data_sram_req ;
wire        es_tlbp ;
wire        es_tlbr ;
wire        es_tlbwi ;
wire        es_dcache_index_invalid ;
wire        es_dcache_index_store ;
wire        es_dcache_hit_nowb ;
wire        es_dcache_hit_wb ;
wire        es_dcache_op ;

wire [`IDX_W-1:0]   es_tlbp_index ;
wire        es_tlbp_found ;

assign {
        es_dcache_index_invalid ,
        es_dcache_index_store ,
        es_dcache_hit_nowb ,
        es_dcache_hit_wb ,
        es_tlbp,
        es_tlbr,
        es_tlbwi,
        es_ex_tlbl_refill0,
        es_ex_tlbl_invalid0,
        es_ex_keep ,
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
assign es_dcache_op = es_dcache_hit_nowb|es_dcache_hit_wb|es_dcache_index_invalid|es_dcache_index_store;

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
assign es_tlbp_index    = s1_index ;
assign es_tlbp_found    = s1_found ;
assign es_to_ms_bus = {
                       es_tlbp_index ,  //167:164
                       es_tlbp_found ,  //163
                       es_tlbp,     //162
                       es_tlbr ,    //161
                       es_tlbwi ,   //160
                       es_ex_tlbl_refill,   //159
                       es_ex_tlbl_invalid,  //158
                       es_ex_tlbs_refill ,  //157
                       es_ex_tlbs_invalid , //156
                       es_ex_tlbs_mod , //155
                       es_mem_en ,  //154
                       es_ex_keep , //153
                       es_bd,   //152
                       es_badaddr,  //151:120
                       es_break,    //119
                       es_syscall,  //118
                       es_eret, //117
                       es_mtc0, //116
                       es_mfc0, //115
                       es_ex_ades,  //114
                       es_ex_adel,  //113
                       es_ex_ov,    //112
                       es_left_algn ,   //111
                       es_right_algn ,  //110
                       es_memh ,    //109
                       es_memb ,    //108
                       es_ext_sign ,    //107
                       es_alu_result2 , //106:75
                       es_src_hi ,  //74
                       es_dst_hi ,  //73
                       es_src_lo ,  //72    
                       es_dst_lo ,  //71
                       es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_alu_result  ,  //63:32
                       es_pc             //31:0
                      };

assign es_ready_go    = ex_status ? 1'b1 :
                        es_mem_en ? data_sram_addr_ok : 
                        es_tlbp   ? !ms_src_entry_hi : 1'b1 ;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go && !(ws_ex|ws_eret|ws_refetch);
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end
    
    if(reset)
        ds_to_es_bus_r <= 0 ;
    else if (ds_to_es_valid && es_allowin) begin
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
wire   [ 1:0]       memw_size ;
wire                data_addr_maped_flag ;

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
assign left_algn_size  = addr_l2bit==0 ? 2'd0 :
                         addr_l2bit==1 ? 2'd1 :
                         addr_l2bit==2 ? 2'd2 
                                       : 2'd2 ;
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
assign memw_size    = es_left_algn&addr_l2bit==0 || es_right_algn&addr_l2bit==3 ? 2'd0 :
                      es_left_algn&addr_l2bit==1 || es_right_algn&addr_l2bit==2 ? 2'd1 : 2'd2 ;

assign sram_wen[0]     = (addr_l2bit==0&es_memb)||(~addr_l2bit[1]&es_memh)||(es_sw&es_memw_wen[0]);
assign sram_wen[1]     = (addr_l2bit==1&es_memb)||(~addr_l2bit[1]&es_memh)||(es_sw&es_memw_wen[1]);
assign sram_wen[2]     = (addr_l2bit==2&es_memb)||( addr_l2bit[1]&es_memh)||(es_sw&es_memw_wen[2]);
assign sram_wen[3]     = (addr_l2bit==3&es_memb)||( addr_l2bit[1]&es_memh)||(es_sw&es_memw_wen[3]);
assign ex_status = ms_ex|ms_eret|ws_ex|ws_eret|ws_refetch | 
                   es_ex_ov|es_ex_ades|es_ex_adel|
                   es_ex_tlbl_refill1|es_ex_tlbl_invalid | 
                   es_ex_tlbs_refill | es_ex_tlbs_invalid | es_ex_tlbs_mod ;

assign data_addr_maped_flag    = (es_alu_result[31:28]<4'h8)||(es_alu_result[31:28]>4'hC) ;
assign s1_vpn2      = es_tlbp ? c0_vpn2 : es_alu_result[31:13] ;
assign s1_odd_page  = es_alu_result[12] ;
assign s1_tlbp      = es_tlbp ;
assign s1_asid      = c0_asid ;
assign data_sram_req   =es_valid && ms_allowin && es_mem_en; 
assign data_sram_en    =(es_valid && ms_allowin && es_mem_en) && !(ex_status) ;
assign data_sram_wen   = es_mem_we&&es_valid ? sram_wen : 4'h0;
assign data_sram_addr  = (es_dcache_hit_nowb|es_dcache_hit_wb) ? {s1_pfn[19:0],es_alu_result[11:2],s1_d,s1_v} :
                                                                 {s1_pfn[19:0],es_alu_result[11:0]} ;
assign data_sram_wdata = es_memb ? {4{es_rt_value[7:0]}} : 
                         es_memh ? {2{es_rt_value[15:0]}}:
                   es_left_algn  ? left_noalgn :
                   es_right_algn ? right_noalgn 
                                 : es_rt_value;
assign es_ex_ov     = es_ex_ov_en & es_alu_ov ;
assign es_ex_ades   = !es_dcache_op && data_sram_wen && (es_memh&data_sram_addr[0] || 
                                        es_sw&&!es_left_algn&&!es_right_algn&&data_sram_addr[1:0]!=0) ;
assign ex_adel1     = !es_dcache_op && es_mem_en && !data_sram_wen && ((es_memh&data_sram_addr[0]) ||
                                   (es_lw & !(es_left_algn|es_right_algn) & data_sram_addr[1:0]!=0)) ;
assign es_ex_adel   = ex_adel0|ex_adel1 ;
assign es_ex_tlbl_refill1   = !es_dcache_op && data_sram_req && data_sram_wen==0 && !s1_found ;
assign es_ex_tlbl_invalid1  = !es_dcache_op && data_sram_req && data_sram_wen==0 && s1_found && !s1_v ;
assign es_ex_tlbl_refill    = es_ex_tlbl_refill0 | es_ex_tlbl_refill1 ;
assign es_ex_tlbl_invalid   = es_ex_tlbl_invalid0 | es_ex_tlbl_invalid1 ;
assign es_ex_tlbs_refill    = !es_dcache_op && data_sram_req && |data_sram_wen && !s1_found ;
assign es_ex_tlbs_invalid   = !es_dcache_op && data_sram_req && |data_sram_wen && s1_found && !s1_v ;
assign es_ex_tlbs_mod       = !es_dcache_op && data_sram_req && |data_sram_wen && s1_found && s1_v && !s1_d ;
assign es_ex_inst_load      = ex_adel0 | es_ex_tlbl_refill0 | es_ex_tlbl_invalid0 ;
assign es_badaddr           = es_ex_inst_load ? es_inst_addr : es_alu_result ; // TODO , v addr
assign data_sram_size       = es_memb ? 2'd0 : 
                              es_memh ? 2'd1 : memw_size ; 

endmodule
