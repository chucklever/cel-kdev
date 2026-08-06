# Annotated comment specimens from the kernel tree

Real comments, grouped by what they do well (and, at the end,
what to avoid). Paths and line numbers reflect a recent tree and
drift over time; the point is the pattern, not the coordinate.
The strong examples cluster in carefully-maintained code --
kernel/sched/, kernel/locking/, mm/, net/ipv4/, lib/,
arch/x86/. The counter-examples come from the imported e1000
driver, a useful before/after control within one tree.

## 1. Terse invariant / constraint comments

Document one load-bearing fact a future reader cannot see
locally: a caller obligation, a locking rule, a why-not-the-
obvious-thing. One or two lines.

`mm/rmap.c`, before `tlb_ubc->writable = true;`
```c
/*
 * If the PTE was dirty then it's best to assume it's writable. The
 * caller must use try_to_unmap_flush_dirty() or try_to_unmap_flush()
 * before the page is queued for IO.
 */
```
States a caller obligation (flush before IO) invisible from the
local assignment but required for correctness.

`mm/memory.c`, before `print_bad_page_map()`
```c
 * This function must be called during a proper page table walk, as it will
 * re-walk the page table to dump information: the caller MUST prevent page
 * table teardown (by holding mmap, vma or rmap lock) and MUST hold the leaf
 * page table lock.
```
Capitalized MUSTs spell out the exact locks a debug path needs so
it doesn't itself crash.

`mm/rmap.c`, before `mmu_notifier_invalidate_range_start()`
```c
 * Inform secondary MMUs that we are going to convert this PTE to
 * device-exclusive, such that they unmap it now. Note that the
 * caller must filter this event out to prevent livelocks.
```
The trailing clause is load-bearing: omit the filter and the
system livelocks -- unknowable from the call itself.

`kernel/locking/qspinlock.c`, before
`smp_cond_load_acquire(&lock->locked, !VAL)`
```c
 * this wait loop must be a load-acquire such that we match the
 * store-release that clears the locked bit and create lock
 * sequentiality; this is because not all
 * clear_pending_set_locked() implementations imply full barriers.
```
Explains why this barrier flavor is mandatory -- the classic
why-not-the-plain-load.

## 2. "Why" comments: rationale, hazard, erratum, spec

Explain motivation, history, or hazard the code cannot show.

`arch/x86/kernel/apic/apic.c`, hardware erratum
```c
 * Setting APIC_LVT_MASKED (above) should be enough to tell
 * the hardware that this timer will never fire. But AMD
 * erratum 411 and some Intel CPU behavior circa 2024 say
 * otherwise.  Time for belt and suspenders programming: mask
 * the timer _and_ zero the counter registers:
```
Cites a named erratum and dated behavior to justify redundant-
looking code; the memorable voice ("belt and suspenders") earns
its keep.

`net/ipv4/tcp_input.c`, RFC citations for a security mitigation
```c
/* RFC 5961 5.2 [Blind Data Injection Attack].[Mitigation] */
...
/* If the ack includes data we haven't sent yet, drop the
 * segment.  RFC 793 Section 3.9 and RFC 5961 Section 5.2
 * require us to send an ACK back in that case.
 */
```
Ties otherwise-cryptic sequence-number checks to the exact RFC
sections and the attack they defend against.

`mm/gup.c`, abandoned-behavior history
```c
 * We used to let the write,force case do COW in a
 * VM_MAYWRITE VM_SHARED !VM_WRITE vma, so ptrace could
 * set a breakpoint in a read-only mapping of an
 * executable, without corrupting the file (yet only
 * when that file had been opened for writing!).
 * Anon pages in shared mappings are surprising: now
 * just reject it.
```
Records the removed behavior and its motivating use case so nobody
"helpfully" re-adds it.

`mm/mlock.c`, an honest race note
```c
 * This is a little surprising, but quite possible: PG_mlocked
 * must have got cleared already by another CPU.  Could this
 * folio be unevictable?  I'm not sure, but move it now if so.
```
Names the concurrency window and is candid about residual
uncertainty -- more useful than false confidence.

