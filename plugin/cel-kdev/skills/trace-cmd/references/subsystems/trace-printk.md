# trace_printk events (bprint / bputs)

Kernel code instrumented with `trace_printk()` emits
free-form printf-style events. These lack a structured
format descriptor, appearing under the generic `bprint`
or `bputs` event names rather than subsystem-specific
tracepoints.

Use `trace-cmd report -P` to list the stored
`trace_printk()` format strings from the `.dat` file.

In report output:

```
  nfsd-1234  [002]  1234.567890: bprint: my_function: xid=0x1a2b count=5
  kworker-56 [001]  1234.567891: bputs:  do_something: entering slow path
```

`bprint` carries a printf format string with arguments;
`bputs` is a constant-string variant.

Because these events have no typed fields:
- Field-level `-F` filters do not apply; use `grep`
  on report output instead
- `trace-cmd dump --events` contains no format block
- Values embedded in the text must be extracted with awk

Treat bprint/bputs events as developer-added debug
instrumentation. Extract structure from the message text:

```bash
# List distinct bprint messages
trace-cmd report -i <file> -F 'bprint' 2>&1 | \
  grep 'bprint' | sed -n 's/.*bprint: *//p' | \
  cut -d: -f1 | sort | uniq -c | sort -rn

# Extract a numeric value from a trace_printk message
trace-cmd report -i <file> -F 'bprint' 2>&1 | \
  grep 'my_function' | \
  awk '{for(i=1;i<=NF;i++) if($i ~ /^count=/)
    {split($i,a,"="); print a[2]}}' | sort -n
```
