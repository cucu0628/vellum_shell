--- Vellum Shell: allandoan lathato gyorsbillentyu-sugo.
---
--- Egy kicsi, nem fokuszalhato lebego ablak a sarokban, ami folyamatosan az
--- eppen ervenyes mod alap billentyuit irja ki. A which-key-tol az kulonbozteti
--- meg, hogy nem kell hozza leutes: mindig latszik, es modvaltaskor frissul.
---
--- A szinei a Vellum colorscheme-hez kotott, `default = true` linkek, tehat egy
--- sajat `VellumKeys*` highlight barmikor felulirja oket.

local keys = require("vellum_keys.keys")

local M = {}

local config = {
  enabled = true,
  --- A sugo elfedi a szerkesztot, ezert kis ablakban inkabb el sem indul.
  min_columns = 100,
  min_lines = 24,
  max_width = 46,
  position = "bottom-right",
  border = "rounded",
  winblend = 0,
  --- Ahol a felulet sajat sugot hoz, ott feleslegesek vagyunk.
  ignored_filetypes = {
    "alpha",
    "dashboard",
    "snacks_dashboard",
    "lazy",
    "mason",
    "help",
    "checkhealth",
    "TelescopePrompt",
    "vellum_keys",
  },
}

local state = {
  buf = nil,
  win = nil,
  signature = nil,
  enabled = true,
  pending = false,
  ns = vim.api.nvim_create_namespace("vellum_keys"),
}

local function set_highlights()
  local links = {
    VellumKeysNormal = "NormalFloat",
    VellumKeysBorder = "FloatBorder",
    VellumKeysTitle = "FloatTitle",
    VellumKeysKey = "Special",
    VellumKeysDesc = "Comment",
  }
  for name, target in pairs(links) do
    vim.api.nvim_set_hl(0, name, { link = target, default = true })
  end
end

local function buffer()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    return state.buf
  end
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "hide"
  vim.bo[state.buf].buftype = "nofile"
  vim.bo[state.buf].swapfile = false
  vim.bo[state.buf].filetype = "vellum_keys"
  return state.buf
end

