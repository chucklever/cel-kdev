# Commit messages: the author's own samples

Verbatim commit messages from Chuck Lever's 2024 linux-nfs postings,
chosen to show the voice the skill describes as it actually lands on
the list. Each carries its posting Message-ID for provenance. The
`From:` export line is dropped; trailers are kept so the on-list form
is visible.

These are the postings as sent, not edited to the skill. Where a
sample's wording departs from cel-prose:prose-voice or from
SKILL.md, the rule governs the draft; the sample is evidence for
length, paragraph order, and how much a why says, not for the
phrasing that carries it. Each annotation names the departure, so
an unmarked construction is one to copy.

These are kernel postings. What transfers to any repository is the
body length, the why-then-what order, and the sentence register.
What does not: the trailer block, the `Fixes:`-form commit
citation, and the RFC references. Those follow references/kernel.md
in a kernel tree and the project's own `git log` elsewhere, and
most of the author's non-kernel repositories carry none of them.

Read the word counts as the calibration, and calibrate on the
number, not on the set. The typical body is 40 to 90 words, and
five of the seven samples fall there. Two do not: sample 6 runs to
375 because the bug takes that many words to trace, and sample 7 to
257 because it has to say why no correct estimate exists before it
can defend an arbitrary one. In neither does a sentence describe
the fix. The long ones show when length is earned, not a wider
norm; the short ones are the norm.

Two shapes were deliberately left out. A body that pastes a 25-line
journal excerpt and a line-numbered source listing: references/
kernel.md says distill, do not paste, and the excerpt belongs in
the bug report it answers. And a body that narrates how the author
found the bug: the tracepoints enabled, the hypotheses tried, the
run that finally showed it. The symptom in one sentence is the
report and stays, as in sample 2; the sequence of steps that led to
it is the narrative and goes, because it tells the reader where the
author went, not what the reader needs to judge the fix. Both
shapes exist in the corpus; neither is the form to imitate.

## 1. The norm: current behavior, why it is wrong, stop

2024-10-31, `<20241031134000.53396-15-cel@kernel.org>`, 65 words.

```
NFSD: Block DESTROY_CLIENTID only when there are ongoing async COPY operations

Currently __destroy_client() consults the nfs4_client's async_copies
list to determine whether there are ongoing async COPY operations.
However, NFSD now keeps copy state in that list even when the
async copy has completed, to enable OFFLOAD_STATUS to find the
COPY results for a while after the COPY has completed.

DESTROY_CLIENTID should not be blocked if the client's async_copies
list contains state for only completed copy operations.

Signed-off-by: Chuck Lever <chuck.lever@oracle.com>
```

Paragraph one is the code as it stands and the fact that makes it
wrong. Paragraph two is the required behavior. Nothing describes the
change itself; the diff does that. No `Fixes:`: the check went
stale in an earlier patch of this same series, and an unmerged
patch has no commit for the tag to name. The "Currently" opener is
the older habit: the body's default frame is the tree as it
stands, so SKILL.md drops the marker, and the sentence stands
without it.

## 2. Bug fix: symptom, mechanism, `Fixes:`

2024-01-26, `<170629111684.20612.8595881042301584822.stgit@manet.1015granger.net>`,
90 words.

```
NFSD: Reset cb_seq_status after NFS4ERR_DELAY

I noticed that once an NFSv4.1 callback operation gets a
NFS4ERR_DELAY status on CB_SEQUENCE and then the connection is lost,
the callback client loops, resending it indefinitely.

The switch arm in nfsd4_cb_sequence_done() that handles
NFS4ERR_DELAY uses rpc_restart_call() to rearm the RPC state machine
for the retransmit, but that path does not call the rpc_prepare_call
callback again. Thus cb_seq_status is set to -10008 by the first
NFS4ERR_DELAY result, but is never set back to 1 for the retransmits.

nfsd4_cb_sequence_done() thinks it's getting nothing but a
long series of CB_SEQUENCE NFS4ERR_DELAY replies.

Fixes: 7ba6cad6c88f ("nfsd: New helper nfsd4_cb_sequence_done() for processing more cb errors")
Reviewed-by: Jeff Layton <jlayton@kernel.org>
Signed-off-by: Chuck Lever <chuck.lever@oracle.com>
```

