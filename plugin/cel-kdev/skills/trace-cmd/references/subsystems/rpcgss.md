# RPCGSS events (rpcgss.h)

| Event | Key Fields | Use |
|-------|-----------|-----|
| rpcgss_svc_authenticate | xid | Server-side GSS authentication |
| rpcgss_svc_wrap_failed | xid | Wrap failure |
| rpcgss_svc_unwrap_failed | xid | Unwrap failure |
| rpcgss_svc_seqno_bad | xid, seqno | Sequence number violation |
| rpcgss_svc_seqno_low | xid, seqno | Late sequence number |
| rpcgss_svc_accept_upcall | | Upcall to gssd |
| rpcgss_upcall_msg | | Client upcall message |
| rpcgss_upcall_result | status | Upcall result |
| rpcgss_context | | Context establishment |
| rpcgss_seqno | task_id, xid, seqno | Client sequence number |

Useful for: authentication failures, GSS context churn,
upcall latency (pair svc_accept_upcall with context events).
