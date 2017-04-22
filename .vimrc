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

" Vundle Section Start =============================
filetype off                   " required!
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle
" required! 
Plugin 'VundleVim/Vundle.vim'

" Status bar
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'

" js syntax
Plugin 'jelera/vim-javascript-syntax'
Plugin 'pangloss/vim-javascript'

" indent guides
Plugin 'nathanaelkane/vim-indent-guides'

" auto-close parens etc.
Plugin 'tpope/vim-surround'

" linting
Plugin 'scrooloose/syntastic'

" git integration
Plugin 'tpope/vim-fugitive'
Plugin 'airblade/vim-gitgutter'

" explorer
Plugin 'scrooloose/nerdtree'

" code completion
Plugin 'valloric/youcompleteme'

" toggle comment
Plugin 'tpope/vim-commentary'

" download a bunch of colorschemes
Plugin 'flazz/vim-colorschemes'

" all the code languages
Plugin 'sheerun/vim-polyglot'

call vundle#end()
filetype plugin indent on
" End Vundle =======================================

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

