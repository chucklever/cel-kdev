---
name: prose-voice
description: Use when drafting or editing prose written for other developers -- a code comment in any codebase, a commit message in any repository, or a patch series cover letter, pull request description, or merge commit message. Carries the voice rules the cel-prose:code-comments, cel-prose:commit-message, and cel-prose:cover-letter skills defer to: mechanism-first description, ASCII and US English, short declarative sentences, and dash discipline. Load it before drafting any of those, and whenever one of those skills points here. Does not govern LLM-facing text such as skill documentation.
---

# Prose voice

Voice rules shared by the prose written for other developers --
kernel code comments, commit messages in any repository, and
cover letters. The cel-prose:code-comments,
cel-prose:commit-message, and cel-prose:cover-letter skills own
the per-artifact specifics (line widths, structure, worked
examples) and defer here for the voice common to all three.
These rules do not apply to LLM-facing text such as skill
documentation; a commit message describing a change to that
documentation is ordinary prose and does follow them.

- Describe mechanism and causation: what happens, in what order,
  why. Make the component the subject ("the encoder drops the
  reply"), not "we," and not what the code "wants" or "tries to
  do."
- ASCII only. US English spelling ("recognize," "behavior,"
  "serialize," not "recognise"/"behaviour"/"serialise"). Single
  blank between sentences. Text quoted from RFCs or upstream
  sources keeps its original spelling.
- Preserve domain-specific terms: "quiesce" is not "stop,"
  "elide" is not "skip."
- Use the words the subsystem uses: identifiers out of the code,
  and the vocabulary of its own list traffic. Do not coin an
  abstraction to sound precise. "The cap supplies the return
  boundary that a system call would otherwise provide," "the
  kernel receive context," and "costs the caller its own
  scheduler time" all drew "terms no kernel developer would
  use." The words for those things are "the syscall return
  bounds the loop," "process context," and "costs the caller
  CPU time."
- Subsystem names in prose take their uppercase form: NFSD,
  SUNRPC, NFS. Others write "nfsd" or "knfsd"; do not match
  them. This overrides the preceding rule about taking
  vocabulary from the subsystem's list traffic. Quoted commit
  subjects keep their original casing.
- Write for a reader fluent in the subsystem. Do not explain its
  own mechanics back to it. A paragraph deriving how
  cond_resched() in __release_sock() lets a syscall path
  reschedule tells netdev what netdev wrote. A slip in that
  derivation is what draws the reply. State the change and the
  constraint it operates under, then stop.
- Cut throat-clearing and hedges that carry no information
  ("it's worth noting," "essentially," "importantly," "in order
  to"). Test: if removing the phrase preserves the meaning, it
  was filler.
- Drop "honest"/"honestly" as a framing word: no "the honest
  upshot," "to be honest," "honest synthesis." Honesty is
  assumed; labeling a point honest adds noise and implies the
  rest might not be. State the point directly.
- Short declarative sentences. A causal chain stays connected:
  "the record delivers no payload, so the loop never exits."
  One link per sentence, though. Spend "so" or "because" once,
  and never hang an aside off a sentence that already carries
  one. A second link is the run-on a maintainer bounces. Do not
  bullet-ize reasoning that already reads clearly, and do not
  restructure prose that is already clear.
- Dashes: do not reach for an em dash when drafting. The first
  choice is always a period. Split the clauses into separate
  sentences and let each one carry its own subject and verb.
  Colons, semicolons, and parentheses are not neutral
  substitutes. A clause bolted on with any of the three is as
  strong an LLM tell as the em dash it replaced, so reserve
  them for the cases a period genuinely cannot handle: a colon
  before a true list, commas around a tight appositive. An
  occasional "--" aside is fine. Density is the tell.
- Kernel maintainers increasingly distrust prose that reads as
  LLM-generated. For the full catalog of tells to avoid --
  em-dash overuse, rule-of-three cadence, inflated symbolism,
  negative parallelism ("not X, but Y"), and the rest -- see
  Wikipedia's "Signs of AI writing", or a third-party skill that
  packages it, such as /humanizer.
