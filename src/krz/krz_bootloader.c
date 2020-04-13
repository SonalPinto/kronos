/* 
krz_bootloader.c

Simple bootloader that copies over an application from the SPI Flash
and jumps to it.

If the BOOTVEC is set, then the application is loaded from there

*/

#include <stdint.h>
#include <stdio.h>
#include <string.h>

// ENTRY
__attribute__((naked))  __attribute__((section(".init"))) void _start(void) {
    asm volatile ("\
        la gp, _global_pointer  \n\
        la sp, _stack_pointer   \n\
        j main                  \n\
    ");
}

// EXIT
__attribute__((naked))  __attribute__((section(".init"))) void _exec(void) {
    asm volatile ("\
        la gp, _global_pointer  \n\
        la sp, _stack_pointer   \n\
        j 0x00010000\n\
    ");
}


// Max program size is 128KB
#define MAX_PROG_SIZE       128*1024

// ============================================================
// KRZ Memory Map

#define MMPTR32(x) (*((volatile uint32_t*)(x)))
#define MMPTR16(x) (*((volatile uint16_t*)(x)))
#define MMPTR8(x)  (*((volatile uint8_t*)(x)))

#define KRZ_GPREG           0x800100
#define KRZ_UART            0x800200
#define KRZ_SPIM            0x800400

#define KRZ_SCRATCH         MMPTR32(KRZ_GPREG | (0<<2))
#define KRZ_BOOTVEC         MMPTR32(KRZ_GPREG | (1<<2))
#define KRZ_GPIO_DIR        MMPTR32(KRZ_GPREG | (2<<2))
#define KRZ_GPIO_WRITE      MMPTR32(KRZ_GPREG | (3<<2))
#define KRZ_GPIO_READ       MMPTR32(KRZ_GPREG | (4<<2))
#define KRZ_UART_CTRL       MMPTR32(KRZ_GPREG | (5<<2))
#define KRZ_UART_STATUS     MMPTR32(KRZ_GPREG | (6<<2))
#define KRZ_SPIM_CTRL       MMPTR32(KRZ_GPREG | (7<<2))
#define KRZ_SPIM_STATUS     MMPTR32(KRZ_GPREG | (8<<2))

#define GPIO_LEDR           0
#define GPIO_LEDG           1
#define GPIO_FLASH_CS       2

// ============================================================
// Drivers

// 24MHz system clock - internal oscillator
#define F_CPU 24000000

static inline uint32_t read_mcycle(void) {
    uint32_t tmp;
    asm volatile(
        "csrr %0, mcycle \n"
        : "=r" (tmp)
    );
    return tmp;
}

void delay_us(uint32_t count_us) {
    uint32_t start, delay;
    start = read_mcycle();
    delay = count_us * (F_CPU / 1000000);
    while(read_mcycle() - start < delay);
}

void hexstring(uint32_t in, char* out){
    // Convert 32b unsigned int to 8 character hex
    uint32_t x, y;
    char lut[] = "0123456789ABCDEF";

    x = in;
    for (int i=7; i>=0; i--) {
        y = x & 0xf;
        x = x >> 4;
        out[i] = lut[y];
    }

    out[8] = '\0';
}

void printk(char* txt) {
    /*
        Simple printk for the bootloader.
    */

    uint8_t len = strlen(txt);
    uint32_t qsize, free_space;

    // Wait until there's space in the UART TX Queue
    while (1) {
        qsize = KRZ_UART_STATUS & 0xffff;
        free_space = 64 - qsize;

        if (free_space > len) break;
        else delay_us(50);
    }

    uint8_t remaining = len & 0x03;
    uint8_t words = len >> 2;

    char *p = txt;

    // Send out as many 32b transfers as possible
    for (uint8_t i=0; i<words; i++) {
        MMPTR32(KRZ_UART) = *(uint32_t*)(p);
        p += 4;
    }

    // Send over the remaining bytes
    // 1 - uint8_t 
    // 2 - uint16_t
    // 3 - uint16_t + uint8_t
    if (remaining & 0x02) {
        MMPTR16(KRZ_UART) = *(uint16_t*)(p);
        p += 2;
    }

    if (remaining & 0x01) {
        MMPTR8(KRZ_UART) = *(uint8_t*)(p);
    }
}

