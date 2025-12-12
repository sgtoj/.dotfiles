" Vim syntax file
" Language: .env files (dotenv)
" Maintainer: Custom
" Latest Revision: 2025-12-12

if exists("b:current_syntax")
  finish
endif

" Comments
syn match dotenvComment "^#.*$"
syn match dotenvComment "\s#.*$"

" Environment variable names (KEY=value)
syn match dotenvKey "^\s*\zs[A-Za-z_][A-Za-z0-9_]*\ze="

" Quoted strings
syn region dotenvString start=+"+ skip=+\\\\\|\\"+ end=+"+
syn region dotenvString start=+'+ skip=+\\\\\|\\'+ end=+'+

" Export keyword
syn keyword dotenvExport export

" Highlight groups
hi def link dotenvComment Comment
hi def link dotenvKey Identifier
hi def link dotenvString String
hi def link dotenvExport Keyword

let b:current_syntax = "dotenv"
