" plugin/timetap.vim
"
" Author: Rainer Borene <https://github.com/rainerborene>
"         Takahiro Yoshiahra <https://github.com/tacahiroy>
" Licensed under the same terms of Vim.

" Initialization {{{

if exists("g:timetap_loaded")
  finish
endif

let g:timetap_loaded = 1

if !exists("g:timetap_database")
  let g:timetap_database = "~/.timetapinfo"
endif

command! -nargs=0 TimeTap call timetap#HoursWasted()

if !exists("g:timetap_do_mapping") || g:timetap_do_mapping
  nnoremap <silent> <leader>T :TimeTap<cr>
endif
" }}}

" Auto commands {{{
autocmd BufEnter,WinEnter *.* call timetap#TrackBuffer()
autocmd BufWritePre,WinLeave *.* call timetap#StopTracking()
autocmd BufWritePost *.* call timetap#SaveDatabase()
" }}}

