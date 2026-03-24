# TCP events

| Event | Use |
|-------|-----|
| tcp_send_reset | RST sent; connection teardown |
| tcp_receive_reset | RST received |
| tcp_retransmit_skb | Retransmission; indicates loss or congestion |
| tcp_retransmit_synack | SYN-ACK retransmit |
| tcp_probe | cwnd, ssthresh, srtt; congestion state |

Useful for: correlating NFS/RPC latency spikes with TCP
retransmissions or resets on the same connection.
