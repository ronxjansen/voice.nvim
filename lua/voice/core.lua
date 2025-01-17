local M = {}
local config = require('voice.config')
local installer = require('voice.installer')
local Job = require('plenary.job')

-- Helper function for displaying messages
local function echo_message(msg, level)
    local hl = level == 'ERROR' and 'ErrorMsg' or 'WarningMsg'
    vim.api.nvim_echo({{msg, hl}}, true, {})
end

-- State management
local state = {
    is_recording = false,
    current_job = nil,
    recording_start_time = nil
}

-- Get the temporary file paths
local function get_temp_paths()
    local temp_dir = config.get().temp_dir
    return {
        wav = temp_dir .. 'recording.wav'
    }
end

-- Update statusline to show recording state
local function update_status()
    if not config.get().ui.show_recording_status then
        return
    end

    if state.is_recording then
        local elapsed = os.time() - state.recording_start_time
        local max_time = config.get().max_recording_seconds
        vim.api.nvim_echo({{string.format('Recording... (%ds/%ds)', elapsed, max_time), 'WarningMsg'}}, false, {})
    end
end

-- Clean up temporary files
local function cleanup_temp_files()
    local paths = get_temp_paths()
    for _, path in pairs(paths) do
        os.remove(path)
    end
end

-- Stop any running jobs
local function stop_current_job()
    if state.current_job then
        state.current_job:shutdown()
        state.current_job = nil
    end
end

-- Start recording audio
local function start_recording()
    if state.is_recording then
        return
    end

    -- Ensure temp directory exists
    vim.fn.mkdir(config.get().temp_dir, 'p')

    -- Clean up any existing temporary files
    cleanup_temp_files()

    local paths = get_temp_paths()
    local sample_rate = config.get().sample_rate
    local max_seconds = config.get().max_recording_seconds

    -- Start recording using sox
    state.current_job = Job:new({
        command = 'rec',
        args = {'-r', tostring(sample_rate), '-c', '1', -- mono audio
        '-b', '16', -- 16-bit depth
        paths.wav, 'rate', tostring(sample_rate), 'silence', '1', '0.1', '1%' -- Start recording on sound
        },
        on_exit = function(j, code)
            if code ~= 0 then
                echo_message('Recording failed', 'ERROR')
                cleanup_temp_files()
            end
        end
    })

    state.current_job:start()
    state.is_recording = true
    state.recording_start_time = os.time()

    -- Set up timer to stop recording after max duration
    vim.defer_fn(function()
        if state.is_recording then
            M.stop_recording()
            echo_message('Maximum recording duration reached', 'WARN')
        end
    end, max_seconds * 1000)

    -- Update status
    update_status()

    -- Set up timer for status updates
    vim.fn.timer_start(1000, function()
        if state.is_recording then
            update_status()
        end
    end, {
        ['repeat'] = -1
    })
end

-- Transcribe audio using whisper.cpp
local function transcribe_whisper_cpp(callback)
    if not installer.is_installed() then
        echo_message('whisper.cpp is not installed. Run :VoiceInstall first', 'ERROR')
        return
    end

    local paths = get_temp_paths()
    local model = config.get().model
    local executable = installer.get_executable_path()

    -- Show transcription progress in floating window if enabled
    local win = nil
    if config.get().ui.floating_window then
        local buf = vim.api.nvim_create_buf(false, true)
        local width = 50
        local height = 3
        local opts = {
            relative = 'editor',
            width = width,
            height = height,
            col = (vim.o.columns - width) / 2,
            row = (vim.o.lines - height) / 2,
            style = 'minimal',
            border = 'rounded'
        }
        win = vim.api.nvim_open_win(buf, false, opts)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {'Transcribing...', 'Please wait...'})
    end

    -- Run whisper.cpp transcription
    Job:new({
        command = executable,
        args = {'-m', string.format('models/ggml-%s.bin', model), '-f', paths.wav, '-l', 'auto', -- auto-detect language
        '--output-txt'},
        cwd = installer.get_install_dir(),
        on_exit = function(j, code)
            if win then
                vim.api.nvim_win_close(win, true)
            end

            if code ~= 0 then
                echo_message('Transcription failed', 'ERROR')
                return
            end

            -- Read transcription from the output file
            local output_file = paths.wav .. '.txt'
            local f = io.open(output_file, 'r')
            if f then
                local text = f:read('*all')
                f:close()
                os.remove(output_file)

                if callback then
                    callback(text)
                end
            else
                echo_message('Failed to read transcription output', 'ERROR')
            end
        end
    }):start()
end

-- Transcribe audio using OpenAI Whisper API
local function transcribe_openai(callback)
    local api_key = config.get().openai.api_key
    if not api_key then
        echo_message('OpenAI API key not configured', 'ERROR')
        return
    end

    local paths = get_temp_paths()
    local win = nil

    -- Show transcription progress
    if config.get().ui.floating_window then
        local buf = vim.api.nvim_create_buf(false, true)
        local width = 50
        local height = 3
        local opts = {
            relative = 'editor',
            width = width,
            height = height,
            col = (vim.o.columns - width) / 2,
            row = (vim.o.lines - height) / 2,
            style = 'minimal',
            border = 'rounded'
        }
        win = vim.api.nvim_open_win(buf, false, opts)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {'Transcribing with OpenAI...', 'Please wait...'})
    end

    -- Use curl to send request to OpenAI API
    Job:new({
        command = 'curl',
        args = {'https://api.openai.com/v1/audio/transcriptions', '-H', 'Authorization: Bearer ' .. api_key, '-H',
                'Content-Type: multipart/form-data', '-F', 'file=@' .. paths.wav, '-F', 'model=whisper-1', '-F',
                'response_format=text'},
        on_exit = function(j, code)
            if win then
                vim.api.nvim_win_close(win, true)
            end

            if code ~= 0 then
                echo_message('OpenAI transcription failed', 'ERROR')
                return
            end

            local result = table.concat(j:result(), '\n')
            if callback then
                callback(result)
            end
        end
    }):start()
end

-- Stop recording and start transcription
function M.stop_recording()
    if not state.is_recording then
        return
    end

    stop_current_job()
    state.is_recording = false
    state.recording_start_time = nil

    -- Clear status line
    vim.api.nvim_echo({{'', ''}}, false, {})

    -- Start transcription
    local function insert_text(text)
        if text and text ~= '' then
            local pos = vim.api.nvim_win_get_cursor(0)
            local line = pos[1] - 1
            local col = pos[2]

            -- Split the current line at cursor position
            local current_line = vim.api.nvim_get_current_line()
            local before = string.sub(current_line, 1, col)
            local after = string.sub(current_line, col + 1)

            -- Insert transcribed text between split
            local new_text = before .. text .. after
            vim.api.nvim_set_current_line(new_text)

            -- Move cursor to end of inserted text
            vim.api.nvim_win_set_cursor(0, {line + 1, col + #text})
        end
        cleanup_temp_files()
    end

    if config.get().backend == 'openai' then
        transcribe_openai(insert_text)
    else
        transcribe_whisper_cpp(insert_text)
    end
end

-- Toggle recording state
function M.toggle_recording()
    if state.is_recording then
        M.stop_recording()
    else
        start_recording()
    end
end

-- Clean up on plugin exit
function M.cleanup()
    stop_current_job()
    cleanup_temp_files()
end

return M
