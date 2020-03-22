__attribute__ ((section (".data"))) int done, n, result;

void main() {
    int a, b;

    done = 0;
    result = 0;
    
    a = 1;
    for(b=0; b<n; b++){
        a = 2 * a;
    }
    result = a;

    done = 1;
    while(1);
}
