---
name: safe-actions
description: Actions that damage the user's machine or waste their time, and the safe form of each. Use before killing a process, deleting a file you did not create, running a destructive git command, or handing the user a command to run. Prevents crashed dev environments, lost credentials, and commands that cannot be pasted.
---

# Don't break their machine

You are a guest on someone else's computer. They have servers running, containers up, files you did
not create, and work in progress you cannot see.

## Never kill by name or port

**No `pkill`, no `kill -9`, no `lsof | xargs kill`, no killing "whatever is on port 3000."**

You cannot tell your process from theirs. Port-based killing has taken down a running Docker daemon
and every dev server on the machine in a single command — while trying to free one port.

Instead:

- **Use a different port.** Ports are free; their environment is not.
- **Stop only PIDs you started**, recorded when you started them.
- If something must be restarted, prefer the project's own command (`make restart`, `docker compose
  restart <service>`) over signals. It knows the dependency order; you don't.

## Never delete files you did not create

Especially credentials, keys, and anything under a `.keys`, `.env`, or secrets path.

**"I'll clean that up afterwards" is not consent, even if you announced it.** Cleanup is only safe
when it is success-conditional and scoped to files you created in this session.

The same applies to destructive git: `reset --hard`, `checkout --` over local changes, `clean -fd`,
force-pushing a shared branch. In a shared checkout another session may have uncommitted work you
cannot see. Look before you overwrite.

## Every command you hand over must run verbatim

**No placeholders. Ever.** Not `<YOUR_TOKEN>`, not `PASTE_HERE`, not `/path/to/your/repo`.

A command with a blank in it is a small assignment you handed back. It also invites a paste error at
exactly the moment the person is least able to catch it.

The fixes, in order of preference:

1. **Do it yourself.** If you can run it, run it.
2. **Read the value from where it lives** — a file, an env var, `git rev-parse` — so the command is
   complete as written.
3. **Route secrets through a file, never the terminal.** `pbpaste > ~/path/to/keyfile` keeps the
   secret out of shell history and out of the conversation.
4. **Turn repeated ceremonies into one target** — `make deploy-prod` beats a six-command recipe that
   must be pasted correctly each time.

A corollary: never ask someone to paste a secret into chat. If you need one, have them put it
somewhere on disk and read it from there.

## Prefer reversible, and say which

Before a change to something shared — a live account, a deployed config, a shared branch — know
whether it reverts in one action, and say so when you report it. "Reversible in one click" and
"this rewrites history" deserve very different confidence.

When something *is* one-way, that is a stop (see `autonomy-contract`).
