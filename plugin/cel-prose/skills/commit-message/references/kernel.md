# Linux kernel patches

Read alongside SKILL.md when the commit targets a Linux kernel tree.
The rules in SKILL.md hold; this file states where the kernel departs
from them and what it adds. For a series cover letter use the
cel-prose:cover-letter skill instead, for a "Changes in vN" changelog
cel-prose:version-changelog; for sign-off and patch mechanics,
cel-kdev:stg.

## Subject line

```
subsystem: imperative summary, no trailing period
```

- Lowercase after the prefix. This is the one place the general rule
  inverts: your own repositories capitalize the summary, the kernel
  does not.
- Prefix with the subsystem. Find the prevailing prefix by reading
  `git log --oneline` for the files you touched and match what that
  subsystem already uses (`nfsd:`, `SUNRPC:`, `svcrdma:`). Do not
  invent a new prefix when one is established.
- When `git log --oneline` on the touched files shows no established
  prefix (a new file or subsystem), derive one from the directory or
  nearest parent subsystem rather than dropping it; a prefix-less
  subject reads as unroutable. A kernel patch always carries a
  prefix.

## Body

SKILL.md's why-before-what holds, and so does its length check.
This is not a checklist -- carry the item that exists and leave out
the rest. The kernel asks the body to carry evidence a general
commit log can leave out:

- User-visible impact, even when the bug was found by inspection
  rather than by a report. Most installations run stable or vendor
  trees that cherry-pick, and the stated impact is what routes the
  fix downstream: the provoking circumstances, the dmesg excerpt,
  the corruption, the lockup, the latency spike.
- Numbers behind any claim of improved performance, memory
  footprint, stack usage, or binary size, and the cost paid for
  them. An optimization trades CPU for memory, or one workload for
  another; name the trade so a reviewer can weigh it. Do not claim
  an improvement that has not been measured -- say what is unknown
  instead.
- Backtraces distilled, not pasted. Keep the call chain that shows
  how the code was reached; drop the timestamps, the module list,
  the register and stack dumps, and the rest of the dmesg noise.
- A commit named in the prose carries at least the first twelve
  hex digits of its SHA-1 and its quoted one-line summary, the
  same form the `Fixes:` trailer takes: `Commit 54a4f0239f2e
  ("KVM: MMU: make kvm_mmu_zap_page() return the number of pages
  it actually freed") left the variable unused.` A bare SHA-1
  tells the reader nothing, and a shorter one collides as the
  tree grows.

## Trailers

A single trailer block at the end, no blank lines between trailers.
A trailer is exempt from the body's wrap width and never folds: the
scripts that parse `Fixes:`, `Link:`, and `Closes:` read one line,
so a long quoted subject or URL overruns the margin and stays put.
These are the content trailers you compose:

- `Fixes:` on any bug fix, `Fixes: <12-hex> ("exact subject")`.
  A bug fix corrects a defect that reaches a consumer. Code that is
  wrong on paper but whose error never gets out takes no `Fixes:`.
  The tag is what AUTOSEL and the stable scripts key on, so tagging
  an unreachable correction recruits backports for a non-problem.
  When a real defect should not be backported, the instrument is
  `Cc: <stable+noautosel@kernel.org> # reason`, not omitting the
  tag.
  Do not hand-assemble it; `fixes <sha>` prints the tag on stdout,
  and on stderr warns when <sha> is not in torvalds/master (take
  only the `Fixes:` line). Investigate that warning on a
  mainline-bound fix; on a net-next-based branch it is expected,
  where a Fixes: may name a net-next commit not yet in Linus's
  tree.
- Attribution trailers, ordered above the sign-off:
  `Reported-by:`, `Reviewed-by:`, `Tested-by:`, `Acked-by:`,
  `Suggested-by:`, `Co-developed-by:`. Two rules govern them.

  `Co-developed-by:` denotes authorship, so each one is
  immediately followed by that co-author's own `Signed-off-by:`,
  and the submitter's sign-off comes last. A `Co-developed-by:`
  with no sign-off under it is malformed.

  Every trailer but `Cc:`, `Reported-by:`, and `Suggested-by:`
  needs the named person's explicit permission. Carry a
  `Reviewed-by:`, `Tested-by:`, or `Acked-by:` only when that
  person posted it; never compose one. When a reroll changes the
  patch substantially those tags no longer apply -- drop them, and
  say so below the `---`.
