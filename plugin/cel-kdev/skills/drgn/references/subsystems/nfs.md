# NFS drgn patterns

## Checking direct I/O state

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

## Inspecting open files for a task

```python
from drgn import cast
from drgn.helpers.linux.pid import find_task

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
