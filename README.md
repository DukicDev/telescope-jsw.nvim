# telescope-jsw.nvim

> [!WARNING]
> Still in development! \
> No tests were written during the development of this plugin. \
> Just install and pray

**telescope-jsw.nvim** is a [Neovim](https://neovim.io) plugin that integrates with the [Jira Cloud API](https://developer.atlassian.com/cloud/jira/platform/rest/v3/intro/#version) to bring Jira ticket search and preview capabilities directly to your editor. Built on [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim), this plugin enables you to quickly search, view, and interact with Jira issues, all from within Neovim.

## Features

- **Jira Issue Search**: Search Jira issues by key, summary, and status
- **Issue Preview**: View the summary, assignee, description, and status of any Jira ticket directly within Telescope's preview window.
- **Customizable Search Filters**: Use Jira Query Language (JQL) to set specific filters for your search.
- **Enhanced Navigation**: Quickly navigate through your tasks and issues without leaving the editor.
- **Open Jira**: Selecting an Entry opens the issue in your beloved Jira UI.


## Installation

>[!IMPORTANT]
>Your User Mail and Jira API Token need to be set as environment variables. \
>JIRA_USER_EMAIL and JIRA_API_TOKEN

### Requirements

- **Neovim 0.5+**
- [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [Plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### Installation with [lazy.nvim](https://github.com/folke/lazy.nvim)

Add `telescope-jsw.nvim` to your `lazy.nvim` setup:

```lua
require("lazy").setup({
  {
    "DukicDev/telescope-jsw",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim" },
    config = function()
      require("telescope").load_extension("telescope-jsw")
      require("telescope-jsw").setup({
        url = "https://your-jira-domain.atlassian.net",
        jql = "project = MYPROJECT AND status = 'To Do'", -- Optional: Set default JQL filter, otherwise "assignee = currentUser()" is used
        cache_duration = 60 * 5 -- Optional: Cache duration in seconds. Default is 60*10 (10min)
      })
    end,
  },
})
```


## Usage
```lua
require('telescope').extensions['telescope-jsw'].jira_issues()
```
gets the jira issues and opens telescope. 

### Options when calling jira_issues()
```lua
{
  no_cache = true -- Default: false
}
```
>[!NOTE]
>The cache file is stored at vim.fn.stdpath("cache")/telescope_jsw_cache.json

To easily launch the plugin, add a keymap in your Neovim init.lua:
```lua
vim.keymap.set(
    "n",
    "<leader>ji",
    "<cmd>lua require('telescope').extensions['telescope-jsw'].jira_issues()<CR>",
    { noremap = true, silent = true }
)
vim.keymap.set(
    "n",
    "<leader>jr",
    "<cmd>lua require('telescope').extensions['telescope-jsw'].jira_issues({no_cache = true})<CR>",
    { noremap = true, silent = true }
)
```
This keymap binds the telescope-jsw extension to leader-ji, allowing you to quickly open the Jira issue search within Neovim. leader-jr always sends a request, refreshing the cache.



## Screenshot
![Screenshot](assets/Screenshot.png?raw=true)

## Planned Features
- [ ] Caching
- [ ] Transitioning Issues
