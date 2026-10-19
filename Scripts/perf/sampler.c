// Per-interval resource sampler for one pid, plus a trackpad activity probe (its own MultitouchSupport callback),
// so every interval is labelled with how many touch frames the trackpads produced and the most fingers seen.
// Usage: sampler <pid> <interval_ms> <seconds> [label]
// Output (TSV): t_s label frames maxfingers cpu_ms cpu_pct instr_M cycles_M idle_wk intr_wk footprint_MB energy_mJ
#include <dlfcn.h>
#include <libproc.h>
#include <mach/mach_time.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>
#include <pthread.h>

static _Atomic long frames = 0;
static _Atomic int maxFingers = 0;

typedef int (*Callback)(void *, void *, int, double, int);
static int onFrame(void *dev, void *touches, int count, double ts, int frame) {
    atomic_fetch_add(&frames, 1);
    int m = atomic_load(&maxFingers);
    while (count > m && !atomic_compare_exchange_weak(&maxFingers, &m, count)) {}
    return 0;
}

static void startProbe(void) {
    void *h = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
    if (!h) { fprintf(stderr, "no MT\n"); return; }
    CFArrayRef (*createList)(void) = dlsym(h, "MTDeviceCreateList");
    void (*reg)(void *, Callback) = dlsym(h, "MTRegisterContactFrameCallback");
    int (*start)(void *, int) = dlsym(h, "MTDeviceStart");
    CFArrayRef list = createList();
    for (CFIndex i = 0; i < CFArrayGetCount(list); i++) {
        void *d = (void *)CFArrayGetValueAtIndex(list, i);
        reg(d, onFrame);
        start(d, 0);
    }
}

int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage\n"); return 2; }
    pid_t pid = atoi(argv[1]);
    int intervalMs = atoi(argv[2]);
    int seconds = atoi(argv[3]);
    const char *label = argc > 4 ? argv[4] : "-";
    startProbe();
    mach_timebase_info_data_t tb; mach_timebase_info(&tb);
    struct rusage_info_v6 prev, cur;
    if (proc_pid_rusage(pid, RUSAGE_INFO_V6, (rusage_info_t *)&prev) != 0) { perror("rusage"); return 1; }
    uint64_t t0 = mach_absolute_time();
    struct rusage_info_v6 first = prev;
    long totalFrames = 0;
    printf("t_s\tlabel\tframes\tmaxfing\tcpu_ms\tcpu_pct\tinstr_M\tcycles_M\tidle_wk\tintr_wk\tfoot_MB\tenergy_mJ\n");
    fflush(stdout);
    int n = seconds * 1000 / intervalMs;
    for (int i = 0; i < n; i++) {
        usleep(intervalMs * 1000);
        if (proc_pid_rusage(pid, RUSAGE_INFO_V6, (rusage_info_t *)&cur) != 0) { perror("rusage"); return 1; }
        long f = atomic_exchange(&frames, 0);
        int mf = atomic_exchange(&maxFingers, 0);
        totalFrames += f;
        double cpuNs = (double)((cur.ri_user_time + cur.ri_system_time) - (prev.ri_user_time + prev.ri_system_time)) * tb.numer / tb.denom;
        double t = (double)(mach_absolute_time() - t0) * tb.numer / tb.denom / 1e9;
        printf("%.1f\t%s\t%ld\t%d\t%.3f\t%.3f\t%.3f\t%.3f\t%llu\t%llu\t%.2f\t%.3f\n", t, label, f, mf, cpuNs / 1e6,
               cpuNs / 1e6 / intervalMs * 100, (cur.ri_instructions - prev.ri_instructions) / 1e6,
               (cur.ri_cycles - prev.ri_cycles) / 1e6, cur.ri_pkg_idle_wkups - prev.ri_pkg_idle_wkups,
               cur.ri_interrupt_wkups - prev.ri_interrupt_wkups, cur.ri_phys_footprint / 1048576.0,
               (cur.ri_billed_energy - prev.ri_billed_energy) / 1e6);
        fflush(stdout);
        prev = cur;
    }
    double totalCpuNs = (double)((cur.ri_user_time + cur.ri_system_time) - (first.ri_user_time + first.ri_system_time)) * tb.numer / tb.denom;
    double t = (double)(mach_absolute_time() - t0) * tb.numer / tb.denom / 1e9;
    printf("#TOTAL\t%s\tdur_s=%.1f\tframes=%ld\tcpu_ms=%.3f\tcpu_pct=%.4f\tinstr_M=%.3f\tidle_wk=%llu (%.2f/s)\tintr_wk=%llu\tfoot_MB=%.2f\tpeak_MB=%.2f\tenergy_mJ=%.3f (%.3f mW)\tqos_ui_ms=%.3f\tqos_default_ms=%.3f\tqos_ui_init_ms=%.3f\n",
           label, t, totalFrames, totalCpuNs / 1e6, totalCpuNs / 1e9 / t * 100,
           (cur.ri_instructions - first.ri_instructions) / 1e6, cur.ri_pkg_idle_wkups - first.ri_pkg_idle_wkups,
           (cur.ri_pkg_idle_wkups - first.ri_pkg_idle_wkups) / t, cur.ri_interrupt_wkups - first.ri_interrupt_wkups,
           cur.ri_phys_footprint / 1048576.0, cur.ri_lifetime_max_phys_footprint / 1048576.0,
           (cur.ri_billed_energy - first.ri_billed_energy) / 1e6, (cur.ri_billed_energy - first.ri_billed_energy) / 1e6 / t,
           (double)(cur.ri_cpu_time_qos_user_interactive - first.ri_cpu_time_qos_user_interactive) * tb.numer / tb.denom / 1e6,
           (double)(cur.ri_cpu_time_qos_default - first.ri_cpu_time_qos_default) * tb.numer / tb.denom / 1e6,
           (double)(cur.ri_cpu_time_qos_user_initiated - first.ri_cpu_time_qos_user_initiated) * tb.numer / tb.denom / 1e6);
    return 0;
}
