## vim-localorie

Localorie is a Vim plugin which makes working with Rails i18n locale files a little easier.


### Look up translations

With your cursor on an i18n key in a Rails view or controller, call `localorie#translate()` to populate the quickfix or location list with all the translations of that key.

For example, with your cursor somewhere on `.title`:

```erb
# app/views/projects/index.html.erb
<h1><%= t '.title' %></h1>
```

– calling `localorie#translate()` will show the translations for `projects.index.title`.

#### Supported

- String keys
- Fully-qualified lookup in views
- Lazy lookup in views
- Fully-qualified lookup in controllers
- Lazy lookup in controllers
- `Model.model_name.human`
- `Model.human_attribute_name`

#### Unsupported (so far)

- Sub/nested keys (e.g. `foo/bar`)
- Symbol keys
- `:scope` and `:default` options
- Ruby locale files

It would also be nice, in a locale file, to look up locations where a key is used.


### Expand YAML key

In a locale file, call `localorie#expand_key()` to echo the fully qualified key of the current line.  This is handy when you are in the depths of a locale file and have lost track of the current line's scope.

For example, with your cursor anywhere on the last line:

```yaml
en:
  foo:
    bar:
      baz: hello
```

– calling `localorie#expand_key()` will echo `en.foo.bar.baz`.


### Mappings

I recommend mapping the functions in your vimrc.  For example:

```viml
nnoremap <silent> <leader>lt :call localorie#translate()<CR>
nnoremap <silent> <leader>le :call localorie#expand_key()<CR>
```


### Configuration

By default vim-localorie uses the quickfix list but doesn't switch to the quickfix window.  To use the location list and/or switch to the new window, put this in your vimrc:

```viml
let g:localorie = {
    \ 'quickfix':  0,
    \ 'switch':    1
    \ }
```


### Installation

Install like any other vim plugin.

##### Pathogen

```
cd ~/.vim/bundle
git clone git://github.com/airblade/vim-localorie.git
```

##### Voom

Edit your plugin manifest (`voom edit`) and add:

```
airblade/vim-localorie
```

##### VimPlug

Place this in your .vimrc:

```viml
Plug 'airblade/vim-localorie'
```

Then run the following in Vim:

```
:source %
:PlugInstall
```

##### NeoBundle

Place this in your .vimrc:

```viml
NeoBundle 'airblade/vim-localorie'
```

Then run the following in Vim:

```
:source %
:NeoBundleInstall
```

##### No plugin manager

Copy vim-localorie's subdirectories into your vim configuration directory:

```
cd /tmp && git clone git://github.com/airblade/vim-localorie.git
cp -r vim-localorie/* ~/.vim/
```

See `:help add-global-plugin`.


### Intellectual Property

Copyright 2016 Andrew Stewart.  Released under the MIT licence.

