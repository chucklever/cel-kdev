---
name: syzbot
description: >-
  Load when the user mentions syzbot or syzkaller, names or
  pastes a "[syzbot]" report, or asks to triage, evaluate,
  fix, or reply to one.  Load it also to send any "#syz"
  command (test, fix, dup, undup, invalid, upstream, set),
  to write the Reported-by, Closes, and Tested-by trailers
  for a bug syzbot found, to fetch a syzbot reproducer or
  kernel config, or to check whether syzbot has closed a
  bug.  Load it also when a crash report or a commit trailer
  carries an address at syzkaller.appspotmail.com, a link to
  syzkaller.appspot.com, or "syz repro:" / "C reproducer:"
  lines, even if the user never says syzbot, and when a lore
  fetch of such a thread answers 403 or the local mirror finds
  no replies -- this skill covers those failure signatures.
---

# syzbot: triaging reports and talking to the bot

syzbot is the reporting front end for syzkaller's continuous
kernel fuzzing.  It mails crash reports to the subsystem lists,
tracks each bug on a dashboard, tests proposed patches on
request, and closes a bug on its own once a commit carrying the
bug's address reaches every tree it fuzzes.  Everything a
maintainer says back to it is a plain-text email whose command
lines start with `#syz`.

Scope of this skill: retrieving and reading a report, fetching
its reproducer and config for reading, the commit trailers a
fix carries, and sending `#syz` commands with `git send-email`.
Running a reproducer is out of scope; do not attempt it.

## Identify the bug first

Every report carries the line

    Reported-by: syzbot+HASH@syzkaller.appspotmail.com

The 20-hex `HASH` is the bug's identity everywhere: it is the
`extid` on the dashboard, the address every `#syz` command
goes to, and the string syzbot searches commit trailers for.
Copy it from the report; never reconstruct or abbreviate it.

| Artifact          | Where                                                   |
| ----------------- | ------------------------------------------------------- |
| Dashboard page    | `https://syzkaller.appspot.com/bug?extid=HASH`          |
| Report Message-ID | in the report header, ends in `@google.com` (newer form `<hex.hex.hex.hex.GAE@google.com>`) |
| Subsystem bug list | `https://syzkaller.appspot.com/upstream/s/<subsystem>` |
| Subsystem names   | `https://syzkaller.appspot.com/upstream/subsystems`, the names `#syz set subsystems:` accepts |
| Reproducer, config | `syz repro:`, `C reproducer:`, `kernel config:` lines in the report |

## Getting the report and its artifacts

Pick the first source that applies.  Save long output to a
scratch file and read it in ranges; a report thread runs to
hundreds of lines.

| Have                    | Use                                                              |
| ----------------------- | ---------------------------------------------------------------- |
| Subject or Message-ID, list is mirrored locally | the `cel-kdev:semcode` skill: `semcode -q "lore -s '<subject>'"`, then `semcode -q "lore -m <msgid> --thread -v"` (there is no bare `lore` binary) |
| Message-ID, any list    | `b4 mbox -o <dir> <msgid>`                                       |
| Message-ID, no b4       | `curl -sA Mozilla 'https://lore.kernel.org/all/MSGID/raw'` (the id bare, no angle brackets) |
| Only the HASH           | `curl -s 'https://syzkaller.appspot.com/bug?extid=HASH'`, then the `/text?tag=` links in it |

The local lore mirror does not index `syzkaller-bugs`, and
today's replies may not be indexed yet; an empty mirror result
is not evidence the thread is empty.  A bare `curl` of
lore.kernel.org answers 403 without a browser User-Agent; pass
`-A Mozilla` or use `b4 mbox`.

The dashboard is plain HTML with no scripting, so `curl` reads
it.  The report's own header links are the shortest path to
artifacts; grep the saved report for `syz repro:`,
`C reproducer:`, and `kernel config:` to get the `?x=<hex>`
values.  All return text/plain.  Run these from the scratch
directory, never from a kernel tree, and name each output
file with `-o`: `curl -O` names the file from the URL path, so
the config lands as `.config` in the current directory and
clobbers a kernel build's config.  Quote each URL; an unquoted
`?` globs and an unquoted `<hex>` is a shell redirection.

    curl -s -o repro.c   'https://syzkaller.appspot.com/x/repro.c?x=HEX'
    curl -s -o repro.syz 'https://syzkaller.appspot.com/x/repro.syz?x=HEX'
    curl -s -o config    'https://syzkaller.appspot.com/x/.config?x=HEX'
    curl -s -o log.txt   'https://syzkaller.appspot.com/x/log.txt?x=HEX'

A `.syz` program is the primary evidence; a C reproducer is a
translation of it.  A report with no reproducer link has no
reproducer, and syzbot cannot test patches for it.
[references/reproducers.md](references/reproducers.md) explains
how to read a `.syz` program and its header line.

