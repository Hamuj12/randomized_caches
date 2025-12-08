// Minimal multi-bit sender with no libc dependencies.
// Uses RC_SYMBOLS/RC_MESSAGE/RC_REPEAT from the environment when available.

__attribute__((noreturn))
static void sys_exit(long code) {
    __asm__ volatile("mov $60, %%rax; syscall" :: "D"(code) : "rax", "rcx", "r11", "memory");
    __builtin_unreachable();
}

static long sys_write(int fd, const char *buf, long len) {
    long ret;
    __asm__ volatile("mov $1, %%rax; syscall" : "=a"(ret) : "D"(fd), "S"(buf), "d"(len) : "rcx", "r11", "memory");
    return ret;
}

static long my_strlen(const char *s) {
    long n = 0;
    while (s && s[n]) {
        ++n;
    }
    return n;
}

static int my_strncmp(const char *a, const char *b, long n) {
    for (long i = 0; i < n; ++i) {
        if (a[i] != b[i] || !a[i] || !b[i]) {
            return (unsigned char)a[i] - (unsigned char)b[i];
        }
    }
    return 0;
}

static long my_atoul(const char *s, long fallback) {
    long v = 0;
    if (!s || !*s) return fallback;
    for (const char *p = s; *p; ++p) {
        if (*p < '0' || *p > '9') return fallback;
        v = v * 10 + (*p - '0');
    }
    return v;
}

static void write_str(const char *s) {
    if (s) sys_write(1, s, my_strlen(s));
}

static void write_line(const char *s) {
    write_str(s);
    write_str("\n");
}

static void utoa_buf(unsigned long v, char *buf, int buf_sz) {
    int i = buf_sz - 1;
    buf[i] = '\0';
    if (v == 0) {
        buf[--i] = '0';
    } else {
        while (i > 0 && v > 0) {
            buf[--i] = (char)('0' + (v % 10));
            v /= 10;
        }
    }
    int j = 0;
    while (buf[i]) buf[j++] = buf[i++];
    buf[j] = '\0';
}

static const char *get_env(char **envp, const char *key) {
    long key_len = my_strlen(key);
    for (long i = 0; envp[i]; ++i) {
        const char *entry = envp[i];
        if (my_strncmp(entry, key, key_len) == 0 && entry[key_len] == '=') {
            return entry + key_len + 1;
        }
    }
    return 0;
}

#define CHANNEL_WORDS (1 << 20)
#define BASE_TOUCHES 4096
#define TOUCH_STEP 1536
#define SYMBOL_AMPLIFY 3

static volatile unsigned long channel[CHANNEL_WORDS];

static long find_symbol(char symbol, const char *alphabet) {
    for (long i = 0; alphabet && alphabet[i]; ++i) {
        if (alphabet[i] == symbol) return i;
    }
    return -1;
}

static void touch_symbol(unsigned long idx) {
    const unsigned long touches = BASE_TOUCHES + idx * TOUCH_STEP;
    const unsigned long mask = CHANNEL_WORDS - 1;
    for (unsigned long round = 0; round < SYMBOL_AMPLIFY; ++round) {
        for (unsigned long i = 0; i < touches; ++i) {
            unsigned long pos = (i * 1315423911UL + (idx + 1) * 2654435761UL + round * 17UL) & mask;
            channel[pos] ^= (i + 1 + idx);
        }
    }
}

static void log_symbol(char sym, unsigned long idx, unsigned long round) {
    char buf[80];
    char num[32];
    int pos = 0;
    const char prefix[] = "[multibit] sent symbol '";
    for (int i = 0; prefix[i]; ++i) buf[pos++] = prefix[i];
    buf[pos++] = sym;
    buf[pos++] = '\'';
    buf[pos++] = ' ';
    buf[pos++] = '(';
    buf[pos++] = 'l'; buf[pos++] = 'e'; buf[pos++] = 'v'; buf[pos++] = 'e'; buf[pos++] = 'l'; buf[pos++] = ' ';
    utoa_buf(idx, num, sizeof num);
    for (int i = 0; num[i]; ++i) buf[pos++] = num[i];
    buf[pos++] = ')'; buf[pos++] = ' ';
    buf[pos++] = 'r'; buf[pos++] = 'o'; buf[pos++] = 'u'; buf[pos++] = 'n'; buf[pos++] = 'd'; buf[pos++] = ' ';
    utoa_buf(round, num, sizeof num);
    for (int i = 0; num[i]; ++i) buf[pos++] = num[i];
    buf[pos++] = '\0';
    write_line(buf);
}

void _start(void) {
    register long *sp asm("rsp");
    long argc = *sp++;
    (void)argc;
    char **argv = (char **)sp;
    while (*argv++) {
    }
    char **envp = argv;

    const char *alphabet = get_env(envp, "RC_SYMBOLS");
    const char *message = get_env(envp, "RC_MESSAGE");
    const char *repeat_env = get_env(envp, "RC_REPEAT");
    if (!alphabet || !*alphabet) alphabet = "0123";
    if (!message || !*message) message = alphabet;
    unsigned long repeat = (unsigned long)my_atoul(repeat_env, 1);
    if (repeat == 0) repeat = 1;

    write_str("[multibit] alphabet=\"");
    write_str(alphabet);
    write_str("\" message=\"");
    write_str(message);
    write_str("\" repeat=");
    char num[32];
    utoa_buf(repeat, num, sizeof num);
    write_line(num);

    for (unsigned long r = 0; r < repeat; ++r) {
        for (long i = 0; message[i]; ++i) {
            long idx = find_symbol(message[i], alphabet);
            if (idx < 0) {
                write_str("[multibit] skip unknown symbol '");
                char c[2] = {message[i], '\0'};
                write_str(c);
                write_line("'");
                continue;
            }
            touch_symbol((unsigned long)idx);
            log_symbol(message[i], (unsigned long)idx, r + 1);
        }
    }

    write_line("[multibit] sequence complete");
    sys_exit(0);
}
