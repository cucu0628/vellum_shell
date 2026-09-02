-- Vellum Shell -> allandoan lathato gyorsbillentyu-sugo.
--
-- Masold (vagy linkeld) ide: ~/.config/nvim/lua/plugins/vellum-keys.lua
-- A `setup.sh` ezt megteszi, ha van LazyVim konfiguracio a gepen.
--
-- A plugin kodja a shell repojaban marad (`nvim/vellum-keys/`), ez a fajl csak
-- rakoti a lazy.nvim-et. Igy egy `git pull` frissiti a sugot is, es nem kell
-- masolatot karbantartani a nvim configban.

local shell_dir = vim.env.VELLUM_SHELL_DIR or vim.fn.expand("~/.config/quickshell/vellum_shell")
local plugin_dir = shell_dir .. "/nvim/vellum-keys"

-- Ha a shell repoja nincs a helyen, a spec csendben kimarad: a Neovim indulasat
-- nem torheti el egy hianyzo desktop shell.
if vim.fn.isdirectory(plugin_dir) == 0 then
  return {}
end

return {
  {
    dir = plugin_dir,
    name = "vellum-keys",
    lazy = false,
    opts = {
      -- position: "bottom-right" | "bottom-left" | "top-right" | "top-left"
      position = "bottom-right",
    },
    config = function(_, opts)
      require("vellum_keys").setup(opts)
    end,
  },
}
