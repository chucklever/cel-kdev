---
name: prose-voice
description: Use when drafting or editing prose written for other developers -- a code comment in any codebase, a commit message in any repository, or a patch series cover letter, version changelog, pull request description, or merge commit message. Carries the voice rules the cel-prose:code-comments, cel-prose:commit-message, cel-prose:cover-letter, and cel-prose:version-changelog skills defer to: mechanism-first description, ASCII and US English, short declarative sentences, and dash discipline. Load it before drafting any of those, and whenever one of those skills points here. Does not govern LLM-facing text such as skill documentation.
---

# Prose voice

Voice rules shared by the prose written for other developers --
code comments in any codebase, commit messages in any repository, and
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
  do." Keep the action in the verb. A nominalization ("performs
  validation of," "does a lookup of," "makes a comparison of")
  buries the action in a noun and demotes the actor to an
  of-phrase; write "validates," "looks up," "compares."
- The subject is the component, not the role it plays in the
  protocol. "The server retries" and "the client sends" name a
  role that any implementation fills, so the reader cannot tell
  which code is meant; in a series that touches both peers, or
  on a host that runs both, not even which side. Name the
  thing: "NFSD," "the NFS client," "svcrdma," "the xprtrdma
  transport," "nfsd4_encode_fattr4()." A role word is right
  only when the sentence is about whatever fills the role, any
  implementation: what an RFC requires, a quotation from one,
  or the peer at the other end of the wire as seen from this
  code ("the client may retry after NFS4ERR_DELAY" in an NFSD
  comment means every client). A sentence about code in this
  tree names that code. The list traffic writes "the server"
  freely; that does not vouch for it as the subject of a
  sentence about this code.
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
  CPU time." "Consumes" used as a noun drew the same reply;
  the noun is "consumer" or "the read side." When unsure
  whether a phrase is coined, grep the subsystem. The corpus
  for that grep is the subsystem's own directories and its list
  traffic as they stand before the patch. On an stg branch that
  means grep the stack base with a pathspec
  (`git grep <term> $(stg id '{base}') -- <subsystem paths>`;
  for NFSD and SUNRPC, `fs/nfsd net/sunrpc include/linux/sunrpc`),
  and search the list archive with semcode's lore_search. Text
  the patch adds, including its own README or Documentation/
  page, does not vouch for a term, and neither does an earlier
  version of the same series on the list; the corpus is what
  other people wrote. An identifier the patch introduces names
  what it names; a descriptive word that appears only in the
  patch's prose is the patch's coinage. If the subsystem's
  existing code and comments do not use the term, and either a
  plain kernel term or the domain's standard term covers the
  same thing, it is coined; the draft uses that term instead,
  even when the coined word is ordinary English. Wire-to-memory
  is "unmarshal" or "decode" in SUNRPC and XDR, never
  "materialize"; a pool under pressure is "exhausted" or
  "oversubscribed", not "over-utilized". A hit elsewhere in the
  tree does not vouch: the scheduler's "over-utilized" is not
  SUNRPC's word. Terminology the subsystem itself uses is not
  coined however unfamiliar it looks, so read its files before
  cutting a term.
- A subsystem's name in prose, and in the subject-line prefix
  of a kernel patch, takes the casing that subsystem's own
  maintainers use in their subject prefixes: NFSD, SUNRPC, NFS
  uppercase; net, tls lowercase. Check `git log --oneline --
  <dir>` when unsure. Module, transport, and directory names
  keep the code's spelling (svcrdma, xprtrdma). Others write
  "nfsd" or "knfsd" for NFSD; do not match them. This overrides
  the rule about taking vocabulary from the subsystem's list
  traffic. Quoted commit subjects keep their original casing.
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
  one. The run-on a maintainer bounces is a sentence past
  roughly 40 words carrying two or more "so"/"because"/"which"
  links. Count them before concluding a long sentence reads
  clearly. A short sentence with two links is usually better
  split, but it is not that fault. A sentence that
  enumerates rather than argues does not count, however long it
  runs. Do not
  bullet-ize reasoning that already reads clearly, and do not
  restructure prose that is already clear.
- Every pronoun points at a named noun. "This fixes it," "this
  is because," and a bare "This" opening a sentence after a
  paragraph of setup leave the reader to guess which of the
  preceding things is meant. "This patch" and "this series"
  name their noun and are fine. Name the antecedent in the
  sentence's own frame: in a comment or a why-paragraph, "the
  loop never exits because the socket stays locked"; in a
  commit message's what-half, the imperative already names
  nothing, so "Retry the send after NFS4ERR_DELAY" replaces
  "This fixes the hang." A "which" that refers back to a whole
  clause is the same fault, and usually the second causal link
  the one-link rule forbids.
- Dashes: do not reach for an em dash when drafting. The first
  choice is always a period. Split the clauses into separate
  sentences and let each one carry its own subject and verb.
  Colons, semicolons, and parentheses are not neutral
  substitutes. A clause bolted on with any of the three is as
  strong an LLM tell as the em dash it replaced, so reserve
  them for the cases a period genuinely cannot handle: a colon
  before a true list, commas around a tight appositive. An
  occasional "--" aside is fine. Density is the tell.
- Kernel maintainers distrust prose that reads as LLM-generated.
  The bullets above are the pass for that; do not load a
  general de-AI skill or fetch a tells catalog while drafting.
  The catalog they draw on, for reference only, is Wikipedia's
  "Signs of AI writing": em-dash overuse, rule-of-three cadence,
  inflated symbolism, negative parallelism ("not X, but Y"), and
  the rest. Consult it, or a skill that packages it such as
  /humanizer, only when a reviewer has flagged a draft as
  LLM-written or the user asks for that audit, and keep this
  file's rules where the two disagree.

## Words to drop

Each term below is a symptom. The rules are the bullets above.
Finding one of these in a draft means re-read the sentence, not
swap the word. If the replacement leaves the sentence otherwise
unchanged, nothing was fixed: the term was standing in for
something the sentence never said, and that omission is what to
repair. Every entry names what the term stands in for, so the
entry is only satisfied when that thing is on the page.

This list is short on purpose. The general catalog of AI
vocabulary is not its job; that is the guide the last bullet
points to. A list long enough to check mechanically will be checked
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
