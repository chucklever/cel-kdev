---
name: drgn
description: Live kernel debugging with drgn. Load when using drgn to inspect /proc/kcore, analyze running kernel state, or debug hangs and crashes. Covers API patterns, per-cpu access, type introspection, and common pitfalls.
invocation_policy: automatic
allowed-tools: Bash(*:drgn *), Bash(*:sudo drgn *)
---

# drgn Live Kernel Debugger

Inspect running kernel state through `/proc/kcore`. Use for
diagnosing hangs, verifying data structure contents, tracing
reference counts, and examining queue states.

## Invocation

Always use `-k` for live kernel debugging:

```bash
sudo drgn -k
```

Do NOT use `-c /proc/kcore -s <path> -e vmlinux`. The `-e`
flag is parsed as inline Python, not as a vmlinux path. The
`-k` flag handles symbol resolution automatically.

For one-shot commands:

```bash
sudo drgn -k -c 'print(prog["jiffies"])'
```

For multi-line scripts, write to a temp file and execute:

```bash
cat > /tmp/drgn-script.py << 'PYEOF'
from drgn.helpers.linux.pid import find_task
task = find_task(prog, 1234)
print(task.comm)
PYEOF
sudo drgn -k /tmp/drgn-script.py
```

## Core API Patterns

### Creating Typed Objects

To create a typed pointer from a raw address:

```python
from drgn import Object, cast

# From an address (e.g., reading a pointer field)
obj = Object(prog, 'struct kioctx', address=addr)

# Cast an existing object to a different type
page = cast('struct page *', folio)
```

Do NOT use `prog.object(type_=..., value=...)` -- that API
does not exist. Use `Object()` from `drgn` directly.

### Reading Pointer Values

Printing a pointer field dumps the entire target struct.
Use `.value_()` to get the raw address:

```python
# BAD: prints entire task_struct
print(task.tk_client)

# GOOD: prints the pointer address
print(hex(task.tk_client.value_()))
```

### Type Introspection

Discover struct members when field names have changed across
kernel versions:

```python
members = [m.name for m in obj.type_.type.members if m.name]
print(members)
```

This is essential when a field has been renamed (e.g.,
`ring_pages` became `ring_folios` in the AIO subsystem).

### Container-of for Embedded Structs

When a struct is embedded inside another, cast the outer
struct using `container_of`, not a direct cast of the inner
pointer:

```python
from drgn.helpers.linux.list import container_of

# xprt is embedded in rpcrdma_xprt
rdma_xprt = container_of(xprt, 'struct rpcrdma_xprt', 'rx_xprt')
```

## Per-CPU Variable Access

Per-cpu variables require computing the actual address from
the base symbol and the per-cpu offset for each CPU:

```python
from drgn.helpers.linux.percpu import per_cpu_ptr

# Method 1: per_cpu_ptr helper (preferred)
symbol = prog['runqueues']  # or any per-cpu symbol
for cpu in range(nr_cpus):
    rq = per_cpu_ptr(symbol, cpu)
    print(f"CPU {cpu}: nr_running={rq.nr_running}")

# Method 2: manual offset calculation
offsets = prog['__per_cpu_offset']
for cpu in range(nr_cpus):
    addr = base_addr + offsets[cpu].value_()
    obj = Object(prog, 'struct kioctx_cpu', address=addr)
    print(f"CPU {cpu}: reqs_available={obj.reqs_available}")
```

To get the number of online CPUs:

```python
from drgn.helpers.linux.cpumask import for_each_online_cpu
cpus = list(for_each_online_cpu(prog))
```

## Stack Traces

### All threads of a process

```python
from drgn.helpers.linux.pid import find_task

task = find_task(prog, PID)
print(prog.stack_trace(task))
```

### Accessing frame locals

Use `frame[name]` to access local variables in stack frames.
Do NOT use `frame.locals()` for values -- it returns metadata
tuples, not the variables themselves.

Variables may be `<optimized out>` -- the `frame[name]` call
succeeds but the value is unusable.  Check by printing it
before dereferencing fields.  Wrap access in try/except:

```python
trace = prog.stack_trace(task)
for frame in trace:
    try:
        ctx = frame['ctx']
        print(f"frame {frame}: ctx={ctx}")
    except (KeyError, LookupError):
        pass
```

## Common Helpers

### Process lookup

```python
from drgn.helpers.linux.pid import find_task, for_each_task

# Single PID
task = find_task(prog, 1234)

# All tasks
for task in for_each_task(prog):
    print(task.pid.value_(), task.comm.string_())
```

