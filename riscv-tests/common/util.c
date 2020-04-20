// See LICENSE for license details.

#include <stdint.h>
#include <string.h>
#include "mini-printf.h"
#include "util.h"

// ============================================================
// KRZ System

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

// 24MHz system clock - internal oscillator
#define F_CPU               24000000

// UART TX Queue
#define UART_TXQ_SIZE       128

// UART TX Buffer
#define UART_BUFFER_SIZE    64
static uint8_t uart_buffer[UART_BUFFER_SIZE];

// ------------------------------------------------------------

#define NUM_COUNTERS 2

static int counters[NUM_COUNTERS];
static char* counter_names[NUM_COUNTERS];

// ------------------------------------------------------------

void delay_us(int count_us) {
    int start, delay;
    start = read_csr(mcycle);
    delay = count_us * (F_CPU / 1000000);
    while(read_csr(mcycle) - start < delay);
}

void setStats(int enable) {
  int i = 0;
  #define READ_CTR(name) do { \
      while (i >= NUM_COUNTERS) ; \
      int csr = read_csr(name); \
      if (!enable) { csr -= counters[i]; counter_names[i] = #name; } \
      counters[i++] = csr; \
    } while (0)

    READ_CTR(mcycle);
    READ_CTR(minstret);

  #undef READ_CTR
}

void printStats(void) {
  printk("\n\ncycles: %u\n", counters[0]);
  printk("intrs: %u\n", counters[1]);
}

int verify(int n, const volatile int* test, const int* verify) {
  int i;

  printStats();

  // Unrolled for faster verification
  for (i = 0; i < n/2*2; i+=2)
  {
    int t0 = test[i], t1 = test[i+1];
    int v0 = verify[i], v1 = verify[i+1];
    if (t0 != v0) return i+1;
    if (t1 != v1) return i+2;
  }
  if (n % 2 != 0 && test[n-1] != verify[n-1])
    return n;
  return 0;
}

void printk(const char *fmt, ...) {
    int len;
    uint32_t qsize;

    // Format using mini-printf
    va_list va;
    va_start(va, fmt);
    len = mini_vsnprintf(uart_buffer, UART_BUFFER_SIZE, fmt, va);
    va_end(va);

    // guard against overflows or null strings
    if (len <= 0) return;

    // transmit over UART
    char *p = uart_buffer;
    for (uint8_t i=0; i<len; i++) {
        // Wait until there's space in the UART TX Queue
        while (1) {
            qsize = KRZ_UART_STATUS & 0x00ff;
            if (qsize < UART_TXQ_SIZE) break;
        }

        MMPTR8(KRZ_UART) = *p;
        p++;
    }    
}

void  trap_handler (int mcause, int mtval, int mepc) {
  printk("\n\n-= TRAP =-\n");
  printk("mcause = %x\n", mcause);
  printk("mtval = %x\n", mcause);
  printk("mepc = %x\n", mcause);
  while(1);
}
