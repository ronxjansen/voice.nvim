local M = {}

-- Import required modules
local has_plenary, Job = pcall(require, 'plenary.job')
if not has_plenary then
    error('voice.nvim requires plenary.nvim to be installed')
end

local config = require('voice.config')
local core = require('voice.core')
local installer = require('voice.installer')
local keymaps = require('voice.keymaps')

-- Helper function for displaying messages
local function echo_message(msg, level)
    local hl = level == 'ERROR' and 'ErrorMsg' or 'WarningMsg'
    vim.api.nvim_echo({{msg, hl}}, true, {})
end

-- Create user commands
local function create_commands()
    -- Main commands
    vim.api.nvim_create_user_command('VoiceToggle', function()
        core.toggle_recording()
    end, {
        desc = 'Toggle voice recording'
    })

    vim.api.nvim_create_user_command('VoiceInstall', function()
        if installer.check_dependencies() then
            echo_message('Installing whisper.cpp...', 'WARN')
            local success, err = installer.install_whisper_cpp()
            if success then
                echo_message('Installation completed successfully', 'WARN')
            else
                echo_message('Installation failed: ' .. tostring(err), 'ERROR')
            end
        end
    end, {
        desc = 'Install whisper.cpp and download model'
    })

    -- Additional commands for model management
    vim.api.nvim_create_user_command('VoiceDownloadModel', function()
        if installer.is_installed() then
            echo_message('Downloading Whisper model...', 'WARN')
            if installer.download_model() then
                echo_message('Model downloaded successfully', 'WARN')
            end
        else
            echo_message('whisper.cpp is not installed. Run :VoiceInstall first', 'ERROR')
        end
    end, {
        desc = 'Download Whisper model'
    })
end

-- Plugin setup function
function M.setup(opts)
    -- Check dependencies first
    if not installer.check_dependencies() then
        echo_message('Missing required dependencies. Plugin initialization aborted.', 'ERROR')
        return false
    end

    -- Initialize configuration with error handling
    local ok, err = pcall(function()
        config.setup(opts)
    end)
    if not ok then
        echo_message('Configuration error: ' .. tostring(err), 'ERROR')
        return false
    end

    -- Create commands with error handling
    ok, err = pcall(create_commands)
    if not ok then
        echo_message('Failed to create commands: ' .. tostring(err), 'ERROR')
        return false
    end

    -- Set up keymaps with error handling
    ok, err = pcall(keymaps.setup)
    if not ok then
        echo_message('Failed to setup keymaps: ' .. tostring(err), 'ERROR')
        return false
    end

    -- Set up auto-cleanup
    vim.api.nvim_create_autocmd('VimLeavePre', {
        callback = function()
            keymaps.clear()
            core.cleanup()
        end
    })

    return M
end

-- Expose core functionality
M.toggle_recording = core.toggle_recording
M.stop_recording = core.stop_recording

-- Expose keymap management
M.update_keymaps = keymaps.update

return M
