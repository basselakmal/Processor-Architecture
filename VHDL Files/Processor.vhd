Library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith;

Entity Processor is
port(	
	Interrupt, Reset, Clk : in std_logic;
	inPort : in std_logic_vector(15 downto 0);
	outPort : out std_logic_vector(15 downto 0)
    );
end Processor;

Architecture Pipelined_Processor of Processor is

----------------------------------------------------------------------------------------------------------------------------------
--1)Components :-
------------------

Component ALU is
port(A,B : in std_logic_vector(15 downto 0); Shift : in std_logic_vector(3 downto 0); Cin : in std_logic; S : in std_logic_vector(3 downto 0); F : out std_logic_vector(15 downto 0); 
Cout, Zero, Neg, Overflow : out std_logic);
end Component ALU;

Component ALU_CU is
Port(
OPCode	: in std_logic_vector(4 downto 0);
ALUCode	: out std_logic_vector(3 downto 0);
ALUCin : out std_logic);
End Component ALU_CU;

Component BranchModule is
Port(
Cout, JC, Zero, JZ, Neg, JN, JMP : in std_logic;
RstC, RstZ, RstN, PCSrc : out std_logic);
End Component BranchModule;

Component entityCCR is
port( Clk, RST, WriteCCR, SETC, CLRC, CoutAlu, ZeroAlu, NegAlu, OverflowAlu: in std_logic;
CoutTempCCR, ZeroTempCCR, NegTempCCR, OverflowTempCCR: in std_logic;
Cout, Zero, Neg, Overflow: out std_logic);
end Component entityCCR;

Component entityTempCCR is
port( Clk, WriteTempCCR: in std_logic;
CoutCCR, ZeroCCR, NegCCR, OverflowCCR: in std_logic;
Cout, Zero, Neg, Overflow: out std_logic);
end Component entityTempCCR;

Component CU is
Port(
OPCode	: in std_logic_vector(4 downto 0);
Int	: in std_logic;
JZ, JN, JC, JMP, ALUSrc, ALUCin, SETC, CLRC, MemWrite, MemRead, RegWrite, MemToReg, PortSelect, PortWrite, SPSel,
PCWrite, MemPC, CallSel, WriteCCR, ReadImm, RTI_Flush: out std_logic);
End Component CU;

Component FU is
port( 	ExMem_Rdst, IdEx_Rsrc, IdEx_Rdst, MemWB_Rdst : in std_logic_vector (2 downto 0);
	ExMem_RegWrite, MemWB_RegWrite, ExMem_MemRead, MemWB_MemRead, ExMem_NOP, MemWB_NOP : in std_logic;
	MUX_A, MUX_B : out std_logic_vector(1 downto 0));
end Component FU;

Component FA is
generic (n: integer := 8);
port(A, B : in std_logic_vector(n-1 downto 0); Cin : in std_logic; F : out std_logic_vector(n-1 downto 0); Cout : out std_logic);
end Component FA;

Component FA_OneBit is
port(A, B, Cin : in std_logic; F : out std_logic; Cout : out std_logic);
end Component FA_OneBit;

Component HDU is
port( 	IdEx_MemRead : in std_logic;
	IfId_Rdst, IdEx_Rdst : in std_logic_vector (2 downto 0);
	Flush, PCFreeze : out std_logic);
end Component HDU;

Component Memory is
generic(n:integer:=10; m:integer:=16);
port( Clk, MemWrite : in std_logic;
Write_Data : in std_logic_vector (m-1 downto 0);
Read_Data : out std_logic_vector (m-1 downto 0);
Address : in std_logic_vector(n-1 downto 0));
end Component Memory;

Component PCModule is
port( 	Interrupt, Reset, Clk, PCSrc, CallSel, PCFreeze, PCWrite : in std_logic;
	RdstVal, WriteData : in std_logic_vector(15 downto 0);
	Flush_IdEx : out std_logic;
	Instruction, PC, Imm : out std_logic_vector (15 downto 0));
end Component PCModule;

