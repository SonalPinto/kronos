/* 
krz_blinky.c 

blinky for KRZ

*/

#include <stdint.h>
#include <string.h>
#include "mini-printf.h"

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

// ============================================================
// KRZ Memory Map

#define MMPTR32(x) (*((volatile uint32_t*)(x)))
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

#define LEDR        0
#define LEDG        1
#define FLASH_CS    2
#define OLED_CS     3

#define LED2        4
#define LED3        5
#define LED5        6
#define BTN2        7
#define LED1        8
#define LED4        9
#define BTN1        10
#define BTN3        11

// ============================================================
// Drivers

// 24MHz system clock - internal oscillator
#define F_CPU 24000000

// UART TX Buffer
#define UART_BUFFER_SIZE    64
static uint8_t uart_buffer[UART_BUFFER_SIZE];

static inline uint32_t read_mcycle(void) {
    uint32_t tmp;
    asm volatile(
        "csrr %0, mcycle \n"
        : "=r" (tmp)
    );
    return tmp;
}

static void delay_us(uint32_t count_us) {
    uint32_t start, delay;
    start = read_mcycle();
    delay = count_us * (F_CPU / 1000000);
    while(read_mcycle() - start < delay);
}

void printk(const char *fmt, ...) {
    int len;
    uint32_t qsize, free_space;

    // Format using mini-printf
    va_list va;
    va_start(va, fmt);
    len = mini_vsnprintf(uart_buffer, UART_BUFFER_SIZE, fmt, va);
    va_end(va);

    // Wait until there's space in the UART TX Queue
    while (1) {
        qsize = KRZ_UART_STATUS;
        free_space = 128 - (qsize & 0x00ff);

        if (free_space > len) break;
        else delay_us(50);
    }

    // transmit over UART
    char *p = uart_buffer;
    for (uint8_t i=0; i<len; i++) {
        MMPTR8(KRZ_UART) = *p;
        p++;
    }
}

void print_banner(void){
    printk("\n\n");
    printk(" ____  __.                                  \n");
    printk("|    |/ _|______  ____   ____   ____  ______\n");
    printk("|      < \\_  __ \\/  _ \\ /    \\ /  _ \\/  ___/\n");
    printk("|    |  \\ |  | \\(  <_> )   |  (  <_> )___ \\ \n");
    printk("|____|__ \\|__|   \\____/|___|  /\\____/____  >\n");
    printk("        \\/                  \\/           \\/ \n\n");
}

void gpio_write(uint8_t pin, uint8_t value) {
    if (value == 0) {
        KRZ_GPIO_WRITE &= ~(1 << pin);
    } else {
        KRZ_GPIO_WRITE |= (1 << pin);
    }
}

uint8_t gpio_read(uint8_t pin) {
    return ((KRZ_GPIO_READ >> pin) & 0x1);
}


// ============================================================
void main (void) {
    // Init GPIO
    KRZ_GPIO_DIR = (1<<LEDR)
                | (1<<LEDG)
                | (1<<FLASH_CS) 
                | (1<<OLED_CS) 
                | (1<<LED1)
                | (1<<LED2)
                | (1<<LED3)
                | (1<<LED4)
                | (1<<LED5);

    // Set outputs
    //  - turns the LEDs
    //  - deselects flash chips
    KRZ_GPIO_WRITE = (1<<LEDR)
                | (1<<LEDG)
                | (1<<FLASH_CS) 
                | (1<<OLED_CS) 
                | (0<<LED1)
                | (0<<LED2)
                | (0<<LED3)
                | (0<<LED4)
                | (0<<LED5);


    memset(uart_buffer, 0x00, UART_BUFFER_SIZE);

    uint8_t ledr;
    uint8_t ledg;
    uint8_t b1, b2, b3;
    uint32_t ticks;

    // print banner
    print_banner();

    ticks = 0;
    ledg = 0;
    ledr = 1;
    while(1) {
        // read buttons, and set pmod LEDs, every 1ms
        b1 = gpio_read(BTN1);
        b2 = gpio_read(BTN2);
        b3 = gpio_read(BTN3);

        gpio_write(LED4, b1);
        gpio_write(LED1, b2);
        gpio_write(LED5, b3);

        delay_us(1000);
        ticks++;

        // then, every 200ms, print buttons and toggle LEDS
        if (ticks == 200) {
            // toggle LEDs
            ledr ^= 1;
            ledg ^= 1;

            gpio_write(LEDR, ledr);
            gpio_write(LEDG, ledg);

            printk("BTN[%u][%u][%u]\n", b1, b2, b3);

            // reset ticks
            ticks = 0;
        }
    }
}
