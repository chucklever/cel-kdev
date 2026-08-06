# Official kernel guidance on code comments

Distilled from the kernel tree's own documentation and tooling.
Each entry gives the source, the load-bearing quotations, and a
one-line gloss. Focus: VOICE (how a comment reads) and VERBOSITY
(how much to write, what to omit). Line numbers drift between
releases; treat them as hints, not anchors.

## 1. Documentation/process/coding-style.rst, "8) Commenting"

The canonical, tree-wide rule.

> Comments are good, but there is also a danger of
> over-commenting. NEVER try to explain HOW your code works in a
> comment: it's much better to write the code so that the
> **working** is obvious, and it's a waste of time to explain
> badly written code.
>
> Generally, you want your comments to tell WHAT your code does,
> not HOW. Also, try to avoid putting comments inside a function
> body: if the function is so complex that you need to separately
> comment parts of it, you should probably go back to chapter 6
> for a while. You can make small comments to note or warn about
> something particularly clever (or ugly), but try to avoid
> excess. Instead, put the comments at the head of the function,
> telling people what it does, and possibly WHY it does it.
>
> When commenting the kernel API functions, please use the
> kernel-doc format. [...] Note that the danger of over-commenting
> applies to kernel-doc comments all the same. Do not add
> boilerplate kernel-doc which simply reiterates what's obvious
> from the signature of the function.

Preferred long-comment form:

```c
/*
 * This is the preferred style for multi-line
 * comments in the Linux kernel source code.
 * Please use it consistently.
 *
 * Description:  A column of asterisks on the left side,
 * with beginning and ending almost-blank lines.
 */
```

On data: "It's also important to comment data [...] use just one
data declaration per line [...] This leaves you room for a small
comment on each item, explaining its use."

Gloss: Comment WHAT and WHY, never HOW; prefer self-evident code;
head-of-function over in-body; over-commenting (kernel-doc
included) is a named danger.

## 2. Documentation/doc-guide/kernel-doc.rst, kernel-doc structure

Which entities to document: every `EXPORT_SYMBOL`/
`EXPORT_SYMBOL_GPL` function should have a kernel-doc comment;
module-facing functions and structs in headers should too.
Non-static routines: "good practice." Static routines:
"recommend[ed] [...] for consistency [...] lower priority and at
the discretion of the maintainer."

Fixed grammar -- brief line, in-order `@param`, blank line, longer
description, then `Context:` and `Return:`:

```c
/**
 * function_name() - Brief description of function.
 * @arg1: Describe the first argument.
 * @arg2: Describe the second argument.
 *
 * A longer description.
 *
 * Context: Describes whether the function can sleep, what locks
 *          it takes, releases, or expects to be held.
 * Return: Describe the return value of function_name.
 */
```

Rules: no blank line between the brief and the args, nor between
args. `Context:` states execution context, sleeping behavior,
and locks taken/released/required, in that order. `Return:` goes last; multi-line return
text needs a ReST list, and any line beginning "phrase:" is
misparsed as a section heading. Structs/unions/enums use the same
shape with `@member:` lines.

Gloss: A rigid, tool-parsed grammar for exported/module-facing
symbols. When kernel-doc applies, completeness governs -- every
param, the return, the calling context -- because the reader is a
caller who cannot see the body.

## 3. Documentation/process/4.Coding.rst, "Documentation"

The clearest verbosity stance in the process docs:

> [...] comments are most notable by their absence. Once again,
> the expectations for new code are higher than they were in the
> past; merging uncommented code will be harder. That said, there
> is little desire for verbosely-commented code. The code should,
> itself, be readable, with comments explaining the more subtle
> aspects.
>
> Certain things should always be commented. Uses of memory
> barriers should be accompanied by a line explaining why the
> barrier is necessary. The locking rules for data structures
> generally need to be explained somewhere. Major data structures
> need comprehensive documentation in general. [Non-obvious]
> "cleanup" needs a comment saying why it is done the way it is.

