# svcrdma server events (rpcrdma.h)

| Event | Key Fields | Use |
|-------|-----------|-----|
| svcrdma_decode_rqst | xid, hdrlen | Incoming RDMA request decode |
| svcrdma_post_send | cq_id | RDMA send posted |
| svcrdma_wc_read | cq_id, status | RDMA read completion |
| svcrdma_send_err | status | Send failure |
| svcrdma_rq_post_err | status | Receive post failure |
| svcrdma_qp_error | | Queue pair error |
| svcrdma_sq_post_err | | Send queue post failure |
| svcrdma_dma_map_rw_err | | DMA mapping failure |
| svcrdma_send_pullup | | Inline send data copy |
| svcrdma_cc_release | | Chunk completion release |

Pairable: svcrdma_post_send -> completion events (by cq_id)
