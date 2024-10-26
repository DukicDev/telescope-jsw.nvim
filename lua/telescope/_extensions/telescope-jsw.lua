return require("telescope").register_extension({
	setup = function(ext_config, config) end,
	exports = {
		setup = require("telescope-jsw").setup,
		jira_issues = require("telescope-jsw").jira_issues,
	},
})