Sentence one is the observable symptom. Its opener, "I noticed
that", is the author narrating, and the sentence loses nothing
without it: "Once an NFSv4.1 callback operation gets ...". Copy
the content of the sentence, not its first three words; the
symptom in one sentence is the report, and where the narrative of
finding it would begin is where the excluded shape begins. The
middle paragraph is the
mechanism, named by function and by the value that goes stale. The
last line is the consequence in the code's own terms. The fix is
not described: the subject line already says it.

## 3. Precedent instead of argument

2024-01-29, `<170653984365.24162.652127313173673494.stgit@manet.1015granger.net>`,
63 words.

```
svcrdma: Use all allocated Send Queue entries

For upper layer protocols that request rw_ctxs, ib_create_qp()
adjusts ib_qp_init_attr::max_send_wr to accommodate the WQEs those
rw_ctxs will consume. See rdma_rw_init_qp() for details.

To actually use those additional WQEs, svc_rdma_accept() needs to
retrieve the corrected SQ depth after calling rdma_create_qp() and
set newxprt->sc_sq_depth and  newxprt->sc_sq_avail so that
svc_rdma_send() and svc_rdma_post_chunk_ctxt() can utilize those
WQEs.

The NVMe target driver, for example, already does this properly.

Fixes: 26fb2254dd33 ("svcrdma: Estimate Send Queue depth properly")
Signed-off-by: Chuck Lever <chuck.lever@oracle.com>
```

The core API's behavior is stated and a pointer given for the
details, rather than the details being reproduced. The closing line
cites another in-tree consumer as the precedent, which settles the
question of whether this is the intended usage in one sentence.

## 4. Behavior change with no bug: cite the origin, no `Fixes:`

2024-06-25, `<20240625200204.276770-7-cel@kernel.org>`, 83 words.

```
nfs/blocklayout: Report only when /no/ device is found

Since commit f931d8374cad ("nfs/blocklayout: refactor block device
opening"), an error is reported when no multi-path device is found.
But this isn't a fatal error if the subsequent device open is
successful. On systems without multi-path devices, this message
always appears whether there is a problem or not.

Instead, generate less system journal noise by reporting an error
only when both open attempts fail. The new error message is more
actionable since it indicates that there is a real configuration
issue to be addressed.

Reviewed-by: Christoph Hellwig <hch@lst.de>
Reviewed-by: Benjamin Coddington <bcodding@redhat.com>
Signed-off-by: Chuck Lever <chuck.lever@oracle.com>
```

The commit that introduced the behavior is named in the body, in
`Fixes:` form, but there is no `Fixes:` trailer. The test in
references/kernel.md is whether a defect reaches a consumer: the
message was accurate on the multi-path systems the cited commit
was written for, and this change narrows a reporting policy rather
than correcting wrong output. Whether stable should carry a change
is never the reason to omit the tag; `Cc: stable+noautosel` is the
instrument for that. The second paragraph states the new behavior
and the one reason it is better.

## 5. The spec permits it

2024-12-20, `<20241220154227.16873-10-cel@kernel.org>`, 37 words.

```
NFS: CB_OFFLOAD can return NFS4ERR_DELAY

RFC 7862 permits the callback service to respond to a CB_OFFLOAD
operation with NFS4ERR_DELAY. Use that instead of
NFS4ERR_SERVERFAULT for temporary memory allocation failure, as that
is more consistent with how other operations report memory
allocation failure.

Signed-off-by: Chuck Lever <chuck.lever@oracle.com>
```

Two sentences: what the specification allows, and the consistency
argument for using it. This is as short as a body gets while still
carrying a why.

## 6. Earned length: a causal chain that needs every link

2024-12-26, `<20241226162853.8940-2-cel@kernel.org>`, 375 words.

