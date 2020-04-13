# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0


add_hdl_source(fifo.sv)
add_hdl_source(uart_tx.sv)
add_hdl_source(spi_master.sv)

add_hdl_source(wb_uart_tx.sv
    DEPENDS
        fifo
        uart_tx
)

add_hdl_source(wb_spi_master.sv
    DEPENDS
        fifo
        spi_master
)


add_hdl_source(spiflash.sv
    SYNTHESIS FALSE
    LINT FALSE
)
