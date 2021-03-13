let s:save_cpo = &cpo
set cpo&vim

let s:connections = []
let s:connection_index = 0
let g:iced_multi_session#does_switch_session = get(g:, 'iced_multi_session#does_switch_session', v:false)
let g:iced_multi_session#name_prefix = get(g:, 'iced_multi_session#name_prefix', 'new')

call iced#hook#add('disconnected', {
      \ 'type': 'function',
      \ 'exec': {_ -> iced_multi_session#disconnect()},
      \ })

function! s:init() abort
  if !iced#nrepl#is_connected() | return | endif
  if empty(s:connections)
    let s:connections += [{'name': 'main', 'conn': iced#nrepl#current_connection()}]
  else
    let s:connections[s:connection_index]['conn'] = iced#nrepl#current_connection()
  endif
endfunction

function! iced_multi_session#new(...) abort
  let session_name = get(a:, 1, '')
  if empty(session_name)
    let session_name = input('Name: ', g:iced_multi_session#name_prefix)
  endif
  if empty(session_name)
    return
  endif

  call s:init()
  let new_conn = iced#nrepl#reset_connection()
  let s:connection_index += 1
  let s:connections += [{'name': session_name, 'conn': new_conn}]
endfunction

function! s:switch(new_connection_index) abort
  call s:init()
  let s:connection_index = a:new_connection_index
  let conn = s:connections[s:connection_index]
  call iced#nrepl#reset_connection(conn['conn'])
  call iced#message#info_str(printf('MultiSession: changed to %s', conn['name']))
endfunction

function! iced_multi_session#next() abort
  call s:init()
  let next_connection_index = s:connection_index + 1
  if len(s:connections) == next_connection_index
    let next_connection_index = 0
  endif

  return s:switch(next_connection_index)
endfunction

function! iced_multi_session#list() abort
  call s:init()

  if empty(s:connections)
    return iced#message#warning_str('No sessions.')
  endif

  let idx = 0
  for conn in s:connections
    echo printf('%s %s',
          \ (idx == s:connection_index) ? '+' : ' ',
          \ conn['name'])
    let idx += 1
  endfor
endfunction

function! iced_multi_session#current() abort
  let current = get(s:connections, s:connection_index, {})
  let result = toupper(get(current, 'name', ''))
  if empty(result) | return '' | endif

  let connection_count = len(s:connections)
  if connection_count >= 2
    let indexes = range(len(s:connections))
    let indexes = filter(indexes, {_, i -> i != s:connection_index})
    let names = map(indexes, {_, i -> s:connections[i]['name']})
    let result .= printf('(%s)', join(names, '|'))
  endif

  return result
endfunction

function! iced_multi_session#disconnect() abort
  if len(s:connections) > s:connection_index
    unlet s:connections[s:connection_index]

    if len(s:connections) > 0
      let s:connection_index = 0
      let conn = s:connections[s:connection_index]
      call iced#nrepl#reset_connection(conn['conn'])

      call iced#message#info_str(printf('Disconnecting %s', conn['name']))
      call iced#nrepl#disconnect()
    endif
  endif
endfunction

function! iced_multi_session#connect() abort
  call s:init()

  let connection_count = len(s:connections)
  if connection_count > 0
    let new_name = printf('%s%s',
          \ g:iced_multi_session#name_prefix,
          \ connection_count == 1 ? '' : connection_count,
          \ )
    call iced_multi_session#new(new_name)
  endif

  exec ':IcedConnect'
endfunction

function! s:auto_switching_session() abort
  if iced#nrepl#check_session_validity(v:false) | return | endif

  let connection_count = len(s:connections)
  if connection_count == 2
    return iced_multi_session#next()
  elseif connection_count > 2
    return iced_multi_session#switch()
  endif
endfunction

function! iced_multi_session#auto_bufread() abort
  if ! g:iced_multi_session#does_switch_session | return | endif
  call s:auto_switching_session()
endfunction

function! iced_multi_session#auto_bufenter() abort
  if ! g:iced_multi_session#does_switch_session | return | endif
  call s:auto_switching_session()
endfunction

function! iced_multi_session#switch()
  call iced#selector({
        \ 'candidates': map(copy(s:connections), {i, v -> printf('%d: %s', i, v['name'])}),
        \ 'accept': {_, s -> s:switch(str2nr(split(s, ':')[0]))}
        \ })
endfunction

function! iced_multi_session#rename(...)
  let session_name = get(a:, 1, '')
  if empty(session_name)
    let session_name = input('New name: ')
  endif
  if empty(session_name)
    return
  endif
  let s:connections[s:connection_index]['name'] = session_name
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
