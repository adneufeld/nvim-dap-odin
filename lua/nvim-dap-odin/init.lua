local M = {}

-- Default configuration
local default_config = {
	build_command = "odin build",
	build_flags = "-debug", -- Used for debug builds
	release_flags = "", -- Flags for non-debug (release) builds
	output_dir = nil, -- nil means same directory as the main package
	executable_extension = vim.fn.has("win32") == 1 and ".exe" or "",
	main_file_patterns = { "main.odin", "*.odin" },
	main_proc_pattern = "main%s*::%s*proc",
	notifications = true,
	fallback_to_manual = true,
	max_search_depth = 10,
}

local config = default_config

-- Utility functions
local function notify(msg, level)
	if config.notifications then
		vim.notify(msg, level or vim.log.levels.INFO)
	end
end

local function find_main_directory()
	local current_dir = vim.fn.getcwd()
	local search_dir = current_dir
	local depth = 0

	-- Search upwards through parent directories
	while search_dir ~= "/" and search_dir ~= "" and depth < config.max_search_depth do
		-- Check for main.odin in this directory
		local main_path = search_dir .. "/main.odin"
		if vim.fn.filereadable(main_path) == 1 then
			return search_dir, "main.odin"
		end

		-- Search for any .odin file with main procedure in this directory
		local odin_files = vim.fn.glob(search_dir .. "/*.odin", false, true)
		for _, file in ipairs(odin_files) do
			-- Only read files that aren't too large (performance consideration)
			local file_size = vim.fn.getfsize(file)
			if file_size >= 0 and file_size < 1024 * 1024 then -- Skip files > 1MB
				local content = vim.fn.readfile(file)
				for _, line in ipairs(content) do
					if line:match(config.main_proc_pattern) then
						return search_dir, vim.fn.fnamemodify(file, ":t")
					end
				end
			end
		end

		-- Move up one directory
		local parent = vim.fn.fnamemodify(search_dir, ":h")
		if parent == search_dir then
			break -- Reached root or hit a filesystem boundary
		end
		search_dir = parent
		depth = depth + 1
	end

	-- If no main found anywhere, use current directory
	return current_dir, nil
end

-- Refactored build function to handle different build types and output names
-- @param build_type 'debug' or 'release'
-- @param output_name_override string to override the executable name (optional)
local function build_project(build_type, output_name_override)
	local build_dir, main_file = find_main_directory()

	if not main_file then
		notify("Could not find a main Odin file.", vim.log.levels.ERROR)
		return nil
	end

	-- Determine build flags based on the requested type
	local build_flags = (build_type == "debug") and config.build_flags or config.release_flags

	-- Determine the executable name based on the override or project directory name
	local output_name
	if output_name_override then
		output_name = output_name_override .. config.executable_extension
	else
		local project_name = vim.fn.fnamemodify(build_dir, ":t")
		output_name = project_name .. config.executable_extension
	end

	local output_path
	if config.output_dir then
		-- Create the output directory if it doesn't exist
		vim.fn.mkdir(config.output_dir, "p")
		output_path = config.output_dir .. "/" .. output_name
	else
		output_path = build_dir .. "/" .. output_name
	end

	-- Build the command - use full output path so Odin knows exactly where to put it
	local build_cmd = string.format(
		"%s %s %s -out:%s",
		config.build_command,
		build_dir,
		build_flags,
		output_path -- Use full path instead of just filename
	)

	notify("Building Odin project: " .. build_cmd)

	-- Execute build from the build directory
	local old_cwd = vim.fn.getcwd()
	vim.cmd("cd " .. vim.fn.fnameescape(build_dir))

	local result = vim.fn.system(build_cmd)
	local exit_code = vim.v.shell_error

	-- Restore original directory
	vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))

	if exit_code ~= 0 then
		-- This is the key change: use vim.fn.confirm for blocking on errors
		vim.fn.confirm("Build failed:\n" .. result, "&OK", 1)
		return nil
	end

	-- Check if executable was created
	if vim.fn.filereadable(output_path) == 1 then
		notify("Build successful: " .. output_path)
		return output_path
	else
		notify("Build completed but executable not found: " .. output_path, vim.log.levels.ERROR)
		return nil
	end
end

-- Main function to get program path with auto-build
function M.get_program_path(opts)
	opts = opts or {}
	local auto_build = opts.auto_build ~= false -- default to true
	local program_path_override = opts.program_path_override

	if auto_build then
		local built_path = build_project(
			"debug", -- Always a debug build for auto-launch
			"debug" -- Always named 'debug' for auto-launch
		)
		-- Early-exit if the build failed
		if not built_path then
			return nil
		end
		return built_path
	else
		return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
	end
end

-- Function to setup DAP configurations
function M.setup_dap_config()
	local ok, dap = pcall(require, "dap")
	if not ok then
		notify("nvim-dap not found. Please install nvim-dap first.", vim.log.levels.ERROR)
		return
	end

	dap.configurations.odin = {
		{
			name = "Odin: Auto-build and Launch",
			type = "codelldb",
			request = "launch",
			program = function()
				local program_path = M.get_program_path({ auto_build = true })
				if not program_path then
					-- Early exit on build failure
					return
				end
				return program_path
			end,
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
			args = {},
			runInTerminal = false,
		},
		{
			name = "Odin: Auto-build and Launch (with args)",
			type = "codelldb",
			request = "launch",
			program = function()
				local program_path = M.get_program_path({ auto_build = true })
				if not program_path then
					-- Early exit on build failure
					return
				end
				return program_path
			end,
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
			args = function()
				local input = vim.fn.input("Arguments: ")
				return vim.split(input, " ")
			end,
			runInTerminal = false,
		},
		{
			name = "Odin: Launch (Manual)",
			type = "codelldb",
			request = "launch",
			program = function()
				return M.get_program_path({ auto_build = false })
			end,
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
			args = {},
			runInTerminal = false,
		},
		{
			name = "Odin: Launch (Manual, with args)",
			type = "codelldb",
			request = "launch",
			program = function()
				return M.get_program_path({ auto_build = false })
			end,
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
			args = function()
				local input = vim.fn.input("Arguments: ")
				return vim.split(input, " ")
			end,
			runInTerminal = false,
		},
	}

	notify("Odin DAP configurations loaded")
end

-- User commands
local function create_commands()
	-- This command now performs a non-debug (release) build
	vim.api.nvim_create_user_command("OdinBuild", function()
		build_project("release") -- No output name override, so it uses the project directory name
	end, { desc = "Build Odin project" })

	-- This command now performs a debug build
	vim.api.nvim_create_user_command("OdinDebug", function()
		-- The build function returns the path, but we don't need it for this command
		-- as DAP.run will call get_program_path again
		build_project("debug", "debug") -- Use 'debug' as the output name
	end, { desc = "Build and debug Odin project" })
end

-- Setup function
function M.setup(user_config)
	-- Merge user config with defaults
	if user_config then
		config = vim.tbl_deep_extend("force", default_config, user_config)
	end

	-- Create user commands
	create_commands()

	-- Auto-setup DAP if it's available
	vim.defer_fn(function()
		local ok, _ = pcall(require, "dap")
		if ok then
			M.setup_dap_config()
		end
	end, 100) -- Small delay to ensure DAP is loaded
end

-- Export functions for manual use
M.build = build_project
M.find_main_directory = find_main_directory

return M
