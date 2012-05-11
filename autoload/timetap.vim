" autoload/timetap.vim
"
" Author: Rainer Borene <https://github.com/rainerborene>
"         Takahiro Yoshiahra <https://github.com/tacahiroy>
" Licensed under the same terms of Vim.

let s:saved_cpo = &cpo
set cpo&vim

let s:timetap_records = { "__cache": [] }

" Functions

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

function! s:GetAbsolutePath()
  return expand("%:p")
endfunction

" public {{{
function! timetap#TrackBuffer() " {{{
  let path = s:GetAbsolutePath()
  if empty(path)
    return
  endif

  let s:timetap_records[path] = localtime()
endfunction " }}}

function! timetap#StopTracking() " {{{
  let full_path = s:GetAbsolutePath()

  if empty(full_path) || !has_key(s:timetap_records, full_path)
    return
  endif

  let start_date = get(s:timetap_records, full_path)
  let end_date = localtime()

  let line = printf("%s|%s|%s", full_path, start_date, end_date)
  call add(s:timetap_records['__cache'], line)
  let s:timetap_records[full_path] = localtime()
endfunction " }}}

function! timetap#SaveDatabase() "{{{
  " FIXME: only works in *nix system
  silent exe '!touch ' . g:timetap_database
  let data = readfile(expand(g:timetap_database), "b")
  for line in s:timetap_records['__cache']
    call add(data, line)
  endfor
  call writefile(data, expand(g:timetap_database), "b")
  let s:timetap_records['__cache'] = []
endfunction " }}}

function! timetap#HoursWasted() " {{{
  echohl Question
  let query = input("Working directory: ", getcwd(), "dir")
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
" }}}

let &cpo = s:saved_cpo
unlet s:saved_cpo

" vim: fen fdm=marker et ts=2 sw=2 sts=2
