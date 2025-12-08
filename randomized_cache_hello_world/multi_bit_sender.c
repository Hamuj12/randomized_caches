#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHANNEL_WORDS (1 << 20)
#define BASE_TOUCHES 4096
#define TOUCH_STEP 1536
#define SYMBOL_AMPLIFY 3

static volatile uint64_t channel[CHANNEL_WORDS];

static const char DEFAULT_SYMBOLS[] = "0123";

static size_t symbol_index(char symbol, const char *alphabet) {
    const char *hit = strchr(alphabet, symbol);
    return hit ? (size_t)(hit - alphabet) : (size_t)-1;
}

static void touch_symbol(size_t idx) {
    const size_t touches = BASE_TOUCHES + idx * TOUCH_STEP;
    const size_t mask = CHANNEL_WORDS - 1;
    for (size_t round = 0; round < SYMBOL_AMPLIFY; ++round) {
        for (size_t i = 0; i < touches; ++i) {
            size_t pos = (i * 1315423911u + (idx + 1) * 2654435761u + round * 17u) & mask;
            channel[pos] ^= (uint64_t)(i + 1 + idx);
        }
    }
}

int main(void) {
    const char *alphabet = getenv("RC_SYMBOLS");
    const char *message = getenv("RC_MESSAGE");
    const char *repeat_env = getenv("RC_REPEAT");

    if (!alphabet || !*alphabet) {
        alphabet = DEFAULT_SYMBOLS;
    }
    if (!message || !*message) {
        message = alphabet;
    }

    char *endptr = NULL;
    unsigned long repeat = repeat_env ? strtoul(repeat_env, &endptr, 10) : 1;
    if (repeat == 0 || (endptr && *endptr != '\0')) {
        repeat = 1;
    }

    printf("[multibit] alphabet=\"%s\" message=\"%s\" repeat=%lu\n", alphabet, message, repeat);

    size_t msg_len = strlen(message);

    for (unsigned long r = 0; r < repeat; ++r) {
        for (size_t i = 0; i < msg_len; ++i) {
            size_t idx = symbol_index(message[i], alphabet);
            if (idx == (size_t)-1) {
                printf("[multibit] skip unknown symbol '%c'\n", message[i]);
                continue;
            }
            touch_symbol(idx);
            printf("[multibit] sent symbol '%c' (level %zu) round %lu\n", message[i], idx, r + 1);
        }
    }

    printf("[multibit] sequence complete\n");
    return 0;
}

