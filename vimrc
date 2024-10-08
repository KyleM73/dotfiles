" Turn off vi compatibility mode to enable all Vim features
set nocompatible

" Set encoding to UTF-8 for proper character handling
set encoding=utf-8

" Add Vundle to Vim's runtime path
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" Plugin management by Vundle
Plugin 'gmarik/Vundle.vim'  " Vundle itself
Plugin 'preservim/nerdtree'  " NERDTree for file navigation
Plugin 'Xuyuanp/nerdtree-git-plugin'  " Git integration for NERDTree
Plugin 'mhartington/oceanic-next'  " OceanicNext color scheme
Plugin 'vim-airline/vim-airline'  " Vim airline status bar
Plugin 'vim-airline/vim-airline-themes'  " Airline themes
Plugin 'ryanoasis/vim-devicons'  " File type icons
Plugin 'xolox/vim-misc'  " Helper functions for vim-session
Plugin 'xolox/vim-session'  " Session management

call vundle#end()  " Finalize Vundle setup

" Enable filetype detection, plugins, and indentation
filetype plugin indent on
" to install plugins from cmd line: vim +PluginInstall +qall

" NERDTree configuration
let NERDTreeMinimalUI = 1  " Enable minimal UI for NERDTree
let NERDTreeDirArrows = 1  " Show directory arrows
let NERDTreeMouseMode = 3  " Enable mouse mode in NERDTree

" Custom mappings
" Map 'os' to open a session
nmap os :OpenSession 
" Map 'nt' to open NERDTree
nmap nt :NERDTree
" Map 'ntm' to mirror NERDTree
nmap ntm :NERDTreeMirror  

" Airline configuration
let g:airline_powerline_fonts = 1  " Enable powerline fonts
let g:airline#extensions#tabline#enabled = 1  " Enable airline tabline
let g:airline#extensions#tabline#left_sep = ' '  " Set left separator
let g:airline#extensions#tabline#left_alt_sep = '|'  " Set alternative separator
let g:airline_theme = 'minimal'  " Set airline theme
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
set textwidth=80      " Maximum width of text before wrapping
set autoindent        " Enable automatic indentation
set smartindent       " Enable smart indentation
set smarttab          " Tab inserts 'shiftwidth' spaces in insert mode
set wrap              " Enable text wrapping
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

" Custom mappings
" Map 'ma' to enable mouse usage
map ma :set mouse=a
" Map 'mi' to disable mouse usage
map mi :set mouse=i
" Map 'new' to open a new tab
nmap new :tabnew 

" Color scheme settings
colorscheme OceanicNext  " Set the color scheme to OceanicNext

" Enable 256 colors in terminal if supported
if (has("termguicolors"))
    set t_Co=256
endif

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
    " Create a backup directory if it doesn't exist
    silent !mkdir ~/.vim/backups > /dev/null 2>&1  
    set undodir=~/.vim/backups    " Set undo directory
    set undofile                  " Enable persistent undo across sessions
endif