void spim_transfer(char* tx, char* rx, uint8_t len) {
    uint32_t qsize;
    uint8_t remaining = len & 0x03;
    uint8_t words = len >> 2;

    uint32_t gpio = KRZ_GPIO_WRITE;
    uint32_t ctrl = KRZ_SPIM_CTRL;

    // FLASH_CS = 0
    KRZ_GPIO_WRITE = gpio & ~(1<<GPIO_FLASH_CS);

    // --------------------------------------------------------
    // Write bytes to TX as efficiently as words
    char *p = tx;
    for (uint8_t i=0; i<words; i++) {
        MMPTR32(KRZ_SPIM) = *(uint32_t*)(p);
        p += 4;
    }

    // Send over the remaining bytes
    if (remaining & 0x02) {
        MMPTR16(KRZ_SPIM) = *(uint16_t*)(p);
        p += 2;
    }

    if (remaining & 0x01) {
        MMPTR8(KRZ_SPIM) = *(uint8_t*)(p);
    }

    // Wait to transaction to be done
    while (1) {
        qsize = KRZ_SPIM_STATUS & 0xffff;
        if (qsize == 0) break;
    }
    // FIXME - plumb busy status form peripherals - cant just look at queues
    delay_us(1);

    // FLASH_CS = 1
    KRZ_GPIO_WRITE = gpio | (1<<GPIO_FLASH_CS);

    // --------------------------------------------------------
    // Read from received bytes, in words
    p = rx;
    for (uint8_t i=0; i<len; i++) {
        *(uint8_t*)(p) = MMPTR8(KRZ_SPIM);
        p++;
    }

    // Clear TX/RX Queue
    KRZ_SPIM_CTRL = ctrl | (0x3 << 18);
}

void flashboot(uint32_t boot_addr) {
    char txt[32], ptxt[32]; 
    uint8_t tx[64], rx[64];
    uint32_t prog_size, addr;
    uint32_t bytes_left, work_size;
    uint32_t words, data;
    char *p;

    memset(&tx, 0x00, 64);
    memset(&rx, 0x00, 64);

    // Set SPI prescaler to max = 12MHz and SPI-Mode-0
    KRZ_SPIM_CTRL = 0;

    // Wake up the SPI Flash
    tx[0] = 0xAB;
    spim_transfer(tx, rx, 1);

    // Read program size at given boot_addr
    tx[0] = 0x03;
    tx[1] = (boot_addr>>16) & 0xff; 
    tx[2] = (boot_addr>>8) & 0xff;
    tx[3] = boot_addr & 0xff;
    spim_transfer(tx, rx, 8);

    prog_size = *(uint32_t*)(&rx[4]);

    strcpy(txt, "Program size = 0x");
    hexstring(prog_size, ptxt);
    strcat(txt, ptxt);
    strcat(txt, "B\n");
    printk(txt);

    // Check if program size is valid
    if (prog_size > MAX_PROG_SIZE || prog_size == 0 || prog_size & 0x3) {
        strcpy(txt, "ERROR");
        printk(txt);
        while(1);
    }

    // Copy program from Flash to RAM
    bytes_left = prog_size;
    addr = boot_addr + 4;

    while (bytes_left > 0) {

        if (bytes_left > 60) work_size = 60;
        else work_size = bytes_left;

        memset(&tx, 0x00, 64);

        tx[0] = 0x03;
        tx[1] = (addr>>16) & 0xff; 
        tx[2] = (addr>>8) & 0xff;
        tx[3] = addr & 0xff;

        spim_transfer(tx, rx, work_size+4);

        words = work_size >> 2;
        p = &rx[4];
        for(uint8_t i=0; i<words; i++) {
            data = *(uint32_t*)(p);

            hexstring(addr, txt);
            hexstring(data, ptxt);
            strcat(txt, ": 0x");
            strcat(txt, ptxt);
            strcat(txt, "\n");
            printk(txt);

            p += 4;
        }

        bytes_left -= work_size;
        addr += work_size;
    }
}


// ============================================================
void main(void) {
    // init GPIO0/1/2 as outputs, rest as inputs.
    // Set value = 1, as  this turns the LEDs off and deselects the SPI Flash
    KRZ_GPIO_DIR = 0x00000007;
    KRZ_GPIO_WRITE = 0x00000007;

    char txt[32], ptxt[32];

    // Inform Host
    strcpy(txt, "Kronos!\n");
    printk(txt);

    // Read Boot vector
    uint32_t boot_addr = KRZ_BOOTVEC;

    strcpy(txt, "\n\nBooting from ");
    hexstring(boot_addr, ptxt);
    strcat(txt, ptxt);
    strcat(txt, "\n");
    printk(txt);

    flashboot(boot_addr);

    while(1);
}