### List iteration

```python
from drgn.helpers.linux.list import (
    list_for_each_entry,
    list_empty,
    hlist_for_each_entry,
)

# Iterate a list_head
for entry in list_for_each_entry('struct rpc_task',
                                  head, 'u.tk_wait.list'):
    print(entry.tk_status)

# Check if list is empty
if list_empty(head):
    print("empty")
```

### RB-tree iteration

```python
from drgn.helpers.linux.rbtree import rbtree_inorder_for_each_entry

for node in rbtree_inorder_for_each_entry('struct my_type',
                                           root, 'rb_node'):
    print(node.key)
```

### Slab cache inspection

**WARNING: slab iteration is extremely slow on live systems.**
Iterating all allocated objects in a slab can take minutes
and may time out.  Prefer targeted approaches first:

- Check `/sys/kernel/slab/<name>/` stats for object counts
- Use reference counts, list membership, or hash table
  lookups to find specific objects
- Use slab iteration only as a last resort, with a timeout

To find a slab cache by name (when no global `cachep`
variable is available):

```python
from drgn.helpers.linux.slab import (
    for_each_slab_cache,
    slab_cache_for_each_allocated_object,
)

for cache in for_each_slab_cache(prog):
    if cache.name.string_() == b'aio_kiocb':
        for obj in slab_cache_for_each_allocated_object(
                cache, 'struct aio_kiocb'):
            print(hex(obj.value_()))
        break
```

When a global cachep pointer exists:

```python
cache = prog['nfs_direct_cachep']
for obj in slab_cache_for_each_allocated_object(cache,
        'struct nfs_direct_req'):
    print(obj.io_count)
```

## Memory and Address Translation

### Page/folio address

`folio_address()` may not be available in drgn. Work around
by casting to `struct page *` and using `page_to_virt()`:

```python
from drgn.helpers.linux.mm import page_to_virt

page = cast('struct page *', folio)
virt = page_to_virt(page)
```

### Reading raw memory

```python
# Read N bytes at a virtual address
data = prog.read(address, nbytes)

# Interpret as a specific type
import struct
val = struct.unpack('<I', prog.read(addr, 4))[0]
```

## Percpu-ref Counting

`percpu_ref` uses a per-cpu mode for fast paths and falls
back to an atomic counter.

Check whether percpu or atomic mode is active:

```python
pcp_raw = ref.percpu_count_ptr.value_()
is_atomic = pcp_raw & 1  # bit 0 = dead/atomic flag
```

Read the atomic counter (meaningful in atomic mode;
includes BIAS in percpu mode):

```python
# atomic_long_t has .counter directly (NOT .refs.counter)
atomic_count = ref.data.count.counter.value_()
PERCPU_COUNT_BIAS = 1 << 32  # on 64-bit
real_count = atomic_count - PERCPU_COUNT_BIAS
```

In percpu mode the atomic counter alone is not meaningful.
Summing the per-cpu counters requires the `percpu_count_ptr`
base address, which is a `__percpu` pointer and cannot be
dereferenced directly.  Use `per_cpu_ptr` on the owning
struct's per-cpu field instead (see Per-CPU Variable Access).

A base reference of 1 means no outstanding references beyond
the initial one.

## Per-netns Data (net_generic)

Access per-network-namespace data such as `sunrpc_net`:

```python
from drgn import cast

sn_id = prog['sunrpc_net_id'].value_()
net = prog['init_net']
ptr = net.gen.ptr[sn_id]
sn = cast('struct sunrpc_net *', ptr)

# Iterate all SUNRPC clients
for clnt in list_for_each_entry('struct rpc_clnt',
        sn.all_clients.address_of_(), 'cl_clients'):
    print(f"prog={clnt.cl_prog.value_()} "
          f"vers={clnt.cl_vers.value_()}")
```

## SUNRPC-Specific Patterns

### Inspecting RPC wait queues

`rpc_wait_queue` is NOT a `list_head`. Check `.qlen` for
the queue depth; iterate `.tasks[]` for entries.

Array elements need `.address_of_()` when passed to list
helpers:

