# Reading syzbot reproducers

This skill fetches reproducers to read them, not to run them.
Running one needs a VM built from the report's config and
commit; that is a separate, deliberate task.

## Which artifact to read

- `syz repro:` (`repro.syz`) is the program syzkaller minimised
  from the crashing fuzz run.  It is the primary evidence of
  what the kernel was asked to do.
- `C reproducer:` (`repro.c`) is `syz-prog2c` output for the
  same program: a large generated harness around the same
  calls.  Read it only when the `.syz` form is ambiguous about
  data layout; grep for `syscall(` to find the calls.
- Absence of a C reproducer means syzbot could not trigger the
  bug from the C translation; the `.syz` program is still
  valid.
- `kernel config:` matters when the crash depends on a debug
  option (KASAN, KMSAN, lockdep, PROVE_RCU) or on a subsystem
  being built in.  Grep it rather than reading it whole.

## The `.syz` header line

The first line describes how the program was executed.  Two
forms occur:

    # {Threaded:true Repeat:true RepeatTimes:0 Procs:6 Slowdown:1 Sandbox:none ...}
    #{"threaded":true,"repeat":true,"procs":1,"slowdown":1,"sandbox":"none",...}

| Field | Meaning |
| ----- | ------- |
| `Threaded` | each call runs in its own thread, so calls can overlap |
| `Repeat`, `RepeatTimes:0` | the program loops until it crashes |
| `Procs` | this many copies run concurrently |
| `Sandbox` | `none` runs as root; `setuid` and `namespace` drop privilege |
| `Collide` | (older repros) pairs of calls issued simultaneously |

`Sandbox:none` with root-only paths such as `/proc/fs/nfsd`
tells you the crash needs privilege; that shapes the severity
argument.  `Threaded:true` with `Procs` above one means a race
is plausible even when the call list looks sequential.

## Syscall lines

    r0 = openat$nfsd_portlist(0xffffffffffffff9c, &(0x7f0000000000), 0x2, 0x0)
    write$nfsd_portlist(r0, &(0x7f0000000040)={...}, 0x40)

- `name$variant` is a syzkaller description of one syscall
  entry point; the variant after `$` names the file, ioctl, or
  socket type.  The kernel function reached is the one the
  variant's description targets.
- `r0 = ...` binds a returned resource (fd, socket, id) used by
  later lines.
- `&(0x7f0000000000)` is an address in the shared data region;
  the `={...}` that follows is the bytes written there.  Strings
  appear as `'...'`, `\x` escapes, or `""`.
- `0xffffffffffffff9c` is `AT_FDCWD`.
- Repeated identical lines are intentional: the second call is
  usually the one that trips the bug.

Map each line to the kernel entry it exercises, then read the
crash trace from the innermost frame outward against those
entries.  The reproducer plus the trace together should name
the guilty path before any code is changed.

## C reproducer notes

- The generated code loops (`for (;;)`) when the header said
  `Repeat`; a single quick exit does not mean the bug is fixed.
- A reproducer exercises the kernel it runs on.  Never build or
  run it on the host you are working from: it will crash or
  corrupt that kernel.  Running one belongs in a throwaway VM
  booted from a kernel built at the report's `HEAD commit:`
  with the report's config, which is a separate task this skill
  does not perform.  When the user asks you to run it, say so,
  and offer instead to read the `.syz` program against the
  trace, or to send `#syz test` so syzbot runs it.
