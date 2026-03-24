# SunRPC server events (sunrpc.h)

| Event | Key Fields | Use |
|-------|-----------|-----|
| svc_xprt_enqueue | flags | Transport queued for service; flags show state |
| svc_xprt_dequeue | wakeup-us, qtime-us | Thread picked up transport; wakeup-us = thread wake latency, qtime-us = time on queue |
| svc_process | xid, procedure | RPC request dispatch |
| svc_stats_latency | procedure, execute-us | RPC execution time |
| svc_alloc_arg_err | (none) | Page allocation failure |
| svc_replace_page_err | (none) | Page replacement failure |

Pairable: svc_xprt_enqueue -> svc_xprt_dequeue (by transport addr)