```python
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

### Checking transport state

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

### Full transport health check

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

## AIO-Specific Patterns

### Ring buffer state

```python
ring_folio = ctx.ring_folios[0]
page = cast('struct page *', ring_folio)
virt = page_to_virt(page).value_()
ring = Object(prog, 'struct aio_ring', address=virt)
print(f"head={ring.head} tail={ring.tail} nr={ring.nr}")
avail = (ring.tail.value_() - ring.head.value_()) % ring.nr.value_()
print(f"events available: {avail}")
```

### Slot accounting

`reqs_available` is initialized to `nr_events - 1`, not
`max_reqs`. The invariant:

    atomic + sum(per_cpu) + ring_events + in_flight = nr_events - 1

## NFS-Specific Patterns

### Checking direct I/O state

`i_dio_count` tracks outstanding O_DIRECT I/Os on an inode.
Non-zero means a `nfs_direct_req` is still in flight:

```python
from drgn.helpers.linux.list import container_of

# From an open file descriptor
inode = f.f_inode
dio_count = inode.i_dio_count.counter.value_()
print(f"outstanding DIO: {dio_count}")

# Get NFS inode from VFS inode
nfsi = container_of(inode, 'struct nfs_inode', 'vfs_inode')
print(f"nfs flags: {hex(nfsi.flags.value_())}")
```

### Inspecting open files for a task

```python
task = find_task(prog, PID)
fdt = task.files.fdt
max_fds = fdt.max_fds.value_()

for fd in range(min(max_fds, 256)):
    fp = fdt.fd[fd]
    if fp.value_() == 0:
        continue
    f = cast('struct file *', fp)
    fs_type = f.f_inode.i_sb.s_type.name.string_()
    if b'nfs' in fs_type:
        print(f"fd={fd}: NFS inode "
              f"{hex(f.f_inode.value_())}")
```

## Scripting Practices

### Introspect before accessing fields

Struct layouts change across kernel versions.  Always check
member names before accessing unfamiliar fields, especially
when a script will run unattended:

```python
members = [m.name for m in obj.type_.type.members
           if m.name]
print(members)
```

### Atomic types vary

`atomic_t` has `.counter`.  `atomic_long_t` has `.counter`
directly (NOT `.refs.counter`).  `refcount_t` wraps
`atomic_t` as `.refs.counter`.  When in doubt, introspect:

```python
# atomic_t / atomic_long_t
val = obj.counter.value_()

# refcount_t
val = obj.refs.counter.value_()
```

### Use timeouts for expensive operations

Wrap `sudo drgn -k script.py` in `sudo timeout 60 drgn ...`
when running slab iterations or other operations that may
take unbounded time on a live system.

### Always use sudo

Every drgn invocation, `/sys/kernel/slab/` read, and
`/proc/kcore` access requires root.  Do not attempt
unprivileged access first — it wastes a round-trip.

### Filter early inside scripts

When iterating tasks or slab objects, filter inside the
drgn script (by comm, stack frame content, field value)
rather than dumping everything and scanning the output.
Large unfiltered dumps consume context and often time out:

```python
# BAD: dump all tasks, scan output manually
for task in for_each_task(prog):
    print(task.pid.value_(), task.comm.string_())

# GOOD: filter to what matters
for task in for_each_task(prog):
    if task.comm.string_() == b'fio':
        print(task.pid.value_(), hex(task.state.value_()))
```

### Combine discovery and reading in one script

Separate scripts for "discover the struct layout" and
"read the values" cost two drgn invocations and double
the startup overhead.  Probe the layout and act on it
in one script:

```python
members = {m.name for m in obj.type_.type.members if m.name}
if 'ring_folios' in members:
    folio = obj.ring_folios[0]
elif 'ring_pages' in members:
    folio = obj.ring_pages[0]
print(folio)
```

## Common Pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| `NameError: vmlinux` | `-e vmlinux` parsed as Python | Use `drgn -k` |
| `AttributeError: ring_pages` | Field renamed | Introspect members first |
| `TypeError: prog.object(value=)` | Wrong API | Use `Object(prog, type, address=)` |
| `FaultError` on cast | Embedded struct | Use `container_of()` |
| Huge output on print | Printing struct pointer | Use `.value_()` for address |
| `frame.locals()` confusion | Returns tuples | Use `frame[name]` directly |
| Wrong per-cpu value | Missing offset | Add `__per_cpu_offset[cpu]` |
| `folio_address` import error | Not in drgn helpers | Cast to page, use `page_to_virt` |
| `.refs.counter` on `atomic_long_t` | Wrong atomic type | Use `.counter` directly |
| slab iteration hangs | Too many objects | Use `timeout`, prefer targeted lookup |
| `list_empty(array[i])` fails | Need pointer, not value | Use `array[i].address_of_()` |
