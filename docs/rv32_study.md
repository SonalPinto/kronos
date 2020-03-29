# RV32I Base Integer ISA Study

I've summarized my study of the ISA and its influences on the architecture of Kronos in this section. This section is **not** a reiteration of the spec. For a detailed overview of the spec, I recommended heading [here](https://riscv.org/specifications/). Aside from the spec, [The RISC-V Reader](http://riscvbook.com/) has been pretty handy for quick references.


## RV32I

#### Opcode

The lowest 7b of the RV32I instruction form the opcode. The two lowest bits are always `11`, and if not, the instruction should be considered illegal.


#### LUI

Load-Upper Immediate. We store the **Type-I** immediate from the instruction into the register indexed by `rd` (also from the instruction). 

> Well, "store" is an abstract concept here. What really needs to happen is that the Type-I immediate needs to get handed off to the Write Back stage  which is responsible for writing data in to the registers. In general, in pipelined architectures, though memory elements (registers) can have multiple readers, limiting the write access to a single owner can be an easy solution to avoid hazards. In Kronos, while it may seem trivial to write back the readily available immediate into the destination register, it would be chaos. There are two stages (and thus two instructions) ahead of the decode stage that are yet to be committed.


#### AUIPC

Add Upper Immediate to PC. `REG[rd] = PC + Imm`.

Need to add the PC and the **Type-U** immediate into `REG[rd]`. I finally need an adder, and let's say the lay the foundation of my ALU with a 32B adder. The two operands will be the `PC` and the immediate, and the result of the operation will be written back by the last stage.


#### OP-IMM

Integer Register-Immediate instructions (using **Type-I** immediate):

- ADDI: `REG[rd] = REG[rs1] + Imm`, aluop: add
- SLTI: `REG[rd] = (REG[rs1] < Imm) ? 1 : 0`, aluop: set if less than
- SLTIU: `REG[rd] = (REG[rs1] <u Imm) ? 1 : 0`, aluop: set if unsigned less than
- XORI: `REG[rd] = REG[rs1] ^ Imm`, aluop: logical XOR
- ORI: `REG[rd] = REG[rs1] | Imm`, aluop: logical OR
- ANDI: `REG[rd] = REG[rs1] & Imm`, aluop: logical AND
- SLLI: `REG[rd] = REG[rs1] << Imm[4:0]`, aluop: shift left
- SRLI: `REG[rd] = REG[rs1] >> Imm[4:0]`, aluop: shift right
- SRAI: `REG[rd] = REG[rs1] >>> Imm[4:0]`, aluop, arithmetic shift right 

Where aluop is the operation that needs to be performed the ALU over the two operands. Clearly the ALU needs to be upgraded from a simple adder, to be able to perform the above noted operations. For the shift operations, only the lower 5b of the immediate is used. The ALU operation can swiftly be decoded using the `funct3` field of the instruction.


#### OP

Integer Register-Register instructions:

- ADD: `REG[rd] = REG[rs1] + REG[rs2]`, aluop: add
- SUB: `REG[rd] = REG[rs1] - REG[rs2]`, aluop: subtract
- SLL: `REG[rd] = REG[rs1] >> REG[rs2][4:0]`, aluop: shift left
- SLT: `REG[rd] = (REG[rs1] < REG[rs2]) ? 1 : 0`, aluop: set if less than
- SLTU: `REG[rd] = (REG[rs1] <u REG[rs2])? 1 : 0`, aluop: set if unsigned less than
- XOR: `REG[rd] = REG[rs1] ^ REG[rs2]`, aluop: logical XOR
- SRL: `REG[rd] = REG[rs1] >> REG[rs2][4:0]`, aluop: shift right
- SRA: `REG[rd] = REG[rs1] >>> REG[rs2][4:0]`, aluop: arithmetic shift right
- OR: `REG[rd] = REG[rs1] | REG[rs2]`, aluop: logical OR
- AND: `REG[rd] = REG[rs1] & REG[rs2]`, aluop: logical AND

For these instructions, both operands are sourced from the integer registers, else the execution sequence is the same as the `OP-IMM` instructions. Interesting thing to note that a `SUB` instruction is present here because the authors of the spec decided that they could use the `ADDI` to subtract an immediate from a register since the **Type-I** immediate is signed (in fact, all RV32I immediates are signed).


#### JAL

Jump and Link. `REG[rd] = PC + 4` and unconditional jump to a new address, `PC = PC + Imm` by adding a **Type-J** immediate to `PC`. So far, we have gotten away with a single track ALU, i.e. calculating a single result. This instruction needs to calculate the link data for the destination integer register _and_ the jump address for the Fetch stage. So we need at least two tracks at the Execute stage, with the second track being at least a 32b adder. The primary track needs to be feature rich enough to execute the OP and OP-IMM instructions.


#### JALR

