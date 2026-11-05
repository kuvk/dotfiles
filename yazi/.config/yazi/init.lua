-- Status line drawn like the Neovim lualine: a bold mode bubble that flows
-- into a secondary block (size, name), plain readable text in the middle
-- (counts, date, permissions), then a secondary block (percent) flowing into
-- a bold position bubble. Rounded separators only between blocks, none inside
-- them. Based on yaziline (llanosrocas/yaziline.yazi, MIT), built in so no
-- plugin is needed. Colors come from theme.toml (theme-set.py).

-- Nerd Font glyphs by code point, so editors can't mangle them
local sep = {
  left = "\u{e0b6}",  -- rounded, opening to the right
  right = "\u{e0b4}", -- rounded, closing to the right
}
local select_symbol = "\u{f4a7}"
local yank_symbol = "\u{f0190}"
local name_max = 24 -- truncate names longer than this
local name_keep = 6 -- characters kept on each side

-- Section B/Y background, like lualine's (surface0 in Catppuccin)
local function secondary()
  return th.tabs.inactive:bg() or "darkgray"
end

-- Text on the bubbles
local function mask()
  return th.which.mask:bg() or "black"
end

-- Section C text: readable but quieter than the blocks (overlay1)
local function muted()
  return th.mgr.border_style:fg() or "gray"
end

local function utf8_sub(str, i, j)
  local s = utf8.offset(str, i)
  local e = j and (utf8.offset(str, j + 1) - 1) or #str
  if not s or not e then
    return ""
  end
  return string.sub(str, s, e)
end

local function truncate(name)
  local base, ext = name:match("^(.+)(%.[^%.]+)$")
  base, ext = base or name, ext or ""
  if utf8.len(base) > name_max then
    base = utf8_sub(base, 1, name_keep) .. "..." .. utf8_sub(base, -name_keep)
  end
  return base .. ext
end

function Header:count()
  return ui.Line({})
end

-- A: bold mode bubble, flowing into the secondary block
function Status:mode()
  local mode = tostring(self._tab.mode):upper()
  local main = self:style().main:bg()
  return ui.Line({
    ui.Span(sep.left):fg(main),
    ui.Span(" " .. mode .. " "):fg(mask()):bg(main):bold(),
    ui.Span(sep.right):fg(main):bg(secondary()),
  })
end

-- B: size and name on the secondary block, closed with a curve.
-- yazi calls the size component `length` (`size` in older versions).
function Status:length()
  local h = self._current.hovered
  local main = self:style().main:bg()
  return ui.Span(" " .. ya.readable_size(h and h.cha.len or 0) .. " "):fg(main):bg(secondary())
end

Status.size = Status.length

function Status:name()
  local h = self._current.hovered
  local main = self:style().main:bg()
  return ui.Line({
    ui.Span(" " .. (h and truncate(h.name) or "Empty dir") .. " "):fg(main):bg(secondary()),
    ui.Span(sep.right):fg(secondary()),
  })
end

-- C (left): selected and yanked counts
function Status:files()
  local yanked = #cx.yanked
  local selected = #cx.active.selected
  local yank_color = cx.yanked.is_cut and th.mgr.count_cut:bg() or th.mgr.count_copied:bg()
  return ui.Line({
    ui.Span("  " .. select_symbol .. " " .. selected):fg(selected > 0 and th.mgr.count_selected:bg() or muted()),
    ui.Span("  " .. yank_symbol .. " " .. yanked .. " "):fg(yanked > 0 and yank_color or muted()),
  })
end

-- C (right): modification time of the hovered file
function Status:modified()
  local h = cx.active.current.hovered
  if not h then
    return ""
  end
  return ui.Span(os.date("%Y-%m-%d %H:%M", (h.cha.mtime or 0) // 1) .. "  "):fg(muted())
end

-- Y: percentage on the secondary block
function Status:percent()
  local cursor, length = self._tab.current.cursor, #self._tab.current.files
  local p = (cursor ~= 0 and length ~= 0) and math.floor((cursor + 1) * 100 / length) or 0
  local text = p == 0 and " Top " or p == 100 and " Bot " or string.format(" %2d%% ", p)
  local main = self:style().main:bg()
  return ui.Line({
    ui.Span(" " .. sep.left):fg(secondary()),
    ui.Span(text):fg(main):bg(secondary()),
  })
end

-- Z: bold position bubble
function Status:position()
  local cursor, length = self._tab.current.cursor, #self._tab.current.files
  local main = self:style().main:bg()
  return ui.Line({
    ui.Span(sep.left):fg(main):bg(secondary()),
    ui.Span(string.format(" %2d/%-2d ", math.min(cursor + 1, length), length)):fg(mask()):bg(main):bold(),
    ui.Span(sep.right):fg(main),
  })
end

Status:children_add(Status.files, 4000, Status.LEFT)
Status:children_add(Status.modified, 0, Status.RIGHT)
