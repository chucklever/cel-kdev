# NFSD events (fs/nfsd/trace.h)

| Event | Key Fields | Use |
|-------|-----------|-----|
| nfsd_compound | xid, opcnt, tag | Compound request arrival |
| nfsd_compound_status | op, name, status | Per-op completion status |
| nfsd_compound_decode_err | | XDR decode failure |
| nfsd_read_start | xid, fh_hash, offset, len | Read I/O begin |
| nfsd_read_io_done | xid, fh_hash, offset, len | Read I/O complete |
| nfsd_read_done | xid, fh_hash, offset, len | Read op complete |
| nfsd_write_start | xid, fh_hash, offset, len | Write I/O begin |
| nfsd_write_io_done | xid, fh_hash, offset, len | Write I/O complete |
| nfsd_write_done | xid, fh_hash, offset, len | Write op complete |
| nfsd_read_err | xid, fh_hash, offset, status | Read error |
| nfsd_write_err | xid, fh_hash, offset, status | Write error |
| nfsd_file_acquire | | File cache lookup |
| nfsd_drc_found | | Duplicate request cache hit |
| nfsd_drc_mismatch | | DRC mismatch |
| nfsd_cb_* | | Callback events |

Pairable: nfsd_read_start -> nfsd_read_io_done -> nfsd_read_done
(by xid); same for write. nfsd_compound brackets per-op events.
