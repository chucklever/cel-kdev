# Code comments: the author's own samples

Comments added by Chuck Lever's 2024 linux-nfs patches, quoted from
the posted diffs with a few lines of the surrounding added code.
Each names the file and the posting Message-ID. The companion file
[examples.md](examples.md) holds specimens from other maintainers'
code; this one shows the same rules in the author's hand.

Calibration first. Those patches added about 140 distinct comment
blocks, of which around 20 explain a why. Roughly 60 are one-line
labels, about 20 are license or specification boilerplate, and
about 20 are kernel-doc headers; the remainder are neither why
comments nor kernel-doc. The explanatory comment is the exception,
not the rule, and nine of the twenty are quoted below. The
default is no comment; a why comment appears where the code's
choice would otherwise look wrong or arbitrary.

Two house conventions show in the samples. Under net/sunrpc the
block comment opens on the first line, `/* text`, in the networking
style; under fs/nfsd and fs/nfs the opener stands alone. Match the
surrounding file. The kernel-doc return documentation is what the
author has written in these trees: a `Return values:` table with
`%`-prefixed constants, or a two-sentence "Returns zero ...
Otherwise, a negative errno" pair in the description. kernel-doc
recognizes neither as the return section, and `scripts/kernel-doc
-Wreturn` reports every one of them as missing a return
description. New blocks take `Return:`, as references/kernel.md
says, and a table under it is a ReST list, one `* ` item per row:

```
 * Return:
 * * %0: Server returned an NFS4_OK completion status
 * * %-EINPROGRESS: Server returned no completion status
```

Copy the content of the return documentation in the samples below,
not its heading.

## Why comments

### The obvious alternative, and why not

`net/sunrpc/xprtrdma/verbs.c`,
`<20240604194522.10390-6-cel@kernel.org>`

```c
	rpcrdma_regbuf_dma_unmap(req->rl_recvbuf);

	/* The verbs consumer can't know the state of an MR on the
	 * req->rl_registered list unless a successful completion
	 * has occurred, so they cannot be re-used.
	 */
	while ((mr = rpcrdma_mr_pop(&req->rl_registered))) {
```

A reader sees MRs being discarded rather than recycled and asks why.
The comment gives the one fact that forbids recycling.

`fs/nfs/nfs42proc.c`,
`<20241203162908.302354-14-cel@kernel.org>`

```c
	case -NFS4ERR_ADMIN_REVOKED:
	case -NFS4ERR_BAD_STATEID:
	case -NFS4ERR_OLD_STATEID:
		/*
		 * Server does not recognize the COPY stateid. CB_OFFLOAD
		 * could have purged it, or server might have rebooted.
		 * Since COPY stateids don't have an associated inode,
		 * avoid triggering state recovery.
		 */
		task->tk_status = -EBADF;
		break;
```

Every other stateid error in this file goes to state recovery. The
comment says what the server-side causes are and why recovery is the
wrong response for this stateid class.

### Naming an estimate as an estimate

`net/sunrpc/xprtrdma/svc_rdma_transport.c`,
`<170653985002.24162.17277374573743602302.stgit@manet.1015granger.net>`

```c
	/* Arbitrarily estimate the number of rw_ctxs needed for
	 * this transport. This is enough rw_ctxs to make forward
	 * progress even if the client is using one rkey per page
	 * in each Read chunk.
	 */
	ctxts = 3 * RPCSVC_MAXPAGES;
```

`net/sunrpc/xprtrdma/svc_rdma_recvfrom.c`,
`<172658972948.2454.1618005255141213668.stgit@oracle-102.chuck.lever.oracle.com.nfsv4.dev>`

```c
	/* Before trusting the segcount value enough to perform
	 * computation with it, perform a simple range check. This
	 * is an arbitrary but sensible limit (ie, not architectural).
	 */
	if (unlikely(segcount > RPCSVC_MAXPAGES))
		return false;
```

