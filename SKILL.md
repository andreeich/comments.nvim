---
name: comments
description: Read, act on, and resolve per-line comments authored by the user in comments.nvim. Triggers when a repo contains .comments/comments.json or when the user references "comments.nvim", "in-line review comments", "resolve my comments".
---

# comments.nvim — agent skill

comments.nvim lets the user pin notes to specific lines of source files. Notes
are written to `.comments/comments.json` at the working directory root. They
are intended as durable, machine-readable context: the user expects you to
read them, act on the instruction, and remove the entry once resolved.

## File layout

```
<cwd>/.comments/comments.json
```

Schema (`version` is currently `1`):

```json
{
  "version": 1,
  "comments": [
    {
      "id": "uuid-v4",
      "relpath": "src/foo.ts",
      "line": 42,
      "line_text": "  const x = doThing()",
      "text": "Why is this cast needed?",
      "created_at": "2026-05-19T12:00:00Z"
    }
  ]
}
```

Fields:

- `id` — opaque identifier. **Never modify.** Use it as the key when removing.
- `relpath` — path relative to the JSON file's parent directory (the cwd).
- `line` — 1-indexed line number when the comment was last persisted by nvim.
- `line_text` — literal contents of `line` at write time. Use this to find
  the current location (line numbers drift when files are edited).
- `text` — the user's note. This is the instruction you must satisfy.
- `created_at` — ISO 8601 UTC.

## Resolving a comment

The workflow is fixed:

1. **Locate the anchor.** Read the file at `relpath`. Try matching `line_text`
   first (full-line exact match). If found, use that line number. If not
   found, fall back to `line`. If neither matches anything plausible, ask the
   user before guessing.
2. **Act on `text`.** Treat it as a normal instruction from the user
   (refactor, fix, answer a question via code change, etc.).
3. **Remove the entry.** Once the instruction is satisfied, delete the
   comment from `comments`. Identify it by `id`. Write the updated JSON
   back to `.comments/comments.json`. Preserve `version` and the order of
   remaining entries.

If a comment is asking a question rather than requesting a change, answer it
in your reply and still remove the entry — the user's expectation is that
resolved comments disappear from the file.

## Rules

- **Do not edit other entries.** Touch only the entry you're resolving.
- **Do not invent line numbers** if `line_text` doesn't match. Report
  ambiguity to the user.
- **Preserve the JSON shape.** Keep `version`, keep the top-level
  `comments` array, keep field names. Round-trip safely.
- **One comment per pass when possible.** Resolve, save, move on. Batched
  edits to multiple comments are fine if they're in different files or
  obviously independent — but commit a single coherent change per comment.
- **Don't add new fields** unless the user asks. Stick to the schema.
