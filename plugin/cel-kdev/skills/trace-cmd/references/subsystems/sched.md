# Scheduler events (sched.h)

| Event | Use |
|-------|-----|
| sched_switch | Context switches; look for nfsd/kworker preemption |
| sched_wakeup | Wake latency for service threads |

Useful for correlating: high svc_xprt_dequeue wakeup-us with
sched_switch events showing the nfsd thread was preempted or
migrated.