Both say the constant is arbitrary and then say what it guarantees
or what it is not. A future reader who needs to change the number
knows what property to preserve and that no protocol rule pins it.

### Why the arithmetic

`net/sunrpc/xprtrdma/svc_rdma_transport.c`,
`<170653984365.24162.652127313173673494.stgit@manet.1015granger.net>`

```c
	/* The Completion Queue depth is the maximum number of signaled
	 * WRs expected to be in flight. Every Send WR is signaled, and
	 * each rw_ctx has a chain of WRs, but only one WR in each chain
	 * is signaled.
	 */
	newxprt->sc_sq_cq = ib_alloc_cq_any(dev, newxprt, sq_depth + ctxts,
					    IB_POLL_WORKQUEUE);
```

The sum `sq_depth + ctxts` looks like it undercounts, since each
rw_ctx posts several WRs. The comment states the signaling rule that
makes the sum correct.

### Why the wait terminates

`net/sunrpc/xprtrdma/svc_rdma_sendto.c`,
`<170653986907.24162.2435133775108024319.stgit@manet.1015granger.net>`

```c
		if ((atomic_dec_return(&rdma->sc_sq_avail) < 0)) {
			svc_rdma_wake_send_waiters(rdma, 1);

			/* When the transport is torn down, assume
			 * ib_drain_sq() will trigger enough Send
			 * completions to wake us. The XPT_CLOSE test
			 * above should then cause the while loop to
			 * exit.
			 */
			percpu_counter_inc(&svcrdma_stat_sq_starve);
			trace_svcrdma_sq_full(rdma, &cid);
			wait_event(rdma->sc_send_wait,
```

A blocking wait in a teardown-sensitive path. The comment names the
mechanism that guarantees a wakeup and the test that turns the
wakeup into an exit.

### Why the fallthrough

`fs/nfsd/nfs4callback.c`,
`<170620013890.2833.522544267659511118.stgit@manet.1015granger.net>`

```c
	case 1:
		/*
		 * cb_seq_status remains 1 if an RPC Reply was never
		 * received. NFSD can't know if the client processed
		 * the CB_SEQUENCE operation. Ask the client to send a
		 * DESTROY_SESSION to recover.
		 */
		fallthrough;
	case -NFS4ERR_BADSESSION:
		nfsd4_mark_cb_fault(cb->cb_clp, cb->cb_seq_status);
```

The magic value 1 is decoded, the resulting uncertainty stated, and
the recovery it forces named. Sharing the BADSESSION arm then needs
no further defense.

### Specification quoted, then the local consequence

`fs/nfsd/state.h`,
`<20241031134000.53396-17-cel@kernel.org>`

```c
/*
 * RFC 7862 Section 4.8 states:
 *
 * | A copy offload stateid will be valid until either (A) the client
 * | or server restarts or (B) the client returns the resource by
 * | issuing an OFFLOAD_CANCEL operation or the client replies to a
 * | CB_OFFLOAD operation.
 *
 * Because a client might not reply to a CB_OFFLOAD, or a reply
 * might get lost due to connection loss, NFSD purges async copy
 * state after a short period to prevent it from accumulating
 * over time.
 */
#define NFSD_COPY_INITIAL_TTL 10
```

The specification text is quoted with a section number and a `|`
gutter, so a reader can tell the normative words from the
implementation's reasoning. The second paragraph is the gap between
the two and why the constant exists. The value itself is not
justified; it is a tunable, and the name says so.

### The constraint the code enforces

`fs/nfsd/nfs4xdr.c`,
`<20241226162853.8940-3-cel@kernel.org>`

```c
	/*
	 * Splice read doesn't work if encoding has already wandered
	 * into the XDR buf's page array.
	 */
	if (unlikely(xdr->buf->page_len)) {
		WARN_ON_ONCE(1);
		return nfserr_serverfault;
```

