" LaTeX filetype plugin
" Languages:    Vimscript
" Maintainer:   Óscar Pereira
" Version:      0.2
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
"    Copyright Óscar Pereira, 2020-2021
"
"************************************************************************

" Used for completion of sub and super scripts.
function tex_seven#IsLeft(lchar)
  let left = getline('.')[col('.')-2]
  return left == a:lchar ? 1 : 0
endfunction

function tex_seven#ChangeFontStyle(style)
  let str = 'di'
  let is_math = tex_seven#environments#Is_latex_math_environment()
  let str .= is_math ? '\math'.a:style : '\text'.a:style
  let str .= "{}\<Left>\<C-R>\""
  return str
endfunction

" For visual selection operators of inner or outer (current) environment.
function tex_seven#EnvironmentOperator(mode)
  let pos = tex_seven#environments#Get_latex_environment()[1:]
  if !pos[0] && !pos[1]
    return "\<Esc>"
  endif
  if a:mode == 'inner'
    let pos[0] += 1
    let pos[1] -= 1
  endif
  return "\<Esc>:".pos[1]."\<Enter>m>:".pos[0]."\<Enter>V'>"
endfunction

" For completion of \ref's, \cite's, etc.
function tex_seven#OmniCompletion(findstart, base)
  if a:findstart
    return -1 " Completion starts at cursor's position.
  else
    return tex_seven#omni#OmniCompletions()
  endif
endfunction

" Inserts a LaTeX statement and starts omni completion. If the
" line already contains the statement and the statement is still
" incomplete, i.e. missing the closing delimiter, only omni
" completion is started.
function tex_seven#SmartInsert(keyword, ...)
  return a:keyword."}\<Esc>i"
endfunction

