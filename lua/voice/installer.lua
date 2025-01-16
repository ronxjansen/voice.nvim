local M = {}
local config = require('voice.config')

-- Helper function for displaying messages
local function echo_message(msg, level)
    local hl = level == 'ERROR' and 'ErrorMsg' or 'WarningMsg'
    vim.api.nvim_echo({{msg, hl}}, true, {})
end

-- Check if a command exists
local function command_exists(cmd)
    local handle = io.popen('command -v ' .. cmd .. ' 2>/dev/null')
    if handle then
        local result = handle:read('*a')
        handle:close()
        return result and result:len() > 0
    end
    return false
end

-- Check system dependencies
function M.check_dependencies()
    local required_deps = {
        { name = 'git', message = 'Git is required for installation' },
        { name = 'cmake', message = 'CMake is required for building whisper.cpp' },
        { name = 'make', message = 'Make is required for building whisper.cpp' },
        { name = 'ffmpeg', message = 'FFmpeg is required for audio processing' },
        { name = 'rec', message = 'SoX (rec command) is required for audio recording' },
    }

    local missing_deps = {}
    for _, dep in ipairs(required_deps) do
        if not command_exists(dep.name) then
            table.insert(missing_deps, dep)
        end
    end

    if #missing_deps > 0 then
        echo_message('Missing required dependencies:', 'ERROR')
        for _, dep in ipairs(missing_deps) do
            echo_message('- ' .. dep.message, 'ERROR')
        end
        return false
    end

    return true
end

-- Get the installation directory for whisper.cpp
local function get_install_dir()
    local data_path = vim.fn.stdpath('data')
    return data_path .. '/whisper.cpp'
end

-- Clone and build whisper.cpp
function M.install_whisper_cpp()
    if not M.check_dependencies() then
        return false
    end

    local install_dir = get_install_dir()
    
    -- Create installation directory if it doesn't exist
    vim.fn.mkdir(install_dir, 'p')

    -- Clone whisper.cpp repository
    echo_message('Cloning whisper.cpp...', 'WARN')
    local clone_cmd = string.format('git clone https://github.com/ggerganov/whisper.cpp.git %s', install_dir)
    local clone_success = os.execute(clone_cmd)
    
    if not clone_success then
        echo_message('Failed to clone whisper.cpp repository', 'ERROR')
        return false
    end

    -- Build whisper.cpp
    echo_message('Building whisper.cpp...', 'WARN')
    local build_success = os.execute(string.format('cd %s && make', install_dir))
    
    if not build_success then
        echo_message('Failed to build whisper.cpp', 'ERROR')
        return false
    end

    -- Download the model based on configuration
    return M.download_model()
end

-- Download the Whisper model
function M.download_model()
    local install_dir = get_install_dir()
    local model = config.get().model or 'small'
    local model_path = string.format('%s/models/ggml-%s.bin', install_dir, model)

    -- Check if model already exists
    if vim.fn.filereadable(model_path) == 1 then
        echo_message('Model already downloaded', 'WARN')
        return true
    end

    -- Create models directory
    vim.fn.mkdir(install_dir .. '/models', 'p')

    -- Download the model
    echo_message(string.format('Downloading %s model...', model), 'WARN')
    local download_cmd = string.format('cd %s && bash ./models/download-%s.sh', install_dir, model)
    local download_success = os.execute(download_cmd)

    if not download_success then
        echo_message('Failed to download Whisper model', 'ERROR')
        return false
    end

    echo_message('Model downloaded successfully', 'WARN')
    return true
end

-- Check if whisper.cpp is installed
function M.is_installed()
    local install_dir = get_install_dir()
    local model = config.get().model or 'small'
    local model_path = string.format('%s/models/ggml-%s.bin', install_dir, model)
    local main_executable = install_dir .. '/main'

    return vim.fn.filereadable(main_executable) == 1 and vim.fn.filereadable(model_path) == 1
end

-- Get the path to the whisper.cpp executable
function M.get_executable_path()
    return get_install_dir() .. '/main'
end

return M 