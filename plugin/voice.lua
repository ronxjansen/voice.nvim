-- Prevent loading multiple times
if vim.g.loaded_voice_nvim == 1 then
    return
end
vim.g.loaded_voice_nvim = 1

-- Ensure minimum Neovim version (using 0.7.0 as it has the newer API features we need)
if vim.fn.has('nvim-0.7.0') ~= 1 then
    vim.api.nvim_err_writeln('Voice.nvim requires Neovim version 0.7.0 or higher')
    return
end

-- Create user commands
vim.api.nvim_create_user_command('VoiceToggle', function()
    require('voice.core').toggle_recording()
end, {
    desc = 'Toggle voice recording'
})

vim.api.nvim_create_user_command('VoiceStop', function()
    require('voice.core').stop_recording()
end, {
    desc = 'Stop voice recording'
})

-- The main setup of the plugin will be handled through require('voice').setup()
-- This file just ensures the plugin is loaded and basic commands are available 