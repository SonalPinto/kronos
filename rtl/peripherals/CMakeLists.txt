# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0


add_hdl_source(fifo.sv)

add_hdl_source(uart_tx.sv
    DEPENDS
        fifo
)
