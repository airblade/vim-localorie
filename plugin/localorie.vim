scriptencoding utf-8

let s:options = {
      \ 'quickfix': 1,
      \ 'switch':   0
      \ }
if !exists('g:localorie')
  let g:localorie = {}
endif
call extend(g:localorie, s:options, 'keep')


augroup localorie
  autocmd!
  autocmd BufWritePost */config/locales/*.yml call localorie#load_translations(expand('<amatch>'))
augroup END

