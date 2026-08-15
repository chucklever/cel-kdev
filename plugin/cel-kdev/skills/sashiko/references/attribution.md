# Crediting sashiko in a commit message

Loaded from the sashiko skill.  For reading and verifying the
review being credited, see `SKILL.md`.

When a patch exists to address something sashiko flagged,
credit the bot with a trailer pair following the syzbot
precedent:

```
Reported-by: sashiko-bot <sashiko-bot@kernel.org>
Closes: https://sashiko.dev/#/patchset/<cover-msgid>?part=<n>
```

Use `Suggested-by:` (same address) when the bot proposed an
improvement rather than reporting a defect.

The `Closes:` URL is the SPA route, fragile but the only
canonical reference when the review never reached a public
list.  Prefer a `lore.kernel.org/r/<bot-message-id>` URL
when sashiko's `email_policy.toml` routes reviews to the
destination list (i.e., `reply_all = true` for that block).

Avoid `Reviewed-by:` and `Co-developed-by:` for the bot;
these are routinely stripped by maintainers and overstate
the bot's role given the self-reported false-positive rate.

The sender address `sashiko-bot@kernel.org` is greppable
and worth using verbatim so downstream tooling can match
on it.
