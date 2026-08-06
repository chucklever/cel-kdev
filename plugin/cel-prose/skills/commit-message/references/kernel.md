# Linux kernel patches

Read alongside SKILL.md when the commit targets a Linux kernel tree.
The rules in SKILL.md hold; this file states where the kernel departs
from them and what it adds. For a series cover letter or a "Changes in
vN" changelog use the cel-prose:cover-letter skill instead; for
sign-off and patch mechanics, cel-kdev:stg.

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

## Trailers

A single trailer block at the end, no blank lines between trailers.
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
- Attribution trailers (`Reported-by:`, `Reviewed-by:`,
  `Tested-by:`, `Co-developed-by:`), ordered above the sign-off.
- `Cc: stable@vger.kernel.org` marks a fix for backport. The
  maintainer adds it when applying the patch; do not write it in
  yourself.
- `Link:`/`Closes:` pointing at the lore message or tracker issue
  the change resolves. b4 and the maintainer add a `Link:` to the
  posting on apply, so add one by hand only to cite a specific
  discussion or bug, not the submission itself.

Do not hand-write `Signed-off-by:`. When `stgit.autosign` is set,
`stg new`/`stg import` append it automatically and writing it by hand
duplicates the trailer; when autosign is unset, no sign-off is added
unless the user asks. See cel-kdev:stg for the autosign rules and the
`stg edit` cases that preserve a sign-off the patch already carries.
When present, the sign-off sorts last.

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

The `Signed-off-by:` is shown to illustrate the final on-list form.
The stg/b4 workflow appends it (see cel-kdev:stg); do not type it
into the message yourself.
