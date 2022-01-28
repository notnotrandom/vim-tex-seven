" LaTeX filetype plugin
" Languages:    Vimscript
" Maintainer:   Óscar Pereira
" License:      GPL

"************************************************************************
"
"                     TeX-7 library: Vim script
"
"    This program is free software: you can redistribute it and/or modify
"    it under the terms of the GNU General Public License as published by
"    the Free Software Foundation, either version 3 of the License, or
"    (at your option) any later version.
"
"    This program is distributed in the hope that it will be useful,
"    but WITHOUT ANY WARRANTY; without even the implied warranty of
"    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
"    GNU General Public License for more details.
"
"    You should have received a copy of the GNU General Public License
"    along with this program. If not, see <http://www.gnu.org/licenses/>.
"                    
"    Copyright Elias Toivanen, 2011-2014
"    Copyright Óscar Pereira, 2020-2022
"
"************************************************************************

if exists('g:maplocalleader')
  let s:maplocalleader_saved = g:maplocalleader
endif

" The user might have opened a .bib file, before opening a .tex file, so TeX-7
" might not have run yet.
if exists('b:init_tex_seven')
  let g:maplocalleader = g:tex_seven_config.leader
else
  let g:maplocalleader = ":"
endif

" This map is here to allow one to return from the .bib file to the main
" (.tex) file -- if there is a main .tex file.
nnoremap <buffer><silent> gm :call tex_seven#GoToMainFileIfSet()<CR>

inoremap <buffer><expr> <LocalLeader>B tex_seven#InsertBibEntry()

if exists('s:maplocalleader_saved')
  let g:maplocalleader = s:maplocalleader_saved
  unlet s:maplocalleader_saved
else
  unlet g:maplocalleader
endif