One sentence, stating the invariant a WARN guards. Nothing about how
splice read works or why the page array matters; the reader fluent
in XDR buffers has that.

## One-line comments

`net/sunrpc/xprtrdma/svc_rdma_transport.c`,
`<170653984365.24162.652127313173673494.stgit@manet.1015granger.net>`

```c
	/* Every Receive WR is signaled. */
	newxprt->sc_rq_cq = ib_alloc_cq_any(dev, newxprt, rq_depth,
					    IB_POLL_WORKQUEUE);
```

The Receive CQ depth equals the Receive queue depth. The comment is
the one fact that makes that equality correct, and it is a full
sentence with a period.

`fs/nfsd/nfs4xdr.c`,
`<20241226162853.8940-3-cel@kernel.org>`

```c
	/* Reserve space for the eof flag and byte count */
	if (unlikely(!xdr_reserve_space(xdr, XDR_UNIT * 2))) {
```

A label, not a why. It earns its line because `XDR_UNIT * 2` does
not say which two items, and the reservation is filled in far below.

## kernel-doc headers

`fs/nfs/nfs42proc.c`,
`<20241220154227.16873-14-cel@kernel.org>`

```c
/**
 * nfs42_proc_offload_status - Poll completion status of an async copy operation
 * @dst: handle of file being copied into
 * @stateid: copy stateid (from async COPY result)
 * @copied: OUT: number of bytes copied so far
 *
 * Return values:
 *   %0: Server returned an NFS4_OK completion status
 *   %-EINPROGRESS: Server returned no completion status
 *   %-EREMOTEIO: Server returned an error completion status
 *   %-EBADF: Server did not recognize the copy stateid
 *   %-EOPNOTSUPP: Server does not support OFFLOAD_STATUS
 *   %-ERESTARTSYS: Wait interrupted by signal
 *
 * Other negative errnos indicate the client could not complete the
 * request.
 */
static int __maybe_unused
nfs42_proc_offload_status(struct file *dst, nfs4_stateid *stateid, u64 *copied)
```

The header is almost entirely the return contract, because the
callers switch on it and the errnos are mapped from NFS status
codes a caller cannot see. The `OUT:` marker on the output
parameter and the catch-all sentence for unlisted errnos are the
house form; the `Return values:` heading is not, per the intro.

`fs/nfsd/nfs4proc.c`,
`<20241031134000.53396-15-cel@kernel.org>`

```c
/**
 * nfsd4_has_active_async_copies - Check for ongoing copy operations
 * @clp: Client to be checked
 *
 * NFSD maintains state for async COPY operations after they complete,
 * and this state remains in the nfs4_client's async_copies list.
 * Ongoing copies should block the destruction of the nfs4_client, but
 * completed copies should not.
 *
 * Return values:
 *   %true: At least one active async COPY is ongoing
 *   %false: No active async COPY operations were found
 */
bool nfsd4_has_active_async_copies(struct nfs4_client *clp)
```

The body paragraph is the same fact the commit message carries, in
the place a reader of the function will actually see it: the list
holds completed copies too, so a non-empty list does not mean
active. That is the reason the helper exists.

`net/sunrpc/xprtrdma/ib_client.c`,
`<20240604194522.10390-7-cel@kernel.org>`

```c
/**
 * rpcrdma_rn_register - register to get device removal notifications
 * @device: device to monitor
 * @rn: notification object that wishes to be notified
 * @done: callback to notify caller of device removal
 *
 * Returns zero on success. The callback in rn_done is guaranteed
 * to be invoked when the device is removed, unless this notification
 * is unregistered first.
 *
 * On failure, a negative errno is returned.
 */
int rpcrdma_rn_register(struct ib_device *device,
```

The one sentence of body is a guarantee to the caller, which is what
an API header is for. The two-sentence return form is used here
because there is nothing to tabulate; in a new block those two
sentences go under a `Return:` heading.
