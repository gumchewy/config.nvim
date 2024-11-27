#!/usr/bin/env lua
-- vim: noexpandtab:tabstop=4:shiftwidth=4:textwidth=80
-- vim: foldlevel=2:foldmethod=expr

--
--
-- ~/dev/config.nvim/lua/config/init.lua
--
--

-- Table passed to setup() that contains a dictionary of pairs
-- Schema:
-- 	key			= (str) alias, shorthand argument passed to "Config" command
--	value		= pair table
	-- 	[1]	= (str)	filepath of of the file to edit
	-- 	[2]	= (tbl(str)) shell commands to execute once the file has been written
local config_settings = {}

-- If success, returns shell command table
-- If failure, returns nil
local function check_shell_commands_exist(alias)
	local _, tbl_shell_commands = config_settings[alias]
	if tbl_shell_commands == nil then return nil end

	for index = 1, #tbl_shell_commands, 1 do
		local command = tbl_shell_commands[index]

		if not vim.fn.executable(string.match(command,"%S+")) then
			vim.api.nvim_err_write(command .. " not executable\n")
			return nil
		end
	end
	
	return tbl_shell_commands
end

-- If success, returns expanded filepath
-- If failure, returns empty string 
local function check_alias_and_filepath_valid(alias)
	-- Is defined?
	if config_settings[alias] ~= nil then
		vim.api.nvim_err_write(alias .. " not defined\n")
		return ""
	end

	-- File exists?
	local filepath_expanded = vim.fn.expand(config_settings[alias][1])
	if not vim.fn.exists(filepath_expanded) then
		vim.api.nvim_err_write(filepath_expanded .. " not found\n")
		return ""
	end

	return filepath_expanded
end

local function setup_buf_autocmd_on_write(tbl_shell_commands, buffer)
	vim.api.nvim_create_autocommand("BufWritePost", {
		group	= "Config",
		buffer	= buffer,
		callback = function()
			for _, command in ipairs(tbl_shell_commands) do
				vim.system(command)
			end
		end
	})
end

local function open_config_files(nvim_user_command_table)
	local tbl_aliases = nvim_user_command_table.fargs

	for _, alias in ipairs(tbl_aliases) do
		local filepath = check_alias_and_filepath_valid(alias)
		if filepath == "" then return end

		vim.cmd.edit(filepath)
		local buffer = vim.api.nvim_get_current_buf()

		local tbl_commands = check_shell_commands_exist(alias)
		if tbl_commands == nil then return end
		
		setup_buf_autocmd_on_write(tbl_commands, buffer)
	end
end

local M = {}

function M.setup(opts)
	-- User calls command with argument equal to a pre-defined alias
	vim.api.nvim_create_user_command("Config", open_config_files)

	-- For shell command execution upon write
	vim.api.nvim_create_augroup("Config", { clear = true })

	for alias, filepath_and_commands in pairs(opts.configs) do
		config_settings[alias] = filepath_and_commands
	end
end

return M
