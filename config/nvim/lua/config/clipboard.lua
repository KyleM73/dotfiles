-- Clipboard, including over SSH via OSC52.
--
-- On a remote/headless box there is no system clipboard, so a plain
-- `clipboard = unnamedplus` either errors or silently does nothing. OSC52 is a
-- terminal escape sequence that forwards yanks to whatever clipboard your LOCAL
-- terminal (ghostty) controls. Result: `yy` on a Linux box over SSH lands in
-- your Mac clipboard. Neovim 0.10+ ships an OSC52 provider.

-- Make y/d/p use the system (+) register by default.
vim.opt.clipboard = "unnamedplus"

-- Only swap in the OSC52 provider when we're actually over SSH. Locally, the
-- native clipboard (pbcopy / wl-copy / xclip) is faster and pastes without
-- prompting, so we leave Neovim's auto-detected provider alone.
local over_ssh = vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil
if over_ssh then
  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if ok then
    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      -- OSC52 *paste* prompts/echoes in some terminals, which is annoying. We
      -- instead read back the register we just wrote, so paste WITHIN nvim
      -- works cleanly; to paste text from your Mac, use the terminal's normal
      -- paste (Cmd-V). If your terminal supports OSC52 paste and you want it,
      -- replace these two lines with osc52.paste("+") / osc52.paste("*").
      paste = {
        ["+"] = function()
          return { vim.fn.split(vim.fn.getreg("+"), "\n"), vim.fn.getregtype("+") }
        end,
        ["*"] = function()
          return { vim.fn.split(vim.fn.getreg("*"), "\n"), vim.fn.getregtype("*") }
        end,
      },
    }
  end
end
