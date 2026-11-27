vim.g.mapleader = " "

local o = vim.opt
o.number         = true
o.relativenumber = true
o.signcolumn     = "yes"
o.cursorline     = true
o.termguicolors  = true
o.mouse          = "a"
o.clipboard      = "unnamedplus"
o.expandtab      = true
o.shiftwidth     = 4
o.tabstop        = 4
o.smartindent    = true
o.ignorecase     = true
o.smartcase      = true
o.undofile       = true
o.scrolloff      = 8
o.splitright     = true
o.splitbelow     = true
o.wrap           = false
o.updatetime     = 250
o.laststatus     = 3

vim.cmd.colorscheme("quiet")
for _, g in ipairs({ "Normal", "NormalNC", "SignColumn", "EndOfBuffer" }) do
    vim.api.nvim_set_hl(0, g, { bg = "NONE" })
end

local map = vim.keymap.set
map("n", "<Esc>", "<cmd>nohlsearch<CR>")
map("n", "<leader>w", "<cmd>write<CR>")
map("n", "<leader>q", "<cmd>quit<CR>")
map("n", "<leader>e", "<cmd>Explore<CR>")
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})
