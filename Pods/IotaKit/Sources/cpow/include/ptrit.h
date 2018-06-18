#ifndef __COMMON_TRINARY_PTRIT_H_
#define __COMMON_TRINARY_PTRIT_H_

#include <stdint.h>

#define HIGH_BITS 0xFFFFFFFFFFFFFFFF
#define LOW_BITS 0x0000000000000000

typedef int64_t ptrit_s;

typedef struct {
  ptrit_s low;
  ptrit_s high;
} ptrit_t;

#endif
