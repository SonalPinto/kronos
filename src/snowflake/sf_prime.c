// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/* prime.c */

#include <stdint.h>
#include <stdbool.h>

// ============================================================
// Drivers

// 24MHz system clock - internal oscillator
#define SYSTEM_CLK_MHZ 24

// LEDs
int *ledr   =  (int*) 0x1000;
int *ledg   =  (int*) 0x1004;

// Seven segment display
int *ssd_en =  (int*) 0x1008;
int *ssd_a  =  (int*) 0x100C;
int *ssd_b  =  (int*) 0x1010;

// Seven segment display charatcter map
#define SSD_BLANK   (uint32_t) 0b1111111
#define SSD_0       (uint32_t) 0b1000000
#define SSD_1       (uint32_t) 0b1111001
#define SSD_2       (uint32_t) 0b0100100
#define SSD_3       (uint32_t) 0b0110000
#define SSD_4       (uint32_t) 0b0011001
#define SSD_5       (uint32_t) 0b0010010
#define SSD_6       (uint32_t) 0b0000010
#define SSD_7       (uint32_t) 0b1111000
#define SSD_8       (uint32_t) 0b0000000
#define SSD_9       (uint32_t) 0b0010000
#define SSD_A       (uint32_t) 0b0001000
#define SSD_B       (uint32_t) 0b0000011
#define SSD_C       (uint32_t) 0b1000110
#define SSD_D       (uint32_t) 0b0100001
#define SSD_E       (uint32_t) 0b0000110
#define SSD_F       (uint32_t) 0b0001110

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

void ssd_draw_character(int* ssd_char, uint8_t value){
    switch (value){
        case 0: *ssd_char = SSD_0; break;
        case 1: *ssd_char = SSD_1; break;
        case 2: *ssd_char = SSD_2; break;
        case 3: *ssd_char = SSD_3; break;
        case 4: *ssd_char = SSD_4; break;
        case 5: *ssd_char = SSD_5; break;
        case 6: *ssd_char = SSD_6; break;
        case 7: *ssd_char = SSD_7; break;
        case 8: *ssd_char = SSD_8; break;
        case 9: *ssd_char = SSD_9; break;
    }
}

void ssd_draw (uint8_t n) {
    uint8_t ones = n%10;
    uint8_t tens = n/10;

    ssd_draw_character(ssd_a, ones);
    ssd_draw_character(ssd_b, tens);
}

// ============================================================
bool is_prime(uint8_t n) {
    // ref: https://en.wikipedia.org/wiki/Primality_test

    if (n <= 3) {
        return (n > 1);
    } else if ((n&1) == 0 || n%3 == 0) {
        return false;
    }

    uint8_t i = 5;
    while (i*i <= n) {
        if (n%i == 0 || n%(i+2) == 0) {
            return false;
        }
        i = i + 6;
    }

    return true;
}

void main() {
    uint8_t count;

    // Init LEDs
    *ledr = 1;
    *ledg = 0;

    // Init SSD
    *ssd_a = SSD_BLANK;
    *ssd_b = SSD_BLANK;
    *ssd_en = 0;
    *ssd_en = 1;

    count = 0;

    while(1) {
        delay_us(500000); // 500ms
        // delay_us(10);

        // toggle LEDs      
        *ledg ^= 1;
        *ledr ^= 1;

        // Find next prime number
        while(!is_prime(count)){
            if (count == 99) count = 0;
            else count++;
        }

        // Draw prime number on SSD
        ssd_draw(count);
        count++;
    }
}
