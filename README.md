# comments.nvim

Per-line notes pinned to source files, intended as durable context for AI
agents and reviewers. Stored as JSON at `<cwd>/.comments/comments.json`,
anchored to lines via extmarks (survives edits across the session; line
numbers are written back on save).

## Setup

```lua
require("comments").setup({
  auto_enable = true, -- attach on BufEnter
})
```

## Commands

- `:CommentAdd` — add/edit a comment on the current line; blank submit deletes
- `:CommentRemove` — remove comment on cursor line, or all comments in `:'<,'>` range
- `:CommentClear` — remove every comment on the current buffer
- `:CommentPreview` — wrapped popup with the full comment on the cursor line
- `:CommentNext` — jump to the next comment in the current buffer
- `:CommentPrev` — jump to the previous comment in the current buffer

## Prompt

Add/edit opens a floating buffer (markdown, wrapped). Multiline supported.

- `<CR>` submit
- `<S-CR>` insert newline (requires terminal with extended keyboard protocol; use `<C-j>` as fallback)
- `<Esc>` / `q` cancel

## Suggested keymaps

```lua
vim.keymap.set("n", "<leader>cc", "<cmd>CommentAdd<cr>",     { desc = "Add/Edit comment" })
vim.keymap.set({ "n", "x" }, "<leader>cr", ":CommentRemove<cr>", { silent = true, desc = "Remove comment(s)" })
vim.keymap.set("n", "<leader>cR", "<cmd>CommentClear<cr>",   { desc = "Clear all comments" })
vim.keymap.set("n", "<leader>cp", "<cmd>CommentPreview<cr>", { desc = "Preview comment" })
vim.keymap.set("n", "]c",         "<cmd>CommentNext<cr>",    { desc = "Next comment" })
vim.keymap.set("n", "[c",         "<cmd>CommentPrev<cr>",    { desc = "Previous comment" })
```

## API

```lua
local c = require("comments")

c.setup(opts)
c.attach(bufnr?)
c.detach(bufnr?)
c.comment()                          -- add/edit at cursor (blank submit = delete)
c.comment_remove({ line1?, line2? }) -- omit for cursor line
c.comment_clear()                    -- remove every comment in current buffer
c.comment_preview()                  -- popup with full comment text
c.comment_next()                     -- jump to the next comment in the current buffer
c.comment_prev()                     -- jump to the previous comment in the current buffer
c.comment_list()                     -- { { id, relpath, line, text, created_at } } for pickers
c.render_for(bufnr, relpath)         -- render comments into an arbitrary buffer
```

## Storage

```json
{
  "version": 1,
  "comments": [
    {
      "id": "uuid",
      "relpath": "src/foo.ts",
      "line": 42,
      "line_text": "  const x = doThing()",
      "text": "Why is this cast needed?",
      "created_at": "2026-05-19T12:00:00Z"
    }
  ]
}
```

## snacks.nvim integration

```lua
vim.keymap.set("n", "<leader>sc", function()
  local c = require("comments")
  local items = vim.tbl_map(function(x)
    return { text = x.text, file = x.relpath, pos = { x.line, 0 }, comment = x }
  end, c.comment_list())

  Snacks.picker.pick({
    source = "comments",
    items = items,
    format = "file",
    preview = function(ctx)
      Snacks.picker.preview.file(ctx)
      vim.schedule(function()
        c.render_for(ctx.buf, ctx.item.file)
      end)
    end,
    confirm = function(picker, item)
      picker:close()
      vim.cmd("edit " .. item.file)
      vim.api.nvim_win_set_cursor(0, item.pos)
    end,
  })
end)
```
