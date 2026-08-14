---
name: prose-voice
description: Use when drafting or editing prose written for other developers -- a code comment in any codebase, a commit message in any repository, or a patch series cover letter, version changelog, pull request description, or merge commit message. Carries the voice rules the cel-prose:code-comments, cel-prose:commit-message, cel-prose:cover-letter, and cel-prose:version-changelog skills defer to: mechanism-first description, ASCII and US English, short declarative sentences, and dash discipline. Load it before drafting any of those, and whenever one of those skills points here. Does not govern LLM-facing text such as skill documentation.
---

# Prose voice

Voice rules shared by the prose written for other developers --
kernel code comments, commit messages in any repository, and
cover letters with their changelogs. The cel-prose:code-comments,
cel-prose:commit-message, cel-prose:cover-letter, and
cel-prose:version-changelog skills own the per-artifact specifics
(line widths, structure, worked examples) and defer here for the
voice common to all four.
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
- Preserve domain-specific terms. "Quiesce" is not "stop": it
  means refuse new work and wait for in-flight work to drain.
  "Elide" is not "skip": it means omit something that would
  otherwise be emitted. The mechanism picks the word, not the
  register. Do not flatten a precise term to its everyday
  neighbor, and do not reach for the rarer one when the plain
  word is accurate.
- Use the words the subsystem uses: identifiers out of the code,
  and the vocabulary of its own list traffic. Do not coin an
  abstraction to sound precise. "The cap supplies the return
  boundary that a system call would otherwise provide," "the
  kernel receive context," and "costs the caller its own
  scheduler time" all drew "terms no kernel developer would
  use." The words for those things are "the syscall return
  bounds the loop," "process context," and "costs the caller
  CPU time." When unsure whether a phrase is coined, grep the
  subsystem. If neither the code nor the file's existing
  comments use it, and a plain kernel term covers the same
  thing, it is coined. Terminology the subsystem does use is
  not coined however unfamiliar it looks, so read the tree
  before cutting a term.
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
- Cut throat-clearing and hedges that carry no information.
  Test: if removing the phrase preserves the meaning, it was
  filler. "Words to drop" below lists the ones that recur.
- Do not stack more than three nouns in a row. "RPC transport
  reconnect completion handler" makes the reader guess which
  noun modifies which. Break the stack with a preposition or a
  verb: "the completion handler for a transport reconnect."
- Short declarative sentences. A causal chain stays connected:
  "the record delivers no payload, so the loop never exits."
  One link per sentence, though. Spend "so" or "because" once,
  and never hang an aside off a sentence that already carries
  one. A second link is the run-on a maintainer bounces. The
  countable instance is two or more "so"/"because"/"which"
  links in a sentence past roughly 40 words. Count them before
  concluding a long sentence reads clearly. A sentence that
  enumerates rather than argues does not count, however long it
  runs. Do not
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

## Words to drop

Each term below is a symptom. The rules are the bullets above.
Finding one of these in a draft means re-read the sentence, not
swap the word. If the replacement leaves the sentence otherwise
unchanged, nothing was fixed: the term was standing in for
something the sentence never said, and that omission is what to
repair. Every entry names what the term stands in for, so the
entry is only satisfied when that thing is on the page.

Two rules keep this list from becoming a checklist. A term earns
a place only after it has been caught in prose that was about to
be sent to someone. And the general catalog of AI vocabulary is
not this list's job; that is the guide the last bullet points to.
A list long enough to check mechanically will be checked
mechanically, and the failures that draw a maintainer's reply --
run-on causal chains, coined abstractions, explaining a
subsystem to itself -- have no vocabulary to check.

- "Shape," "shaped," figuratively. Stands in for a property that
  was never named: which property of the fix, the patch, the
  path? Name that property. The literal senses stay, as in a
  waveform or a latency distribution.
- "Load-bearing." Asserts that something matters without saying
  what fails without it. Write the consequence: what breaks when
  the line is removed.
- "Honest," "honestly," as framing. Honesty is assumed, and
  labeling one point honest implies the rest are not. State the
  point.
- "It's worth noting," "essentially," "importantly," "in order
  to." Stand in for nothing. Delete the phrase and check that
  the meaning survived; it will.
