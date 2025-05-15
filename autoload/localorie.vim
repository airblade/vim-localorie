let s:translations = {}


" Loads translations for the key into the quickfix or location list.
" The code first looks for a key at the cursor position; if none is found
" it looks for a key anywhere on the line.
function! localorie#translate() abort
  let fq_key = s:key()
  if empty(fq_key) | return | endif
  let translations = s:translations_for_key(fq_key)
  call s:display(fq_key, translations)
endfunction


" Returns the fully qualified key (including the locale prefix) of the current
" line in a YAML locale file.
function! localorie#expand_key() abort
  let parts = []

  call add(parts, matchstr(getline('.'), '\v[^: ]+'))
  let indent = indent(line('.'))

  while indent > 0
    let indent -= 2
    let dedent = search('\v^\s{'. indent .'}\w', 'bnW')
    call add(parts, matchstr(getline(dedent), '\v[^: ]+'))
  endwhile

  return join(reverse(parts), '.')
endfunction


" Returns the fully qualified key (excluding the locale prefix) of the current
" line in a YAML locale file.
function! localorie#expand_key_without_locale() abort
  let fq_key = localorie#expand_key()
  return join(split(fq_key, '[.]')[1:], '.')
endfunction


" Returns a nested dictionary for all Rails i18n locale YAML files combined.
"
" Each leaf value is a dictionary with keys 'value', 'line', and 'file'.
"
" Optional argument: a locale file (full path)
" - no argument given: all locale files are read
" - argument given: the file's existing translations are discarded and it is re-read
function! localorie#load_translations(...) abort
  if a:0
    let s:translations = s:reject(s:translations, a:1)
    let s:translations = s:merge(s:translations, s:parse_yaml(a:1))
  else
    let s:translations = {}
    for file in glob(s:rails_root().'/config/locales/**/*.yml', 1, 1)
      let s:translations = s:merge(s:translations, s:parse_yaml(file))
    endfor
  endif
endfunction


" Returns a nested dictionary for the given YAML.
"
" Each leaf value is a dictionary with keys 'value', 'line', and 'file'.
"
" file - a Rails i18n locale YAML file
function! s:parse_yaml(file)
  let lines = readfile(a:file)

  " Get fully qualified key for each line.
  let fqkeys = []
  let ancestors = []
  let last_indent = -1
  let last_key = ''
  for line in lines
    let matches = matchlist(line, '\v^(\s*)([^: #]+):')  " key:

    if empty(matches)
      call add(fqkeys, [])
      continue
    endif

    let indent = len(matches[1])
    if indent < last_indent
      call remove(ancestors, (indent - last_indent)/2, -1)
    elseif indent > last_indent
      if !empty(last_key)
        call add(ancestors, last_key)
      endif
    endif

    let key = matches[2]
    call add(fqkeys, add(copy(ancestors),key))

    let last_key = key
    let last_indent = indent
  endfor

  " Populate dictionary.
  let dict = {}
  let anchors = {}
  let linenr = 0
  for line in lines
    let linenr += 1
    let matches = matchlist(line, '\v^\s*([^: #]+):\s+(.+)$')  " key: value

    if empty(matches) | continue | endif

    let key = matches[1]
    let parents = key == '<<' ? fqkeys[linenr - 1][:-2] : fqkeys[linenr - 1]
    let d = dict
    for key in parents
      if !has_key(d, key)
        let d[key] = {}
      endif
      let d = d[key]
    endfor

    let value = matches[2]
    if value[0] == '&'
      let matches = matchlist(value, '\v\&(\w+)( (.+))?$')
      let anchor = matches[1]
      if !empty(matches[3])  " scalar anchor
        let d.value = matches[3]
        let d.line = linenr
        let d.file = a:file
      endif
      let anchors[anchor] = fqkeys[linenr - 1]  " alias: fqkey

    elseif value[0] == '*'
      let anchor = value[1:]
      let anchor_fqkey = anchors[anchor]
      let anchor_d = dict
      for key in anchor_fqkey
        let anchor_d = anchor_d[key]
      endfor
      call extend(d, deepcopy(anchor_d))

    else
      let d.value = value
      let d.line = linenr
      let d.file = a:file
    endif
  endfor

  return dict
endfunction


function! s:translations_for_key(fq_key) abort
  if empty(s:translations)
    call localorie#load_translations()
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

    if miss | continue | endif

    if s:leaf_node(dict)  " exact translation
      call add(results, {
            \   'filename': dict.file,
            \   'lnum':     dict.line,
            \   'text':     '['.locale.'] '.dict.value
            \ })
    else  " pluralised model
      for k in keys(dict)
        call add(results, {
              \   'filename': dict[k].file,
              \   'lnum':     dict[k].line,
              \   'text':     '['.locale.'] '.k.': '.dict[k].value
              \ })
      endfor
    endif
  endfor

  return results
endfunction


function! s:display(key, translations) abort
  let qf = g:localorie.quickfix

  if qf
    call setqflist(a:translations)
  else
    call setloclist(0, a:translations)
  endif

  if empty(a:translations)
    execute (qf ? 'cclose' : 'lclose')
    redraw
    echo "No translations for '".a:key."'."
  else
    execute (qf ? 'copen' : 'lopen')
    let w:quickfix_title = a:key
    if !g:localorie.switch
      wincmd p
    endif
  endif
