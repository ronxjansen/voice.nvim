local M = {}

-- Import required modules
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
            if installer.install_whisper_cpp() then
                echo_message('Installation completed successfully', 'WARN')
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
    -- Initialize configuration
    config.setup(opts)

    -- Create commands
    create_commands()

    -- Set up keymaps using the keymaps module
    keymaps.setup()

    -- Set up auto-cleanup
    vim.api.nvim_create_autocmd('VimLeavePre', {
        callback = function()
            keymaps.clear() -- Clear keymaps on exit
            core.cleanup()
        end,
    })

    -- Check dependencies on startup
    if not installer.check_dependencies() then
        echo_message('Some dependencies are missing. Run :VoiceInstall after installing the required dependencies.', 'WARN')
    end

    return M
end

-- Expose core functionality
M.toggle_recording = core.toggle_recording
M.stop_recording = core.stop_recording

-- Expose keymap management
M.update_keymaps = keymaps.update

return M 