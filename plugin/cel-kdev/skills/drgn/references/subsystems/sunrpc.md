# SUNRPC drgn patterns

## Inspecting RPC wait queues

`rpc_wait_queue` is NOT a `list_head`. Check `.qlen` for
the queue depth; iterate `.tasks[]` for entries.

Array elements need `.address_of_()` when passed to list
helpers:

```python
from drgn.helpers.linux.list import list_for_each_entry, list_empty

queue = xprt.backlog
print(f"backlog qlen: {queue.qlen}")
for prio in range(4):
    head = queue.tasks[prio]
    if not list_empty(head.address_of_()):
        for task in list_for_each_entry(
                'struct rpc_task',
                head.address_of_(),
                'u.tk_wait.list'):
            print(f"  task pid={task.tk_pid} "
                  f"status={task.tk_status}")
```

## Checking transport state

```python
from drgn.helpers.linux.list import container_of

clnt = task.tk_client
xprt = clnt.cl_xprt

# For RDMA transport
rdma_xprt = container_of(xprt, 'struct rpcrdma_xprt', 'rx_xprt')
print(f"sends: {xprt.stat.sends}")
print(f"recvs: {xprt.stat.recvs}")
print(f"bad_xids: {xprt.stat.bad_xids}")
print(f"backlog: {xprt.backlog.qlen}")
```

## Full transport health check

```python
print(f"state: {hex(xprt.state.value_())}")
print(f"sends: {xprt.stat.sends.value_()} "
      f"recvs: {xprt.stat.recvs.value_()}")
print(f"bad_xids: {xprt.stat.bad_xids.value_()}")
print(f"num_reqs: {xprt.num_reqs.value_()} "
      f"max_reqs: {xprt.max_reqs.value_()}")
print(f"backlog: {xprt.backlog.qlen.value_()} "
      f"sending: {xprt.sending.qlen.value_()} "
      f"pending: {xprt.pending.qlen.value_()}")
# recv_hash (rhashtable, replaces recv_queue rb-tree)
print(f"recv_hash.nelems: "
      f"{xprt.recv_hash.nelems.counter.value_()}")
```
