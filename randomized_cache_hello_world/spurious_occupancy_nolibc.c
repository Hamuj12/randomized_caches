__attribute__((noreturn))
static void sys_exit(long code){
    __asm__ volatile("mov $60, %%rax; syscall" :: "D"(code) : "rax","rcx","r11","memory");
    __builtin_unreachable();
}
__attribute__((noreturn))
void _start(void){
    volatile unsigned long sum=0;
    static volatile unsigned long buf[1<<20];
    const unsigned long N=(64UL<<20)/sizeof(unsigned long);
    for(unsigned long i=0;i<N;++i){
        unsigned long idx=(i*1315423911UL)&((1UL<<20)-1);
        buf[idx]^=i; sum+=buf[idx];
    }
    sys_exit(0);
}
