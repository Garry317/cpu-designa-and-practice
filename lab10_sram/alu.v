module alu(
  input  [14:0] alu_op,
  input  [31:0] alu_src1,
  input  [31:0] alu_src2,
  output        ov_flag ,
  output [31:0] alu_result ,
  output [31:0] alu_result2 
);

wire op_add;   //�ӷ�����
wire op_sub;   //��������
wire op_slt;   //�з��űȽϣ�С����λ
wire op_sltu;  //�޷��űȽϣ�С����λ
wire op_and;   //��λ��
wire op_nor;   //��λ���
wire op_or;    //��λ��
wire op_xor;   //��λ���
wire op_sll;   //�߼�����
wire op_srl;   //�߼�����
wire op_sra;   //��������
wire op_lui;   //���������ڸ߰벿��
wire op_mult; // multiple
wire op_div; // divide

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];
assign op_div  = alu_op[12];
assign op_mult = alu_op[13];
assign op_unsign = alu_op[14];

wire [31:0] add_sub_result; 
wire [31:0] slt_result; 
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result; 
wire [63:0] sr64_result; 
wire [31:0] sr_result; 


// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;
wire [1:0]  adder_high;

// div & mult
wire [32:0] op_a ;
wire [32:0] op_b ;
wire [32:0] quot_result ;
wire [32:0] remd_result ;
wire [64:0] mult_result ;
wire [31:0] mult_result_hi ;
wire [31:0] mult_result_lo ;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;
assign adder_high   = {alu_src1[31],alu_src2[31]} ;
assign ov_flag      = adder_high==2'b00 && op_add ? adder_result[31] :
                      adder_high==2'b11 && op_add ? ~adder_result[31] :
                      adder_high==2'b01 && op_sub ? adder_result[31] :
                      adder_high==2'b10 && op_sub ? ~adder_result[31] 
                                                  : 1'b0 ;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2 ;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = {alu_src2[15:0], 16'b0};

// SLL result 
assign sll_result = alu_src2 << alu_src1[4:0];

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src2[31]}}, alu_src2[31:0]} >> alu_src1[4:0];

assign sr_result   = sr64_result[31:0];

assign op_a = {alu_src1[31] & ~op_unsign , alu_src1} ;
assign op_b = {alu_src2[31] & ~op_unsign , alu_src2} ;
// DIV result
assign quot_result = $signed(op_a)/$signed(op_b) ;
assign remd_result = $signed(op_a)%$signed(op_b) ;
// MULT result
assign mult_result = $signed(op_a)*$signed(op_b) ;
assign mult_result_hi = mult_result[63:32] ;
assign mult_result_lo = mult_result[31:0] ;

// final result mux
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                  | ({32{op_slt       }} & slt_result)
                  | ({32{op_sltu      }} & sltu_result)
                  | ({32{op_and       }} & and_result)
                  | ({32{op_nor       }} & nor_result)
                  | ({32{op_or        }} & or_result)
                  | ({32{op_xor       }} & xor_result)
                  | ({32{op_lui       }} & lui_result)
                  | ({32{op_sll       }} & sll_result)
                  | ({32{op_srl|op_sra}} & sr_result)
                  | ({32{op_div       }} & remd_result[31:0])
                  | ({32{op_mult      }} & mult_result_hi) ;
assign alu_result2 = ({32{op_div      }} & quot_result[31:0])
                  |  ({32{op_mult     }} & mult_result_lo) ;

endmodule