--- A megjeleno sorok, plusz soronkent a billentyu-oszlop szelessege.
local function render(group, height_limit)
  local key_width = 0
  for _, item in ipairs(group.items) do
    key_width = math.max(key_width, #item[1])
  end

  local desc_width = math.max(12, config.max_width - key_width - 1)
  local lines = { group.title }
  local key_columns = { 0 }

  for _, item in ipairs(group.items) do
    -- A fejlec es a keret is helyet foglal: ami nem fer be, az lemarad.
    if #lines >= height_limit then
      break
    end
    local desc = item[2]
    if #desc > desc_width then
      desc = desc:sub(1, desc_width - 1) .. "…"
    end
    lines[#lines + 1] = string.format("%-" .. key_width .. "s %s", item[1], desc)
    key_columns[#key_columns + 1] = #item[1]
  end

  local width = #group.title
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end

  return lines, key_columns, key_width, width
end

local function place(width, height)
  local row, col
  if config.position:find("top") then
    row = 1
  else
    -- A statuszsor es a parancssor ala nem logunk be.
    row = vim.o.lines - height - 4
  end
  if config.position:find("left") then
    col = 1
  else
    col = vim.o.columns - width - 3
  end
  return math.max(row, 0), math.max(col, 0)
end

local function close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  state.win = nil
  state.signature = nil
end

local function visible()
  if not state.enabled then
    return false
  end
  if vim.o.columns < config.min_columns or vim.o.lines < config.min_lines then
    return false
  end
  if vim.tbl_contains(config.ignored_filetypes, vim.bo.filetype) then
    return false
  end
  -- Egy fokuszalt lebego ablak (picker, Lazy, Mason) sajat sugoval jon.
  local ok, win = pcall(vim.api.nvim_win_get_config, 0)
  if ok and win.relative ~= "" then
    return false
  end
  return true
end

local function draw()
  if not visible() then
    close()
    return
  end

  local group = keys.group_for(vim.api.nvim_get_mode().mode)
  local lines, key_columns, key_width, width = render(group, vim.o.lines - 8)
  local height = #lines
  local row, col = place(width, height)

  -- Ugyanaz a tartalom ugyanott: nincs mit ujrarajzolni. Enelkul minden
  -- ablakvaltas felesleges buffer- es ablakmuveletet keltene.
  local signature = table.concat({ table.concat(lines, "\n"), row, col, width, height }, "|")
  if state.signature == signature and state.win and vim.api.nvim_win_is_valid(state.win) then
    return
  end
  state.signature = signature

  local buf = buffer()

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(buf, state.ns, 0, -1)
  vim.api.nvim_buf_set_extmark(buf, state.ns, 0, 0, { end_col = #lines[1], hl_group = "VellumKeysTitle" })
  for index = 2, #lines do
    vim.api.nvim_buf_set_extmark(buf, state.ns, index - 1, 0, {
      end_col = key_columns[index],
      hl_group = "VellumKeysKey",
    })
    vim.api.nvim_buf_set_extmark(buf, state.ns, index - 1, math.min(key_width + 1, #lines[index]), {
      end_col = #lines[index],
      hl_group = "VellumKeysDesc",
    })
  end

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_config(state.win, {
      relative = "editor",
      row = row,
      col = col,
      width = width,
      height = height,
    })
    return
  end

  state.win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = config.border,
    focusable = false,
    noautocmd = true,
    zindex = 40,
  })
  vim.wo[state.win].winhighlight = "Normal:VellumKeysNormal,FloatBorder:VellumKeysBorder"
  vim.wo[state.win].winblend = config.winblend
end

--- A rajzolas mindig a fo hurokban, egyetlen alkalommal fut le: egy modvaltas
--- tobb esemenyt is kelt, es koztuk az API allapota meg nem stabil.
local function schedule()
  if state.pending then
    return
  end
  state.pending = true
  vim.schedule(function()
    state.pending = false
    if vim.v.exiting == vim.NIL then
      pcall(draw)
    end
  end)
end

function M.enable()
  state.enabled = true
  schedule()
end

function M.disable()
  state.enabled = false
  close()
end

function M.toggle()
  if state.enabled then
    M.disable()
  else
    M.enable()
  end
end

function M.is_enabled()
  return state.enabled
end

function M.setup(opts)
  opts = opts or {}
  local groups = opts.groups
  opts.groups = nil
  config = vim.tbl_deep_extend("force", config, opts)
  if groups then
    keys.groups = vim.tbl_deep_extend("force", keys.groups, groups)
  end
  state.enabled = config.enabled

  set_highlights()

  local augroup = vim.api.nvim_create_augroup("vellum_keys", { clear = true })
  vim.api.nvim_create_autocmd({
    "ModeChanged",
    "BufEnter",
    "BufWinEnter",
    "WinEnter",
    "WinClosed",
    "VimResized",
    "TermEnter",
    "TermLeave",
    "CmdlineLeave",
  }, { group = augroup, callback = schedule })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    callback = function()
      set_highlights()
      schedule()
    end,
  })
  -- Kilepeskor es az utolso ablak bezarasakor ne maradjon arva lebego ablak.
  vim.api.nvim_create_autocmd({ "VimLeavePre", "QuitPre" }, { group = augroup, callback = close })

  vim.api.nvim_create_user_command("VellumKeys", function(args)
    local action = args.args ~= "" and args.args or "toggle"
    if action == "on" then
      M.enable()
    elseif action == "off" then
      M.disable()
    else
      M.toggle()
    end
  end, {
    nargs = "?",
    complete = function()
      return { "toggle", "on", "off" }
    end,
    desc = "Vellum gyorsbillentyu-sugo",
  })

  vim.keymap.set("n", "<leader>uk", M.toggle, { desc = "Vellum gyorsbillentyu-sugo" })

  schedule()
end

return M
