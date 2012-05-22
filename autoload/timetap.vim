" autoload/timetap.vim
"
" Author: Rainer Borene <https://github.com/rainerborene>
"         Takahiro Yoshiahra <https://github.com/tacahiroy>
" Licensed under the same terms of Vim.

let s:saved_cpo = &cpo
set cpo&vim

let s:STOP  = 0
let s:START = 1

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

function! s:GetCurrentFile()
  return expand("%:p")
endfunction

function! s:IsTracked(f)
  return !empty(a:f) && has_key(s:timetap_records, a:f)
endfunction

function! s:ShortenPath(s)
  if a:s == $HOME
    return a:s
  else
    return substitute(a:s, '^'.$HOME, '~', '')
  endif
endfunction

function! s:ExpandPath(s)
  " error E33 would occur if you forget to escape tilde
  return substitute(a:s, '\~', $HOME, 'g')
endfunction

" public " {{{
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

function! timetap#complete(A, L, P)
endfunction

function! timetap#new(f)
  let obj = deepcopy(s:TimeTap)
  call obj.set_database(a:f)
  call obj.load()
  return obj
endfunction

" args: k: int: 0 => today's, 1 => full
function! timetap#dbname(k)
  return a:k ? "full.db" : strftime("%Y%m%d.db")
endfunction
" }}}

" Object " {{{
let s:TimeTap = {}

function! s:TimeTap.set_database(name) dict
  let self.db = self.data_dir . '/' . a:name
endfunction

function! s:TimeTap.StartTracking() dict
  let path = s:GetCurrentFile()

  if self.is_ignored(path)
    return
  endif

  if !self.is_known(path)
    call self.add_file(path)
  endif

  if self.files[path].status == s:START
    return
  endif

  " date might be changed when the file is being edited
  call self.set_database(timetap#dbname(0))

  let self.files[path].start = localtime()
  let self.files[path].status = s:START
  let self.files[path].cursor = getpos(".")
endfunction

function! s:TimeTap.StopTracking() dict
  let path = s:GetCurrentFile()
  if !self.is_known(path)
    return
  endif

  if self.files[path].status == s:STOP
    return
  endif

  let self.files[path].end = localtime()

  call self.calc(path)
  call self.reset(path)
endfunction

function! s:TimeTap.detect_cursor_move() dict
  let f = s:GetCurrentFile()
  if !self.observe_cursor_position
    return
  endif

  if !self.is_known(f)
    return
  endif

  let cur_pos = getpos(".")

  if self.files[f].cursor == cur_pos
    call self.StopTracking()
  else
    if self.files[f].status == s:STOP
      call self.StartTracking()
    else
      let self.files[f].cursor = cur_pos
    endif
  endif
endfunction

function! s:TimeTap.is_known(f) dict
  return has_key(self.files, a:f)
endfunction

function! s:TimeTap.add_file(f) dict
  let self.files[a:f] = { 'start': [], 'end': [], 'total': 0, 'status': s:STOP }
endfunction

function! s:TimeTap.reset(f) dict
  let self.files[a:f].start = 0
  let self.files[a:f].end = 0
  let self.files[a:f].status = s:STOP
endfunction

function! s:TimeTap.get_total(f) dict
  return self.is_known(a:f) ? self.files[a:f].total : 0
endfunction

function! s:TimeTap.remove(f) dict
  call remove(self.files, a:f)
endfunction

function! s:TimeTap.calc(f) dict
  " today
  let period = self.files[a:f].end - self.files[a:f].start
  let self.files[a:f].total += period

  " total
  if !self.summary.is_known(a:f)
    call self.summary.add_file(a:f)
  endif
  let self.summary.files[a:f].total += period

  call self.save()
  call self.summary.save()
endfunction

function! s:TimeTap.save() dict
  let files = []
  for [k, v] in items(self.files)
    let info = {}
    let info[k] = {'total': v.total}
    call add(files, string(info))
  endfor
  call writefile(files, self.db)
endfunction

function! s:TimeTap.load() dict
  if !filereadable(self.db)
    return
  endif

  let files = readfile(self.db)
  for f in files
    for [k, v] in items(eval(f))
      let self.files[k] = v
      call extend(self.files[k], {'start': [], 'end': [], 'status': s:STOP})
    endfor
  endfor
endfunction

" TODO: display into a buffer
" TODO: omit file name if it's better
function! s:TimeTap.show(path) dict
  try
    call self.StopTracking()

    if a:0 == 0 && self.is_ignored(s:GetCurrentFile())
      return
    endif

    let files = filter(copy(self.summary.files), "v:key =~# '^".a:path."'")

    let sortedlist = self.sort(files)
    if !self.is_display_zero
      let sortedlist = self.filter(sortedlist)
    endif
    let sortedlist = sortedlist[0:self.display_limit - 1]

    let sum = 0
    let today = 0
    for [k, v] in sortedlist
      let sum += self.summary.files[k].total
      let today += self.get_total(k)
      " echo printf("%s %s", k, s:PrettyPrint(self.summary.files[k].total))
    endfor

    echo printf("%s: %s (%s)", s:ShortenPath(a:path), s:PrettyPrint(today), s:PrettyPrint(sum))
  finally
    call self.StartTracking()
  endtry
endfunction

function! s:TimeTap.sort(files) dict
  let list = []

  for [k, v] in items(a:files)
    call add(list, [k, v])
  endfor

  if empty(self.sort_function)
    let self.sort_function = self.sort_by_timetap
  endif

  return sort(sort(list), self.sort_function, self)
endfunction

function! s:TimeTap.filter(list)
  let l = filter(a:list, '0.0 < v:val[1].total')
  return filter(l, 'filereadable(v:val[0])')
endfunction

function! s:TimeTap.sort_by_timetap(a, b) dict
  " a:a[0] => key, [1] => {'total': 999.99}
  let a = a:a[1].total
  let b = a:b[1].total
  let r = 0

  if a < b
    let r = -1
  elseif b < a
    let r = 1
  else
    let r = 0
  endif

  return r * (self.is_sort_order_desc ? -1 : 1)
endfunction

function! s:TimeTap.sort_by_name(a, b) dict
  let a = a:a[0]
  let b = a:b[0]
  let r = 0

  if a < b
    let r = -1
  elseif b < a
    let r = 1
  else
    let r = 0
  endif

  return r * (self.is_sort_order_desc ? -1 : 1)
endfunction

" returns whether {f} is ignored or not
function! s:TimeTap.is_ignored(f) dict
  if empty(a:f)
    return 1
  endif

  if isdirectory(a:f)
    return 1
  endif

  if expand(a:f) == self.db
    return 1
  endif

  if !empty(&l:buftype)
    return 1
  endif

  if !empty(self.accept_path_pattern)
    if a:f !~# self.accept_path_pattern
      return 1
    endif
  endif

  if !empty(self.ignore_path_pattern)
    if a:f =~# self.ignore_path_pattern
      return 1
    endif
  endif

  return 0
endfunction

let s:is_debug = get(g:, 'timetap_is_debug', 0)

""
" Initialization etc ...
"
let s:TimeTap.files = {}
let s:TimeTap.db = ''
let s:TimeTap.summary = {}

let s:data_dir = expand(get(g:, 'timetap_data_dir', '~/.timetap'))
if !isdirectory(s:data_dir)
  call mkdir(s:data_dir, 'p')
endif
let s:TimeTap.data_dir = s:data_dir

" NOTE: files that `accept_path_pattern` - `ignore_path_pattern` are managed
" if both pattern are specified
let s:TimeTap.accept_path_pattern = s:ExpandPath(get(g:, 'timetap_accept_path_pattern', ''))
let s:TimeTap.ignore_path_pattern = s:ExpandPath(get(g:, 'timetap_ignore_path_pattern', ''))

let s:TimeTap.is_display_zero = get(g:, 'timetap_is_display_zero', 0)
let s:TimeTap.display_limit = get(g:, 'timetap_display_limit', 10)

" sort
let s:sort_functions = filter(keys(s:TimeTap),
      \ 'v:val =~ "^sort_by_" && type(s:TimeTap[v:val]) == type(function("tr"))')

let s:DEFAULT_SORT_METHOD = 'sort_by_timetap'
let s:sort_method = get(g:, 'timetap_sort_method', s:DEFAULT_SORT_METHOD)
if index(s:sort_functions, s:sort_method) == -1
  let s:sort_method = s:DEFAULT_SORT_METHOD
endif
let s:TimeTap.sort_function = s:TimeTap[s:sort_method]

let s:TimeTap.is_sort_base_today = get(g:, 'timetap_is_sort_base_today', 1)
let s:TimeTap.is_sort_order_desc = get(g:, 'timetap_is_sort_order_desc', 1)

let s:TimeTap.observe_cursor_position = get(g:, 'timetap_observe_cursor_position',
                                                   \ has('gui_running') ? 0 : 1)
" }}}

let &cpo = s:saved_cpo
unlet s:saved_cpo

" vim: fen fdm=marker et ts=2 sw=2 sts=2