Jump and Link Register. `REG[rd] = PC + 4` and unconditional jump to a new 2B-aligned address, `PC = (REG[rs1] + Imm) & ~1` by adding register operand, `REG[rs1]` to a **Type-I** immediate. We need to use both tracks of the ALU, and the second track needs to blank the LSB of the result. Note, that this instruction needs **three** operands; the `PC`, register operand `REG[rs1]` and the **Type-I** immediate.


#### BRANCH

Conditional Branch instructions. Jump to `PC = PC + Imm` (**Type-B** immediate) if conditional check using two register operands is true.

- BEQ: jump if `condition = REG[rs1] == REG[rs2]`, aluop: equal
- BNE: jump if `condition = REG[rs1] != REG[rs2]`, aluop: not equal
- BLT: jump if `condition = REG[rs1] < REG[rs2]`, aluop: signed less than
- BGE: jump if `condition = REG[rs1] >= REG[rs2]`, aluop: signed greater than or equal
- BLTU: jump if `condition = REG[rs1] <u REG[rs2]`, aluop: unsigned less than
- BGEU: jump if `condition = REG[rs1] >=u REG[rs2]`, aluop: unsigned greater than or equal

This class of instructions need **FOUR** operands! The jump address calculation needs the `PC` and the immediate, while the condition evaluation needs the two register operands, `REG[rs1]` and `REG[rs2]`. The primary track takes the task of evaluation the condition, and the secondary track generates the branch target.


#### LOAD

Load data from memory into register. Read the data memory at a specific address and write the read data to the destination register. The read data size is specified in the instruction and can be either a byte (8b), halfword (16b) or word (32b) access. Non-word boundary access is considered a misaligned access, but that's a discussion for subsequent sections. The load instructions are described below:

- LB: `REG[rd] = sext( MEM[ REG[rs1] + Imm ][7:0] )`, load a sign-extended byte
- LBU: `REG[rd] = zext( MEM[ REG[rs1] + Imm ][7:0] )`, load a zero-extended byte
- LH: `REG[rd] = sext( MEM[ REG[rs1] + Imm ][15:0] )`, load a sign-extended halfword
- LHU: `REG[rd] = zext( MEM[ REG[rs1] + Imm ][15:0] )`, load a zero-extended halfword
- LW: `REG[rd] = sext( MEM[ REG[rs1] + Imm ][31:0] )`, load a word

The data memory read address is calculated using a register operand, `REG[rs1]` and a signed offset (**Type-I** immediate). The primary track of the ALU can care of this.


#### STORE

Store register data into memory. The instruction defines the size of the data that needs to be written into data memory, and is one of byte, halfword or word. The store instructions are described below.

- SB: `MEM[ REG[rs1] + Imm ][7:0] = REG[rs2][7:0]`, store a byte
- SH: `MEM[ REG[rs1] + Imm ][15:0] = REG[rs2][15:0]`, store a halfword
- SW: `MEM[ REG[rs1] + Imm ][31:0] = REG[rs2][31:0]`, store a word

The data memory write address is generated by adding a **Type-S** immediate to `REG[rs1]`. And, we also need to pass along the write data, `REG[rs2]` using the secondary track.


#### MISC

EBREAK and ECALL are calls to the environment by raising the Breakpoint and Environment Call exception respectively. FENCE instruction is an operation that ensures pending memory and IO tasks have concluded before the next instruction. These are decoded as one-off control signals that are to be handled by the Write Back stage and don't need any work done in the ALU.

The above 40 instructions for the RV32I Base Integer ISA. The Kronos core implements the above and the following two extensions to enable a practical implementation.


## Zicsr Extension

The Kronos core fully implements the `Zicsr` extension which has instructions for atomic Read/Modify/Write of CSR. Each of these instructions require first, reading current value of `REG[csr]` onto `rd` (if `rd != 0`), followed by these specific modify+write. For the immediate instructions, **zimm** (zero extended 5b immediate) is used. For CSRRS and CSRRC, if the source register `rs1` is 0 (`x0`), then the write will not be attempted.

- CSRRW: `REG[csr] = REG[rs1]`, write
- CSRRS: `REG[csr] = REG[csr] | REG[rs1]`, set
- CSRRC: `REG[csr] = REG[csr] & ~REG[rs1]`, clear
- CSRRWI: `REG[csr] = zimm`, write-immediate
- CSRRSI: `REG[csr] = REG[csr] | zimm`, set-immediate
- CSRRCI: `REG[csr] = REG[csr] &~ zimm`, clear-immediate


## Zifenci Extension

The FENCE.I instruction demands that all accesses to the instruction memory have concluded before executing the next instruction. This is trivially implemented in Kronos as a `j f1` (jump to `PC+4`) as this will flush the pipeline and ensure a fresh fetch of instructions from the memory.