endfunction


function! s:key() abort
  " Model.model_name.human
  " Model.human_attribute_name :attr  | Model.human_attribute_name(:attr)
  " Model.human_attribute_name 'attr' | Model.human_attribute_name('attr) | Model.human_attribute_name("attr)
  " t :attr  | translate :attr  | t(:attr  | translate(:attr
  " t 'attr' | translate 'attr' | t('attr' | translate('attr' | t "attr" | translate "attr" | t("attr" | translate("attr"
  let patterns = [
        \   ['\v([A-Z][a-z_]+)[.]model_name[.]human',                         {matchlist ->     'activerecord.models.'.s:underscore(matchlist[1])}],
        \   ['\v([A-Z][a-z_]+)[.]human_attribute_name[ (][:](\k+)[)]?',       {matchlist -> 'activerecord.attributes.'.s:underscore(matchlist[1]).'.'.matchlist[2]}],
        \   ['\v([A-Z][a-z_]+)[.]human_attribute_name[ (]([''"])(\k+)\2[)]?', {matchlist -> 'activerecord.attributes.'.s:underscore(matchlist[1]).'.'.matchlist[3]}],
        \   ['\vt%(ranslate)?[ (]:(\k+)',          {matchlist ->          matchlist[1]}],
        \   ['\vt%(ranslate)?[ (]([''"])(.{-})\1', {matchlist -> s:fq_key(matchlist[2])}]
        \ ]
  for match_at_cursor in [1, 0]
    for [re, L] in patterns
      let key = s:match(re, L, match_at_cursor)
      if !empty(key)
        return key
      endif
    endfor
  endfor
endfunction


function! s:match(re, func, match_at_cursor)
  let col = getpos('.')[2]
  let line = getline('.')
  let start = 0

  while 1
    let match = matchstrpos(line, a:re, start)

    if match == ['', -1, -1]
      return ''
    end

    let [first, last] = match[1:2]

    if !a:match_at_cursor
      let list = matchlist(line, a:re, first)
      return a:func(list)
    endif

    if first < col && col <= last
      let list = matchlist(line, a:re, first)
      return a:func(list)
    end

    let start = last
  endwhile
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
    let scope = s:sub(scope, '\v^.*[\/]app[\/]views[\/]', '')
    let scope = s:sub(scope, '\v\.[^\/]+$',               '')
    let scope = s:gsub(scope, '\v[\/]_?',                 '.')

  elseif scope =~ '\v[\/]app[\/]controllers[\/]'
    let scope = s:sub(scope, '\v^.*[\/]app[\/]controllers[\/]', '')
    let scope = s:sub(scope, '\v_controller$', '')
    let action = matchstr(getline(search('\v^\s*def \w+$', 'bn')), '\v\w+$')
    let scope .= '.'.action
  endif

  return scope.a:key
endfunction


" https://github.com/tpope/vim-rails/blob/80e03f766f5f049d6bd8998bd7b25b77ddaa9a1e/autoload/rails.vim#L28-L30
function! s:sub(str, pat, rep)
  return substitute(a:str, '\v\C'.a:pat, a:rep, '')
endfunction


" https://github.com/tpope/vim-rails/blob/80e03f766f5f049d6bd8998bd7b25b77ddaa9a1e/autoload/rails.vim#L32-L34
function! s:gsub(str, pat, rep)
  return substitute(a:str, '\v\C'.a:pat, a:rep, 'g')
endfunction


" https://github.com/tpope/vim-rails/blob/80e03f766f5f049d6bd8998bd7b25b77ddaa9a1e/autoload/rails.vim#L543-L549
function! s:underscore(str)
  let str = s:gsub(a:str,'::','/')
  let str = s:gsub(str,'(\u+)(\u\l)','\1_\2')
  let str = s:gsub(str,'(\l|\d)(\u)','\1_\2')
  let str = tolower(str)
  return str
endfunction


function! s:rails_root()
  return fnamemodify(findfile('Gemfile', '.;'), ':p:h')
endfunction


" Merges dictionary y into dictionary x.
" Returns x.
function! s:merge(x, y)
  for [k,v] in items(a:y)
    let a:x[k] = (type(v) == v:t_dict && type(get(a:x, k)) == v:t_dict)
          \ ? s:merge(a:x[k], v)
          \ : v
  endfor
  return a:x
endfunction


let s:leaf_keys = ['file', 'line', 'value']

function s:leaf_node(dict)
  return sort(copy(keys(a:dict))) == s:leaf_keys
endfunction


" Removes translation leaf dictionaries having a 'file' key pointing to the given file value.
"
" Note this can leave keys pointing to empty dictionary values.  This is a
" little untidy but does not matter.
function s:reject(dict, file) abort
  for [k,v] in items(a:dict)
    " v is always a dictionary
    if s:leaf_node(v)
      if v.file == a:file
        call remove(a:dict, k)
      endif
    else
      call s:reject(v, a:file)
    endif
  endfor
  return a:dict
endfunction
