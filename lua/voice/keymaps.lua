local M = {}
local config = require('voice.config')
local core = require('voice.core')

-- Helper function for displaying messages
local function echo_message(msg, level)
    local hl = level == 'ERROR' and 'ErrorMsg' or 'WarningMsg'
    vim.api.nvim_echo({{msg, hl}}, true, {})
end

-- Default keymap options
local default_opts = {
    noremap = true,
    silent = true
}

-- Set up the default keymaps
function M.setup()
    local keymaps = config.get().keymaps

    -- Set up toggle recording keymap
    if keymaps.toggle_recording then
        vim.keymap.set('n', keymaps.toggle_recording, function()
            core.toggle_recording()
        end, default_opts)
    else
        echo_message('No toggle_recording keymap configured', 'WARN')
    end
end

-- Remove all plugin keymaps
function M.clear()
    local keymaps = config.get().keymaps

    -- Remove toggle recording keymap if it exists
    if keymaps.toggle_recording then
        pcall(vim.keymap.del, 'n', keymaps.toggle_recording)
    end
end

-- Update keymaps (useful for runtime config changes)
function M.update(new_keymaps)
    -- Clear existing keymaps
    M.clear()

    -- Update configuration
    if new_keymaps then
        config.get().keymaps = vim.tbl_deep_extend('force', config.get().keymaps, new_keymaps)
    end

    -- Set up new keymaps
    M.setup()
end

return M
