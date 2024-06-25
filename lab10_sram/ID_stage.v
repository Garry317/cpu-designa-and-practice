`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    // from es 
    input  [`ES_TO_RF_BUS_WD -1:0] es_to_rf_bus ,
    // eret
    input                          ws_ex ,
    input   ws_eret ,
    // from ms
    input  [`MS_TO_RF_BUS_WD -1:0] ms_to_rf_bus
);

reg         ds_valid   ;
wire        ds_ready_go;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire        ds_ex_keep;
wire        ds_ex_adel;
wire [31:0] ds_badaddr;
wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
wire        ds_bd;
assign  ds_ex_adel = |ds_badaddr[1:0] ;
assign {ds_bd,
        ds_badaddr,
        ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire [ 3:0] rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        bd_inst;      
wire        br_taken;
wire [31:0] br_target;

wire [4:0]  es_to_rf_dest ;
wire [31:0] es_result ;
wire es_res_from_mem ;
wire es_res_from_hilo;
wire es_mfc0 ;
assign {es_mfc0 ,
        es_res_from_hilo ,
        es_res_from_mem ,
        es_to_rf_dest ,
        es_result 
        } = es_to_rf_bus ;

wire [4:0]  ms_to_rf_dest ;
wire [31:0] ms_result ;
wire [3:0]  ms_to_rf_we ;
wire        ms_mfc0 ;
wire        ms_ready ;
assign {ms_ready ,
        ms_mfc0 ,
        ms_to_rf_we,
        ms_to_rf_dest ,
        ms_result 
        } = ms_to_rf_bus ;


wire [14:0] alu_op;
wire        load_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_ext0;
wire        src2_is_8;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire        mem_en;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

wire        inst_add;
wire        inst_addi;
wire        inst_addu; // rs rt
wire        inst_sub;
wire        inst_subu; // rs 
wire        inst_slt;  // rs rt
wire        inst_sltu; // rs rt
wire        inst_slti;
wire        inst_sltiu;
wire        inst_and;  // rs rt 
wire        inst_andi;
wire        inst_or;
wire        inst_ori;
wire        inst_xor;
wire        inst_xori;
wire        inst_nor;
wire        inst_sll; // rt
wire        inst_sllv;
wire        inst_srl; // rt
wire        inst_srlv;
wire        inst_sra; // rt
wire        inst_srav;
wire        inst_addiu;// rs 
wire        inst_lui;
wire        inst_lw; // rs
wire        inst_lwl;
wire        inst_lwr;
wire        inst_lh; // rs
wire        inst_lhu; // rs
wire        inst_lb; // rs
wire        inst_lbu; // rs
wire        inst_sw; // rs
wire        inst_swl;
wire        inst_swr;
wire        inst_sh; // rs
wire        inst_sb; // rs
wire        inst_beq; // rs rt
wire        inst_bne; // rs rt
wire        inst_bgez;
wire        inst_bgtz;
wire        inst_blez;
wire        inst_bltz;
wire        inst_bgezal;
wire        inst_bltzal;
wire        inst_jal;
wire        inst_jr; // rs
wire        inst_j;
wire        inst_jalr;
wire        inst_mfhi;
wire        inst_mflo;
wire        inst_mthi;
wire        inst_mtlo;
wire        inst_div;
wire        inst_divu;
wire        inst_mult;
wire        inst_multu;
wire        inst_syscall;
wire        inst_break;
wire        inst_mtc0;
wire        inst_mfc0;
wire        inst_eret;

wire        dst_is_r31;  
wire        dst_is_rt;   

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;
wire        rs_eq_z;
wire        rs_gt_z;
wire        rs_lt_z;
wire        rs_ge_z;
wire        rs_le_z;
wire        tgt_from_imm;
wire        tgt_from_rs;
wire        rs_eq_es_dst ;
wire        rs_eq_ms_dst;
wire        rs_eq_ws_dst;
wire        es_rf_nrdy;
wire        ms_rf_nrdy;
wire        rs_raw_stall ;
wire        rt_eq_es_dst ;
wire        rt_eq_ms_dst;
wire        rt_eq_ws_dst;
wire        rt_raw_stall ;
wire        raw_stall ;
wire        rs_vld ;
wire        rt_vld ;
wire        src_hi;
wire        dst_hi;
wire        src_lo;
wire        dst_lo;
wire        memh_mode;
wire        memb_mode;
wire        load_sign;
wire        mem_store;
wire        left_algn;
wire        right_algn;
wire        ex_ov_en;

assign br_bus       = {bd_inst,br_taken,br_target};

assign ds_to_es_bus = {ds_ex_keep,
                       ds_bd,
                       ds_badaddr,
                       inst_break,
                       inst_syscall,
                       inst_eret,
                       inst_mtc0,
                       inst_mfc0,
                       ds_ex_adel,
                       ex_ov_en ,
                       left_algn ,
                       right_algn ,
                       memh_mode ,
                       memb_mode ,
                       load_sign ,
                       src_hi ,
                       dst_hi ,
                       src_lo ,
                       dst_lo ,
                       src2_ext0 ,
                       mem_en ,
                       alu_op      ,  //135:124
                       load_op     ,  //123:123
                       src1_is_sa  ,  //122:122
                       src1_is_pc  ,  //121:121
                       src2_is_imm ,  //120:120
                       src2_is_8   ,  //119:119
                       gr_we       ,  //118:118
                       mem_we      ,  //117:117
                       dest        ,  //116:112
                       imm         ,  //111:96
                       rs_value    ,  //95 :64
                       rt_value    ,  //63 :32
                       ds_pc          //31 :0
                      };

assign ds_ready_go    = ds_valid && !raw_stall ;
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin ||(ws_ex|ws_eret);
assign ds_to_es_valid = ds_valid && ds_ready_go && !(ws_eret | ws_ex ) ;
always @(posedge clk) begin
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
end

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_addi   = op_d[6'h08];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_slti   = op_d[6'h0a] ;
assign inst_sltiu  = op_d[6'h0b] ;
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_andi   = op_d[6'h0c] ;
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_ori    = op_d[6'h0d] ;
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_xori   = op_d[6'h0e] ;
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07];
assign inst_addiu  = op_d[6'h09];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw     = op_d[6'h23];
assign inst_lwl    = op_d[6'h22];
assign inst_lwr    = op_d[6'h26];
assign inst_lb     = op_d[6'h20];
assign inst_lh     = op_d[6'h21];
assign inst_lbu    = op_d[6'h24];
assign inst_lhu    = op_d[6'h25];
assign inst_sw     = op_d[6'h2b];
assign inst_swl     = op_d[6'h2a];
assign inst_swr     = op_d[6'h2e];
assign inst_sh     = op_d[6'h29];
assign inst_sb     = op_d[6'h28];
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_bgez   = op_d[6'h01] & rt_d[5'h01];
assign inst_bgtz   = op_d[6'h07] & rt_d[5'h00];
assign inst_blez   = op_d[6'h06] & rt_d[5'h00];
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00];
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11];
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10];
assign inst_jal    = op_d[6'h03];
assign inst_j      = op_d[6'h02];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_jalr   = op_d[6'h00] & func_d[6'h09] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & rt_d[5'h00] & rs_d[5'h00] & sa_d[5'h00];
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & rt_d[5'h00] & rs_d[5'h00] & sa_d[5'h00];
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & rd_d[5'h00] & sa_d[5'h00] ;
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & rd_d[5'h00] & sa_d[5'h00] ;
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & rd_d[5'h00] & sa_d[5'h00] ;
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & rd_d[5'h00] & sa_d[5'h00] ;
assign inst_break  = op_d[6'h00] & func_d[6'h0d] ;
assign inst_syscall = op_d[6'h00] & func_d[6'h0c] ;
assign inst_eret   = op_d[6'h10] & func_d[6'h18] & ds_inst[25] & ds_inst[24:6]==0 ;
assign inst_mfc0   = op_d[6'h10] & rs_d[5'h00] & ds_inst[10:3]==0 ;
assign inst_mtc0   = op_d[6'h10] & rs_d[5'h04] & ds_inst[10:3]==0 ;


assign ds_ex_keep = ~(inst_add| inst_addi| inst_addu| inst_sub| inst_subu| inst_slt| inst_sltu
                    | inst_addi| inst_addu| inst_sub| inst_subu| inst_slt| inst_sltu
                    | inst_slti| inst_sltiu| inst_and| inst_andi| inst_or| inst_ori
                    | inst_xor| inst_xori| inst_nor| inst_sll| inst_sllv| inst_srl
                    | inst_srlv| inst_sra| inst_srav| inst_addiu| inst_lui| inst_lw
                    | inst_lwl| inst_lwr| inst_lh| inst_lhu| inst_lb| inst_lbu| inst_sw
                    | inst_swl| inst_swr| inst_sh| inst_sb| inst_beq| inst_bne| inst_bgez
                    | inst_bgtz| inst_blez| inst_bltz| inst_bgezal| inst_bltzal| inst_jal
                    | inst_jr| inst_j| inst_jalr| inst_mfhi| inst_mflo| inst_mthi| inst_mtlo
                    | inst_div| inst_divu| inst_mult| inst_multu| inst_syscall| inst_break
                    | inst_mtc0| inst_mfc0| inst_eret) ;

assign alu_op[ 0] = inst_addu | inst_addiu | inst_addi | inst_add 
                  | res_from_mem | mem_we | inst_jal | inst_bgezal | inst_bltzal
                  | inst_jalr ;
assign alu_op[ 1] = inst_subu | inst_sub ;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and | inst_andi  ;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori | inst_mthi | inst_mtlo | inst_mtc0 | inst_mfc0;
assign alu_op[ 7] = inst_xor | inst_xori ;
assign alu_op[ 8] = inst_sll | inst_sllv;
assign alu_op[ 9] = inst_srl | inst_srlv;
assign alu_op[10] = inst_sra | inst_srav;
assign alu_op[11] = inst_lui;
assign alu_op[12] = inst_div|inst_divu ;
assign alu_op[13] = inst_mult|inst_multu;
assign alu_op[14] = inst_divu | inst_multu;
assign load_op = res_from_mem ;
assign src_hi  = inst_mfhi ;
assign dst_hi  = inst_mthi | inst_div | inst_divu | inst_mult | inst_multu;
assign src_lo  = inst_mflo ;
assign dst_lo  = inst_mtlo | inst_div | inst_divu | inst_mult | inst_multu;
assign memh_mode = inst_lh | inst_lhu | inst_sh;
assign memb_mode = inst_lb | inst_lbu | inst_sb;
assign load_sign = inst_lh | inst_lb ;
assign left_algn = inst_lwl|inst_swl;
assign right_algn= inst_lwr|inst_swr;
assign ex_ov_en  = inst_sub|inst_add|inst_addi;

assign src1_is_sa   = inst_sll   | inst_srl | inst_sra;
assign src1_is_pc   = inst_jal | inst_bgezal | inst_bltzal | inst_jalr ;
assign src2_is_imm  = inst_addiu | inst_lui | res_from_mem | mem_we | inst_addi 
                    | inst_slti | inst_sltiu | inst_andi | inst_ori | inst_xori ;
assign src2_ext0    = inst_andi | inst_ori | inst_xori ;
assign src2_is_8    = inst_jal | inst_bgezal | inst_bltzal | inst_jalr ;
assign res_from_mem = inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu 
                    | inst_lwl | inst_lwr ;
assign dst_is_r31   = inst_jal | inst_bgezal | inst_bltzal;
assign dst_is_rt    = inst_addiu | inst_lui | res_from_mem | inst_addi 
                    | inst_andi | inst_ori | inst_xori | inst_slti | inst_sltiu 
                    | inst_mfc0 ;
assign gr_we        = ~mem_we & ~inst_beq & ~inst_bne & ~inst_jr & ~inst_div 
                    & ~inst_divu & ~inst_mult & ~inst_multu & ~inst_mthi 
                    & ~inst_mtlo & ~inst_bgez & ~inst_bgtz & ~inst_blez 
                    & ~inst_bltz & ~inst_j & ~inst_mtc0;
assign mem_we       = inst_sw|inst_sh|inst_sb|inst_swl|inst_swr;
assign mem_en       = mem_we | res_from_mem ;

assign dest         = inst_mtc0 ? rd : 
                      ~gr_we     ? 5'd0 :
                      dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    :
                                   rd;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rs_value = rs_eq_es_dst ? es_result : 
                  rs_eq_ms_dst ? ms_result : 
                  rs_eq_ws_dst ? rf_wdata  : 
           inst_mfc0|inst_mtc0 ? 32'd0 :
                                 rf_rdata1;

assign rt_value = rt_eq_es_dst ? es_result : 
                  rt_eq_ms_dst ? ms_result : 
                  rt_eq_ws_dst ? rf_wdata :
                  inst_mfc0    ? {27'd0,rd} :
                                 rf_rdata2;

assign rs_vld   = (inst_addu|inst_subu|inst_slt|inst_sltu|inst_and|
                   inst_or|inst_xor|inst_nor|inst_addiu|res_from_mem|mem_we|
                   inst_beq|inst_bne|inst_jr|inst_add|inst_sub|inst_sllv|
                   inst_srlv | inst_srav | inst_addi | inst_slti | inst_sltiu| 
                   inst_andi | inst_ori | inst_xori | inst_mthi | inst_mtlo | 
                   inst_div | inst_divu | inst_mult | inst_multu | inst_bgez |
                   inst_bgtz | inst_blez | inst_bltz | inst_bgezal | inst_bltzal |
                   inst_jalr ) & rs!=0 ;
assign rt_vld   = (inst_addu|inst_subu|inst_slt|inst_sltu|inst_and|inst_or|
                   inst_xor|inst_nor|inst_sll|inst_srl|inst_sra|inst_beq|
                   inst_bne|mem_we|inst_add|inst_sub|inst_sllv|inst_srlv|
                   inst_srav | inst_div | inst_divu | inst_mult | inst_multu|
                   inst_mtc0 ) & rt!=0 ;

assign rs_eq_rt = (rs_value == rt_value);
assign rs_eq_z  = rs_value==32'd0 ;
assign rs_gt_z  = ~rs_value[31] && |rs_value[30:0] ;
assign rs_lt_z  = rs_value[31] ;
assign rs_ge_z  = rs_eq_z | rs_gt_z ;
assign rs_le_z  = rs_eq_z | rs_lt_z ;

assign es_rf_nrdy   = es_res_from_mem|es_res_from_hilo|es_mfc0 ;
assign ms_rf_nrdy   = ms_mfc0 || !ms_ready;
assign rs_eq_es_dst = rs_vld & rs==es_to_rf_dest ; 
assign rs_eq_ms_dst = rs_vld & rs==ms_to_rf_dest ; 
assign rs_eq_ws_dst = rs_vld & rs==rf_waddr ;
assign rs_raw_stall = (rs_eq_es_dst & es_rf_nrdy) |
                      (rs_eq_ms_dst & ms_rf_nrdy) ;
assign rt_eq_es_dst = rt_vld & rt==es_to_rf_dest ; 
assign rt_eq_ms_dst = rt_vld & rt==ms_to_rf_dest ; 
assign rt_eq_ws_dst = rt_vld & rt==rf_waddr ;
assign rt_raw_stall = (rt_eq_es_dst & es_rf_nrdy) |
                      (rt_eq_ms_dst & ms_rf_nrdy) ;
assign raw_stall    = rs_raw_stall | rt_raw_stall ;

assign bd_inst = (inst_beq|inst_bne|inst_bgezal|inst_bgez|inst_bgtz
                |inst_blez|inst_bltzal|inst_bltz|inst_jalr|inst_jal|
                |inst_j|inst_jr)  ;
assign br_taken = (   inst_beq  &&  rs_eq_rt
                   || inst_bne  && !rs_eq_rt
                   || (inst_bgezal|inst_bgez) &&  rs_ge_z
                   || inst_bgtz &&  rs_gt_z
                   || inst_blez &&  rs_le_z
                   || (inst_bltzal|inst_bltz) &&  rs_lt_z
                   || inst_jalr
                   || inst_jal
                   || inst_jr
                   || inst_j
                  ) && ds_ready_go;
assign tgt_from_imm = inst_beq | inst_bne | inst_bgez | inst_bgtz 
                     |inst_blez | inst_bltz | inst_bgezal | inst_bltzal;
assign tgt_from_rs  = inst_jr | inst_jalr ;
assign br_target = tgt_from_imm ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   tgt_from_rs  ? rs_value :
                  /*inst_jal*/    {fs_pc[31:28], jidx[25:0], 2'b0};

endmodule
