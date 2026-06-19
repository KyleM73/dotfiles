" Turn off vi compatibility mode to enable all Vim features
set nocompatible

" Set encoding to UTF-8 for proper character handling
set encoding=utf-8

" Auto-install vim-plug on first launch, then install plugins
let s:plug = expand('~/.vim/autoload/plug.vim')
if empty(glob(s:plug))
    silent execute '!curl -fLo ' . s:plug . ' --create-dirs '
        \ . 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Plugins (managed by vim-plug, installed under ~/.vim/plugged)
call plug#begin('~/.vim/plugged')
Plug 'preservim/nerdtree'             " File navigation
Plug 'Xuyuanp/nerdtree-git-plugin'    " Git status in NERDTree
Plug 'mhartington/oceanic-next'       " OceanicNext color scheme
Plug 'vim-airline/vim-airline'        " Status bar
Plug 'vim-airline/vim-airline-themes' " Airline themes
Plug 'ryanoasis/vim-devicons'         " File type icons
Plug 'xolox/vim-misc'                 " Helpers for vim-session
Plug 'xolox/vim-session'              " Session management
call plug#end()

" Enable filetype detection, plugins, and indentation
filetype plugin indent on

" NERDTree configuration
let NERDTreeMinimalUI = 1  " Enable minimal UI for NERDTree
let NERDTreeDirArrows = 1  " Show directory arrows
let NERDTreeMouseMode = 3  " Enable mouse mode in NERDTree

" Leader key (Space) for custom mappings
let mapleader = " "

" Plugin mappings
nnoremap <leader>n :NERDTreeToggle<CR>
nnoremap <leader>m :NERDTreeMirror<CR>
nnoremap <leader>o :OpenSession<Space>

" Airline configuration
let g:airline_powerline_fonts = 1  " Enable powerline fonts
let g:airline#extensions#tabline#enabled = 1  " Enable airline tabline
let g:airline#extensions#tabline#left_sep = ' '  " Set left separator
let g:airline#extensions#tabline#left_alt_sep = '|'  " Set alternative separator
let g:airline_theme = 'dark_minimal'  " Set airline theme
let g:airline_section_b = '%{getcwd()}'
let g:airline_section_c = '%t'
let g:airline_section_z = ' %p%%  %l:%c '  " Display percentage, line, and column

" Python syntax highlighting for indentation and space errors
let python_highlight_indent_errors = 1  " Highlight indentation errors in Python
let python_highlight_space_errors = 1   " Highlight space errors in Python

" Enable syntax highlighting
syntax enable

" Prettify markdown
augroup markdown
  au!
  au BufNewFile,BufRead *.md,*.markdown setlocal filetype=ghmarkdown
augroup END

" Session settings
let g:session_autosave = 'no'  " Disable automatic session saving
set sessionoptions-=buffers     " Do not save buffers in sessions

" Text formatting options
set expandtab        " Convert tabs to spaces
set softtabstop=4     " Number of spaces per tab (while editing)
set shiftwidth=4      " Indentation width for auto-indent operations
" set textwidth=80      " Maximum width of text before wrapping
set autoindent        " Enable automatic indentation
set smartindent       " Enable smart indentation
set smarttab          " Tab inserts 'shiftwidth' spaces in insert mode
" set wrap              " Enable text wrapping
set lbr               " Break long lines at 'breakat' characters
set tabstop=4         " Number of spaces in a tab
set linebreak         " Wrap lines at word boundaries rather than mid-word

" Navigation settings
set mouse=a           " Enable mouse usage in all modes
set scrolloff=3       " Keep 3 lines visible above/below the cursor
set nostartofline     " Don’t jump to start of the line when moving around
set backspace=indent,eol,start  " Make backspace behave as expected
set cmdheight=2       " Increase command-line height to 2 lines for visibility

" Markers and visual feedback
set number            " Show line numbers
set noruler           " Disable ruler (line/column position) display
set showmode          " Display mode (INSERT, REPLACE, etc.)
set laststatus=2      " Always show the status line
set visualbell        " Enable visual bell instead of audio bell
set cursorline        " Highlight the current line
set noerrorbells      " Disable error beeps
set title             " Set the terminal title to the file name
set titlestring=%t

" Search settings
set hlsearch          " Highlight search results
set ignorecase        " Case-insensitive search by default
set smartcase         " Override 'ignorecase' if search contains capital letters
set incsearch         " Show search matches as you type
set showmatch         " Highlight matching parentheses/brackets
set history=1000      " Keep 1000 commands in history

" Autocompletion settings
set complete-=i       " Remove certain options from completion (e.g., ignore case)
set showcmd           " Display incomplete commands in the status line
set wildmenu          " Enable enhanced command-line completion
set wildmode=list:longest  " Command-line completion: longest common match, then list
set wildignore=*.docx,*.jpg,*.png,*.gif,*.pdf,*.pyc,*.exe,*.flv,*.img,*.xlsx " Ignore during autocompletion

" Other performance settings
set lazyredraw        " Do not redraw screen during macro execution for speed

" Editor mappings
nnoremap <leader>t :tabnew<CR>
nnoremap <leader>e :set mouse=a<CR>
nnoremap <leader>d :set mouse=<CR>

" Color scheme settings
" Use 24-bit true color where supported, otherwise fall back to 256 colors
if has('termguicolors')
    set termguicolors
else
    set t_Co=256
endif
silent! colorscheme OceanicNext   " silent! avoids errors before plugins install

" Disable Background Color Erase (BCE) in 256-color terminals (e.g., GNU screen)
if &term =~ '256color'
    set t_ut=          " Disable Background Color Erase to maintain color consistency
endif

" Word Processor Mode configuration
func! WordProcessorMode()
    setlocal textwidth=80          " Set text width for word processing
    setlocal smartindent           " Enable smart indentation
    setlocal spell spelllang=en_us  " Enable spell check with US English
    setlocal noexpandtab           " Use tabs instead of spaces in word processing mode
endfu
com! WP call WordProcessorMode()  " Create a command 'WP' to activate Word Processor Mode

" Persistent undo configuration
if has('persistent_undo')
    let s:undodir = expand('~/.vim/backups')
    if !isdirectory(s:undodir)
        call mkdir(s:undodir, 'p')
    endif
    let &undodir = s:undodir
    set undofile                  " Enable persistent undo across sessions
endif
