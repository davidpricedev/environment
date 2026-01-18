" Visual Bell (esp. wezterm - yikes)
set belloff=all

" Tabs
set tabstop=4
set shiftwidth=4
set softtabstop=4
set smarttab
set expandtab
set autoindent

" Theme / Color
set t_Co=256
set background=dark
colorscheme turbo

" Code Folding
set foldmethod=indent
set foldlevel=99
nnoremap <space> za

" Turn on line numbers
set number

" Enable syntax highlighting (and tab-completion?)
syntax on
syntax enable

" show matching braces
set showmatch

" Use python to format json nicely with :formatJson
com! FormatJson %!python -m json.tool

"----------------------------------
" everything below is borrowed from
" http://stevelosh.com/blog/2010/09/coming-home-to-vim/

" force vim instead of old vi
set nocompatible

set encoding=utf-8
set scrolloff=3
set autoindent
set showmode
set showcmd
set hidden
set wildmenu
set wildmode=list:longest
set visualbell
set cursorline
set ttyfast
set ruler
set backspace=indent,eol,start
set laststatus=2

" relative line numbers
set relativenumber

" Leader is the custom command prefix
let mapleader = ","

" Searching
set ignorecase
set smartcase
set incsearch
set showmatch
set hlsearch

" Line wrapping
set wrap
set textwidth=140
set formatoptions=qrn1
set colorcolumn=100

" save on focus loss
au FocusLost * :wa

" alternatives to jump out of insert mode
inoremap jj <ESC>
inoremap kk <ESC>
