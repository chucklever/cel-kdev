# Linux kernel comments

Read alongside SKILL.md when the comment goes in a Linux kernel tree.
Everything in SKILL.md holds; this file states what the kernel adds or
decides differently. For the guidance quoted at length from the
kernel's own documents, see
[documentation.md](documentation.md).

## Mechanics

The two SKILL.md defers to the project on, decided here:

- **Wrap** comment text with `fmt -g 74 -w 74` -- 80 columns minus the
  ` * ` prefix.
- **No tail comments.** They disturb the reading flow; use a
  freestanding comment above the code. The one sanctioned exception is
  C++-style `//` docs on struct members in headers, for compact
  bitfield layouts. (maintainer-tip)

## kernel-doc

The API-documentation exception in SKILL.md governs; this is the
kernel's grammar for it.

A kernel-doc block (`/** */`) is a brief line, then every `@param` in
order, then a `Context:` section recording execution context, sleeping
behavior, and locks taken, released, or required, and finally the
return value. `Return:` goes last. A lock passed as a parameter carries
its ownership on its `@param` line; everything else about locking --
the locks the caller must hold and the locks the function takes and
releases itself -- is one line in `Context:`, never a narration of the
function's own locking through the description.

Every parameter is mandatory and they appear in signature order. A
missing or misnamed one is a `scripts/kernel-doc` warning under
`make W=1`, so never drop a parameter to shorten the block -- SKILL.md's
length budget, redundancy gate, and banned-openings list do not reach
inside it; the "never how" rule and the contract test do.

Required for `EXPORT_SYMBOL*` and module-facing symbols; discretionary
for file-static ones. Some subsystems, KVM among them, deliberately
forbid kernel-doc on internal functions -- check the subsystem before
adding one.

A patch that changes which callers can reach a function re-decides
its comment. When a function becomes static in a .c file and a new
exported function now carries the contract, do not leave two blocks
stating it: keep only what the new block does not say and the code
cannot show, as a plain `/* */` comment that goes through SKILL.md's
gate like any other, and drop the old block outright when nothing
survives that. With no replacement carrying the contract, the block
is discretionary again, as for any file-static function: keep it
where the subsystem allows kernel-doc on internal functions, drop it
where the subsystem forbids one. A function that becomes
`static inline` in a header has not left the API surface: every file
that includes the header is a caller that cannot see the body, and
the block stays. A function that stops being exported but stays
non-static still has callers that cannot see its body; its block
stays. When a function becomes exported, it gains the kernel-doc
requirement and needs the full block. Check this whenever the diff
changes where a function can be called from -- a storage-class
keyword, an `EXPORT_SYMBOL*` line added or removed, or a prototype
entering or leaving a header. A change of export flavor alone,
`EXPORT_SYMBOL` to `EXPORT_SYMBOL_GPL`, is not one.

Judge a kernel-doc block by completeness. Over-commenting applies to
what each line *says*, not to which lines exist: give every parameter a
line, and make the line carry units, ownership, lifetime, or valid
range rather than restating the name and type.

## The always-comment floor

SKILL.md carries the list. Its kernel sources are `4.Coding.rst` and
the tip maintainer handbook, quoted in
[documentation.md](documentation.md). Two entries there are kernel
specifics rather than general practice:

- Every memory barrier takes one line on why it is necessary and, where
  it pairs, what it pairs with. `4.Coding.rst` requires the why-line;
  naming the pairing site is the kernel norm.
- Locking rules for a data structure are stated centrally, and
  `lockdep_assert_held()` in the code beats a `/* caller must hold
  ... */` comment. The assertion enforces what the comment only
  claims, and it cannot go stale silently.
