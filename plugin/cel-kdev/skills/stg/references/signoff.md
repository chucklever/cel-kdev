# Sign-off identity and fixing a wrong-address trailer

Background: see the `stgit.autosign` pitfall in SKILL.md.
Autosign stamps the `Signed-off-by` from git's effective
`user.email`, which falls back to global config when the repo
has no local identity -- so on a project whose sign-off identity
differs from your global default it silently bakes the wrong
address into the trailer.

## Confirming the right identity

Before the first `stg new`/`stg import` on such a project, check
the address autosign will stamp and confirm it matches how you
sign off *on this project*:

```bash
git config --get user.email   # the address autosign will stamp
```

If you do not know which address that is, ask the user -- do not
infer it from history. Recent sign-offs are a rough hint only; in
a shared repo the most common one is often another contributor's
address, not yours, so never copy it into your own identity:

```bash
git log -20 --format='%(trailers:key=Signed-off-by,valueonly)' \
    | grep . | sort | uniq -c | sort -rn
```

If `user.email` is wrong for this project, set a repo-local
identity before creating any patch:

```bash
git config --local user.email <your-addr>
```

## Correcting a patch already stamped wrong

Once a patch is stamped with the wrong address, a plain
`stg refresh` does not correct it -- the trailer is already
baked into the commit message. Re-edit the message with the
corrected trailer:

```bash
stg edit --file <corrected-msg> <patch>
```

`stg edit --file` does not autosign, so put the corrected
`Signed-off-by` line directly in the message text (see the
`stg edit` exception in SKILL.md). Every patch at or above the
edited one gets a new SHA.
