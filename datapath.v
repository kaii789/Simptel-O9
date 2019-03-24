module datapath(
	PCWriteCond,
	PCWrite,
	IorD,
	MemRead,
	MemWrite,
	MemtoReg,
	IRWrite,
	PCSource,
	ALUOp,
	ALUSrcB,
	ALUSrcA,
	RegWrite,
	RegDst,
	clk,
	reset
);


	input PCWriteCond, PCWrite, IorD, MemRead, MemWrite, MemtoReg, IRWrite, ALUOp, ALUSrcA, RegWrite, RegDst, clk, reset;
	input [1:0] PCSource;
	input [2:0] ALUSrcB;
	output [5:0] opCode;
	
	wire [31:0] ALU_Out_Bus;
	wire [31:0] instr_shifted;
	wire [31:0] mux_F_out;
	wire [31:0] PC_Out_Bus;
	wire [31:0] mux_A_out;
	wire [31:0] B_reg_out;
	wire [31:0] mem_out;
//	wire [6:0] instruc3_bus;
	wire [5:0] instruc2_bus;
	wire [5:0] instruc1_bus;
	wire [15:0] instruc0_bus;
	wire [31:0] mux_C_out;
	wire [4:0] mux_B_out;
	wire [31:0] sign_extend_out;
	wire [31:0] A;
	wire [31:0] B;
	wire [31:0] mux_D_out;
	wire [31:0] shift_left_out;
	wire [31:0] mux_E_out;
	wire zero;
 	
	three_to_one_mux mux_F(
		.sel(PCSource[1:0]),
		.in_0(ALU_Out_Bus), // something weird here
		.in_1(ALU_Out_Bus),
		.in_2(instr_shifted),
		.q(mux_F_out)
	);
	
	ProgramCounter program_counter(
		.reset(reset),
		.clk(clk),
		.PC_in(mux_F_out),
		.PC_out(PC_Out_Bus)
	);
	
	two_two_one_mux mux_A(
		.sel(IorD),
		.in_0(PC_Out_Bus),
		.in_1(ALU_Out_Bus),
		.q(mux_A_out)
	);
	
	ram65536x32 Memory(
		.address(mux_A_out[15:0]),
		.clock(clk),
		.data(b_reg_out),
		.wren(MemWrite),
		.q(mem_out)
	);
	
	Instruction_Register IR(
		.memory_data(mem_out),
		.clk(clk),
		.instruc3(opCode),
		.instruc2(instruc2_bus),
		.instruc1(instruc1_bus),
		.instruc0(instruc0_bus),
		.IRWrite(IRWrite)
	);
	
	two_to_one_mux_5_bit mux_B(
		.in_0(instruc1_bus),
		.in_1(instruc0_bus[4:0]), // TODO
		.sel(RegDst),
		.q(mux_B_out)
	);
	
	Registers register(
		.clk(clk),
		.reset(reset),
		.write_reg(mux_B_out),
		.write_data(mux_C_out),
		.read_reg1(instruc2_bus),
		.read_reg2(instruc1_bus),
		.RegWrite(RegWrite),
		.read_data1(),
		.read_data2()
	);
	
	two_to_one_mux mux_C(
		.in_0(ALU_out_bus),
		.in_1(mem_out),
		.q(mux_C_out),
		.sel(MemtoReg)
	);
	
	SignExtend sign_extend(
		.to_extend(instruc0_bus),
		.extended(sign_extend_out)
	);
	
	two_to_one_mux mux_D(
		.in_0(PC_Out_Bus),
		.in_1(A),
		.q(mux_D_out),
		.sel(ALUSrcA)
	);
	
	four_to_one_mux mux_E(
		.in_0(B),
		.in_1(32'b00000000000000000000000000000100),
		.in_2(sign_extend_out),
		.in_3(shift_left_out),
		.sel(ALUSrcB),
	);
	
	ShiftLeft shift_left_2_A(
		.to_shift(sign_extend_out),
		.shifted(shift_left_out)
	);
	
	ALU alu(
		.clk(clk),
		.srcA(mux_D_out),
		.srcB(mux_E_out),
		.ALU_control(instruc0_bus[3:0]), // be careful here. how to resolve conflict with ALUOp?
		.zero(zero),
		.ALU_result(ALU_Out_Bus) // not using a separate register here
	);

endmodule

module and(in_0, in_1, q);
	input in_0, in_1;
	output q;
	
	assign q = in_0 & in_1;
endmodule

module or(in_0, in_1, q);
	input in_0, in_1, q;
	output q;
	
	assign q = in_0 | in_1;
endmodule

module two_to_one_mux(in_0, in_1, sel, q);
	input [31:0] in_0, in_1;
	input sel;
	output [31:0] q;
	reg [31:0] q;
	
	always @(in_0 or in_1 or sel)
		if (sel == 1'b0)
			q = in_0;
		else
			q = in_1;
		
endmodule

module three_to_one_mux(in_0, in_1, in_2, sel, q);
	input [31:0] in_0, in_1, in_2;
	input [1:0] sel;
	output [31:0] q;
	reg [31:0] q;
	
	always @(in_0 or in_1 or in_2 or sel)
		if (sel == 2'b00)
			q = in_0;
		else if (sel == 2'b01)
			q = in_1;
		else
			q = in_2;
		
endmodule

module two_to_one_mux_5_bit(in_0, in_1, q, sel);
	input [4:0] in_0, in_1;
	input sel;
	output [4:0] q;
	
	always @(in_0 or in_1 or sel)
		if (sel == 1'b0)
			q = in_0;
		else
			q = in_1;

endmodule

module four_to_one_mux(in_0, in_1, in_2, in_3, q, sel);
	input [31:0] in_0, in_1, in_2, in_3;
	input [1:0] sel;
	output [31:0] q;
	
	always @(in_0 or in_1 or in_2 or in_3 or sel)
		if (sel == 2'b00)
			q = in_0
		else if (sel == 2'b01)
			q = in_1
		else if (sel == 2'b10)
			q = in_2
		else
			q = in_3
	
endmodule