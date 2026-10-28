--- @sync entry
--- Enter: go into a folder, open a file with its default app (like a file
--- manager's double click).
return {
  entry = function()
    local tab = cx.active or cx.tab
    local h = tab.current.hovered
    local emit = ya.emit or ya.mgr_emit or ya.manager_emit
    emit(h and h.cha.is_dir and "enter" or "open", { hovered = true })
  end,
}
