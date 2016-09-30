let s:railsapp = expand('%:p:h').'/'.'railsapp'


function Test_expand_key()
  execute 'edit' s:railsapp.'/config/locales/en.yml'
  normal 4G

  redir => msg
    call localorie#expand_key()
  redir END
  " Drop leading new line which is an artifact of redir.
  let msg = substitute(msg, "\n", '', '')

  call assert_equal('en.books.index.title', msg)
endfunction


function Test_translate_fq_key_view()
  execute 'edit' s:railsapp.'/app/views/books/index.html.haml'
  for line in [1, 2]
    execute 'normal '.line.'Gfb'

    call localorie#translate()

    let list = getqflist()
    call assert_equal(2, len(list))

    let location = list[0]
    call assert_match('/config/locales/en.yml', bufname(location.bufnr))
    call assert_equal(4, location.lnum)
    call assert_equal('[en] All books', location.text)

    let location = list[1]
    call assert_match('/config/locales/de.yml', bufname(location.bufnr))
    call assert_equal(4, location.lnum)
    call assert_equal('[de] Alle Bücher', location.text)
  endfor
endfunction


function Test_translate_lazy_key_view()
  execute 'edit' s:railsapp.'/app/views/books/index.html.haml'
  for line in [4, 5]
    execute 'normal '.line.'Gfi'

    call localorie#translate()

    let list = getqflist()
    call assert_equal(2, len(list))

    let location = list[0]
    call assert_match('/config/locales/en.yml', bufname(location.bufnr))
    call assert_equal(4, location.lnum)
    call assert_equal('[en] All books', location.text)

    let location = list[1]
    call assert_match('/config/locales/de.yml', bufname(location.bufnr))
    call assert_equal(4, location.lnum)
    call assert_equal('[de] Alle Bücher', location.text)
  endfor
endfunction


function Test_translate_fq_key_controller()
  execute 'edit' s:railsapp.'/app/controllers/books_controller.rb'
  normal 3Gfb

  call localorie#translate()

  let list = getqflist()
  call assert_equal(2, len(list))

  let location = list[0]
  call assert_match('/config/locales/en.yml', bufname(location.bufnr))
  call assert_equal(6, location.lnum)
  call assert_equal('[en] Book!', location.text)

  let location = list[1]
  call assert_match('/config/locales/de.yml', bufname(location.bufnr))
  call assert_equal(6, location.lnum)
  call assert_equal('[de] Buch!', location.text)
endfunction


function Test_translate_lazy_key_controller()
  execute 'edit' s:railsapp.'/app/controllers/books_controller.rb'
  normal 4Gfs

  call localorie#translate()

  let list = getqflist()
  call assert_equal(2, len(list))

  let location = list[0]
  call assert_match('/config/locales/en.yml', bufname(location.bufnr))
  call assert_equal(6, location.lnum)
  call assert_equal('[en] Book!', location.text)

  let location = list[1]
  call assert_match('/config/locales/de.yml', bufname(location.bufnr))
  call assert_equal(6, location.lnum)
  call assert_equal('[de] Buch!', location.text)
endfunction


function! Test_reloads_translations()
  execute 'edit' s:railsapp.'/app/views/books/index.html.haml'
  normal 1Gfb
  call localorie#translate()
  let location = getqflist()[0]
  call assert_equal('[en] All books', location.text)

  " modify translation
  execute 'edit' s:railsapp.'/config/locales/en.yml'
  normal 4GfAgU$
  write

  execute 'edit' s:railsapp.'/app/views/books/index.html.haml'
  normal 1Gfb
  call localorie#translate()
  let location = getqflist()[0]
  call assert_equal('[en] ALL BOOKS', location.text)

  " undo modification
  execute 'edit' s:railsapp.'/config/locales/en.yml'
  normal 4GfLgu$
  write
endfunction


function! Test_model_name_without_plural()
  execute 'edit' s:railsapp.'/app/views/books/index.html.haml'
  normal 7G

  call localorie#translate()

  let list = getqflist()
  call assert_equal(2, len(list))

  let location = list[0]
  call assert_match('/config/locales/en.yml', bufname(location.bufnr))
  call assert_equal(13, location.lnum)
  call assert_equal('[en] Table', location.text)

  let location = list[1]
  call assert_match('/config/locales/de.yml', bufname(location.bufnr))
  call assert_equal(13, location.lnum)
  call assert_equal('[de] Tisch', location.text)
endfunction


