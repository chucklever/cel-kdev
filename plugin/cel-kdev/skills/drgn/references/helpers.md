# drgn common helpers

## Process lookup

```python
from drgn.helpers.linux.pid import find_task, for_each_task

# Single PID
task = find_task(prog, 1234)

# All tasks
for task in for_each_task(prog):
    print(task.pid.value_(), task.comm.string_())
```

## List iteration

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

## RB-tree iteration

```python
from drgn.helpers.linux.rbtree import rbtree_inorder_for_each_entry

for node in rbtree_inorder_for_each_entry('struct my_type',
                                           root, 'rb_node'):
    print(node.key)
```

## Slab cache inspection

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

## Memory and address translation

### Page/folio address

`folio_address()` may not be available in drgn. Work around
by casting to `struct page *` and using `page_to_virt()`:

```python
from drgn.helpers.linux.mm import page_to_virt
from drgn import cast

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

## Percpu-ref counting

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
dereferenced directly. Use `per_cpu_ptr` on the owning
struct's per-cpu field instead.

A base reference of 1 means no outstanding references beyond
the initial one.

## Per-netns data (net_generic)

Access per-network-namespace data such as `sunrpc_net`:

```python
from drgn import cast

sn_id = prog['sunrpc_net_id'].value_()
net = prog['init_net']
ptr = net.gen.ptr[sn_id]
sn = cast('struct sunrpc_net *', ptr)

# Iterate all SUNRPC clients
from drgn.helpers.linux.list import list_for_each_entry
for clnt in list_for_each_entry('struct rpc_clnt',
        sn.all_clients.address_of_(), 'cl_clients'):
    print(f"prog={clnt.cl_prog.value_()} "
          f"vers={clnt.cl_vers.value_()}")
```
