--- Places, like the sidebar of Dolphin: home and the standard folders, your
--- bookmarks, drives (mounted ones, and plugged-in ones that aren't mounted
--- yet: picking one mounts it with udisksctl) and network mounts.
---
---   plugin places          pick a place (g p)
---   plugin places add      bookmark the current folder (b a)
---   plugin places remove   remove a bookmark (b d)
---
--- Bookmarks are one folder per line in ~/.local/share/yazi/bookmarks.

local M = {}

local HOME = os.getenv("HOME") or ""
local USER = os.getenv("USER") or ""
local DATA = os.getenv("XDG_DATA_HOME") or (HOME .. "/.local/share")
local BOOKMARKS = DATA .. "/yazi/bookmarks"
local KEYS = "1234567890abcdefhijklmnoprstuvwxyz" -- no g/q: they read like commands

-- File systems shown under "network"
local NETWORK = {
  cifs = true, smb3 = true, nfs = true, nfs4 = true, ["fuse.sshfs"] = true, sshfs = true,
  ["fuse.rclone"] = true, davfs = true, ["fuse.davfs2"] = true, ["fuse.gvfsd-fuse"] = true,
}

local ICON = { place = "\u{f015}", bookmark = "\u{f02e}", drive = "\u{f0a0}", network = "\u{f0ac}", eject = "\u{f052}" }

local emit = ya.emit or ya.mgr_emit or ya.manager_emit

local cwd = ya.sync(function()
  local tab = cx.active or cx.tab
  return tostring(tab.current.cwd)
end)

local function command(name, args)
  local c = Command(name)
  return (c.arg or c.args)(c, args)
end

