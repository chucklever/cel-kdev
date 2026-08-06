# cel-prose

Voice rules for prose written for other developers: code
comments, commit messages in any repository, and patch series
cover letters. The rules are the ones a kernel maintainer
applies by reflex -- describe mechanism and causation, ASCII
and US English, short declarative sentences, no throat-clearing,
and dash discipline strict enough that the text does not read
as LLM output.

## Skills

### prose-voice

The shared voice. The three skills below own the per-artifact
specifics (line widths, structure, worked examples) and defer
here for what they have in common. The rules do not govern
LLM-facing text such as skill documentation; a commit message
describing a change to that documentation is ordinary prose and
does follow them.

### code-comments

When a comment earns its place, and what it says once it does.
Calibrates voice and verbosity against the code the comment sits
beside, covers API documentation blocks (kernel-doc, rustdoc,
docstrings), and carries a reference of annotated before-and-after
examples. A `references/kernel.md` layer states where Linux
kernel trees depart from the general rules.

### commit-message

Subject-line form, the why-first body, and trailers, for a commit
in any repository. Governs the message text only; the mechanics
of committing and sending belong to `cel-kdev:stg` and
`series-send`. A `references/kernel.md` layer covers the kernel's
subject casing, trailer block, and sign-off ownership.

### cover-letter

The content of a document that introduces a set of changes to the
people who will review them: a kernel series cover letter and its
per-version "Changes in vN" changelog, a GitHub pull request
description, or a merge commit message taking a topic branch.
Where those files live and how a series is sent belongs to
`series-send` and `cel-kdev:b4`.

## Install

```
claude plugin marketplace add chucklever/cel-kdev
claude plugin install cel-prose
```

## Wiring it into CLAUDE.md

A skill applies only when something loads it. The three prose
skills each point here, but prose gets drafted outside them
too, and a pointer in `~/.claude/CLAUDE.md` keeps the mandate
at user-instruction rank rather than skill rank. Add a section
like this:

```markdown
## Prose voice

Prose I write for other developers -- kernel code comments,
commit messages in any repository, and cover letters -- follows
the voice rules in the cel-prose:prose-voice skill. Load that
skill before drafting any of them. The cel-prose:code-comments,
cel-prose:commit-message, and cel-prose:cover-letter skills own
the per-artifact specifics (line widths, structure, worked
examples) and defer to prose-voice for the voice common to all
three. These rules do not apply to LLM-facing text such as skill
documentation; a commit message describing a change to that
documentation is ordinary prose and does follow them.
```

Keeping the rules in the skill rather than in `CLAUDE.md`
means the ~60 lines load when prose is being written instead
of on every session.

## Codex

Claude Code only for now. The `cel-kdev` plugin carries the
`.codex-plugin` manifest and per-skill `agents/openai.yaml`
files that Codex needs; this plugin carries neither.
