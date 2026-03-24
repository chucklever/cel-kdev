# xprtrdma client events (rpcrdma.h)

| Event | Key Fields | Use |
|-------|-----------|-----|
| xprtrdma_post_send | task_id, client_id, cq_id, cid | Client RDMA send posted |
| xprtrdma_post_send_err | status | Client send failure |
| xprtrdma_post_recvs | count | Receive buffers posted |
| xprtrdma_post_recvs_err | status | Receive post failure |
| xprtrdma_reply | task_id, xid, credits | Reply received |
| xprtrdma_marshal | task_id, xid, hdrlen, rtype, wtype | Request marshalled |
| xprtrdma_marshal_failed | task_id, status | Marshal failure |
| xprtrdma_op_connect | | Connection attempt |
| xprtrdma_createmrs | count | MR pool growth |
| xprtrdma_nomrs_err | task_id | MR exhaustion |
| xprtrdma_frwr_alloc | | FRWR allocated |
| xprtrdma_frwr_dereg | | FRWR deregistered |

Pairable: xprtrdma_marshal -> xprtrdma_post_send -> xprtrdma_reply
(by task_id/xid)
