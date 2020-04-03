# Instruction Fetch

The Fetch stage is the feed belt to the processor. The stage needs to fetch instructions as fast as possible because the feed rate will critically decide the performance of the core. The Kronos core is designed to target a single-cycle execution rate, and the thus, the Fetch stage needs to be able to read an instruction from the memory at th same rate.

The Fetch stage is designed with a wishbone master interface. The `instr_addr` (ADR_O) and `instr_req` (STB_O) are presented on the active edge, and the `instr_ack` (ACK_I) is expected from the memory or arbiter. Each cycle that the `instr_req` is high is to be considered a complete bus cycle (STB_O == CYC_O). An ideal interaction is shown below.

![sram read](_images/sram_read.svg)

The iCE40UP5K has 128KB of single port synchronous SRAM. In order to achieve high throughput with clocked SRAM, where the control and address is clocked and the read data is registered, the memory (and arbitration) needs to be clocked at the off-edge.

![sram read](_images/sram_read_delay.svg)

The control logic of the Fetch Stage is boiled down to a simple 2-state FSM. The `instr_addr` is the `PC` under ideal circumstances. And, the `PC` is updated during the FETCH state, regardless of result of the current instruction fetch. Normally, in case of the **miss** (`ack` doesn't appear right after a `req`), delayed ack, arbitration loss or pipeline stall, the `instr_addr` needs to revert to the previous value of `PC` seamlessly. This is the STALL state. In this design, A shadow of the `PC`, called `PC_LAST` is maintained. Upon stalling or missing, the `instr_addr` is driven by `PC_LAST`.

![sram read](_images/kronos_fetch.svg)

When you clock the `instr_ack` on the off-edge, the critical path is now on the half-cycle path from the memory's read data (`instr_data`) and the `instr_ack`. The Fetch stage is design to have minimal logic on these paths, and thus, the Program Counter (`PC`) update (a 32-bit addition) does not depend on `instr_ack`. Similarly, there is minimal logic on the `instr_req` (registered) and `instr_addr` (1 mux between `PC` and `PC_LAST`) paths.

When the core issues a branch, the `PC` is updated to the branch target, and a fresh FETCH is attempted.
