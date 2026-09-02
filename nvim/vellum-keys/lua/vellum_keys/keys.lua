--- A HUD tartalma: modonkent egy lista, `{ billentyu, leiras }` parokkal.
---
--- A LazyVim alapertelmezett kioszatasat kovetik. Sajat kiosztashoz nem ezt a
--- fajlt kell atirni: a `setup({ groups = ... })` felulirja barmelyik modot.

local M = {}

M.groups = {
  n = {
    title = "Normal",
    items = {
      { "<leader>e", "filekezelo" },
      { "<leader>ff", "fajl kereses" },
      { "<leader>sg", "kereses a projektben" },
      { "<leader>,", "bufferek" },
      { "<S-h> <S-l>", "elozo / kovetkezo buffer" },
      { "<leader>bd", "buffer bezarasa" },
      { "<leader><tab><tab>", "uj tab" },
      { "<leader><tab>d", "tab bezarasa" },
      { "<leader>| <leader>-", "fuggoleges / vizszintes osztas" },
      { "<C-hjkl>", "ablakvaltas" },
      { "dd  x  D", "sor / karakter / sorveg torlese" },
      { "u  <C-r>", "vissza / ujra" },
      { "gcc", "sor kikommentelese" },
      { "gd  K", "definicio / dokumentacio" },
      { "]d  [d", "kovetkezo / elozo hiba" },
      { "<leader>ca", "code action" },
      { "<leader>cr", "atnevezes" },
      { "<leader>cf", "formazas" },
      { "<leader>gg", "lazygit" },
      { "<leader>l", "Lazy" },
      { "<C-/>", "terminal" },
      { "<C-s>", "mentes" },
      { "<leader>qq", "kilepes" },
      { "<leader>uk", "ez a sugo be/ki" },
    },
  },
  i = {
    title = "Insert",
    items = {
      { "<Esc>", "normal mod" },
      { "<C-w>", "szo torlese visszafele" },
      { "<C-u>", "sor torlese visszafele" },
      { "<C-space>", "kiegeszites" },
      { "<CR>", "kiegeszites elfogadasa" },
      { "<C-e>", "kiegeszites bezarasa" },
      { "<Tab> <S-Tab>", "snippet elore / hatra" },
      { "<A-j> <A-k>", "sor mozgatasa" },
      { "<C-o>", "egy parancs normal modban" },
      { "<C-s>", "mentes" },
    },
  },
  v = {
    title = "Visual",
    items = {
      { "d  y  p", "torles / masolas / beillesztes" },
      { "< >", "behuzas, kijeloles marad" },
      { "<A-j> <A-k>", "sorok mozgatasa" },
      { "gc", "kikommentelas" },
      { "o", "kijeloles masik vege" },
      { "gv", "utolso kijeloles" },
      { "<leader>ca", "code action" },
      { "<Esc>", "normal mod" },
    },
  },
  t = {
    title = "Terminal",
    items = {
      { "<C-/>", "terminal elrejtese" },
      { "<Esc><Esc>", "normal mod" },
      { "<C-hjkl>", "ablakvaltas" },
    },
  },
}

--- A `nvim_get_mode().mode` rovidites lekepezese egy csoportra.
---
--- A parancssor, a csere es az operator-pending mod nem kap sajat listat: ott a
--- normal kiosztas a hasznos, mert egy pillanat mulva ugyis oda terunk vissza.
function M.group_for(mode)
  local first = mode:sub(1, 1)
  if first == "i" or first == "R" then
    return M.groups.i
  elseif first == "v" or first == "V" or first == "\22" or first == "s" or first == "S" then
    return M.groups.v
  elseif first == "t" then
    return M.groups.t
  end
  return M.groups.n
end

return M
