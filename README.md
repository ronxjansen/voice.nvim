# Voice.nvim

A Neovim plugin for voice recording and transcription using Whisper models.

## Prerequisites

Before installing the plugin, ensure you have the following dependencies:

- Neovim >= 0.8.0
- `sox` (for audio recording)
- `ffmpeg` (for audio processing)
- `cmake` and `make` (for building whisper.cpp)
- `git` (for installation)

### Installing Prerequisites

#### macOS
```bash
brew install sox ffmpeg cmake make git
```

#### Linux (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install sox ffmpeg cmake make git
```

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "ronjansen/voice.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    config = function()
        require("voice").setup({
            -- your configuration here
        })
    end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'nvim-lua/plenary.nvim'
Plug 'ronjansen/voice.nvim'
```

Then add to your init.lua:
```lua
require("voice").setup({
    -- your configuration here
})
```

## Configuration

Here's the default configuration:

```lua
require('voice').setup({
    model = 'small',                -- Whisper model size
    backend = 'whisper.cpp',        -- Backend ('whisper.cpp' or 'openai')
    keymaps = {
        toggle_recording = '<leader>r', -- Keybinding for recording
    },
    max_recording_seconds = 60,     -- Max recording duration
    openai = {
        api_key = nil,              -- Your OpenAI API key if using OpenAI backend
    },
    ui = {
        show_recording_status = true,   -- Show recording status in statusline
        floating_window = true,         -- Show transcription progress in floating window
    }
})
```

## Usage

1. Start recording by pressing `<leader>r` (or your configured keybinding)
2. Speak clearly into your microphone (English is recommended)
3. Press `<leader>r` again to stop recording
4. Wait for transcription to complete
5. The transcribed text will appear at your cursor position

## Troubleshooting

## Common Issues

## License

MIT License - See LICENSE file for details 