local function read_lines(path)
  local f = io.open(path, "r")
  if not f then
    return {}
  end
  local lines = {}
  for line in f:lines() do
    if line ~= "" then
      lines[#lines + 1] = line
    end
  end
  f:close()
  return lines
end

local function write_lines(path, lines)
  command("mkdir", { "-p", path:match("^(.*)/") }):status()
  local f = io.open(path, "w")
  if not f then
    return false
  end
  f:write(table.concat(lines, "\n"), #lines > 0 and "\n" or "")
  f:close()
  return true
end

local function exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

local function short(path)
  if HOME ~= "" and path:sub(1, #HOME) == HOME then
    return "~" .. path:sub(#HOME + 1)
  end
  return path
end

local function basename(path)
  return path:match("([^/]+)/?$") or path
end

-- /proc/mounts escapes spaces and such as \040
local function unescape(s)
  return (s:gsub("\\(%d%d%d)", function(o) return string.char(tonumber(o, 8)) end))
end

local function mounts()
  local drives, network = {}, {}
  local f = io.open("/proc/mounts", "r")
  if not f then
    return drives, network
  end
  for line in f:lines() do
    local dev, mp, fstype = line:match("^(%S+)%s+(%S+)%s+(%S+)")
    if mp then
      mp = unescape(mp)
      if NETWORK[fstype] then
        network[#network + 1] = { path = mp, label = basename(mp) .. "  " .. dev }
      elseif mp:find("^/run/media/") or mp:find("^/media/") or mp:find("^/mnt/") then
        drives[#drives + 1] = { path = mp, label = basename(mp) }
      end
    end
  end
  f:close()
  return drives, network
end

-- Plugged-in partitions with a file system that aren't mounted yet
local function unmounted()
  local out = command("lsblk", { "-rnpo", "NAME,TYPE,HOTPLUG,FSTYPE,MOUNTPOINT,LABEL,SIZE" }):output()
  local list = {}
  if not out then
    return list
  end
  for line in out.stdout:gmatch("[^\n]+") do
    -- raw mode: empty columns are kept as consecutive spaces, spaces in
    -- values are \x20
    local cols = {}
    for col in (line .. " "):gmatch("(.-) ") do
      cols[#cols + 1] = col:gsub("\\x(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
    end
    local name, kind, hotplug, fstype, mountpoint, label, size = table.unpack(cols)
    if kind == "part" and hotplug == "1" and (fstype or "") ~= "" and fstype ~= "swap" and (mountpoint or "") == "" then
      list[#list + 1] = { device = name, label = (label ~= "" and label or basename(name)) .. "  " .. (size or "") }
    end
  end
  return list
end

local function places()
  local list = {}
  local function add(kind, path, label, extra)
    list[#list + 1] = { kind = kind, path = path, label = label, device = extra }
  end

  add("place", HOME, "Home")
  for _, dir in ipairs({ "Desktop", "Documents", "Downloads", "Music", "Pictures", "Videos" }) do
    if exists(HOME .. "/" .. dir) then
      add("place", HOME .. "/" .. dir, dir)
    end
  end
  for _, path in ipairs(read_lines(BOOKMARKS)) do
    add("bookmark", path, basename(path) .. "  " .. short(path))
  end
  local drives, network = mounts()
  for _, d in ipairs(drives) do
    add("drive", d.path, d.label .. "  " .. d.path)
  end
  for _, d in ipairs(unmounted()) do
    add("eject", nil, d.label .. "  (not mounted)", d.device)
  end
  for _, n in ipairs(network) do
    add("network", n.path, n.label)
  end
  -- folders shared through a file manager (gvfs)
  local id = command("id", { "-u" }):output()
  local uid = id and id.stdout:match("%d+")
  if uid then
    local gvfs = "/run/user/" .. uid .. "/gvfs"
    local out = command("find", { gvfs, "-mindepth", "1", "-maxdepth", "1" }):output()
    for path in (out and out.stdout or ""):gmatch("[^\n]+") do
      add("network", path, basename(path))
    end
  end
  return list
end

local function pick(list, title)
  local cands = {}
  for i, p in ipairs(list) do
    if i > #KEYS then
      break
    end
    cands[#cands + 1] = { on = KEYS:sub(i, i), desc = ICON[p.kind] .. "  " .. p.label }
  end
  if #cands == 0 then
    ya.notify { title = title, content = "Nothing here", timeout = 3 }
    return nil
  end
  local idx = ya.which { cands = cands }
  return idx and list[idx] or nil
end

local function go(place)
  if place.kind == "eject" then
    local out = command("udisksctl", { "mount", "-b", place.device }):output()
    local path = out and out.stdout:match("at (.-)%.?\n") or nil
    if not path then
      ya.notify { title = "Places", content = "Could not mount " .. place.device, timeout = 5, level = "error" }
      return
    end
    place.path = path
  end
  emit("cd", { place.path, raw = true })
end

function M:entry(job)
  local action = job.args and job.args[1]
  if action == "add" then
    local dir = cwd()
    local marks = read_lines(BOOKMARKS)
    for _, m in ipairs(marks) do
      if m == dir then
        ya.notify { title = "Bookmarks", content = short(dir) .. " is already bookmarked", timeout = 3 }
        return
      end
    end
    marks[#marks + 1] = dir
    write_lines(BOOKMARKS, marks)
    ya.notify { title = "Bookmarks", content = "Added " .. short(dir), timeout = 3 }
  elseif action == "remove" then
    local marks = read_lines(BOOKMARKS)
    local list = {}
    for _, m in ipairs(marks) do
      list[#list + 1] = { kind = "bookmark", path = m, label = basename(m) .. "  " .. short(m) }
    end
    local chosen = pick(list, "Bookmarks")
    if chosen then
      local keep = {}
      for _, m in ipairs(marks) do
        if m ~= chosen.path then
          keep[#keep + 1] = m
        end
      end
      write_lines(BOOKMARKS, keep)
      ya.notify { title = "Bookmarks", content = "Removed " .. short(chosen.path), timeout = 3 }
    end
  else
    local chosen = pick(places(), "Places")
    if chosen then
      go(chosen)
    end
  end
end

return M
