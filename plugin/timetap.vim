" plugin/timetap.vim
"
" Author: Rainer Borene <https://github.com/rainerborene>
" Licensed under the same terms of Vim.

" Initialization {{{

if exists("g:timetap_loaded")
  finish
endif

let g:timetap_loaded = 1
let g:timetap_database = "~/.timetapinfo"
let s:timetap_records = { '__cache': [] }

if !exists("g:timetap_do_mapping") || g:timetap_do_mapping == 1
  nnoremap <leader>h :TimeTap<cr>
endif

" }}}
" Functions {{{

function! s:DateDebug(values) " {{{
  let from = strftime("%H:%M:%S", a:values[1])
  let to = strftime("%H:%M:%S", a:values[2])
  let diff = abs(a:values[1] - a:values[2])
  echo printf("%s - %s - %s", from, to, diff)
endfunction " }}}

function! s:PrettyPrint(seconds) " {{{
  let pp = []
  let hours = floor(a:seconds / 3600)
  let minutes = ceil(fmod(a:seconds, 3600) / 60)
  if hours > 0
    call add(pp, float2nr(hours))
    call add(pp, hours > 1 ? "hours" : "hour")
  endif
  if hours > 0 && minutes > 0
    call add(pp, "and")
  endif
  if minutes > 0
    call add(pp, float2nr(minutes))
    call add(pp, minutes > 1 ? "minutes" : "minute")
  endif
  return join(pp)
endfunction " }}}

function! s:TrackBuffer() " {{{
  let s:timetap_records[expand("%:p")] = localtime()
endfunction " }}}

function! s:StopTracking() " {{{
  let full_path = expand("%:p")
  let start_date = get(s:timetap_records, full_path)
  let end_date = localtime()

  if !empty(full_path)
    let line = printf("%s|%s|%s", full_path, start_date, end_date)
    call add(s:timetap_records['__cache'], line)
    let s:timetap_records[full_path] = localtime()
  endif
endfunction " }}}

function! s:SaveDatabase() "{{{
  let data = readfile(expand(g:timetap_database), "b")
  for line in s:timetap_records['__cache']
    call add(data, line)
  endfor
  call writefile(data, expand(g:timetap_database), "b")
  let s:timetap_records['__cache'] = []
endfunction " }}}

function! s:HoursWasted() " {{{
  echohl Question
  let query = input("Working directory: ", expand("%:p:h"), "dir")
  redraw

  let seconds = 0
  for line in readfile(expand(g:timetap_database), '')
    let fields = split(line, "|")
    if !empty(fields) && fields[0] =~ query
      let period = abs(fields[1] - fields[2])
      let seconds += period
    endif
  endfor

  if seconds
    echohl Title
    echo "You worked " . s:PrettyPrint(seconds) . "."
    echohl None
  else
    echohl ErrorMsg
    echom "You didn't work in this directory yet."
    echohl None
  endif
endfunction " }}}

command! -nargs=0 TimeTap call s:HoursWasted()

" }}}
" Auto commands {{{

autocmd BufEnter,WinEnter *.* call s:TrackBuffer()
autocmd BufWritePre,WinLeave, *.* call s:StopTracking()
autocmd BufWritePost *.* call s:SaveDatabase()

" }}}
