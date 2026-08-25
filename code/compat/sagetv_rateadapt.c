#include "config.h"

#include <errno.h>
#include <inttypes.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "sagetv_rateadapt.h"
#include "libavutil/common.h"
#include "libavutil/log.h"
#include "libavutil/opt.h"

int sagetv_rate_ctrl = 0;

static atomic_int_fast64_t rate_adjust_total = 0;
#define CMD_BUF_SIZE 512
static char cmd_buf[CMD_BUF_SIZE];
static size_t cmd_len;

static void process_command(const char *line)
{
    const char *name = NULL;
    const char *p;
    char *end = NULL;
    long kbps;

    if (!strncmp(line, "videorateadapt", strlen("videorateadapt")))
        name = "videorateadapt";
    else if (!strncmp(line, "sagetv_videorateadapt", strlen("sagetv_videorateadapt")))
        name = "sagetv_videorateadapt";
    else {
        if (*line)
            av_log(NULL, AV_LOG_DEBUG, "Ignoring unknown SageTV rate-control command '%s'\n", line);
        return;
    }

    p = line + strlen(name);
    while (*p == ' ' || *p == '\t')
        p++;

    errno = 0;
    kbps = strtol(p, &end, 10);
    if (errno || end == p) {
        av_log(NULL, AV_LOG_WARNING, "Invalid SageTV videorateadapt command: %s\n", line);
        return;
    }

    atomic_fetch_add(&rate_adjust_total, (int64_t)kbps * 1000);
    av_log(NULL, AV_LOG_VERBOSE,
           "SageTV videorateadapt %+ld kbps, cumulative=%" PRIdFAST64 " bps\n",
           kbps, atomic_load(&rate_adjust_total));
}

void sagetv_rateadapt_feed(int ch)
{
    if (ch == '\r' || ch == '\n') {
        if (cmd_len) {
            cmd_buf[cmd_len] = 0;
            process_command(cmd_buf);
            cmd_len = 0;
        }
        return;
    }

    if (ch <= 0)
        return;

    if (cmd_len + 1 >= sizeof(cmd_buf)) {
        av_log(NULL, AV_LOG_WARNING,
               "SageTV rate-control command exceeded %d bytes; resetting buffer\n",
               CMD_BUF_SIZE - 1);
        cmd_len = 0;
        return;
    }

    cmd_buf[cmd_len++] = (char)ch;
}

void sagetv_rateadapt_apply(AVCodecContext *enc, int64_t *applied_total)
{
    int64_t target_total;
    int64_t delta;
    int64_t new_rate;

    if (!enc || enc->codec_type != AVMEDIA_TYPE_VIDEO || !applied_total)
        return;

    target_total = atomic_load(&rate_adjust_total);
    delta = target_total - *applied_total;
    if (!delta)
        return;

    if (enc->bit_rate <= 0) {
        *applied_total = target_total;
        av_log(enc, AV_LOG_WARNING,
               "SageTV videorateadapt ignored because encoder bitrate is not explicitly set\n");
        return;
    }

    new_rate = FFMAX(INT64_C(1000), enc->bit_rate + delta);
    av_log(enc, AV_LOG_INFO,
           "SageTV videorateadapt encoder=%s old=%" PRId64
           " delta=%" PRId64 " new=%" PRId64 "\n",
           enc->codec ? enc->codec->name : "?", enc->bit_rate, delta, new_rate);

    enc->bit_rate = new_rate;
    if (enc->rc_max_rate > 0)
        enc->rc_max_rate = FFMAX(INT64_C(1000), enc->rc_max_rate + delta);

    /* Generic AVCodecContext plus encoder private AVOptions. Encoders differ in
     * whether they honor live RC changes; the MIM may restart unsupported ones. */
    av_opt_set_int(enc, "b", new_rate, 0);
    if (enc->priv_data)
        av_opt_set_int(enc->priv_data, "b", new_rate, AV_OPT_SEARCH_CHILDREN);

    *applied_total = target_total;
}
