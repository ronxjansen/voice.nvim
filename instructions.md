# Voice.nvim

Voice.nvim is a Neovim plugin that allows you to record voice and transcribe it using `whisper.cpp` or cloud-based Whisper models.

## Spec

- **Plugin Type**: Neovim plugin installable via `lazy` or `vim-plug`.
- **Language**: Lua with minimal dependencies.
- **Recording**: Single configurable key to start/stop recording voice.
- **Model Configuration**: Configurable Whisper models (e.g., small, large).
- **Installer**: Script to install `whisper.cpp`.
- **Dependency Check**: Ensure dependencies (e.g., `ffmpeg`, `cmake`, `make`, `git`) are installed.
  - Add a "Prerequisites" section in the README.
- **Default Model**: Whisper.cpp is the default; supports OpenAI Whisper (requires an OpenAI token).
- **Text Output**: Transcriptions are placed at the current cursor position.
- **Documentation**: Include a clear README with installation, prerequisites, and configuration instructions.


## Project Structure

voice.nvim/
├── lua/
│   ├── voice/
│   │   ├── init.lua        -- Main plugin entry point
│   │   ├── core.lua        -- Core logic for voice recording
│   │   ├── config.lua      -- Configuration options and defaults
│   │   ├── keymaps.lua     -- Keybinding setup
│   │   ├── voice_command.lua -- Future feature: handling voice commands
│   │   ├── installer.lua -- Script for installing whisper.cpp
│   └── ...
├── README.md              -- Documentation for the plugin
├── LICENSE                -- License file
├── .gitignore             -- Git ignore for the repository
└── plugin/
    └── voice.lua          -- Entry point for Neovim to source the plugin


## Audio Recording

- **Format**: WAV (16-bit PCM) for compatibility and quality.
- **Sample Rate**: Standard 16kHz (preferred by Whisper).
- **Command**: Use the `rec` command from the `sox` package for recording (cross-platform and lightweight).
- **Temporary Files**:
  - Unix: `/tmp/voice.nvim/`
  - Windows: `%TEMP%/voice.nvim/`
- **Cleanup**: Delete temporary files after transcription or on error.


## Error Handling

- Fail gracefully with clear error messages.
- Provide a troubleshooting section in the README for common issues.


## UI/UX

1. Use `vim.api.nvim_echo()` for error messages and status updates.
2. Update the statusline to show the recording state.
3. Optional floating window for transcription progress (configurable).


## Performance

- Run transcription asynchronously using Neovim's built-in job control.
- Default settings:
  - Max recording time: 60 seconds.
- Use `plenary.nvim` for async operations (widely adopted Neovim dependency).


## Security

- Store the OpenAI API key in the user's configuration (user's responsibility).
- Use OS-standard permissions for temporary directories.
- No additional security required as this is a local tool.


## Platform Support

- **Initial**: Linux and macOS.
- **Stretch Goal**: Windows support.
- **Documentation**: Clearly outline platform-specific requirements.


## Configuration

Follow the standard Neovim plugin setup pattern:

```lua
require('voice.nvim').setup({
    model = 'small',                -- Whisper model size
    backend = 'whisper.cpp',        -- Backend ('whisper.cpp' or 'openai')
    keymaps = {
        toggle_recording = '<leader>r', -- Keybinding for recording
    },
    max_recording_seconds = 60,     -- Max recording duration
})
