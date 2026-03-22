---
name: drgn
description: >-
  Live kernel debugging with drgn. Guides inspection of
  /proc/kcore, per-cpu variables, stack traces, slab caches,
  and data structure traversal. Covers correct API patterns,
  type introspection, container_of usage, and common pitfalls
  for SUNRPC, NFS, and AIO subsystems.
invocation_policy: automatic
allowed-tools: Bash(*:drgn *), Bash(*:sudo drgn *), Bash(*:sudo timeout * drgn *)
---

# drgn live kernel debugger

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

## Core API patterns

### Creating typed objects

To create a typed pointer from a raw address:

```python
from drgn import Object, cast

# From an address
obj = Object(prog, 'struct kioctx', address=addr)

# Cast an existing object to a different type
page = cast('struct page *', folio)
```

Do NOT use `prog.object(type_=..., value=...)` -- that API
does not exist. Use `Object()` from `drgn` directly.

### Reading pointer values

Printing a pointer field dumps the entire target struct.
Use `.value_()` to get the raw address:

```python
# BAD: prints entire task_struct
print(task.tk_client)

# GOOD: prints the pointer address
print(hex(task.tk_client.value_()))
```

### Type introspection

Discover struct members when field names have changed across
kernel versions:

```python
members = [m.name for m in obj.type_.type.members if m.name]
print(members)
```

Essential when a field has been renamed (e.g., `ring_pages`
became `ring_folios` in the AIO subsystem).

### Container-of for embedded structs

When a struct is embedded inside another, cast the outer
struct using `container_of`, not a direct cast of the inner
pointer:

```python
from drgn.helpers.linux.list import container_of

# xprt is embedded in rpcrdma_xprt
rdma_xprt = container_of(xprt, 'struct rpcrdma_xprt', 'rx_xprt')
```

## Per-CPU variable access

Per-cpu variables require computing the actual address from
the base symbol and the per-cpu offset for each CPU:

```python
from drgn.helpers.linux.percpu import per_cpu_ptr

# Method 1: per_cpu_ptr helper (preferred)
symbol = prog['runqueues']
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

## Stack traces

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
succeeds but the value is unusable. Check by printing it
before dereferencing fields. Wrap access in try/except:

```python
trace = prog.stack_trace(task)
for frame in trace:
    try:
        ctx = frame['ctx']
        print(f"frame {frame}: ctx={ctx}")
    except (KeyError, LookupError):
        pass
```

## Slab cache inspection

**WARNING: slab iteration is extremely slow on live systems.**
Iterating all allocated objects in a slab can take minutes
and may time out. Prefer targeted approaches first:

- Check `/sys/kernel/slab/<name>/` stats for object counts
- Use reference counts, list membership, or hash table
  lookups to find specific objects
- Use slab iteration only as a last resort, with a timeout

Wrap `sudo drgn -k script.py` in `sudo timeout 60 drgn ...`
for slab iterations or other operations that may take
unbounded time.

See [references/helpers.md](references/helpers.md) for
slab iteration code patterns.

## Scripting practices

### Introspect before accessing fields

Struct layouts change across kernel versions. Always check
member names before accessing unfamiliar fields:

```python
members = [m.name for m in obj.type_.type.members
           if m.name]
print(members)
```

### Atomic types vary

`atomic_t` has `.counter`. `atomic_long_t` has `.counter`
directly (NOT `.refs.counter`). `refcount_t` wraps
`atomic_t` as `.refs.counter`. When in doubt, introspect:

```python
# atomic_t / atomic_long_t
val = obj.counter.value_()

# refcount_t
val = obj.refs.counter.value_()
```

### Always use sudo

Every drgn invocation, `/sys/kernel/slab/` read, and
`/proc/kcore` access requires root. Do not attempt
unprivileged access first -- it wastes a round-trip.

### Filter early inside scripts

When iterating tasks or slab objects, filter inside the
drgn script rather than dumping everything and scanning
the output. Large unfiltered dumps consume context and
often time out:

```python
# BAD: dump all tasks
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
the startup overhead. Probe the layout and act on it
in one script:

```python
members = {m.name for m in obj.type_.type.members if m.name}
if 'ring_folios' in members:
    folio = obj.ring_folios[0]
elif 'ring_pages' in members:
    folio = obj.ring_pages[0]
print(folio)
```

## Common pitfalls

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

## Reference files

- [references/helpers.md](references/helpers.md) --
  process lookup, list/rbtree iteration, slab cache,
  memory translation, percpu-ref, per-netns access
- [references/subsystems/sunrpc.md](references/subsystems/sunrpc.md) --
  RPC wait queues, transport state, health check
- [references/subsystems/nfs.md](references/subsystems/nfs.md) --
  direct I/O state, open file inspection
- [references/subsystems/aio.md](references/subsystems/aio.md) --
  ring buffer state, slot accounting
