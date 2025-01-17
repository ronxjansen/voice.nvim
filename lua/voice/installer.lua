local M = {}
local config = require('voice.config')
local has_plenary, Job = pcall(require, 'plenary.job')
if not has_plenary then
    error('voice.nvim requires plenary.nvim to be installed')
end

-- Helper function for displaying messages
local function echo_message(msg, level)
    local hl = level == 'ERROR' and 'ErrorMsg' or 'WarningMsg'
    vim.schedule(function()
        vim.api.nvim_echo({{msg, hl}}, true, {})
    end)
end

-- Cross-platform command existence check
local function command_exists(cmd)
    if vim.fn.has('win32') == 1 then
        -- Windows: use 'where' command
        local handle = io.popen('where ' .. cmd .. ' 2>nul')
        if not handle then
            return false
        end
        local result = handle:read('*a')
        handle:close()
        return result and result:len() > 0
    else
        -- Unix-like: use 'command -v'
        local handle = io.popen('command -v ' .. cmd .. ' 2>/dev/null')
        if not handle then
            return false
        end
        local result = handle:read('*a')
        handle:close()
        return result and result:len() > 0
    end
end

-- Helper function to execute command and capture output

-- Check system dependencies
function M.check_dependencies()
    local required_deps = {{
        name = vim.fn.has('win32') == 1 and 'git.exe' or 'git',
        message = 'Git is required for installation'
    }, {
        name = vim.fn.has('win32') == 1 and 'cmake.exe' or 'cmake',
        message = 'CMake is required for building whisper.cpp'
    }, {
        name = vim.fn.has('win32') == 1 and 'make.exe' or 'make',
        message = 'Make is required for building whisper.cpp'
    }, {
        name = vim.fn.has('win32') == 1 and 'ffmpeg.exe' or 'ffmpeg',
        message = 'FFmpeg is required for audio processing'
    }, {
        name = vim.fn.has('win32') == 1 and 'sox.exe' or 'rec',
        message = 'SoX is required for audio recording'
    }}

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
    -- Always use data directory for whisper.cpp
    local data_path = vim.fn.stdpath('data')
    return vim.fn.fnamemodify(data_path .. '/whisper.cpp', ':p')
end

-- Check if we have write permissions for the installation directory
local function check_write_permissions()
    local install_dir = get_install_dir()
    local parent_dir = vim.fn.fnamemodify(install_dir, ':h')

    -- Check if parent directory exists and is writable
    if vim.fn.isdirectory(parent_dir) == 0 then
        echo_message('Parent directory does not exist: ' .. parent_dir, 'ERROR')
        return false
    end

    -- Try to create a temporary file to test write permissions
    local test_file = parent_dir .. '/.write_test'
    local success = pcall(function()
        local file = io.open(test_file, 'w')
        if file then
            file:close()
            vim.fn.delete(test_file)
            return true
        end
        return false
    end)

    if not success then
        echo_message('Insufficient permissions to write to: ' .. parent_dir, 'ERROR')
        return false
    end

    return true
end

-- Clean up installation directory on failure
local function cleanup_install_dir()
    local install_dir = get_install_dir()
    if vim.fn.isdirectory(install_dir) == 1 then
        vim.schedule(function()
            vim.fn.delete(install_dir, 'rf')
        end)
    end
end

-- Separate function for the actual cmake build
local function build_with_cmake(install_dir, on_complete)
    echo_message('Building with cmake...', 'WARN')
    local build_job = Job:new({
        command = 'cmake',
        args = {'--build', 'build', '--config', 'Release'},
        cwd = install_dir,
        on_stdout = function(_, data)
            if data then
                vim.schedule(function()
                    echo_message('Build: ' .. data, 'WARN')
                end)
            end
        end,
        on_stderr = function(_, data)
            if data and data ~= "" then
                vim.schedule(function()
                    echo_message('Build: ' .. data, 'WARN')
                end)
            end
        end,
        on_exit = function(j, code)
            if code ~= 0 then
                echo_message('Build failed', 'ERROR')
                cleanup_install_dir()
                if on_complete then
                    on_complete(false)
                end
                return
            end

            -- Start model download after successful build
            vim.schedule(function()
                M.download_model(on_complete)
            end)
        end
    })

    build_job:start()
end

-- Separate function for building whisper.cpp
local function build_whisper_cpp(install_dir, on_complete)
    echo_message('Building whisper.cpp...', 'WARN')

    -- First run cmake to configure
    local cmake_job = Job:new({
        command = 'cmake',
        args = {'-B', 'build'},
        cwd = install_dir,
        on_stdout = function(_, data)
            if data then
                vim.schedule(function()
                    echo_message('CMake: ' .. data, 'WARN')
                end)
            end
        end,
        on_stderr = function(_, data)
            if data and data ~= "" then
                vim.schedule(function()
                    echo_message('CMake: ' .. data, 'WARN')
                end)
            end
        end,
        on_exit = function(j, code)
            if code ~= 0 then
                echo_message('CMake configuration failed', 'ERROR')
                cleanup_install_dir()
                if on_complete then
                    on_complete(false)
                end
                return
            end

            -- Start the build after successful cmake configuration
            vim.schedule(function()
                build_with_cmake(install_dir, on_complete)
            end)
        end
    })

    cmake_job:start()
