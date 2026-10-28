--- Office document previews: LibreOffice renders the page to PDF, pdftoppm
--- to an image. Based on macydnah/office.yazi (MIT), kept here so it doesn't
--- need `ya pkg`. Needs libreoffice and poppler.

local M = {}

local emit = ya.emit or ya.mgr_emit or ya.manager_emit
-- renamed between yazi versions
local stat = fs.stat or fs.cha

local function file_name(job)
  local url = job.file.url
  return job.file.name or (url and url.name) or tostring(url):match("([^/]+)$")
end

-- `preview_widget(job, err)` now; `preview_widgets(job, {})` before
local function finish(job, err)
  if ya.preview_widget then
    ya.preview_widget(job, err)
  elseif ya.preview_widgets then
    ya.preview_widgets(job, {})
  end
end

function M:peek(job)
  local start, cache = os.clock(), ya.file_cache(job)
  if not cache then
    return
  end
  local ok, err = self:preload(job)
  if not ok or err then
    -- show why (e.g. LibreOffice missing) instead of an endless preview
    return finish(job, err)
  end
  ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))
  local _, err2 = ya.image_show(cache, job.area)
  finish(job, err2)
end

function M:seek(job)
  local h = cx.active.current.hovered
  if h and h.url == job.file.url then
    local step = ya.clamp(-1, job.units, 1)
    emit("peek", { math.max(0, cx.active.preview.skip + step), only_if = job.file.url })
  end
end

local function to_pdf(job)
  local dir = "/tmp/yazi-" .. ya.uid() .. "/office/"
  local out = Command("libreoffice")
    :arg({
      "--headless",
      "--convert-to",
      'pdf:draw_pdf_Export:{"PageRange":{"type":"string","value":"' .. job.skip + 1 .. '"}}',
      "--outdir",
      dir,
      tostring(job.file.url),
    })
    :stdin(Command.NULL)
    :stdout(Command.PIPED)
    :stderr(Command.PIPED)
    :output()
  if not out or not out.status.success then
    return nil, Err("LibreOffice could not convert `%s`", file_name(job))
  end
  return dir .. (file_name(job):gsub("%.[^%.]+$", ".pdf"))
end

function M:preload(job)
  local cache = ya.file_cache(job)
  if not cache or stat(cache) then
    return true
  end
  local pdf, err = to_pdf(job)
  if not pdf then
    return true, err
  end
  local out, perr = Command("pdftoppm")
    :arg({ "-singlefile", "-jpeg", "-jpegopt", "quality=" .. rt.preview.image_quality, "-f", "1", pdf })
    :stdout(Command.PIPED)
    :stderr(Command.PIPED)
    :output()
  fs.remove("file", Url(pdf))
  if not out or not out.status.success then
    return true, Err("pdftoppm failed: %s", perr or (out and out.stderr) or "")
  end
  return fs.write(cache, out.stdout)
end

return M