Component entityPort is
port(PortWrite: in std_logic;
RegValueIn: in std_logic_vector(15 downto 0);
RegValueOut: out std_logic_vector(15 downto 0);
inPort: in std_logic_vector(15 downto 0);
outPort: out std_logic_vector(15 downto 0));
end Component entityPort;

Component my_DFF is
Generic ( n : integer := 16);
port( Clk,Rst, En : in std_logic;
d : in std_logic_vector(n-1 downto 0);
q : out std_logic_vector(n-1 downto 0));
end component my_DFF;

Component Registers is
port( Clk, Rst, RegWrite : in std_logic;
Write_Reg, Reg_1, Reg_2 : in std_logic_vector (2 downto 0);
Data_1, Data_2 : out std_logic_vector (15 downto 0);
Write_Data : in std_logic_vector(15 downto 0));
end Component Registers;

Component SPModule is
Port(
Clk, Reset, MemWrite, SPSel: in std_logic;
PipeSP : out std_logic_vector(15 downto 0));
End Component SPModule;

----------------------------------------------------------------------------------------------------------------------------------
--2)Signals :-
--------------
--IF/ID Signals :-
-------------------
signal Int : std_logic;					-- 47
signal Op : std_logic_vector(4 downto 0); 		-- 46:42 
signal Imm : std_logic_vector(15 downto 0); 		-- 41:26
signal Shift : std_logic_vector(3 downto 0);		-- 25:22
signal Rdst : std_logic_vector(2 downto 0); 		-- 21:19
signal Rsrc : std_logic_vector(2 downto 0); 		-- 18:16
signal Pc : std_logic_vector(15 downto 0); 		-- 15:0
signal IF_ID : std_logic_vector(47 downto 0); 		-- 48 bits

--ID/EX Signals :-
-------------------
signal RTI_Flush : std_logic;				-- 130
signal MemRead : std_logic;				-- 129
signal RegData1 : std_logic_vector(15 downto 0);	-- 128:113
signal RegData2 : std_logic_vector(15 downto 0);	-- 112:97
--signal Imm : std_logic_vector(15 downto 0);		-- 96:81
--signal Pc : std_logic_vector(15 downto 0);		-- 80:65
signal Sp : std_logic_vector(15 downto 0);		-- 64:49
signal PortVal : std_logic_vector(15 downto 0);		-- 48:33
--signal Op : std_logic_vector(4 downto 0);		-- 32:28
--signal Shift : std_logic_vector(3 downto 0);		-- 27:24
--signal Rdst : std_logic_vector(2 downto 0);		-- 23:21
--signal Rsrc : std_logic_vector(2 downto 0);		-- 20:18
signal Jz : std_logic;					-- 17
signal Jn : std_logic;					-- 16
signal Jc : std_logic;					-- 15
signal Jmp : std_logic;					-- 14
signal ALUSrc : std_logic;				-- 13
signal ALUCin : std_logic;				-- 12
signal ClrC : std_logic;				-- 11
signal SetC : std_logic;				-- 10
signal WriteCcr : std_logic;				-- 9
signal PortSelect : std_logic;				-- 8
signal MemWrite : std_logic;				-- 7
signal SpSel : std_logic;				-- 6
signal CallSel : std_logic;				-- 5
signal MemPc : std_logic;				-- 4
signal MemToReg : std_logic;				-- 3
signal PortWrite : std_logic;				-- 2
signal PcWrite : std_logic;				-- 1
signal RegWrite : std_logic; 				-- 0
signal ID_Ex : std_logic_vector(130 downto 0);		-- 131 bits

