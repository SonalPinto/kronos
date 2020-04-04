# Hazard Control

Kronos has a Hazard Control Unit (HCU) at the Decode stage. It is the singular point of read-before-write detection in the entire pipeline. These hazards occur when a register is being read before it's latest value is written back from the Write Back stage (direct write, load or CSR read data). The HCU monitors the register read requirement of the current instruction being decoded, and can stall the Decode if there are writes pending to those registers.

In the Kronos pipeline, there are 2 stages ahead of the Decoder. Hence, there can be a maximum of two pending writes to any register.

The Kronos HCU design tracks the hazard on any register as a 2-bit vector shift register. The HCU shifts in a '1' to track that a write is pending, and shifts out when it is written back. This is representative of upgrading or downgrading the hazard level on that register. The LSB of this 2-b hazard vector indicates the hazard status. '1' = write pending.

This HCU design scales really well. For deeper levels of pending write-backs (downgrades), the hazard vector needs to be widened. Nonetheless, the stall conditioned only checks the LSB. When the hazard level is `0b01`, register forwarding is possible if the read and write collide. The register forwarding detection and resolution is also a critical path in the design.
