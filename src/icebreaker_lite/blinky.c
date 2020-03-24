volatile int *ledg =  (volatile int*) 0x1000;
const int delay = 333333;

void main() {
    int a;

    *ledg = 0;
    while(1) {
        // some delay
        a = 0;
        for(int i=0; i<delay; i++)
            a = a + 1;

        // toggle LED
        *ledg ^= 1;
    }
}
