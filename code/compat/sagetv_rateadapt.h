#ifndef SAGETV_RATEADAPT_H
#define SAGETV_RATEADAPT_H

#include <stdint.h>
#include "libavcodec/avcodec.h"

extern int sagetv_rate_ctrl;

void sagetv_rateadapt_feed(int ch);
void sagetv_rateadapt_apply(AVCodecContext *enc, int64_t *applied_total);

#endif
