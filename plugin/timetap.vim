" plugin/timetap.vim
"
" Author: Rainer Borene <https://github.com/rainerborene>
"         Takahiro Yoshiahra <https://github.com/tacahiroy>
" Licensed under the same terms of Vim.

" Initialization {{{

if exists("g:timetap_loaded") || &cp
  finish
endif

let g:timetap_loaded = 1

if !has("float")
  echoerr "Sorry. This plugin requires +float feature."
  finish
endif

let s:saved_cpo = &cpo
set cpo&vim


if !exists("g:timetap_database")
  let g:timetap_database = "~/.timetapinfo"
endif

command! -nargs=0 TimeTap call timetap#HoursWasted()

if !exists("g:timetap_do_mapping") || g:timetap_do_mapping
  nnoremap <silent> <leader>T :TimeTap<Cr>
endif
" }}}

" Auto commands {{{
autocmd BufEnter,WinEnter,FocusGained * call timetap#TrackBuffer()
autocmd BufWritePre,WinLeave,FocusLost * call timetap#StopTracking()
autocmd BufWritePost * call timetap#SaveDatabase()
" autocmd CursorHold,CursorHoldI *
" }}}


let &cpo = s:saved_cpo
unlet s:saved_cpo

