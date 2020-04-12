/* 
krz_blinky.c 

blinky for KRZ

*/

#include <stdint.h>

// ============================================================
// Drivers

#define MMPTR32(x) (*((volatile uint32_t*)(x)))
#define MMPTR16(x) (*((volatile uint16_t*)(x)))
#define MMPTR8(x)  (*((volatile uint8_t*)(x)))

// 24MHz system clock - internal oscillator
#define SYSTEM_CLK_MHZ 24

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
    delay = count_us * SYSTEM_CLK_MHZ;
    while(read_mcycle() - start < delay);
}

// ============================================================
__attribute__((naked))  __attribute__((section(".init"))) void main(void) {
    asm volatile ("\
        la gp, _global_pointer  \n\
        la sp, _stack_pointer   \n\
    ");

    // init gpio0/1 as outputs, rest as inputs
    MMPTR32(0x800108) = 0x00000003;
    // Set GPIO0 and GPIO1 as high - turns the LEDs off
    MMPTR32(0x80010C) = 0x00000003;

    uint8_t LEDR = 1;
    uint8_t LEDG = 0;

    char txt[] = "Kronos live\n";

    while(1) {
        delay_us(500000); // 500ms
        // delay_us(50); // 50us

        // Assign LEDs
        MMPTR32(0x80010C) = 0x00000000 | (LEDG << 1) | LEDR;

        // toggle LEDs
        LEDR ^= 1;
        LEDG ^= 1;

        // Transmit - 12B txt
        MMPTR32(0x800200) = *(uint32_t*)(&txt[0]);
        MMPTR32(0x800200) = *(uint32_t*)(&txt[4]);
        MMPTR32(0x800200) = *(uint32_t*)(&txt[8]);
    }
}
