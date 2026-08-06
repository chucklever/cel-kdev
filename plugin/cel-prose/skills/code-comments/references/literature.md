# What the literature says about comment voice and verbosity

An annotated bibliography behind the rules in SKILL.md. Empirical
findings (studies with data) are kept distinct from expert opinion
(practitioner maxims), and commonly-repeated-but-weak claims are
flagged. Citation-confidence caveats are at the end; honor them
before quoting a page number.

## What to comment: foundational practitioner guidance (opinion)

**Kernighan & Plauger, _The Elements of Programming Style_,
McGraw-Hill, 1st ed. 1974 / 2nd ed. 1978.** Origin of two canonical
maxims: "Don't comment bad code -- rewrite it" and "Don't just echo
the code with comments -- make every comment count." A third, "Make
sure comments and code agree," anticipates the staleness studies by
thirty years. Prescriptive, not empirical, but the most-cited root
of "comment why, not what."

**McConnell, _Code Complete_, 2nd ed., Microsoft Press, 2004,
ch. 32 "Self-Documenting Code."** Central prescription: "comment at
the level of intent" -- describe purpose, not a paraphrase of the
statements. Argues code-echoing comments are net-negative: they
cost maintenance and drift out of sync. The Pseudocode Programming
Process: write intent-level pseudocode first, fill code beneath it,
and the pseudocode becomes the comments "for free."

**Ousterhout, _A Philosophy of Software Design_, 1st ed. 2018 /
2nd ed. 2021, esp. ch. 13.** The influential modern counterweight
to the "comments are failure" school. Verified quotes: "Comments
should describe things that are not obvious from the code"; "the
overall idea behind comments is to capture information that was in
the mind of the designer but couldn't be represented in the code";
comments "add precision" or "provide information at a higher, more
abstract level... [they] offer intuition." Rebuts self-documenting-
code absolutism: "Some people believe that if code is written well,
it is so obvious that no comments are needed. This is a delicious
myth." Operational redundancy test: if a reader who had never seen
the code could write the comment just from the adjacent code, it
adds nothing.

**Martin, _Clean Code_, Prentice Hall, 2008, ch. 4 "Comments."**
The strongest form of the minimize-comments position: "comments are
always failures" -- we comment only to compensate for failing to
express ourselves in code. Useful taxonomy of Good (intent,
clarification, warning of consequences, TODO, amplification,
public-API docs) vs Bad (redundant, misleading, mandated, journal,
noise, position markers, closing-brace, commented-out code). The
most contested source: widely argued to overstate comments-as-
failure and undervalue rationale.

The live disagreement -- Martin (minimize) vs Ousterhout (write
deliberately) -- is philosophical, not empirical. The empirical
taxonomy work below leans Ousterhout: much real comment content is
genuinely unrecoverable from code.

## Comment staleness and co-evolution (empirical)

**Fluri, Wursch, Gall, "Do Code and Comments Co-Evolve?", WCRE
2007; extended in _Software Quality Journal_ 17(4), 2009.** AST-
level history of three Java systems. Newly added code is barely
commented; only 23%/52%/43% of code changes carried an associated
comment change, but when comments were updated it happened in the
same revision ~97% of the time. The journal extension found the
comment-to-code ratio roughly constant over the long run. Cite
carefully: "comments co-evolve on average" is supported; "therefore
comments stay accurate" is not -- the inconsistency studies refute
the stronger claim.

**Tan, Yuan, Krishna, Zhou, "/* iComment: Bugs or Bad
Comments? */", SOSP 2007.** Checked locking- and call-rule comments
against code in Linux, Mozilla, Wine, Apache. Found 60
inconsistencies; 33 confirmed by developers as bugs or bad
comments. The empirical anchor for "a wrong comment is worse than
no comment."

**Wen, Nagy, Bavota, Lanza, "A Large-Scale Empirical Study on
Code-Comment Inconsistencies", ICPC 2019.** Many inconsistencies
arise when code changes (deprecation, refactor, signature change)
and the now-stale comment is left untouched. Direct support for the
verbosity rule: the more a comment restates specific code details,
the more surface area it exposes to going stale. Intent-level
comments drift less because they are coupled to purpose, not to
exact statements.

## What makes comments useful; self-admitted debt (empirical)

**Padioleau, Tan, Zhou, "Listening to Programmers -- Taxonomies and
Characteristics of Comments in Operating System Code", ICSE 2009.**
Manually classified 1,050 comments from Linux, FreeBSD, OpenSolaris
by what/for-whom/where/when. Core finding: comments predominantly
encode assumptions, intentions, and rationale -- information not
recoverable from code -- rather than restating behavior. The
empirical companion to Ousterhout's "capture the designer's mind."

**Potdar & Shihab, "An Exploratory Study on Self-Admitted Technical
Debt", ICSME 2014.** Read 101,762 comments across four systems;
derived ~62 patterns (TODO, FIXME, HACK, "workaround", "this is
wrong") signalling admitted debt. SATD appears in up to 31% of
files; more-experienced developers introduce most of it; only
26-64% is ever removed. Legitimizes a specific valuable genre: the
honest admission of a known shortcoming -- intent/warning content
code cannot express. Verbosity is justified when it records a real
hazard, wasted when it echoes code.

## Comment density, readability, defects (empirical, but weak)

**Buse & Weimer, "Learning a Metric for Code Readability", _IEEE
TSE_ 36(4), 2010 (conf. ISSTA 2008).** 120 annotators rated 100
snippets; a model on local features predicted human readability
~80% of the time. Relevant caution: the number of comments was a
comparatively weak predictor -- structural features (blank lines,
identifier length, line length) mattered more. Cite precisely: the
study shows comments were a minor feature, not that comments harm
readability.

**FLAG -- "higher comment density lowers defect rate" is NOT
supported.** No credible study establishes a causal or robust
correlational link between comment density and defect rate. The
evidence (Padioleau, Tan, Wen) points to comment _content and
accuracy_ -- intent, rationale, warnings, agreement with code -- as
what carries value, not quantity. Treat any specific "optimal
comment ratio" as folklore.

## Synthesis

- Strongly supported: comments that restate code are low-value and
  a staleness liability (Kernighan & Plauger; McConnell; Martin;
  Ousterhout; mechanism measured by Fluri, Tan, Wen). They earn
  their keep by recording what code cannot show -- intent,
  rationale, assumptions, invariants, hazards (Ousterhout;
  Padioleau; Potdar & Shihab).
- Supported: stale/incorrect comments actively mislead and cause
  bugs, so a wrong comment is worse than none (Tan; Wen).
- Weak/contested: comment quantity as a driver of readability or
  defects. No target ratio is defensible.

## Citation-confidence caveats

- Venue/year/volume for the empirical papers are high confidence;
  exact page ranges for Fluri 2009, Tan 2007, Potdar & Shihab 2014,
  Wen 2019 are moderate -- verify against the publisher before
  formal use.
- Ousterhout quotes are verbatim-verified. Clean Code ch. 4 and
  Code Complete ch. 32 attributions rest on publisher TOCs and
  multiple secondary summaries, not a fresh primary read; treat
  sub-section numbers as directional.