- `Cc: stable@vger.kernel.org` marks a fix for backport.
  `stable-kernel-rules.rst` makes the author adding this tag the
  strongly preferred route, so write it into a patch bound for
  someone else's subsystem. Your own NFSD patches are the
  exception: there you add the tag when applying, so do not put it
  in the message.
- `Link:`/`Closes:` pointing at the lore message or tracker issue
  the change resolves. b4 and the maintainer add a `Link:` to the
  posting on apply, so add one by hand only to cite a specific
  discussion or bug, not the submission itself. A `Reported-by:`
  takes a `Closes:` beneath it naming the report, or a `Link:`
  when the patch fixes only part of what was reported. When the
  report never reached the web the `Reported-by:` stands alone --
  do not manufacture a citation. The URL must be public and must
  resolve; a private tracker is not a citation.

Do not hand-write `Signed-off-by:`. When `stgit.autosign` is set,
`stg new`/`stg import` append it automatically and writing it by hand
duplicates the trailer; when autosign is unset, no sign-off is added
unless the user asks. See cel-kdev:stg for the autosign rules and the
`stg edit` cases that preserve a sign-off the patch already carries.
When present, the sign-off sorts last.

`coding-assistants.rst` states the harder version of that rule: an
AI agent must not add `Signed-off-by:` at all, because only a human
can certify the Developer's Certificate of Origin. The workflow
reason above is a convenience; this one is not negotiable.

The bar is on the agent typing one. A sign-off that
`stgit.autosign` appends comes from the human's configured
identity, and it is that human who certifies the work, so leave
the path alone: do not disable autosign, and do not strip what it
adds.

### Assisted-by

`submitting-patches.rst` and `coding-assistants.rst` ask for an
`Assisted-by: AGENT_NAME:MODEL_VERSION [tools]` trailer on any
patch an advanced coding tool had a meaningful hand in, and
`generated-content.rst` counts a changelog drafted by a generative
AI tool as in scope.

You do not carry the tag on your own patches. The tag is the
submitter's call, and yours is already made -- do not add it, and
do not raise the question on each patch. A contributor's patch that
arrives carrying one keeps it -- do not strip it when applying.

## Examples

A bug fix whose body leads with the symptom and the cause:

```
nfsd: fix use-after-free in nfsd4_encode_fattr4

A client that closes a stateid while another thread is encoding
GETATTR for the same file can free the nfs4_stid out from under the
encoder. The encoder dereferences the stid after the closing thread
has dropped the final reference, so a concurrent CLOSE turns the
GETATTR reply into a read of freed memory.

Hold the stid reference across the encode rather than borrowing the
caller's, so the structure cannot be freed while it is in use.

Fixes: 1a2b3c4d5e6f ("nfsd: encode fattr4 attributes")
Reported-by: Jane Tester <jane@example.org>
Signed-off-by: Chuck Lever <chuck.lever@oracle.com>
```

An optimization with no bug to cite: the body leads with the cost
the change removes and carries no `Fixes:`.

```
SUNRPC: cache the svc_rqst maximum payload at allocation

Every incoming call recomputes the maximum payload size from the
transport's parameters, though the value is fixed for the life of
the svc_rqst. The repeated arithmetic runs on every call to
produce a constant.

Compute the size once when the svc_rqst is allocated and read the
cached value on the receive path.

Signed-off-by: Chuck Lever <chuck.lever@oracle.com>
```

That body claims no speedup, so it owes no numbers: it names the
cost the change removes and stops. A body that does claim one
carries the measurement and the price paid for it.

The `Signed-off-by:` is shown to illustrate the final on-list form.
The stg/b4 workflow appends it (see cel-kdev:stg); do not type it
into the message yourself.