Recursion traces repeat one frame hundreds of times.  Find the
repeated frame first, then filter it out to read the rest of
the trace; the repetition itself is a finding, so note the
frame and the depth before dropping it:

    grep -o '[A-Za-z_0-9.]*+0x' report.txt | sort | uniq -c | sort -rn | head
    grep -v '<repeated-symbol>+0x' report.txt

## Commit trailers for the fix

The fix commit carries this block, in this order, above the
Signed-off-by:

    Fixes: <12-hex> ("<original subject>")
    Reported-by: syzbot+HASH@syzkaller.appspotmail.com
    Closes: https://syzkaller.appspot.com/bug?extid=HASH

- `Fixes:` names the commit that introduced the faulty code,
  not the one that introduced the function.  Start from the
  frame the trace blames: `git blame -L <line>,<line> <file>`
  or `git log -L :<function>:<file>` on the crashing path, and
  confirm the candidate adds or changes the lines the fix
  touches.  `git log -S<symbol>` finds where a symbol first
  appeared, which is right only when the bug shipped with it.
  Check `command -v fixes`; when the helper exists,
  `fixes <sha>` formats the line and warns if the sha is not in
  Linus' tree.  When the report names a bisected commit, verify
  it rather than copying it.
- `Closes:` follows `Reported-by:` directly; Documentation/process
  requires the pair to be adjacent, and the dashboard URL is the
  stable form.  Use `Link:` for the lore thread only in addition.