Note on voice: the erratum and race examples read informally
("belt and suspenders", "I'm not sure"). That register is
established in old, high-trust code; it is not a license for new
prose. See the kvm-x86 rule (imperative, no pronouns) in
[documentation.md](documentation.md) -- when in doubt, write the
plainer form.

## 3. Multi-line block comments that earn their length

Reserved for ordering arguments, barrier pairing, and algorithm
rationale that genuinely cannot compress.

`kernel/sched/core.c`, barrier pairing with an interleaving
diagram (in `try_to_wake_up()`)
```c
 * Ensure we load p->on_rq _after_ p->state ...
 *
 * sched_ttwu_pending()			try_to_wake_up()
 *   STORE p->on_rq = 1			  LOAD p->state
 *   UNLOCK rq->lock
 * ...
 * Pairs with the LOCK+smp_mb__after_spinlock() on rq->lock in
 * __schedule().  See the comment for smp_mb__after_spinlock().
```
The two-column store/load timeline makes an unfollowable ordering
argument concrete and names the pairing site. This is the bar a
long comment must clear: it conveys something no reformatting of
the code could.

`kernel/sched/core.c`, a shorter pairing note
```c
 * If we are going to wake up a thread waiting for CONDITION we
 * need to ensure that CONDITION=1 done by the caller can not be
 * reordered with p->state check below. This pairs with smp_store_mb()
 * in set_current_state() that the waiting thread does.
```
Earns its length by naming both ends of the pairing and the exact
reordering it prevents.

## 4. kernel-doc API contract comments

When kernel-doc applies, completeness governs: every parameter, an
explicit `Context:`, enumerated returns.

`lib/idr.c`, `ida_alloc_range()`
```c
/**
 * ida_alloc_range() - Allocate an unused ID.
 * @ida: IDA handle.
 * @min: Lowest ID to allocate.
 * @max: Highest ID to allocate.
 * @gfp: Memory allocation flags.
 * ...
 * Context: Any context. It is safe to call this function without
 * locking in your code.
 * Return: The allocated ID, or %-ENOMEM ... or %-ENOSPC ...
 */
```
Textbook: every parameter, an explicit lock-free `Context:`, and
`%`-escaped error returns.

`kernel/locking/mutex.c`, `mutex_lock_interruptible()`
```c
/**
 * mutex_lock_interruptible() - Acquire the mutex, interruptible by signals.
 * @lock: The mutex to be acquired.
 * ...
 * Context: Process context.
 * Return: 0 if the lock was successfully acquired or %-EINTR if a
 * signal arrived.
 */
```
Concise contract that still states the sleeping context and the
exact interrupted-return code.

## 5. Counter-examples: narrating / restating the obvious

From the imported e1000 driver, which predates strict style
review. Each restates what the code plainly shows.

`drivers/net/ethernet/intel/e1000/e1000_ethtool.c`
```c
for (j = 0; j <= lc; j++) { /* loop count loop */
```
Adds zero information; restates the `for` and reads as a tautology.
(Also a tail comment, which maintainer-tip forbids.)

`drivers/net/ethernet/intel/e1000/e1000_ethtool.c`
```c
time = jiffies; /* set the start time for the receive */
```
Narrates an obvious assignment instead of explaining why a start
time is needed.

`drivers/net/ethernet/intel/e1000/e1000_hw.c`
```c
/* Now enable the transmitter */
```
A "Now do X" caption mirroring the call that follows; the pattern
recurs throughout the file.

`drivers/net/ethernet/intel/e1000/e1000_hw.c`
```c
/* Call a subroutine to configure the link and setup flow control. */
```
Describes the mechanics ("call a subroutine") rather than any
rationale -- the restate-the-code style the guidelines discourage.

The fix for every counter-example is the same: delete it, or
replace it with the one non-obvious fact (a why, a constraint) if
there is one. A comment that survives deletion without loss was
noise.
