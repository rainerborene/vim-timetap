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

" }}}

let s:saved_cpo = &cpo
set cpo&vim


if !exists("g:timetap_database")
  let g:timetap_database = "~/.timetapinfo"
endif

" command! -nargs=0 TimeTap call timetap#HoursWasted()

command! -nargs=0 TimeTap call s:tt.show(expand("%:p"))
command! -nargs=0 TimeTapProject call s:tt.show(getcwd())

if !exists("g:timetap_do_mapping") || g:timetap_do_mapping
  nnoremap <silent> <leader>T :TimeTap<Cr>
endif

" data-file is managed each day
" today
let s:tt = timetap#new(timetap#dbname(0))
" total
let s:tt.summary = timetap#new(timetap#dbname(1))

" Command


augroup TimeTap
  autocmd!

  autocmd BufEnter,WinEnter,FocusGained * call s:tt.StartTracking()
  autocmd BufWritePre,WinLeave,FocusLost * call s:tt.StopTracking()
  autocmd BufWritePost * call s:tt.save()
  autocmd CursorHold,CursorHoldI * call s:tt.detect_cursor_move()
augroup END

" }}}


let &cpo = s:saved_cpo
unlet s:saved_cpo

" vim: fen fdm=marker et ts=2 sw=2 sts=2
