/* 
krz_bootloader.c

Simple bootloader that copies over an application from the SPI Flash
and jumps to it.

If the BOOTVEC is set, then the application is loaded from there

*/

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

// Max program size is 128KB
#define MAX_PROG_SIZE       128*1024

// Main memory start
#define RAM_BASE_ADDR       0x00010000


// ENTRY
__attribute__((naked)) void _start(void) {
    asm volatile ("\
        la gp, _global_pointer  \n\
        la sp, _stack_pointer   \n\
        j main                  \n\
        nop                     \n\
        nop                     \n\
        nop                     \n\
        nop                     \n\
        nop                     \n\
        nop                     \n\
        nop                     \n\
        nop                     \n\
    ");
}

// EXIT
__attribute__((naked)) void _exec(void) {
    asm volatile ("\
        la gp, _global_pointer  \n\
        la sp, _stack_pointer   \n\
        j %0                    \n\
        nop                     \n\
        nop                     \n\
        nop                     \n\
        nop                     \n\
        nop                     \n\
        nop                     \n\
        nop                     \n\
        nop                     \n\
    "
    :: "i"(RAM_BASE_ADDR)
    );
}


// ============================================================
// KRZ Memory Map

#define MMPTR32(x) (*((volatile uint32_t*)(x)))
#define MMPTR16(x) (*((volatile uint16_t*)(x)))
#define MMPTR8(x)  (*((volatile uint8_t*)(x)))

#define KRZ_GPREG           0x800000
#define KRZ_UART            0x800100
#define KRZ_SPIM            0x800200

#define KRZ_SCRATCH         MMPTR32(KRZ_GPREG | (0<<2))
#define KRZ_BOOTVEC         MMPTR32(KRZ_GPREG | (1<<2))
#define KRZ_GPIO_DIR        MMPTR32(KRZ_GPREG | (2<<2))
#define KRZ_GPIO_WRITE      MMPTR32(KRZ_GPREG | (3<<2))
#define KRZ_GPIO_READ       MMPTR32(KRZ_GPREG | (4<<2))
#define KRZ_UART_CTRL       MMPTR32(KRZ_GPREG | (5<<2))
#define KRZ_UART_STATUS     MMPTR32(KRZ_GPREG | (6<<2))
#define KRZ_SPIM_CTRL       MMPTR32(KRZ_GPREG | (7<<2))
#define KRZ_SPIM_STATUS     MMPTR32(KRZ_GPREG | (8<<2))

#define GPIO_FLASH_CS       2


// ============================================================
// Drivers

void spim_transfer(uint8_t* tx, uint8_t* rx, uint8_t len, bool start, bool stop) {
    uint32_t qsize;

    uint32_t gpio = KRZ_GPIO_WRITE;
    uint32_t ctrl = KRZ_SPIM_CTRL;

    // FLASH_CS = 0
    if (start) {
        KRZ_GPIO_WRITE = gpio & ~(1<<GPIO_FLASH_CS);
    }

    // --------------------------------------------------------
    // Write bytes to SPIM.TXQ
    uint8_t *p = tx;
    for (uint8_t i=0; i<len; i++) {
        MMPTR8(KRZ_SPIM) = *p;
        p++;
    }

    // Wait to transaction to be done by tracking RXQ size
    while (1) {
        qsize = (KRZ_SPIM_STATUS & 0xff00) >> 8;
        if (qsize == len) break;
    }

    // FLASH_CS = 1
    if (stop) {
        KRZ_GPIO_WRITE = gpio | (1<<GPIO_FLASH_CS);
    }

    // --------------------------------------------------------
    // Read from SPIM.RXQ
    p = rx;
    for (uint8_t i=0; i<len; i++) {
        *p = MMPTR8(KRZ_SPIM);
        p++;
    }

    // Clear TX/RX Queue
    KRZ_SPIM_CTRL = ctrl | (0x3 << 10);
}

void flashboot(uint32_t boot_addr) {
    uint8_t tx[128], rx[128];
    uint32_t prog_size;
    uint32_t bytes_left, block_size;
    uint8_t *p;

    memset(&tx, 0x00, 128);
    memset(&rx, 0x00, 128);

    // Set SPI prescaler to max = 12MHz and SPI-Mode-0
    KRZ_SPIM_CTRL = 0;

    // Wake up the SPI Flash
    tx[0] = 0xAB;
    spim_transfer(tx, rx, 1, true, true);

    // Read program size at given boot_addr, keep transaction open
    tx[0] = 0x03;
    tx[1] = (boot_addr>>16) & 0xff; 
    tx[2] = (boot_addr>>8) & 0xff;
    tx[3] = boot_addr & 0xff;
    spim_transfer(tx, rx, 8, true, false);

    prog_size = *(uint32_t*)(&rx[4]);

    // Check if program size is valid
    if (prog_size > MAX_PROG_SIZE || prog_size == 0 || prog_size & 0x3) {
        // complete transaction
        KRZ_GPIO_WRITE = KRZ_GPIO_WRITE | (1<<GPIO_FLASH_CS);
        // Power down the flash
        tx[0] = 0xB9;
        spim_transfer(tx, rx, 1, true, true);
        while(1);
    }

    // initialize
    bytes_left = prog_size;
    memset(&tx, 0x00, 128);
    p = (uint8_t*)(RAM_BASE_ADDR);

    while (bytes_left > 0) {

        // Read blocks of 128B from the flash
        if (bytes_left > 128) block_size = 128;
        else block_size = bytes_left;

        spim_transfer(tx, rx, block_size, false, false);

        // Write them to the SRAM
        memcpy(p, rx, block_size);

        p += block_size;
        bytes_left -= block_size;
    }

    // complete transaction
    KRZ_GPIO_WRITE = KRZ_GPIO_WRITE | (1<<GPIO_FLASH_CS);
    // Power down the flash
    tx[0] = 0xB9;
    spim_transfer(tx, rx, 1, true, true);
}


// ============================================================
void main(void) {
    // init GPIO2 (FLASH CS) as output and set it
    KRZ_GPIO_DIR = 0x00000004;
    KRZ_GPIO_WRITE = 0x00000004;

    // Read Boot vector
    uint32_t boot_addr = KRZ_BOOTVEC;

    // Copy program from Flash to RAM
    flashboot(boot_addr);

    // Jump to program
    _exec();

    while(1);
}
