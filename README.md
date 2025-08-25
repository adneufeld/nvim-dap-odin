# `nvim-dap-odin`

A Neovim plugin that provides automated build and debug configurations for the [Odin programming language](https://odin-lang.org/) with [nvim-dap](https://github.com/mfussenegger/nvim-dap). 🚀

## Features

* **Automatic Building:** Smart, automated building of Odin projects with either debug or release flags.
* **Intelligent File Detection:** Searches for your main file by looking for `main.odin` or files containing a `main :: proc` definition, now with a configurable search depth.
* **One-Command Debugging:** Build and debug your project in a single step.
* **Configurable Build Options:** Easily customize build commands, flags, and output directories.
* **Cross-Platform Support:** Works seamlessly on Windows, Linux, and macOS.
* **Integrated Notifications:** Get real-time build status updates directly in Neovim.

---

## Requirements

* Neovim 0.7+
* [nvim-dap](https://github.com/mfussenegger/nvim-dap)
* [codelldb](https://github.com/vadimcn/codelldb) (DAP adapter for debugging)
* [Odin compiler](https://odin-lang.org/) installed and in your system's PATH

---

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'path/to/nvim-dap-odin', -- Use the correct path to your local plugin
  name = "nvim-dap-odin",
  dependencies = { "mfussenegger/nvim-dap" },
  config = function()
    require("nvim-dap-odin").setup()
  end,
}
````

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'path/to/nvim-dap-odin', -- Use the correct path to your local plugin
  requires = { "mfussenegger/nvim-dap" },
  config = function()
    require("nvim-dap-odin").setup()
  end
}
```

### Manual Installation

1.  Create the plugin directory:
    ```bash
    mkdir -p ~/.config/nvim/lua/nvim-dap-odin
    ```
2.  Copy your `init.lua` to `~/.config/nvim/lua/nvim-dap-odin/init.lua`.
3.  Add the following line to your Neovim configuration:
    ```lua
    require("nvim-dap-odin").setup()
    ```

-----

## Configuration

### Default Configuration

```lua
require("nvim-dap-odin").setup({
  build_command = "odin build",                      -- Base build command
  build_flags = "-debug",                          -- Flags for debug builds
  release_flags = "",                                -- Flags for release builds
  output_dir = nil,                                  -- Output directory (nil = project root)
  executable_extension = "",                         -- Auto-detected (.exe on Windows)
  main_file_patterns = { 'main.odin', '*.odin' },   -- Files to search for a main procedure
  main_proc_pattern = 'main%s*::%s*proc',           -- Pattern to find the main procedure
  notifications = true,                              -- Show build notifications
  max_search_depth = 10,                             -- Maximum parent directories to search
})
```

### Example Custom Configuration

```lua
require("nvim-dap-odin").setup({
  build_flags = "-debug -opt:0 -subsystem:console",
  release_flags = "-o:speed",
  output_dir = "./build",
  notifications = false,
})
```

-----

## Usage

### Commands

| Command | Description |
| :--- | :--- |
| `:OdinBuild` | Performs a **release build** of the Odin project. |
| `:OdinDebug` | Performs a **debug build** and immediately starts debugging. |

### DAP Configurations

The plugin automatically registers these debug configurations:

  * **Odin: Auto-build and Launch:** Builds the project and launches the debugger.
  * **Odin: Auto-build and Launch (with args):** Prompts for command-line arguments before building and launching.
  * **Odin: Launch (Manual):** Manually select an executable to debug.
  * **Odin: Launch (Manual, with args):** Manually select an executable and provide arguments.

### Workflow Examples

#### Quick Debug Session

1.  Open your Odin project in Neovim.
2.  Run `:OdinDebug`.
3.  The plugin builds your project with debug flags and starts debugging automatically.

#### Using a DAP UI

1.  Open your preferred DAP UI (e.g., [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui)).
2.  Select "Odin: Auto-build and Launch" from the available configurations.
3.  Set your breakpoints and begin debugging.

-----

## Main File Detection

The plugin's logic for finding your main file is now more robust. It:

1.  Starts in the current directory and searches upwards.
2.  First looks for a file named `main.odin`.
3.  If `main.odin` isn't found, it searches all `*.odin` files for the `main :: proc` pattern.
4.  It uses the first file containing a main procedure it finds within the configured `max_search_depth`.

-----

## Build Process

The plugin executes the build command from the **project's root directory**. It names the output executable based on the directory name (e.g., `my_project.exe`).

The commands executed are:

  * For **`:OdinBuild`**: `odin build <project_root> <release_flags> -out:<output_path>`
  * For **`:OdinDebug`** (and auto-launch): `odin build <project_root> <build_flags> -out:<output_path>`

-----

## Troubleshooting

  * **Build fails with "odin command not found"**
      * **Solution:** Ensure the Odin compiler is installed and its path is in your system's `PATH` variable. Test with `odin version` in your terminal.
  * **No main file detected**
      * **Solution:** Verify that your project has either a `main.odin` file or an Odin file containing a `main :: proc` definition. The plugin will search upwards to find it.
  * **Debugger doesn't start**
      * **Solution:** Confirm that `codelldb` is installed and properly configured with `nvim-dap`. Make sure the built executable has debug symbols by checking your `build_flags` configuration.
  * **Executable permissions**
      * **Solution:** If the build is successful but the debugger can't launch, check the file permissions on the generated executable to ensure it's executable.

-----

## API

The plugin exposes these functions for advanced usage:

```lua
local odin_dap = require("nvim-dap-odin")

-- Builds the project with debug flags and a specific output name.
local executable_path = odin_dap.build("debug", "my_program")

-- Find the main directory and file.
local main_dir, main_file = odin_dap.find_main_directory()
```

-----

## License

MIT

