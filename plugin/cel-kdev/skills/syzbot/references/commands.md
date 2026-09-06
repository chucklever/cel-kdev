# `#syz` command reference

Source of truth: `docs/syzbot.md` in the syzkaller repository
and `pkg/email/parser.go`.  Re-read them when a command
misbehaves; the grammar below is a distillation.  Both fetch
with a plain `curl` of
`https://raw.githubusercontent.com/google/syzkaller/master/docs/syzbot.md`
and `.../master/pkg/email/parser.go`.

## Parsing rules

- A command is a line beginning with `#syz` followed by a
  space, tab, dash, or colon.  Quoted lines (`> #syz ...`) do
  not match.
- Only the `text/plain` part is parsed.  Quoted-printable and
  multipart mails are decoded; HTML-only mails yield nothing.
- Several commands in one mail are all honoured.
- The first token after `#syz` is the command; a trailing
  colon is accepted for `fix`, `dup`, `test`, `set`, `unset`,
  and `uncc`.
- The sample commands syzbot prints in its own footer
  (`exact-commit-title`, `git://repo/address.git
  branch-or-commit-hash`, `exact-subject-of-another-report`,
  `subsystems: new-subsystem`, `some-label`) are recognised as
  placeholders and discarded, so quoting the footer is
  harmless.
- syzbot identifies the bug by the `syzbot+HASH@` address the
  mail is sent to.  A reply is not required; a fresh mail to
  that address works.

## Commands

| Command | Argument | Notes |
| ------- | -------- | ----- |
| `#syz fix: <title>` | rest of line is the commit title | Any tree counts; send before merge if the title is final.  Send again to override.  Empty title is rejected with "no commit title".  Argument is the rest of one line only; a wrapped title is truncated at the wrap. |
| `#syz unfix` | none | Removes recorded fixing commits.  Refused once the bug is Fixed, meaning the commit reached every tracked tree. |
| `#syz dup: <title>` | title of the surviving report with every bracketed prefix (`[syzbot]`, `[nfs?]`) stripped | Cannot target a bug still in the moderation queue.  Argument is the rest of one line only; a wrapped title is truncated at the wrap. |
| `#syz undup` | none | Makes the report independent again. |
| `#syz invalid` | none | One-off report, for instance fallout from an earlier corruption.  A recurrence opens a new bug. |
| `#syz test: <url> <ref>` | git URL, then branch or commit hash | Exactly two tokens.  The parser reads on into following lines until it has two, so if the tokens are missing it eats the first line of an inline patch.  Reproducer required. |
| `#syz test` | none | Tests the current tip of the branch the crash was found on, not the report's `HEAD commit:`, with the inline or attached patch if any. |
| `#syz upstream` | none | Moderation-queue bugs only; mails the report to the lists. |
| `#syz set subsystems: a, b` | subsystem names from the dashboard list | Reassigns the bug. |
| `#syz set prio: low` | `low`, `normal`, `high` | |
| `#syz set no-reminders` | none | Stops periodic reminder mail for this bug. |
| `#syz unset <label>` | label name | Drops the flag or the label with all its values. |
| `#syz uncc` | none | Removes the sender from this bug's Cc list.  Undocumented; from the parser. |

`regenerate`, `reject`, and `unreject` exist in the parser but
their effect on the bug is undocumented; do not send them.
(`uncc` is likewise parser-only, but its effect is limited to
your own Cc.)

In a monthly subsystem summary mail, commands address a
numbered bug: `#syz set <1> no-reminders`,
`#syz set <2> subsystems: kernfs`.

## Recipients