--EX/Mem Signals :-
--------------------
--signal OP : std_logic_vector(81 downto 77);		-- 81:77
--signal ExMem_MemRead : std_logic;			-- 76
--signal RTI_Flush : std_logic;				-- 75
signal Result_PortVal : std_logic_vector(15 downto 0);	-- 74:59
--signal RegData2 : std_logic_vector(15 downto 0);	-- 58:43
--signal Pc : std_logic_vector(15 downto 0);		-- 42:27
--signal Sp : std_logic_vector(15 downto 0);		-- 26:11
--signal Rdst : std_logic_vector(2 downto 0);		-- 10:8
--signal MemWrite : std_logic;				-- 7
--signal SpSel : std_logic;				-- 6
--signal CallSel : std_logic;				-- 5
--signal MemPc : std_logic;				-- 4
--signal MemToReg : std_logic;				-- 3
--signal PortWrite : std_logic;				-- 2
--signal PcWrite : std_logic;				-- 1
--signal RegWrite : std_logic;				-- 0
signal Ex_Mem : std_logic_vector(81 downto 0);		-- 82 bits

-- Mem/WB Signals :-
---------------------
--signal OP : std_logic_vector(45 downto 41);		-- 45:41
--signal ExMem_MemRead : std_logic;			-- 40
--signal RTI_Flush : std_logic;				-- 39
--signal PortVal : std_logic_vector(15 downto 0);	-- 38:23
signal ReadData : std_logic_vector(15 downto 0);	-- 22:7
--signal Rdst :std_logic_vector(2 downto 0);		-- 6:4
--signal MemToReg : std_logic;				-- 3
--signal PortWrite : std_logic;				-- 2
--signal PcWrite : std_logic;				-- 1
--signal RegWrite : std_logic;				-- 0
signal Mem_WB : std_logic_vector(45 downto 0);		-- 46 bits

----------------------------------------------------------------------------------------------------------------------------------
--4)Registers Signals :-
------------------------
signal R1_En, R2_En, R3_En ,R4_En : std_logic;
signal R1_Rst, R2_Rst, R3_Rst ,R4_Rst : std_logic;
signal R1_In, R1_Out : std_logic_vector(47 downto 0);
signal R2_In, R2_Out : std_logic_vector(130 downto 0);
signal R3_In, R3_Out : std_logic_vector(81 downto 0);
signal R4_In, R4_Out : std_logic_vector(45 downto 0);
----------------------------------------------------------------------------------------------------------------------------------
--5)Stages Signals :-
---------------------
--a)Fetch Signals :- "PC Module"
---------------------------------
signal PCSrc, PCFreeze : std_logic;
signal RdstVal, WriteData : std_logic_vector(15 downto 0);
signal Flush_IdEx : std_logic;
signal Instruction : std_logic_vector (15 downto 0);
signal PC_Out : std_logic_vector (15 downto 0);

--b)Decode Signals :- 
----------------------
signal Reg_En : std_logic;
signal ReadImm : std_logic;
signal Flush : std_logic;
signal Flushing : std_logic;
signal StackPointer : std_logic_vector(15 downto 0);
signal EX_OP : std_logic_vector(4 downto 0);
signal Control_Cin : std_logic;

--c)Execute Signals :- 
-----------------------
signal ALUCode : std_logic_vector(3 downto 0);
signal Input_A : std_logic_vector(15 downto 0);
signal Input_B : std_logic_vector(15 downto 0);
signal MUX_A : std_logic_vector (1 downto 0);
signal MUX_B : std_logic_vector (1 downto 0);
signal MUX_B_3 : std_logic_vector (15 downto 0);
signal ALU_Cin : std_logic; 
signal Result : std_logic_vector(15 downto 0); 
signal ALU_Cout, Zero, Neg, Overflow : std_logic;
signal CoutTempCCR, ZeroTempCCR, NegTempCCR, OverflowTempCCR : std_logic;
signal CCR_Cout, CCR_Zero, CCR_Neg, CCR_Overflow : std_logic;
signal RstC, RstZ, RstN, CCR_Reset : std_logic;

--d)Memory Signals :- 
----------------------
signal PCSig : std_logic_vector(15 downto 0);
signal FA_Cout : std_logic;
signal Mem_Address : std_logic_vector(15 downto 0);
signal Data_Write_In : std_logic_vector(15 downto 0);

--e)WriteBack Signals :- 
-------------------------
signal Write_Data : std_logic_vector(15 downto 0);
signal Write_Reg : std_logic_vector(2 downto 0); 

