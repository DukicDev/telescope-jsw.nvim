local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local Job = require("plenary.job")

local config = {
	url = nil,
	jql = "assignee=currentUser() and Status != Done",
	cache_duration = 60 * 10,
}

local setup = function(opts)
	config.url = opts.url:gsub("/$", "") or config.url
	config.jql = opts.jql or config.jql
	config.cache_duration = opts.cache_duration or config.cache_duration
end

local cache = {
	issues = nil,
	last_fetch = 0,
}
-- Cache duration in seconds
local cache_duration = config.cache_duration

local cache_file = vim.fn.stdpath("cache") .. "telescope_jsw_cache.json"

local save_cache_to_file = function()
	local cache_data = {
		issues = cache.issues,
		last_fetch = cache.last_fetch,
	}
	local file = io.open(cache_file, "w")
	if file then
		file:write(vim.fn.json_encode(cache_data))
		file:close()
	else
		vim.notify("Error writing to cache file.", vim.log.levels.ERROR)
	end
end

local load_cache_from_file = function()
	local file = io.open(cache_file, "r")
	if file then
		local content = file:read("*a")
		file:close()
		local cache_data = vim.fn.json_decode(content)
		if cache_data and os.time() - cache_data.last_fetch < cache_duration then
			cache.issues = cache_data.issues
			cache.last_fetch = cache_data.last_fetch
		else
			cache.issues = nil
			cache.last_fetch = 0
		end
	end
end

load_cache_from_file()

local get_issues = function(url, jql, no_cache, callback)
	local current_time = os.time()
	if not no_cache and cache.issues and (current_time - cache.last_fetch < cache_duration) then
		callback(cache.issues)
		return
	end
	local api_token = os.getenv("JIRA_API_TOKEN")
	local user_email = os.getenv("JIRA_USER_EMAIL")

	if not api_token then
		vim.notify("Jira API Token missing. Add 'JIRA_API_TOKEN' environment variable.", vim.log.levels.ERROR)
		return nil
	end

	if not user_email then
		vim.notify("Jira User Mail missing. Add 'JIRA_USER_EMAIL' environment variable.", vim.log.levels.ERROR)
		return nil
	end

	local search_url = url .. "/rest/api/3/search"

	Job:new({
		command = "curl",
		args = {
			"-s",
			"-u",
			user_email .. ":" .. api_token,
			"-X",
			"GET",
			"-G",
			search_url,
			"--data-urlencode",
			"jql=" .. jql,
			"-H",
			"Content-Type: application/json",
		},
		on_exit = function(job, return_val)
			if return_val == 0 then
				local result = table.concat(job:result(), "\n")
				local json = vim.json.decode(result)

				vim.schedule(function()
					if json and json.issues then
						if next(json.issues) ~= nil then
							cache.issues = json.issues
							cache.last_fetch = os.time()
							save_cache_to_file()
							callback(json.issues)
						else
							vim.notify("No Issues assigned to you! Congrats :D", vim.log.levels.INFO)
						end
					else
						vim.notify("Error while getting the issues", vim.log.levels.ERROR)
					end
				end)
			else
				vim.schedule(function()
					vim.notify("Error during http request", vim.log.levels.ERROR)
				end)
			end
		end,
	}):start()
end
local function parse_description(content)
	local lines = {}

	local function parse_node(node)
		if node.type == "text" then
			table.insert(lines, node.text)
		elseif node.type == "paragraph" then
			for _, child in ipairs(node.content or {}) do
				parse_node(child)
			end
			table.insert(lines, "")
		elseif node.type == "heading" then
			local heading = ""
			for _, child in ipairs(node.content or {}) do
				if child.type == "text" then
					heading = heading .. child.text
				end
			end
			table.insert(lines, heading)
			table.insert(lines, "")
		elseif node.type == "bulletList" or node.type == "orderedList" then
			for _, item in ipairs(node.content or {}) do
				table.insert(
					lines,
					(node.type == "orderedList" and "* " or "- ") .. (item.content[1].content[1].text or "")
				)
			end
			table.insert(lines, "")
		elseif node.type == "codeBlock" then
			table.insert(lines, "```")
			table.insert(lines, node.content[1].text or "")
			table.insert(lines, "```")
		end
	end

	for _, node in ipairs(content or {}) do
		parse_node(node)
	end

	return lines
end

local issues = function(opts)
	opts = opts or {}
	local no_cache = opts.no_cache or false
	local url = config.url
	local jql = config.jql
	local issue_endpoint = "/browse/"

	if not url then
		vim.notify("No URL configured.", vim.log.levels.ERROR)
		return
	end

	get_issues(url, jql, no_cache, function(issues)
		local finder = finders.new_table({
			results = issues,
			entry_maker = function(entry)
				return {
					value = entry,
					display = entry.key .. " - " .. entry.fields.summary,
					ordinal = entry.key .. entry.fields.summary .. entry.fields.status.statusCategory.name,
				}
			end,
		})

		pickers
			.new(opts, {
				prompt_title = "Jira Software Issues",
				finder = finder,
				sorter = conf.generic_sorter(opts),
				previewer = previewers.new_buffer_previewer({
					title = "Issue preview",
					define_preview = function(self, entry, status)
						local selection = action_state.get_selected_entry()
						local summary = selection.display or "No summary"
						local status = selection.value.fields.status.statusCategory.name or "No Status"
						local assignee = selection.value.fields.assignee
						if assignee == vim.NIL then
							assignee = "Unassigned"
						else
							assignee = "Assignee: " .. assignee.displayName
						end
						local description_content = selection.value.fields.description
						local description = ""
						if description_content == vim.NIL then
							description = "No Description"
						else
							description_content = selection.value.fields.description.content
							description = description_content and parse_description(description_content)
								or { "No Description" }
						end
						if type(description) == "table" then
							vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
								"",
								summary,
								"",
								string.upper(status),
								"",
								assignee,
								"",
								"",
								unpack(description),
							})
						else
							vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
								"",
								summary,
								"",
								string.upper(status),
								"",
								assignee,
								"",
								"",
								description,
							})
						end
					end,
				}),
				attach_mappings = function(prompt_bufnr, map)
					actions.select_default:replace(function()
						actions.close(prompt_bufnr)
						local Selection = action_state.get_selected_entry()
						vim.system({ "open", url .. issue_endpoint .. Selection.value.key })
					end)
					return true
				end,
			})
			:find()
	end)
end
return {
	setup = setup,
	jira_issues = issues,
}
