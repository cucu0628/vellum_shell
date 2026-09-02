-- Vellum Shell -> LazyVim.
--
-- Masold (vagy linkeld) ide: ~/.config/nvim/lua/plugins/vellum.lua
-- A `setup.sh` ezt megteszi, ha van LazyVim konfiguracio a gepen.
--
-- Maga a colorscheme generalt, es nem ebben a fajlban ul:
--   ~/.local/share/nvim/site/colors/vellum.lua
-- A backend minden temavaltaskor ujrairja, ez a spec pedig kivalasztja es
-- ujratolti, hogy a mar futo Neovim is kovesse a shell temajat.

local colors_file = vim.fn.stdpath("data") .. "/site/colors/vellum.lua"

local function reload()
  if vim.g.colors_name ~= "vellum" then
    return
  end
  -- A `pcall` azert kell, mert a fajl egy pillanatra hianyozhat, ha a
  -- generator eppen most nevezi at a helyere.
  pcall(vim.cmd.colorscheme, "vellum")
end

--- A generalt colorscheme figyelese, hogy a temavaltas azonnal latszodjon.
local function watch()
  local uv = vim.uv or vim.loop
  local dir = vim.fs.dirname(colors_file)
  if not uv.fs_stat(dir) then
    return
  end

  local handle = uv.new_fs_event()
  if not handle then
    return
  end

  -- A mappat figyeljuk, nem a fajlt: a generator ideiglenes fajlba ir, majd
  -- atnevez, es a fajlra allitott figyelo az elso csere utan a regi inode-ot
  -- nezne. A timer az atnevezes tobb esemenyet vonja ossze eggye.
  local timer = uv.new_timer()
  handle:start(dir, {}, function(err, filename)
    if err or filename ~= "vellum.lua" or not timer then
      return
    end
    timer:start(80, 0, function()
      vim.schedule(reload)
    end)
  end)

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      pcall(function()
        handle:stop()
      end)
      if timer then
        pcall(function()
          timer:stop()
        end)
      end
    end,
  })
end

vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = watch })

return {
  { "LazyVim/LazyVim", opts = { colorscheme = "vellum" } },
}