----------------------------------------------------------------------------------------------------------------------------------

signal ExMem_MemRead, MemWB_MemRead, ExMem_NOP, MemWB_NOP : std_logic;

begin

--Initial Values:-
-------------------

R1_En <= '1';
R2_En <= '1';
R3_En <= '1';
R4_En <= '1';
Reg_En <= '1';

----------------------------------------------------------------------------------------------------------------------------------
--1)Fetch :-
-------------
PC_Module : PCModule port map(Interrupt, Reset, Clk, PCSrc, CallSel, PCFreeze, R4_Out(1) ,RdstVal, Write_Data, Flush_IdEx, Instruction,PC_Out, Imm);

R1_In <= Interrupt & Instruction(15 downto 11) & Imm(15 downto 0) & Instruction(3 downto 0) & Instruction(7 downto 5) & Instruction(10 downto 8) & PC_Out;
Int <= Interrupt;	

-----------------------------------------------------------------------------------------------------------------------------------
--IF/ID Reg :-
---------------
R1_Rst <= Reset or R4_Out(39);
R1: my_DFF generic map(n => 48) port map(Clk, R1_Rst, R1_En, R1_In, R1_Out);
----------------------------------------------------------------------------------------------------------------------------------
--2)Decode :-
--------------
--Int <= R1_Out(47);
--Op <= R1_Out(46 downto 42);
--Imm <= R1_Out(41 downto 26);
--Shift <= R1_Out(25 downto 22);
--Rdst <= R1_Out(21 downto 19);
--Rsrc <= R1_Out(18 downto 16);
--Pc <= R1_Out(15 downto 0);

Main_Reg : Registers port map ( Clk, Reset, R4_Out(0), Write_Reg,  R1_Out(18 downto 16), R1_Out(21 downto 19) ,RegData1 ,RegData2 ,Write_Data);

Control_Unit: CU port map (R1_Out(46 downto 42), R1_Out(47), Jz, Jn, Jc, Jmp, ALUSrc, ALUCin, SetC, ClrC, MemWrite, MemRead, RegWrite, MemToReg, PortSelect, PortWrite, SpSel, PcWrite, MemPc, CallSel, WriteCcr, ReadImm, RTI_Flush);

Hazard_Unit : HDU port map(R2_Out(129), R1_Out(21 downto 19), R2_Out(23 downto 21), Flush, PCFreeze);

Flushing <= Flush or Reset or PCSrc or ReadImm ;

Main_Port : entityPort port map (R4_Out(2), Write_Data, PortVal, inPort ,outPort);

Module_SP : SPModule port map (Clk, Reset, MemWrite, SpSel, StackPointer);

----------------------------------------------------------------------------------------------------------------------------------
--ID/EX Reg :-
-----------------
--ID_EX <= RegData1(15 downto 0) & RegData2(15 downto 0) & Imm(15 downto 0) & Pc(15 downto 0) & Sp(15 downto 0) & PortVal(15 downto 0) & Op(4 downto 0) &  Shift(3 downto 0) & Rdst(2 downto 0) & Rsrc(2 downto 0) & Jz & Jn & Jc & Jmp & ALUSrc & ALUCin & ClrC & SetC & WriteCcr & PortSelect & MemWrite & SpSel & CallSel & MemPc & MemToReg & PortWrite & PcWrite & RegWrite;
R2_Rst <= Reset or R4_Out(39);

