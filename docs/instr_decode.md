# Instruction Decode

The Instruction Decode stage translates the RISC-V instruction fetched by the previous stage into operands and controls that can be acted upon in the subsequent stages. The default decode for operands is `PC` for OP1 and OP3, and the constant 4 for OP2 and OP4. the default ALU operation is ADD for both the tracks. Only deviations from the default are noted below.

Instr  | OP1     | OP2     | OP3     | OP4     | ALUOP1  | ALUOP2   | Write Back
-------|---------|---------|---------|---------|---------|----------| ----------
Default| PC      | 4       | PC      | 4       | ADD     | ADD      | none
LUI    | 0       | Imm-U   |         |         |         |          | REG[rd] = res1
AUIPC  |         | Imm-U   |         |         |         |          | REG[rd] = res1
JAL    |         |         |         | Imm-J   |         |          | REG[rd] = res1, branch = res2
JALR   |         |         | REG[rs1]| Imm-I   |         |ADD_ALIGN | REG[rd] = res1, branch = res2
BR     | REG[rs1]| REG[rs2]|         | Imm-B   | COMP    |          | cond = res1, branch_cond = res2
LOAD   | REG[rs1]| Imm-I   |         | Imm-B   |         |          | REG[rd] = MEM[res1]
STORE  | REG[rs1]| Imm-S   | 0       | REG[rs2]|         |          | MEM[res1] = res2
OP     | REG[rs1]| REG[rs2]|         |         | ALUOP   |          | REG[rd] = res1
OPIMM  | REG[rs1]| Imm-I   |         |         | ALUOP   |          | REG[rd] = res1
SYS    | 0       | IR      | Zimm/REG[rs1] | 0 | |                  | REG[rd] = REG[csr], REG[csr] = f(res2), res1 = IR

The ALU ops are extracted from the `fucnt3` and `funct7`. Same goes for System CSR operations. Those IR segments also contain the load/store data sizes and whether the load data should be sign-extended or not. One off decodes for FENCE, FENCE.I, ECALL, EBREAK, MRET and WFI are treated as special signals.

> Implementing the 32 integer registers using LUTs is a non-starter. That's 1024 bits. The iCE40UP5K has 16b wide Dual-Port Embedded Block RAM (EBR). The EBR is a synchronous module and the access is clocked, with one read port. I could either spend 2 cycles reading the EBR for the two operands, or keep a shadow of the registers in another EBR (pseudo dual-port read). I chose the latter for Kronos on the iCE40UP5K, which inefficiently takes up four EBR. I also need to read two registers on the off-edge to have it ready by the next active edge, for a single cycle decode.