- `#syz test`: To `syzbot+HASH@syzkaller.appspotmail.com`,
  Cc `syzkaller-bugs@googlegroups.com`, and nothing else.
  Drop every vger and kernel.org list even though the report
  went to them.  This is an absolute rule here.  The upstream
  documentation phrases it as permission ("you may send the
  request only to syzbot") rather than a requirement, but
  patches reaching a patchwork-backed list (netdev,
  netfilter-devel) are ingested as submissions, so treat it
  as required.
- Everything else: reply-all, keeping the report's lists and
  `syzkaller-bugs@googlegroups.com` in Cc so the lists and the
  group archive see the disposition.
- Questions about syzbot itself go to
  `syzkaller@googlegroups.com`.  Moderation-queue reports
  arrive from `syzkaller-upstream-moderation@googlegroups.com`.

## Patch testing

- Eligibility: bugs with a reproducer.  KCSAN bugs cannot be
  tested.  KMSAN bugs must be tested on
  `https://github.com/google/kmsan.git master`.
- Delivery: a unified diff inline below the command line, or as
  a text attachment.  Attachments are tried first, then the
  body.  With no patch, syzbot tests the tree as is.
- Tree: any git URL plus a branch or commit.  syzbot uses the
  newest reproducer and its matching config from the dashboard,
  so a tree that never had the crash produces a false
  Tested-by.
- Turnaround: usually under an hour.  Results are best-effort,
  one reproducer run, not a fuzzing session.

Result mail bodies, verbatim leads:

    syzbot has tested the proposed patch but the reproducer is still triggering an issue:
    <title>
    <report>

    syzbot tried to test the proposed patch but the build/boot failed:
    <error>

    syzbot has tested the proposed patch and the reproducer did not trigger any issue:

    Reported-by: syzbot+HASH@syzkaller.appspotmail.com
    Tested-by: syzbot+HASH@syzkaller.appspotmail.com

Each ends with a "Tested on:" block: commit, git tree, console
output, kernel config, dashboard link, compiler, and either the
patch link or "Note: no patches were applied."

## Fix tracking

- syzbot scans commits in the trees it fuzzes for any trailer
  containing the bug's `syzbot+HASH@` address.  A `Reported-by:`
  is conventional; `Tested-by:` or `Reviewed-by:` with the
  address also matches.
- The exception is a fix folded into the commit that
  introduced the bug, so that the buggy version never reached
  the tree (typical in linux-next).  There is no earlier
  guilty commit for a `Reported-by:` to point at, so the
  documentation recommends `Tested-by:` or `Reviewed-by:`
  carrying the address instead: `Tested-by:` when a
  `#syz test` of the squashed version came back clean,
  `Reviewed-by:` otherwise.  This does not apply to an
  ordinary fix commit merely because it will be rebased on
  its way to a fuzzed tree.
- Once a fixing commit is known, the bug stays open until the
  commit reaches every build on every tracked branch.  Only
  then is it Fixed; later similar crashes open a new bug.
  While open, similar crashes merge into it.
- If the guilty commit was dropped from a rebuilt tree, send
  `#syz invalid` only after syzbot has picked up the new tree
  in every build; otherwise name a later commit with
  `#syz fix:`.

## Bisection

- Cause and fix bisection run only for bugs with reproducers,
  no further back than v4.19.  Each revision is tested ten
  times and one crash marks it bad; any crash counts, not only
  the same crash, so results are best-effort and a single wrong
  decision produces a wrong answer.
- Fix bisection also requires that the bug has not occurred
  for thirty days.  A correct fix-bisection result still needs
  a `#syz fix: <title>` reply to record it.
- "the first bad commit could be any of:" and "the issue happens
  on the oldest tested release" are inconclusive results.

## Dashboard URL patterns

| Path | Content |
| ---- | ------- |
| `/upstream`, `/upstream/fixed`, `/upstream/invalid` | bug lists by state |
| `/upstream/s/<subsystem>` | per-subsystem open bugs |
| `/upstream/subsystems` | subsystem names accepted by `#syz set subsystems:` |
| `/bug?extid=<HASH>` | bug page by external id |
| `/bug?id=<40-hex>` | bug page by internal id, as cited in `.syz` headers |
| `/text?tag=<Tag>&x=<hex>` | raw text; tags `KernelConfig`, `CrashLog`, `CrashReport`, `ReproSyz`, `ReproC`, `ReproLog`, `MachineInfo` |
| `/x/.config?x=`, `/x/repro.c?x=`, `/x/repro.syz?x=`, `/x/log.txt?x=`, `/x/report.txt?x=`, `/x/bisect.txt?x=` | short aliases used in report mail |

A bug page lists `Status:`, `Subsystems:`, `Reported-by:`,
first and last crash age, Discussions (lore thread links), and
a Crashes table with per-crash Config, Log, Report, Syz repro,
and C repro links, plus downloadable `vmlinux`, `bzImage`, and
disk images under `storage.googleapis.com/syzbot-assets/`.

Report mail header lines: `HEAD commit:`, `git tree:`,
`console output:` or `console+strace:`, `kernel config:`,
`dashboard link:`, `compiler:`, `userspace arch:` (i386 means
the C reproducer needs `-m32`), `syz repro:`, `C reproducer:`
(may be marked `[OBSOLETE]`).

## Other facts worth knowing

- Bugs with reproducers go straight to the lists; bugs without
  one wait in the moderation queue, where `fix`, `dup`,
  `invalid`, and `upstream` apply.
- syzbot fuzzes vanilla trees only; every config sets
  `CONFIG_DEBUG_AID_FOR_SYZBOT=y`, a hook for temporary debug
  code in linux-next.
- Reproducers are best-effort.  A report without a reproducer
  link means none exists.