- `Tested-by: syzbot+HASH@...` goes in only after a successful
  `#syz test` result, on its own line directly below `Closes:`.
  syzbot's reply supplies separate `Reported-by:` and
  `Tested-by:` lines; copy them as two lines.
  (`Reported-and-tested-by:` is accepted by checkpatch and
  used by a minority of commits; do not flag it in someone
  else's patch.)
- Sign-off identity comes from git config, not from memory.
- The block above assumes a separate commit introduced the
  bug, which is the normal case.  When the fix is instead
  squashed into the offending commit so the buggy version
  never lands (typical in linux-next), there is no `Fixes:`
  and no earlier commit to report against: omit
  `Reported-by:` and carry the address as `Tested-by:` when a
  `#syz test` of the squashed version came back clean,
  otherwise as `Reviewed-by:` (syzbot matches any trailer
  containing the address).  This does not apply to an
  ordinary fix commit merely because it will be rebased on
  its way to a fuzzed tree.

syzbot matches the `syzbot+HASH@` address in any trailer, so a
commit with these tags closes the bug automatically once it
reaches every fuzzed tree.  Until then the bug stays open and
new crashes with the same signature merge into it.

To answer "has syzbot closed this?", fetch the bug page and
read its `Status:` line.  The value may sit inside an anchor,
so strip the tags rather than stopping at `<`:

    curl -s 'https://syzkaller.appspot.com/bug?extid=HASH' | grep 'Status:' | sed 's/<[^>]*>//g'

`fixed on <date>` means the fix reached every tracked tree;
`closed as dup on`, `closed as invalid on`, and `obsoleted due
to no activity on` are the other closed states.  A status
that starts `upstream: reported` is still open, even when the
page also shows a `Fix commit:` line: that line appears as
soon as a fix is recorded, and its `missing on:` list names
the builds the commit has not reached.  The page's
Discussions list is the authoritative reply list when the
local lore mirror is quiet.

## CRITICAL: `#syz test` goes to syzbot alone

A test request that carries a patch and lands on a
patchwork-backed list (netdev, netfilter-devel, and others) is
ingested as a submission.  Send it To the `syzbot+HASH@`
address with only `syzkaller-bugs@googlegroups.com` in Cc.
Drop every vger and kernel.org list from the reply even though
the report was sent to them.

Every command other than `#syz test` is a reply-all.  Take
the addresses from the report's own `To:` and `Cc:` headers
(the raw message from `b4 mbox` or the lore `/raw` URL):
`syzbot+HASH@` goes in To, and every other address from those
headers plus `syzkaller-bugs@googlegroups.com` goes in Cc, so
the lists and the people already on the thread see the
disposition.

## Commands start a line in the text/plain body

The parser matches `#syz` only at the start of a line in the
`text/plain` part.  A quoted `> #syz` line is ignored and an
HTML-only mail is ignored.

Wrapping matters differently per command.  `#syz fix:`,
`#syz dup:`, and `#syz set` take the rest of one line, so a
title wrapped at 80 columns is silently truncated at the wrap;
emit those on a single unwrapped line however long.
`#syz test:` takes exactly two tokens, a git URL and a branch
or commit hash, and the parser keeps reading following lines
until it has two -- so if the tokens are missing from the
command line it consumes the first two tokens of whatever
comes next, including an inline patch.  Always put both tokens
on the `#syz test:` line itself.  Prose may precede or follow
the command on other lines; wrap prose however you like, but
never break a `#syz` line.

Write the reply file with the platform's file-editing tool or
a quoted heredoc
(`cat <<'EOF'`); an unquoted heredoc expands backticks and `$`
inside a commit title.  Then check that every command line
survived intact before the dry run:

    grep -n '^#syz' reply.txt

Each `#syz fix:` or `#syz dup:` line must end with the full
title, and each `#syz test:` line must carry both the URL and
the ref.

## Before a `#syz test`: choose the form and prove the tree has the bug

Settle these before composing the reply; the header block in
the next section assumes the command line is already decided.

A KMSAN report (`BUG: KMSAN:` in the title) must be tested on
`https://github.com/google/kmsan.git master`; a KCSAN report
cannot be tested at all.

Choose the form of the command:

- Patch not yet on a public branch: bare `#syz test` (no URL,
  no ref) with the patch below the command line.  syzbot
  checks out the *current tip* of the branch the report's
  `git tree:` names, not the report's `HEAD commit:`, and
  applies the patch on top.  When that tip may have moved
  past the guilty commit (linux-next especially), write
  `#syz test: <url> <commit>` with the report's `git tree:`
  URL and `HEAD commit:` hash instead, with the patch below.
- Fix already on a public branch: `#syz test: <url> <ref>`
  with no patch.
- No guilty commit known: let syzbot validate the base first
  by sending `#syz test: <url> <branch>` with no patch.  A
  crash result proves the base reproduces; only then test the
  fix on top of it.  A clean result means that base does not
  reproduce the bug: do not test the fix there; use bare
  `#syz test`, or a commit that does reproduce.

Never name a branch as if it carried the fix when it does
not.  syzbot runs the dashboard's reproducer against whatever
tree is named, so a tree that never had the bug yields a
clean run and a false `Tested-by:`.  The report's
`HEAD commit:` need not be an ancestor of your branch; a
for-next branch based on an -rc tag will not contain a
linux-next or Linus tip, and that is fine.  When the fix
carries a `Fixes:` commit, the branch must contain it:

    git merge-base --is-ancestor <Fixes sha> <branch>

Before any `#syz test:` that names a branch, confirm the
branch is on the public mirror -- kernel.org mirrors lag a
push, and empty `ls-remote` output means the branch is not
there yet:

    git ls-remote <public-git-url> <branch>

To include a patch, export exactly one by name -- a bare
`stg export -s` exports every applied patch:

    stg export -s <patchname>
    git format-patch -1 --stdout <sha>

`git format-patch` output is an mbox message starting with a
`From <sha> ...` line; `stg export` output is a bare
description with `From:`/`Date:` lines after the first blank
line.  Either goes *below* the `#syz test` line, never above
the header block: git send-email takes the first lines of the
file as the headers, so a patch pasted first turns your
header block into body text and loses the recipients.  Paste
the export whole; syzbot ignores everything before the first
`diff --git` line.

Whatever the form, compare the "Tested on:" commit in
syzbot's reply against the report before trusting a clean
result.

## Sending with git send-email

`git send-email` accepts a file whose leading lines are mail
headers, then a blank line, then the body.  Write it to the
scratch directory.  Every value below is a placeholder: take
the hash, the subject, and the Message-ID from the report you
are answering, never from this example.  MSGID is the
report's Message-ID; the angle brackets around it are header
syntax and stay.

    Subject: Re: <the report's exact Subject>
    To: syzbot+HASH@syzkaller.appspotmail.com
    Cc: syzkaller-bugs@googlegroups.com
    In-Reply-To: <MSGID>
    References: <MSGID>

    #syz test: <public-git-url> <branch-or-commit>

For any command other than `#syz test`, the same block but
with the report's full recipient list:

    To: syzbot+HASH@syzkaller.appspotmail.com
    Cc: syzkaller-bugs@googlegroups.com, <every address from the report's To: and Cc:>

    #syz fix: <exact commit title>

The header block supplies the recipients and threading; do
not repeat them as `--to` or `--cc` options, which would
double them.  Always pass `--suppress-cc=body` on both the
dry run and the send, whether or not the body carries a
patch: git send-email otherwise harvests `Cc:`,
`Signed-off-by:`, and other `-by:` addresses out of any
unquoted line in the body -- an inline patch, or the fix's
trailers quoted in your prose -- and puts a
`Cc: stable@vger.kernel.org` or a maintainer's vger list
straight back onto a `#syz test`.  Do not use
`--suppress-cc=all`; it also drops the `Cc:` line in your own
header block.

Dry-run first and show the user the rendered mail, including
the recipient list git prints; confirm it holds only the
addresses you wrote:

    git send-email --dry-run --confirm=always --suppress-cc=body reply.txt

Do not run the real send, regardless of whether your shell
turns out to have a terminal or what `sendemail.confirm` is
set to.  The `--confirm=always` abort is a backstop, not the
rule: without a terminal it dies with "Send this email reply
required", and the flag overrides any config value.  Never
work around it with `--confirm=never`,
`-c sendemail.confirm=...`, `yes |`, a pty wrapper, or by
dropping the flag.  The user's
request to "send" a command is a request to prepare the dry
run, not confirmation to send.  Your last step is to report
the rendered mail and hand the user this exact command to run
in their own terminal, with the scratch path filled in:

    git send-email --confirm=always --suppress-cc=body <path>/reply.txt

syzbot replies in the thread, typically within an hour, with
one of three results: the reproducer still crashes (a fresh
report follows), the build or boot failed (the error follows),
or "the reproducer did not trigger any issue" followed by the
`Reported-by:` and `Tested-by:` lines to copy into the commit.
Each reply ends with a "Tested on:" block naming the commit
and config used; read it before trusting the verdict.

## Command quick reference

| Command | When |
| ------- | ---- |
| `#syz test: <git-url> <branch-or-commit>` | test the tree, optionally with an inline patch |
| `#syz test` | test the current tip of the branch the crash was found on, with an inline patch if any; the form for a patch not yet on a public branch |
| `#syz fix: <exact commit title>` | tell syzbot which commit fixes the bug; resend to correct |
| `#syz dup: <exact title of the other report>` | fold this report into another open one |
| `#syz undup` | make it independent again |
| `#syz invalid` | one-off report; a recurrence opens a new bug |
| `#syz upstream` | release a moderation-queue bug to the lists |
| `#syz unfix` | forget the recorded fix; refused once the bug is closed |
| `#syz set subsystems: <name>` | reassign; names come from the dashboard subsystem list |

[references/commands.md](references/commands.md) carries the
full grammar, the reply shapes, and the constraints on each.

## Choosing the command

- Fix is written and its title is final: send `#syz fix:` with
  the exact commit subject, without any `[PATCH vN]` prefix,
  even before the commit merges.  A commit that carries a
  `syzbot+HASH@` trailer closes the bug on its own, so the
  command is optional there, not wrong; send it when the commit
  lacks the trailer, or when you want the dashboard to name the
  fix before it lands.
- Guilty commit was dropped from a rebuilt tree, so no fix
  commit exists.  Recognize it when the report's `git tree:`
  is linux-next or another rebuilt tree and `git log --oneline
  -S<fragment of the guilty change> <tree-tip>` no longer
  finds the commit.  Wait until syzbot's builds have picked up
  the rebuilt tree -- the bug page's Crashes table shows a
  crash on a commit from the new tree, or its last-crash age
  predates the rebuild -- then `#syz invalid`.  If you cannot
  wait, name a later commit that is in the rebuilt tree with
  `#syz fix:`.
- Two reports, one root cause: reply to the report being folded
  with `#syz dup:` naming the survivor's title without its
  bracketed prefixes.  Test the survivor's fix against the
  duplicate's reproducer first when in doubt.
- Crash was fallout from earlier corruption and will not recur
  (typically `log.txt` shows an earlier, different splat before
  this one, and the bug page shows a single crash):
  `#syz invalid`.  Never use it on a bug that still reproduces
  on a tree syzbot fuzzes; syzbot reopens it as a new bug.
- Report landed in a moderation queue, recognizable by the
  report arriving from
  `syzkaller-upstream-moderation@googlegroups.com` with no
  reproducer link, and the bug is real: `#syz upstream`.

## Common mistakes

- Cc'ing netdev or another patchwork list on a `#syz test`.
- Testing on a tree that never contained the crash.  syzbot
  runs the dashboard's reproducer and config against whatever
  tree is named and reports a clean run as Tested-by, so test
  on a branch that contains the guilty commit.
- Merging the two lines into `Reported-and-tested-by:` in a
  fix you write; keep syzbot's two lines.
- A `#syz fix:` title that differs from the commit subject by
  one character.  syzbot matches the title exactly; send the
  command again with the right title to override.
- Sending `#syz unfix` after the bug closed; it is refused once
  the fix reached every tree.
- Treating a quiet lore mirror as "no replies"; check
  `b4 mbox` or the dashboard's Discussions list.

## References

- [references/commands.md](references/commands.md) -- full
  `#syz` grammar, labels, result mail formats, bisection notes,
  and the dashboard URL patterns and bug-page fields (`Status:`,
  Discussions) that answer "has syzbot closed this?"
- [references/reproducers.md](references/reproducers.md) --
  reading a `.syz` program and its header, C reproducer notes
