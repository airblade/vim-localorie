scriptencoding utf-8


" Configuration

let s:options = {
      \ 'quickfix': 1,
      \ 'switch':   0
      \ }
if exists('g:localorie')
  call extend(s:options, g:localorie)
endif


" Initialisation

let s:lib_dir = expand('<sfile>:p:h:h').'/'.'lib'
let s:translations = {}


" Autocommands

augroup localorie
  autocmd!
  autocmd BufWritePost */config/locales/*.yml call s:load_translations()
augroup END


" Public functions

" Loads translations for the key at the cursor into the quickfix or location list.
function! localorie#translate() abort
  let fq_key = s:key_at_cursor()
  if !empty(fq_key)
    let translations = s:translations_for_key(fq_key)
    call s:display(fq_key, translations)
  endif
endfunction


" Echoes the fully qualified key of the current line in a YAML locale file.
function! localorie#expand_key() abort
  let parts = []

  call add(parts, matchstr(getline('.'), '\v[^: ]+'))
  let indent = indent(line('.'))

  while indent > 0
    let indent -= 2
    let dedent = search('\v^\s{'. indent .'}\w', 'bnW')
    call add(parts, matchstr(getline(dedent), '\v[^: ]+'))
  endwhile

  if !empty(parts)
    echo join(reverse(parts), '.')
  endif
endfunction


" Private functions

function! s:load_translations() abort
  let rb = s:lib_dir.'/'.'localorie.rb'
  let translations = system('ruby '.rb.' '.s:rails_root())
  let s:translations = json_decode(translations)
endfunction

function! s:translations_for_key(fq_key) abort
  if empty(s:translations)
    call s:load_translations()
  endif

  let results = []
  let parts = split(a:fq_key, '[.]')

  for locale in keys(s:translations)
    let miss = 0
    let dict = s:translations[locale]

    for part in parts
      if has_key(dict, part)
        let dict = dict[part]
      else
        let miss = 1
        break
      endif
    endfor

    if !miss
      " if has_key(dict, 'line')
        call add(results, {
              \   'filename': dict.file,
              \   'lnum':     dict.line,
              \   'text':     '['.locale.'] '.dict.value
              \ })
      " else
        " " No line numbers available from ruby locale files.
        " call add(results, {
        "       \   'filename': dict.file,
        "       \   'pattern':  dict.value,
        "       \   'text':     '['.locale.'] '.dict.value
        "       \ })
      " endif
    endif
  endfor

  return results
endfunction

function! s:display(key, translations) abort
  let qf = s:options.quickfix

  if empty(a:translations)
    execute (qf ? 'cclose' : 'lclose')
    redraw
    echo "No translations for '".a:key."'."
    return
  endif

  if qf
    call setqflist(a:translations)
    copen
  else
    call setloclist(0, a:translations)
    lopen
  endif
  let w:quickfix_title = a:key

  if !s:options.switch
    wincmd p
  endif
endfunction

function! s:key_at_cursor() abort
  let key = s:get_ruby_string()
  return s:fq_key(key)
endfunction

function! s:get_ruby_string() abort
  let col = col('.')

  call search('\v[''"]', 'b', line('.'))
  let open_quote = getpos('.')[2]
  call search('\v[''"]',  '', line('.'))
  let close_quote = getpos('.')[2]

  execute 'normal! '.col.'|'

  return strpart(getline('.'), open_quote, close_quote - open_quote - 1)
endfunction

function! s:fq_key(key) abort
  if empty(a:key)
    return
  endif

  if a:key[0] != '.'
    return a:key
  endif

  let scope = expand('%:p:r')
  if scope =~ '\v[\/]app[\/]views[\/]'
    let scope = substitute(scope, '\v^.*[\/]app[\/]views[\/]', '',  '')
    let scope = substitute(scope, '\v\.[^\/]+$',               '',  '')
    let scope = substitute(scope, '\v[\/]_?',                 '.', 'g')

  elseif scope =~ '\v[\/]app[\/]controllers[\/]'
    let scope = substitute(scope, '\v^.*[\/]app[\/]controllers[\/]', '', '')
    let scope = substitute(scope, '\v_controller$', '',  '')
    let action = matchstr(getline(search('\v^\s*def \w+$', 'bn')), '\v\w+$')
    let scope .= '.'.action
  endif

  return scope.a:key
endfunction

function! s:rails_root()
  return fnamemodify(findfile('Gemfile', '.;'), ':p:h')
endfunction

