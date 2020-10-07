if exists('g:loaded_iced_multi_session')
  finish
endif

if !exists('g:vim_iced_version')
      \ || g:vim_iced_version < 20302
  echoe 'iced-multi-session requires vim-iced v2.3.2 or later.'
  finish
endif

let g:loaded_iced_multi_session = 1

let s:save_cpo = &cpo
set cpo&vim

command! IcedMultiSessionNew     call iced_multi_session#new()
command! IcedMultiSessionNext    call iced_multi_session#next()
command! IcedMultiSessionList    call iced_multi_session#list()

if !exists('g:iced#palette')
  let g:iced#palette = {}
endif
call extend(g:iced#palette, {
      \ 'MultiSessionNew': ':IcedMultiSessionNew',
      \ 'MultiSessionNext': ':IcedMultiSessionNext',
      \ 'MultiSessionList': ':IcedMultiSessionList',
      \ })

let &cpo = s:save_cpo
unlet s:save_cpo