Gloss: Neither uncommented nor verbose. The always-comment list --
memory barriers (why), locking rules, major data structures,
non-obvious cleanup -- is the concrete floor.

## 4. Documentation/process/maintainer-tip.rst, "Comment style"

The most detailed subsystem style (x86/tip).

- Sentence case: "Sentences in comments start with an uppercase
  letter."
- Larger comments "should be split into paragraphs."
- No tail comments: "Please refrain from using tail comments. Tail
  comments disturb the reading flow in almost all contexts, but
  especially in code. [...] Use freestanding comments instead."
- Exception: "Use C++ style, tail comments when documenting
  structs in headers to achieve a more compact layout and better
  readability" (bitfield members with `//`).
- Comment the important things: "Comments should be added where
  the operation is not obvious. Documenting the obvious is just a
  distraction." The anti-pattern shown is
  `/* Decrement refcount and check for zero */`.
- Prefer assertions to locking comments:
  `lockdep_assert_held(&foo->lock)` in code over
  `/* Caller must hold foo->lock */`.
- "The usage of descriptive function names often replaces these
  tiny comments. Apply common sense as always."

Gloss: Sentence-case paragraphed blocks; no tail comments (except
C++-style header struct members); comment the non-obvious and the
constraints; prefer an assertion or a good name over a comment.

## 5. Documentation/process/maintainer-kvm-x86.rst, "Comments"

The sharpest VOICE guidance in the tree:

> Write comments using imperative mood and avoid pronouns. Use
> comments to provide a high level overview of the code, and/or to
> explain why the code does what it does. Do not reiterate what
> the code literally does; let the code speak for itself. If the
> code itself is inscrutable, comments will not help.

Also: "Except for a handful of special snowflakes, do not use
kernel-doc comments for functions" (KVM's functions are not truly
public). And: do not cite SDM/APM section or table numbers in
comments (they churn); copy the relevant snippet by name instead.
Architectural references belong in changelogs, not comments.

Gloss: Imperative mood, no pronouns, why-not-what, high-level not
literal. A comment cannot rescue inscrutable code.

## 6. scripts/checkpatch.pl, mechanical form enforcement

checkpatch polices form only, never content:

- `C99_COMMENTS` (ERROR): "do not use C99 // comments"; `--fix`
  rewrites `// x` to `/* x */`.
- `BLOCK_COMMENT_STYLE` (WARN): continuation lines need a leading
  `*`; the closing `*/` goes on its own line; align the `*`
  column.
- `SPDX_LICENSE_TAG` (WARN): `/* */` for C sources vs `//` for the
  SPDX identifier line, per file type.
- `CVS_KEYWORD` (WARN): flags `$Id$`-style keywords.

checkpatch strips comment text before its other checks, so wording
and length are exempt -- nothing mechanical judges those.

Gloss: The mechanics (no `//`, `*`-column blocks, standalone `*/`,
SPDX delimiter) are enforced; voice and verbosity are entirely on
the author.

## Cross-source synthesis

VOICE
- WHAT and WHY, never HOW (coding-style, kvm-x86, tip).
- Imperative mood, avoid pronouns, sentence case (kvm-x86, tip).
- Let readable code speak; comments cannot rescue inscrutable code
  (kvm-x86, coding-style, 4.Coding).

VERBOSITY
- Over-commenting is a named danger, kernel-doc included; omit
  boilerplate restating the signature (coding-style).
- "Little desire for verbosely-commented code"; comment only the
  subtle (4.Coding).
- "Documenting the obvious is just a distraction" (tip).
- Always comment: memory barriers (why), locking rules, major data
  structures, non-obvious cleanup (4.Coding); non-obvious
  constraints (tip).
- Prefer a better name or `lockdep_assert_held()` to a tiny or
  locking comment (tip).

FORM (enforced by checkpatch)
- kernel-doc grammar for exported/public APIs; `/* */` not `//`;
  `*`-column blocks with standalone `*/`; no tail comments except
  C++-style struct-member docs in headers (tip).
