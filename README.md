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

- `:CommentAdd` (add/edit a comment on the current line; submit blank to delete)
- `:CommentClear` (remove every comment on the current buffer)

## Suggested keymaps

```lua
vim.keymap.set("n", "dc", function() require("comments").comment() end)
vim.keymap.set("n", "dC", function() require("comments").comment_clear() end)
```

## API

```lua
local c = require("comments")

c.setup(opts)
c.attach(bufnr?)
c.detach(bufnr?)
c.comment()         -- add/edit comment at cursor (blank submit = delete)
c.comment_clear()   -- remove every comment on the current buffer
c.comment_list()    -- { { id, relpath, line, text, created_at } } for pickers
c.render_for(bufnr, relpath) -- render comments into an arbitrary buffer
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
