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
    input                          ws_eret ,
    input  [31:0]                  epc ,
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
reg         eret_st ;
reg         inst_drop_en ;
wire        if_flush ;

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;
reg [31:0]  fs_inst_lat ;
reg         fs_inst_valid ;

wire [31:0] seq_pc;
wire [31:0] nextpc;
wire [31:0] ex_pc;

wire         br_taken;
wire [ 31:0] br_target;
wire         bd_inst;
wire         fs_bd ;

assign {bd_inst,br_taken,br_target} = br_bus;
assign fs_bd    = bd_inst && !(ws_ex|ws_eret) ;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {fs_bd,
                       fs_badaddr, 
                       fs_inst ,
                       fs_pc   };

// pre-IF stage
assign pre_ready_go = hand_addr_ok ;
assign to_fs_valid  = ~reset  ;
assign pre_to_fs_valid = to_fs_valid && pre_ready_go ;
assign seq_pc       = fs_pc + 3'h4;
assign ex_pc        = 32'hbfc00380;
assign sel_lat_target   = br_valid && bd_done && !fs_valid ; // fs pc not update 
assign sel_br_target    = (br_taken || br_valid && bd_done) && fs_valid ; // 1.ID is branch,IF is branch delay
assign nextpc       = ws_eret | eret_st ? epc : 
                        ws_ex | ex_st ? ex_pc : 
               sel_lat_target ? br_pc : 
                     br_taken & !fs_valid ? seq_pc : 
                       sel_br_target ? br_target : 
                                seq_pc; 



assign hand_addr_ok = inst_sram_addr_ok && inst_sram_en ;
assign hand_data_ok = inst_sram_data_ok ;

// IF stage
assign fs_ready_go    = (hand_data_ok || fs_inst_valid) && !inst_drop_en ;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin || (ws_ex|ws_eret|ex_st|eret_st);
assign fs_to_ds_valid =  (fs_valid && fs_ready_go) && !(ws_ex|ws_eret|ex_st|eret_st);
assign if_flush       = ws_ex | ws_eret ;

always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= pre_to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (pre_to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end

assign br_pc_updt_en = br_taken && !(fs_valid && pre_to_fs_valid) ||
                       bd_done && br_valid && fs_valid ;
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
    else if(fs_inst_valid && ds_allowin || (ws_ex|ws_eret))
        fs_inst_valid <= 0 ;
    else if(fs_to_ds_valid && !ds_allowin)
        fs_inst_valid <= 1 ;

always @(posedge clk) 
    if(fs_to_ds_valid && !ds_allowin)
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
        eret_st   <= 0 ;
    else if(ws_eret && !pre_to_fs_valid )
        eret_st   <= 1 ;
    else if(pre_to_fs_valid)
        eret_st   <= 0 ;
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
    else if((ws_eret|ws_ex) && fs_valid && !hand_data_ok)
        inst_drop_en <= 1 ;
    else if(hand_data_ok)
        inst_drop_en <= 0 ;

assign inst_sram_en    = to_fs_valid && fs_allowin;
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;
assign fs_inst         = inst_sram_rdata;
assign fs_ex_adel      = inst_sram_en && |inst_sram_addr[1:0] ;
assign fs_badaddr      = fs_pc ;
endmodule
