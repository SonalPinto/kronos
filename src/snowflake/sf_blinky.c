/* blinky.c */

#include <stdint.h>

// ============================================================
// Drivers

// 24MHz system clock - internal oscillator
#define SYSTEM_CLK_MHZ 24

// LEDs
volatile int *ledr =  (volatile int*) 0x1000;
volatile int *ledg =  (volatile int*) 0x1004;

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
void main() {
    *ledr = 1;
    *ledg = 0;

    while(1) {
        delay_us(500000); // 500ms

        // toggle LEDs      
        *ledg ^= 1;
        *ledr ^= 1;
    }
}
