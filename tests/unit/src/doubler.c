__attribute__ ((section ("data"))) int result;

void main(int n) {
    int a, b;
    a = 1;
    for(b=0; b<n; b++){
        a = 2 * a;
    }
    result = a;
}
