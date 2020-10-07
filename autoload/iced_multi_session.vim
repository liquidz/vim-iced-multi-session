let s:save_cpo = &cpo
set cpo&vim

let s:connections = []
let s:connection_index = 0

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

function! iced_multi_session#new() abort
  let session_name = input('Name: ')
  if session_name ==# '' | return | endif

  call s:init()
  let new_conn = iced#nrepl#reset_connection()
  let s:connection_index += 1
  let s:connections += [{'name': session_name, 'conn': new_conn}]
endfunction

function! iced_multi_session#next() abort
  call s:init()
  let s:connection_index += 1
  if len(s:connections) == s:connection_index
    let s:connection_index = 0
  endif

  let conn = s:connections[s:connection_index]
  call iced#nrepl#reset_connection(conn['conn'])
  call iced#message#info_str(printf('MultiSession: changed to %s', conn['name']))
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
  return get(current, 'name', '')
endfunction

function! iced_multi_session#disconnect() abort
  unlet s:connections[s:connection_index]

  if len(s:connections) > 0
    let s:connection_index = 0
    let conn = s:connections[s:connection_index]
    call iced#nrepl#reset_connection(conn['conn'])

    call iced#message#info_str(printf('Disconnecting %s', conn['name']))
    call iced#nrepl#disconnect()
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
