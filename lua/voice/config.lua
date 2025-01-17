local M = {}

-- Helper function for displaying messages
local function echo_message(msg, level)
    local hl = level == 'ERROR' and 'ErrorMsg' or 'WarningMsg'
    vim.api.nvim_echo({{msg, hl}}, true, {})
end

-- Default configuration
M.defaults = {
    -- Model configuration
    model = 'small', -- Whisper model size (small, medium, large)
    backend = 'whisper.cpp', -- Backend ('whisper.cpp' or 'openai')

    -- Recording settings
    max_recording_seconds = 60, -- Maximum recording duration
    sample_rate = 16000, -- Sample rate for recording (16kHz as preferred by Whisper)
    audio_format = 'wav', -- Audio format (WAV 16-bit PCM)

    -- Keybindings
    keymaps = {
        toggle_recording = '<leader>r' -- Default keybinding for toggle recording
    },

    -- OpenAI configuration (optional)
    openai = {
        api_key = nil -- OpenAI API key for cloud transcription
    },

    -- UI settings
    ui = {
        show_recording_status = true, -- Show recording status in statusline
        floating_window = true -- Show transcription progress in floating window
    },

    -- Temporary file settings
    temp_dir = vim.fn.has('win32') == 1 and os.getenv('TEMP') .. '/voice.nvim/' or '/tmp/voice.nvim/' -- Platform-specific temp directory
}

-- User configuration (will be populated by setup)
M.options = {}

-- Validate temp directory permissions
local function validate_temp_dir(dir)
    -- Create test file
    local test_file = dir .. '/.voice_test'
    local success = pcall(function()
        local f = io.open(test_file, 'w')
        if f then
            f:close()
            os.remove(test_file)
        else
            error('Cannot write to temp directory')
        end
    end)

    if not success then
        error('No write permission for temp directory: ' .. dir)
    end
    return true
end

-- Validate OpenAI API key
function M.validate_openai_key()
    if M.options.backend == 'openai' then
        if not M.options.openai.api_key then
            error('OpenAI backend selected but no API key provided')
        end
        -- Basic format check
        if not M.options.openai.api_key:match('^sk%-') then
            error('Invalid OpenAI API key format')
        end
    end
    return true
end

-- Configuration validation
function M._validate_config()
    local valid_models = {
        small = true,
        medium = true,
        large = true
    }
    local valid_backends = {
        ['whisper.cpp'] = true,
        openai = true
    }

    -- Validate model
    if not valid_models[M.options.model] then
        echo_message('Invalid model specified. Using default: small', 'WARN')
        M.options.model = 'small'
    end

    -- Validate backend
    if not valid_backends[M.options.backend] then
        echo_message('Invalid backend specified. Using default: whisper.cpp', 'WARN')
        M.options.backend = 'whisper.cpp'
    end

    -- Validate OpenAI settings
    pcall(M.validate_openai_key)

    -- Validate recording duration
    if type(M.options.max_recording_seconds) ~= 'number' or M.options.max_recording_seconds <= 0 then
        echo_message('Invalid max_recording_seconds. Using default: 60', 'WARN')
        M.options.max_recording_seconds = 60
    end

    -- Validate sample rate
    if M.options.sample_rate ~= 16000 then
        echo_message('Sample rate changed from recommended 16kHz', 'WARN')
    end

    -- Validate temp directory
    validate_temp_dir(M.options.temp_dir)
end

-- Merge user config with defaults
function M.setup(opts)
    M.options = vim.tbl_deep_extend('force', {}, M.defaults, opts or {})

    -- Ensure temp directory exists
    vim.fn.mkdir(M.options.temp_dir, 'p')

    -- Validate configuration
    M._validate_config()

    return M.options
end

-- Update configuration at runtime
function M.update(opts)
    if opts then
        M.options = vim.tbl_deep_extend('force', M.options, opts)
        M._validate_config()
    end
    return M.options
end

-- Get current configuration
function M.get()
    return M.options
end

return M
