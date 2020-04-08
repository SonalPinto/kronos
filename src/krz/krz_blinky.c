/* 
krz_blinky.c 

blinky for KRZ

*/

#include <stdint.h>

// ============================================================
// Drivers

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

    // LEDs
    int* ledr = (int*) 0x800000;
    int* ledg = (int*) 0x800004;

    *ledr = 1;
    *ledg = 0;

    while(1) {
        delay_us(500000); // 500ms
        // delay_us(50); // 50us

        // toggle LEDs      
        *ledg ^= 1;
        *ledr ^= 1;
    }
}
