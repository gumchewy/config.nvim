#!/usr/bin/env lua
-- vim: noexpandtab:tabstop=4:shiftwidth=4:textwidth=80
-- vim: foldlevel=2:foldmethod=expr

--
--
-- ~/dev/file_alias.nvim/lua/file_alias/init.lua
--
--

local err = vim.api.nvim_err_write

-- Table passed to setup() that contains a dictionary of pairs
-- Schema:
-- 	key			= (str) alias, shorthand argument passed to "Config" command
--	value		= pair table
--		[1]	= (str)	filepath of of the file to edit
-- 		[2]	= (tbl(str)) shell commands to execute post file write
local files = {}

-- If success, returns expanded filepath
-- If failure, returns nil
local function get_filepath(alias)
	-- Is defined?
	if files[alias] == nil then
		err(alias .. ": not defined\n")
		return nil
	end

	-- File exists?
	local filepath = vim.fn.expand(files[alias].filepath)
	if not vim.fn.exists(filepath) then
		err(filepath .. ": not found\n")
		return nil
	end

	return filepath
end

-- If success, returns shell command table
-- If failure, returns nil
local function get_shell_cmds(alias)
	local shell_cmds = files[alias].execute

	-- Defined?
	if shell_cmds == nil then return nil end

	-- Correct Type?
	if type(shell_cmds) ~= "string" and type(shell_cmds) ~= "table" then
		err(alias .. ": execute set is neither a table nor string\n")
		return nil
	end

	if type(shell_cmds) == "string" then return shell_cmds end

	for _, cmd in ipairs(shell_cmds) do
		-- Correct Type?
		if type(cmd) ~= "string" then
			err("Value within execute of '" .. alias .. "' is not a string\n")
			return nil
		end

		-- Executable?
		-- Doesn't account for piping
		if not vim.fn.executable(string.match(cmd,"%S+")) then
			err(cmd .. ": not executable\n")
			return nil
		end
	end

	return shell_cmds
end

local function create_buf_autocmd(shell_cmds)
	vim.api.nvim_create_autocmd("BufWritePost", {
		group	= "Config",
		buffer	= vim.api.nvim_get_current_buf(),
		callback = function()
			if type(shell_cmds) == "string" then	-- Single Command
				vim.system(shell_cmds)
			else									-- Table of Commands
				for _, cmd in ipairs(shell_cmds) do vim.system(cmd) end
			end
		end
	})
end

local function open_files(user_cmd_invokation)
	local aliases = user_cmd_invokation.fargs

	if #aliases == 0 then
		err("Usage: Config <aliases>\n")
		return
	end

	for _, alias in ipairs(user_cmd_invokation.fargs) do
		local filepath = get_filepath(alias)
		if filepath	== nil then return end
		vim.cmd.edit(filepath)

		local shell_cmds = get_shell_cmds(alias)
		if shell_cmds == nil then return end
		create_buf_autocmd(shell_cmds)
	end
end

-- TODO: This
local function alias_completion(arg_lead, _, _)
	local potential_aliases = {}

	for alias, _ in ipairs(files) do
		--if string.match(alias, arg_lead) ~= nil then
			table.insert(potential_aliases, alias)
		--end
	end

	return potential_aliases
end

local M = {}

function M.setup(opts)
	for _, file in ipairs(opts) do
		-- Alias data type validation
		if type(file[1]) ~= "string" then
			err("my_file failed to load: alias is a "
				.. type(file[1]) .. "\n")
			return
		end

		-- Configs table population
		files[file[1]] = {filepath = file[2], execute = file[3]}
	end

	-- For shell command execution upon write
	vim.api.nvim_create_augroup("FileAlias", {})

	-- User calls command with argument equal to one or more pre-defined aliases
	vim.api.nvim_create_user_command("FileAlias", open_files, {
		nargs = "*",
		complete = alias_completion
	})
end

return M
