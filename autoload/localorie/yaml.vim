" Returns a nested dictionary for all Rails i18n locale YAML files combined.
"
" Each leaf value is a dictionary with keys 'value', 'line', and 'file'.
function! localorie#yaml#load_files()
  let translations = {}
  let files = glob(s:rails_root().'/config/locales/**/*.yml', 1, 1)
  for file in files
    let dict = localorie#yaml#parse(file)
    let translations = s:merge(translations, dict)
  endfor
  return translations
endfunction


" Returns a nested dictionary for the given YAML.
"
" Each leaf value is a dictionary with keys 'value', 'line', and 'file'.
"
" file - a Rails i18n locale YAML file
function! localorie#yaml#parse(file)
  let dict = {}

  " read into a hidden temp buffer or keep as a list?
  let lines = readfile(a:file)
  let linenr = 0

  for line in lines
    let linenr += 1

    let matches = matchlist(line, '\v^(\s*)([^: ]+): (.+)$')  " key: value
    if empty(matches) | continue | endif

    let indent = len(matches[1])
    let key    = matches[2]
    let value  = matches[3]

    " get parent keys
    let keys = []
    let index = linenr - 1
    while indent > 0
      let indent -= 2
      let above = lines[:index-1]
      let i = match(reverse(above), '\v^\s{'.indent.'}\w')
      let dedent_index = index - i - 1
      let dedent_line  = lines[dedent_index]
      let dedent_key   = matchstr(dedent_line, '\v[^: ]+')
      call add(keys, dedent_key)
      let index = dedent_index
    endwhile

    " construct nested dictionaries for parent keys
    let d = dict
    for k in reverse(keys)
      if !has_key(d, k)
        let d[k] = {}
      endif
      let d = d[k]
    endfor

    let d[key] = { 'value': value, 'line': linenr, 'file': a:file }
  endfor

  return dict
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


function! s:rails_root()
  return fnamemodify(findfile('Gemfile', '.;'), ':p:h')
endfunction

