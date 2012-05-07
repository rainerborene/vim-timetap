" plugin/timetape.vim
"
" Author: Rainer Borene <https://github.com/rainerborene>
" Licensed under the same terms of Vim.

" Initialization {{{

if exists("g:timetape_loaded")
  finish
endif

let g:timetape_loaded = 1
let g:timetape_database = "~/.timetapeinfo"
let s:timetape_entries = {}

if !exists("g:timetape_do_mapping") || g:timetape_do_mapping == 1
  nnoremap <leader>h :TimeTape<cr>
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
  let s:timetape_entries[expand("%:p")] = localtime()
endfunction " }}}

function! s:StopTracking() " {{{
  let l:full_path = expand("%:p")
  let l:start_date = get(s:timetape_entries, l:full_path)
  let l:end_date = localtime()

  " Register values to the database
  call s:Register(l:full_path, l:start_date, l:end_date)

  " Restart current timestamp
  let s:timetape_entries[l:full_path] = localtime()
endfunction " }}}

function! s:Register(path, start, end) "{{{
  silent exe '!touch ' . g:timetape_database
  let l:line = printf("%s|%s|%s", a:path, a:start, a:end)
  let l:data = readfile(expand(g:timetape_database), "b")
  call add(l:data, l:line)
  call writefile(l:data, expand(g:timetape_database), "b")
endfunction " }}}

function! s:HoursWasted() " {{{
  echohl Question
  let query = input("Working directory: ", expand("%:p:h"), "dir")
  redraw

  let seconds = 0
  for line in readfile(expand(g:timetape_database), '')
    let fields = split(line, "|")
    if !empty(fields) && fields[0] =~ query
      let period = abs(fields[1] - fields[2])
      let seconds += period
    endif
  endfor

  echohl Title
  echo "You worked " . s:PrettyPrint(seconds) . "."
  echohl None
endfunction " }}}

command! -nargs=0 TimeTape call s:HoursWasted()

" }}}
" Auto commands {{{

autocmd BufEnter *.* call s:TrackBuffer()
autocmd BufWritePost *.* call s:StopTracking()

" }}}
