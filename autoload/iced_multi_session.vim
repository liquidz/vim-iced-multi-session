let s:save_cpo = &cpo
set cpo&vim

let s:connections = []
let s:connection_index = 0
let s:connected_label = '[CONNECTED]'

let g:iced_multi_session#does_switch_session = get(g:, 'iced_multi_session#does_switch_session', v:false)
let g:iced_multi_session#name_prefix = get(g:, 'iced_multi_session#name_prefix', 'new')
" e.g.  [{'port_file': '/path/to/.nrepl-port', 'path': 'foobar', 'name': 'src-cljs/'} ]
let g:iced_multi_session#definitions = get(g:, 'iced_multi_session#definitions', [])

" WARN: Overwrite option
let g:iced#repl#ignore_connected = v:true

function! s:get_port_by_definition(definition) abort
  let port_file = get(a:definition, 'port_file', '')
  if ! filereadable(port_file) | return -1 | endif

  try
    return str2nr(readfile(port_file)[0])
  catch
    return -1
  endtry
endfunction

function! s:find_connection_index_by_definition(definition) abort
  let def_port = s:get_port_by_definition(a:definition)
  let idx = 0
  for conn in s:connections
    if conn['conn']['port'] == def_port
      return idx
    endif
    let idx += 1
  endfor

  return -1
endfunction

function! s:find_definition_by_current_connection() abort
  " c.f. https://github.com/liquidz/vim-iced/blob/3.0.3/autoload/iced/nrepl.vim#L7
  let port = get(iced#nrepl#current_connection(), 'port', -1)
  let path = (iced#nrepl#check_session_validity(v:false)
        \ ? expand('%:p')
        \ : '')
  let name = iced#nrepl#cljs#env_name()

  for definition in g:iced_multi_session#definitions
    let def_port = s:get_port_by_definition(definition)
    if def_port == -1 | continue | endif

    if def_port == port
      return definition
    endif
  endfor

  return {}
endfunction

function! s:find_definition_by_path() abort
  let path = expand('%:p:h')
  for definition in g:iced_multi_session#definitions
    let def_path = get(definition, 'path', '')
    if empty(def_path) | continue | endif
    if stridx(path, def_path) == -1 | continue | endif
    return definition
  endfor

  return {}
endfunction

function! s:env_name() abort
  let name = get(s:find_definition_by_current_connection(), 'name', '')
  if empty(name)
    let name = iced#nrepl#cljs#env_name()
  endif
  return empty(name) ? 'nREPL' : name
endfunction

function! s:init() abort
  if !iced#repl#is_connected() | return | endif
  if empty(s:connections)
    let s:connections += [{'name': s:env_name(), 'conn': iced#nrepl#current_connection()}]
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

function! s:switch(new_connection_index, ...) abort
  let verbose = get(a:, 1, v:true)
  call s:init()
  let s:connection_index = a:new_connection_index
  let conn = s:connections[s:connection_index]
  call iced#nrepl#reset_connection(conn['conn'])
  if verbose
    call iced#message#info_str(printf('MultiSession: changed to %s', conn['name']))
  endif
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

function! iced_multi_session#delete(...) abort
  let index = get(a:, 1, s:connection_index)
  let connection_count = len(s:connections)

  if connection_count == 1
    let s:connections = []
    let s:connection_index = 0
  elseif index < connection_count
    unlet s:connections[index]
    let s:connection_index = max([s:connection_index - 1, 0])
    call s:switch(s:connection_index, v:false)
  endif
endfunction

function! s:auto_switching_session() abort
  let definition = s:find_definition_by_path()
  if !empty(definition)
    let idx = s:find_connection_index_by_definition(definition)
    if idx != -1 && idx != s:connection_index
      return s:switch(idx)
    endif
  endif

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
  call s:init()
  if s:connection_index >= len(s:connections)
    return
  endif

  let session_name = get(a:, 1, '')
  if empty(session_name)
    let session_name = input('New name: ')
  endif
  if empty(session_name)
    return
  endif
  let s:connections[s:connection_index]['name'] = session_name
endfunction

function! s:already_connected(port) abort
  try
    for conn in s:connections
      " c.f. https://github.com/liquidz/vim-iced/blob/3.0.3/autoload/iced/nrepl.vim#L7
      if conn['conn']['port'] == a:port
        call iced#nrepl#reset_connection(conn['conn'])
        if iced#repl#is_connected()
          return v:true
        endif
      endif
    endfor
  finally
    let current = get(s:connections, s:connection_index, {})
    if !empty(current)
      call iced#nrepl#reset_connection(current['conn'])
    endif
  endtry

  return v:false
endfunction


function! s:add_connected_label_to_candidate(candidate) abort
  let c = copy(a:candidate)
  let c['label'] = printf('%s %s', s:connected_label, c['label'])
  return c
endfunction

function! s:sort_candidates_by_connected_status(candidates) abort
  let connected_candidates = []
  let not_connected_candidates = []
  for candidate in a:candidates
    if stridx(candidate['label'], s:connected_label) == -1
      let not_connected_candidates += [candidate]
    else
      let connected_candidates += [candidate]
    endif
  endfor

  return (not_connected_candidates + connected_candidates)
endfunction

function! s:rename_connected(candidates) abort
  " e.g. candidte = {'label': 'nREPL', 'type': 'nrepl', 'port': 12345}
  let candidates = copy(a:candidates)
  let connected_ports = {}
  let does_all_connected = v:true

  for candidate in a:candidates
    let port = candidate['port']
    let does_connected = s:already_connected(port)
    let does_all_connected = does_all_connected && does_connected

    if does_connected
      let connected_ports[port] = v:true
    endif
  endfor

  if does_all_connected
    return []
  endif

  let candidates = map(candidates, {_, v -> (get(connected_ports, v['port'], v:false))
        \ ? s:add_connected_label_to_candidate(v)
        \ : v})
  let candidates = s:sort_candidates_by_connected_status(candidates)
  return candidates
endfunction

function! s:connecting(args) abort
  call s:init()

  if s:already_connected(a:args['port'])
    return {'cancel': iced#message#get('already_connected')}
  endif

  let connection_count = len(s:connections)
  if iced#repl#is_connected()
    let new_name = printf('%s%s',
          \ g:iced_multi_session#name_prefix,
          \ connection_count == 1 ? '' : connection_count,
          \ )
    call iced_multi_session#new(new_name)
  endif
endfunction

call iced#hook#add('connect_prepared', {
     \ 'type': 'function',
     \ 'exec': funcref('s:rename_connected')})

call iced#hook#add('connecting', {
     \ 'type': 'function',
     \ 'exec': funcref('s:connecting')})

call iced#hook#add('connected', {
     \ 'type': 'function',
     \ 'exec': {_ -> iced_multi_session#rename(s:env_name())}})

call iced#hook#add('session_switched', {
      \ 'type': 'function',
      \ 'exec': {_ -> iced_multi_session#rename(s:env_name())}})

call iced#hook#add('disconnected', {
      \ 'type': 'function',
      \ 'exec': {_ -> iced_multi_session#disconnect()}})

let &cpo = s:save_cpo
unlet s:save_cpo