R2: my_DFF generic map(n => 131) port map(Clk, R2_Rst, R2_En, R2_In, R2_Out);
EX_OP <= R1_Out(46 downto 42) when Flush_IdEx = '0' else "00000";
ID_EX <= RTI_Flush & MemRead & RegData1(15 downto 0) & RegData2(15 downto 0) & R1_Out(41 downto 26) & R1_Out(15 downto 0) & StackPointer(15 downto 0) & PortVal(15 downto 0) & EX_OP & R1_Out(25 downto 22) & R1_Out(21 downto 19) & R1_Out(18 downto 16) & Jz & Jn & Jc & Jmp & ALUSrc & ALUCin & ClrC & SetC & WriteCcr & PortSelect & MemWrite & SpSel & CallSel & MemPc & MemToReg & PortWrite & PcWrite & RegWrite;
R2_In <= ID_EX;
----------------------------------------------------------------------------------------------------------------------------------
--3)Execute :-
---------------
--RTI_Flush <= R2_Out(130);
--MemRead <= R2_Out(129);
--RegData1 <= R2_Out(128 downto 113);
--RegData2 <= R2_Out(112 downto 97);
--Imm <= R2_Out(96 downto 81);	
--Pc <= R2_Out(80 downto 65);
--Sp <= R2_Out(64 downto 49);
--PortVal <= R2_Out(48 downto 33);
--Op <= R2_Out(32 downto 28);
--Shift <= R2_Out(27 downto 24);
--Rdst <= R2_Out(23 downto 21);
--Rsrc <= R2_Out(20 downto 18);
--Jz <= R2_Out(17);
--Jn <= R2_Out(16);
--Jc <= R2_Out(15);
--Jmp <= R2_Out(14);
--ALUSrc <= R2_Out(13);
--ALUCin <= R2_Out(12);
--ClrC <= R2_Out(11);
--SetC <= R2_Out(10);
--WriteCcr <= R2_Out(9);
--PortSelect <= R2_Out(8);
--MemWrite <= R2_Out(7);
--SpSel <= R2_Out(6);
--CallSel <= R2_Out(5);
--MemPc <= R2_Out(4);
--MemToReg <= R2_Out(3);
--PortWrite <= R2_Out(2);
--PcWrite <= R2_Out(1);
--RegWrite <= R2_Out(0);

Forward_Unit : FU port map (R3_Out(10 downto 8), R2_Out(20 downto 18), R2_Out(23 downto 21), R4_Out(6 downto 4), R3_Out(0), R4_Out(0), ExMem_MemRead, MemWB_MemRead,ExMem_NOP, MemWB_NOP, MUX_A, MUX_B);

Input_A <= Write_data when MUX_A = "00" else R3_Out(74 downto 59) when MUX_A = "01" else R2_Out(128 downto 113);

MUX_B_3 <= R2_Out(96 downto 81) when R2_Out(13) = '0' else R2_Out(112 downto 97);
Input_B <= Write_data when MUX_B = "00" else R3_Out(74 downto 59) when MUX_B = "01" else MUX_B_3;

ALU_Control : ALU_CU Port map (R2_Out(32 downto 28), ALUCode, Control_Cin);

ALU_Cin <= (R2_Out(12) and '0') or Control_Cin;

PipeLine_ALU : ALU port map (Input_A,Input_B, R2_Out(27 downto 24), ALU_Cin, ALUCode, Result, ALU_Cout, Zero, Neg, Overflow);

RdstVal <= Result;

CCR_Reset <= RstC or RstZ or RstN;

MainCCR : entityCCR port map(Clk, CCR_Reset, R2_Out(9), R2_Out(10), R2_Out(11), ALU_Cout, Zero, Neg, Overflow, CoutTempCCR, ZeroTempCCR, NegTempCCR, OverflowTempCCR, CCR_Cout, CCR_Zero, CCR_Neg, CCR_Overflow);

TempCCR : entityTempCCR port map (Clk, R1_Out(47), CCR_Cout, CCR_Zero, CCR_Neg, CCR_Overflow, CoutTempCCR, ZeroTempCCR, NegTempCCR, OverflowTempCCR);

BM_Unit : BranchModule Port map(CCR_Cout, R2_Out(15), CCR_Zero, R2_Out(17), CCR_Neg, R2_Out(16), R2_Out(14), RstC, RstZ, RstN, PCSrc);

