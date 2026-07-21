---
name: comments
description: Read and resolve per-line comments authored by the user in comments.nvim. Triggers on "read comments", when a repo contains .comments/comments.json, or when the user references "comments.nvim", "in-line review comments", or "resolve my comments".
---

# comments.nvim — agent skill

comments.nvim lets the user pin notes to specific lines of source files. Notes
are written to `.comments/comments.json` at the working directory root. They
are durable, machine-readable context that must be read, addressed, and then
removed.

Comments have two semantic types:

- **Actionable** — requests a code or documentation change. Make the requested
  change, then report what was done.
- **Question** — asks for an explanation or clarification. Answer it in the
  final reply; do not change code unless the question also explicitly requests
  a change.

Infer the type from the comment's wording. If unclear, treat it as actionable
only when a concrete change is requested; otherwise answer it as a question.
Both types are resolved the same way: remove the comment after addressing it.

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
- `text` — the user's note. This is the instruction or question you must
  address.
- `created_at` — ISO 8601 UTC.

## Resolving comments

Process every pending comment unless the user asks for a subset. For each
comment:

1. **Locate the anchor.** Read the file at `relpath`. Match `line_text` first
   (full-line exact match). If found, use that line. If it is not found, fall
   back to `line`. If neither identifies a plausible location, ask the user
   before guessing.
2. **Classify and address it.** For an actionable comment, make the requested
   change. For a question, determine the answer and include it in the final
   reply without making an unrelated code change.
3. **Clean it up.** After the comment has been addressed, delete only that
   entry from `comments`, identified by `id`. Write the updated JSON back to
   `.comments/comments.json`. Preserve `version` and the order of remaining
   entries.

Never leave an addressed actionable or question comment pending.

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