```
NFSD: Encode COMPOUND operation status on page boundaries

J. David reports an odd corruption of a READDIR reply sent to a
FreeBSD client.

xdr_reserve_space() has to do a special trick when the @nbytes value
requests more space than there is in the current page of the XDR
buffer.

In that case, xdr_reserve_space() returns a pointer to the start of
the next page, and then the next call to xdr_reserve_space() invokes
__xdr_commit_encode() to copy enough of the data item back into the
previous page to make that data item contiguous across the page
boundary.

But we need to be careful in the case where buffer space is reserved
early for a data item whose value will be inserted into the buffer
later.

One such caller, nfsd4_encode_operation(), reserves 8 bytes in the
encoding buffer for each COMPOUND operation. However, a READDIR
result can sometimes encode file names so that there are only 4
bytes left at the end of the current XDR buffer page (though plenty
of pages are left to handle the remaining encoding tasks).

If a COMPOUND operation follows the READDIR result (say, a GETATTR),
then nfsd4_encode_operation() will reserve 8 bytes for the op number
(9) and the op status (usually NFS4_OK). In this weird case,
xdr_reserve_space() returns a pointer to byte zero of the next buffer
page, as it assumes the data item will be copied back into place (in
the previous page) on the next call to xdr_reserve_space().

nfsd4_encode_operation() writes the op num into the buffer, then
saves the next 4-byte location for the op's status code. The next
xdr_reserve_space() call is part of GETATTR encoding, so the op num
gets copied back into the previous page, but the saved location for
the op status continues to point to the wrong spot in the current
XDR buffer page because __xdr_commit_encode() moved that data item.

After GETATTR encoding is complete, nfsd4_encode_operation() writes
the op status over the first XDR data item in the GETATTR result.
The NFS4_OK status code (0) makes it look like there are zero items
in the GETATTR's attribute bitmask.

The patch description of commit 2825a7f90753 ("nfsd4: allow encoding
across page boundaries") [2014] remarks that NFSD "can't handle a
new operation starting close to the end of a page." This bug appears
to be one reason for that remark.

Reported-by: J David <j.david.lists@gmail.com>
Closes: https://lore.kernel.org/linux-nfs/3998d739-c042-46b4-8166-dbd6c5f0e804@oracle.com/T/#t
Tested-by: Rick Macklem <rmacklem@uoguelph.ca>
Reviewed-by: NeilBrown <neilb@suse.de>
Signed-off-by: Chuck Lever <chuck.lever@oracle.com>
```

The order is report, general mechanism, the hazard that mechanism
creates, the one caller that trips it, the exact byte layout that
triggers it, the corruption that results, and a line of archaeology
tying it to a ten-year-old remark. Each paragraph is one step and
the next depends on it. Not one sentence describes the patch. When
a body has to be this long, this is why: the reader cannot judge the
fix without the chain, and the chain cannot be cut.

## 7. Admitting an estimate is arbitrary

2024-02-04, `<170708861688.28128.16380294131274226696.stgit@bazille.1015granger.net>`,
257 words.

```
svcrdma: Increase the per-transport rw_ctx count

rdma_rw_mr_factor() returns the smallest number of MRs needed to
move a particular number of pages. svcrdma currently asks for the
number of MRs needed to move RPCSVC_MAXPAGES (a little over one
megabyte), as that is the number of pages in the largest r/wsize
the server supports.

This call assumes that the client's NIC can bundle a full one
megabyte payload in a single rdma_segment. In fact, most NICs cannot
handle a full megabyte with a single rkey / rdma_segment. Clients
will typically split even a single Read chunk into many segments.

The server needs one MR to read each rdma_segment in a Read chunk,
and thus each one needs an rw_ctx.

svcrdma has been vastly underestimating the number of rw_ctxs needed
to handle 64 RPC requests with large Read chunks using small
rdma_segments.

Unfortunately there doesn't seem to be a good way to estimate this
number without knowing the client NIC's capabilities. Even then,
the client RPC/RDMA implementation is still free to split a chunk
into smaller segments (for example, it might be using physical
registration, which needs an rdma_segment per page).

The best we can do for now is choose a number that will guarantee
forward progress in the worst case (one page per segment).

At some later point, we could add some mechanisms to make this
much less of a problem:
- Add a core API to add more rw_ctxs to an already-established QP
- svcrdma could treat rw_ctx exhaustion as a temporary error and
  try again
- Limit the number of Reads in flight

Signed-off-by: Chuck Lever <chuck.lever@oracle.com>
```

The body says outright that the new number is a worst-case bound
and that a correct estimate is not available, then lists what would
make the bound unnecessary. A reviewer who would object "this is
just a bigger magic number" finds the objection already answered.
The list of deferred work is the only bulleted list in the sample
set. It passes SKILL.md's rule because it enumerates independent
options, none of which the body argues for; the reasoning that
makes the bound necessary stays in the prose above it.