end

-- Clone and build whisper.cpp asynchronously
function M.install_whisper_cpp(on_complete)
    if not M.check_dependencies() then
        echo_message('Missing dependencies', 'ERROR')
        if on_complete then
            on_complete(false)
        end
        return
    end

    if not check_write_permissions() then
        if on_complete then
            on_complete(false)
        end
        return
    end

    local install_dir = get_install_dir()

    -- Clean up existing directory if it exists
    if vim.fn.isdirectory(install_dir) == 1 then
        echo_message('Cleaning up existing installation...', 'WARN')
        vim.fn.delete(install_dir, 'rf')
    end

    -- Create installation directory
    vim.fn.mkdir(install_dir, 'p')

    -- Clone repository with real-time feedback
    echo_message('Cloning whisper.cpp repository...', 'WARN')
    local clone_job = Job:new({
        command = 'git',
        args = {'clone', 'https://github.com/ggerganov/whisper.cpp.git', install_dir},
        on_stdout = function(_, data)
            if data then
                vim.schedule(function()
                    echo_message('Clone: ' .. data, 'WARN')
                end)
            end
        end,
        on_stderr = function(_, data)
            if data and data ~= "" then
                vim.schedule(function()
                    echo_message('Clone: ' .. data, 'WARN')
                end)
            end
        end,
        on_exit = function(j, code)
            if code ~= 0 then
                echo_message('Failed to clone repository', 'ERROR')
                cleanup_install_dir()
                if on_complete then
                    on_complete(false)
                end
                return
            end

            -- Start the build process after successful clone
            vim.schedule(function()
                build_whisper_cpp(install_dir, on_complete)
            end)
        end
    })

    clone_job:start()
end

-- Download the Whisper model asynchronously
function M.download_model(on_complete)
    echo_message('Downloading model...', 'WARN')
    local install_dir = get_install_dir()
    local model = config.get().model or 'small'
    local model_path = string.format('%s/models/ggml-%s.bin', install_dir, model)
    local models_dir = install_dir .. '/models'

    -- Check if model already exists
    if vim.fn.filereadable(model_path) == 1 then
        echo_message('Model already downloaded', 'WARN')
        if on_complete then
            on_complete(true)
        end
        return
    end

    -- Create models directory
    if vim.fn.isdirectory(models_dir) == 0 then
        echo_message('Creating models directory...', 'WARN')
        vim.fn.mkdir(models_dir, 'p')
    end

    -- Ensure we're in the correct directory
    if vim.fn.chdir(install_dir) == -1 then
        echo_message('Failed to change to installation directory', 'ERROR')
        if on_complete then
            on_complete(false)
        end
        return
    end

    -- Download model using plenary.job for better control
    echo_message(string.format('Downloading %s model (this may take several minutes)...', model), 'WARN')

    local stderr_data = {}
    local job = Job:new({
        command = 'sh',
        args = {'models/download-ggml-model.sh', model},
        cwd = install_dir,
        on_stderr = function(_, data)
            if data and data ~= "" then
                table.insert(stderr_data, data)
            end
        end
    })

    local ok, result = pcall(function()
        job:sync(600000) -- 10 minute timeout
    end)

    if not ok then
        echo_message('Download process failed: ' .. tostring(result), 'ERROR')
        if #stderr_data > 0 then
            for _, err in ipairs(stderr_data) do
                echo_message("Download error: " .. err, "ERROR")
            end
        end
        if on_complete then
            on_complete(false)
        end
        return
    end

    if job.code ~= 0 then
        echo_message('Failed to download model', 'ERROR')
        if #stderr_data > 0 then
            for _, err in ipairs(stderr_data) do
                echo_message("Download error: " .. err, "ERROR")
            end
        end
        if on_complete then
            on_complete(false)
        end
        return
    end

    -- Verify the model file exists
    if vim.fn.filereadable(model_path) ~= 1 then
        echo_message('Model file not found after download', 'ERROR')
        if on_complete then
            on_complete(false)
        end
        return
    end

    echo_message('Model downloaded successfully!', 'WARN')
    if on_complete then
        on_complete(true)
    end
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
    local executable = get_install_dir() .. '/build/bin/whisper-cli'
    if vim.fn.has('win32') == 1 then
        executable = executable .. '.exe'
    end
    return executable
end

return M
