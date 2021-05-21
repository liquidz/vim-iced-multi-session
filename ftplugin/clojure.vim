if exists('g:loaded_iced_multi_session')
  finish
endif

if !exists('g:vim_iced_version')
      \ || g:vim_iced_version < 30400
  echoe 'iced-multi-session requires vim-iced v3.4.0 or later.'
  finish
endif

let g:loaded_iced_multi_session = 1

let s:save_cpo = &cpo
set cpo&vim

command! IcedMultiSessionNew     call iced_multi_session#new()
command! IcedMultiSessionNext    call iced_multi_session#next()
command! IcedMultiSessionList    call iced_multi_session#list()
command! IcedMultiSessionSwitch  call iced_multi_session#switch()
command! IcedMultiSessionRename  call iced_multi_session#rename()

nnoremap <silent> <Plug>(iced_multi_session_new) :<C-u>IcedMultiSessionNew<CR>
nnoremap <silent> <Plug>(iced_multi_session_next) :<C-u>IcedMultiSessionNext<CR>
nnoremap <silent> <Plug>(iced_multi_session_list) :<C-u>IcedMultiSessionList<CR>

if !exists('g:iced#palette')
  let g:iced#palette = {}
endif
call extend(g:iced#palette, {
      \ 'MultiSessionNew': ':IcedMultiSessionNew',
      \ 'MultiSessionNext': ':IcedMultiSessionNext',
      \ 'MultiSessionList': ':IcedMultiSessionList',
      \ 'MultiSessionRename': ':IcedMultiSessionRename',
      \ 'MultiSessionSwitch': ':IcedMultiSessionSwitch',
      \ })

aug vim_iced_multi_session_initial_setting
  au!
  au BufRead *.clj,*.cljs,*.cljc call iced_multi_session#auto_bufread()
  au BufEnter *.clj,*.cljs,*.cljc call iced_multi_session#auto_bufenter()
aug END

let &cpo = s:save_cpo
unlet s:save_cpo

