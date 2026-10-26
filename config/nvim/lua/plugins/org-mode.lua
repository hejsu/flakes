return {
  'nvim-orgmode/orgmode',
  event = 'VeryLazy',
  config = function()
    require('orgmode').setup({
      org_agenda_files = '~/Documents/orgfiles/**/*',
      org_default_notes_file = '~/Documents/orgfiles/refile.org',
    })
   -- Experimental LSP support
   vim.lsp.enable('org')
  end,
}