Result_PortVal <= Result when R2_Out(8)='0' else R2_Out(48 downto 33);
----------------------------------------------------------------------------------------------------------------------------------
--EX/Mem Reg :-
-----------------
--Ex_Mem <= PortVal(15 downto 0) & RegData2(15 downto 0) & Pc(15 downto 0) & Sp(15 downto 0) & Rdst(2 downto 0) & MemWrite & SpSel & CallSel & MemPc & MemToReg & PortWrite & PcWrite & RegWrite;
R3_Rst <= Reset or R4_Out(39);

R3: my_DFF generic map(n => 82) port map(Clk, R3_Rst, R3_En, R3_In, R3_Out);
Ex_Mem <= R2_Out(32 downto 28) & R2_Out(129) & R2_Out(130) & Result_PortVal & R2_Out(112 downto 97) & R2_Out(80 downto 65) & R2_Out(64 downto 49) & R2_Out(23 downto 21) & R2_Out(7) & R2_Out(6) & R2_Out(5) & R2_Out(4) & R2_Out(3) & R2_Out(2) & R2_Out(1) & R2_Out(0);
R3_In <= Ex_Mem;
ExMem_MemRead <= R3_Out(76);
ExMem_NOP <= '1' when  R3_Out(81 downto 77) = "00000" else '0';
----------------------------------------------------------------------------------------------------------------------------------
--4)Memory :-
--------------
--Op <= R3_Out(81 downto 77);
--MemRead <= R3_Out(76);
--RTI_Flush <= R3_Out(75);
--Result_PortVal <= R3_Out(74 downto 59);
--RegData2 <= R3_Out(58 downto 43);
--Pc <= R3_Out(42 downto 27);
--Sp <= R3_Out(26 downto 11);
--Rdst <= R3_Out(10 downto 8);
--MemWrite <= R3_Out(7);
--SpSel <= R3_Out(6);
--CallSel <= R3_Out(5);
--MemPc <= R3_Out(4);
--MemToReg <= R3_Out(3);
--PortWrite <= R3_Out(2);
--PcWrite <= R3_Out(1);
--RegWrite <= R3_Out(0);

Mem_Address <= R3_Out(74 downto 59) when R3_Out(6)='0' else R3_Out(26 downto 11);

Data_Write_In <= R3_Out(58 downto 43) when R3_Out(4)='0' else R3_Out(42 downto 27);

Data_Memory : Memory port map(Clk, R3_Out(7), Data_Write_In, ReadData, Mem_Address(9 downto 0));

----------------------------------------------------------------------------------------------------------------------------------
--Mem/WB Reg :-
-----------------
--Mem_WB <= PortVal(15 downto 0) & ReadData(15 downto 0) & Rdst(2 downto 0) & MemToReg & PortWrite & PcWrite & RegWrite;
R4_Rst <= Reset;

R4: my_DFF generic map(n => 46) port map(Clk, R4_Rst, R4_En, R4_In, R4_Out);
Mem_WB <= R3_Out(81 downto 77) & R3_Out(76) & R3_Out(75) & R3_Out(74 downto 59) & ReadData & R3_Out(10 downto 8) & R3_Out(3) & R3_Out(2) & R3_Out(1) & R3_Out(0);
R4_In <= Mem_WB;
MemWB_MemRead <= R4_Out(40);	
MemWB_NOP <= '1' when  R4_Out(45 downto 41) = "00000" else '0';
----------------------------------------------------------------------------------------------------------------------------------
--5)WriteBack :-
-----------------
--Op <= R3_Out(45 downto 41);
--MemRead <= R4_Out(40);
--RTI_Flush <= R4_Out(39);
--PortVal <= R4_Out(38 downto 23);
--ReadData <= R4_Out(22 downto 7);
--Rdst <= R4_Out(6 downto 4);
--MemToReg <= R4_Out(3);
--PortWrite <= R4_Out(2);
--PcWrite <= R4_Out(1);
--RegWrite <= R4_Out(0);

Write_Reg <= R4_out(6 downto 4);
Write_data <= R4_Out(22 downto 7) when R4_Out(3)= '0' else R4_Out(38 downto 23);
		
----------------------------------------------------------------------------------------------------------------------------------

end Architecture Pipelined_Processor;
