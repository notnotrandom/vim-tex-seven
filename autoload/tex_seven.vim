" LaTeX filetype plugin
" Languages:    Vimscript
" Author:       Óscar Pereira
" Version:      1.0
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

function tex_seven#QueryMap()
  let l:cursorColumn = col('.') - 1 " Array idx starts at 0, unlike columns.
  echom l:cursorColumn
  let l:keyword = ""
  let l:startBackslashIdx = ""
  let l:fullline = getline('.')
  let l:line = l:fullline[:l:cursorColumn] " Unlike Python, this includes the last index!
  let l:line = l:fullline
  let l:start = l:cursorColumn
  if l:line[l:start] == '\'
    let l:start += 1
  endif
  while l:start > 0
    if l:line[l:start - 1] == '\'
      " echom  "foudass" . l:line[l:start:]
      let l:keyword = matchstr(l:line[l:start:l:cursorColumn], '\m\zs\a\+\ze\(\[.\+\]\)\?{')
      if l:keyword != ""
        let l:startBackslashIdx = l:start - 1
        break
      endif
    endif
    let l:start -= 1
  endwhile
  echom "keyword: " . l:keyword

  " let cmd=getreg()
  if l:keyword =~? '\\.*ref{'
    normal! f}vi}y
    let refkey = getreg()
    echom refkey
    call tex_seven#RefQuery(refkey)
  else
    " l:start is the c in \cite
    let l:aux = matchstrpos(l:fullline,
          \ '\m\\' . l:keyword . '\(\[.\+\]\)\?\zs{\ze', l:startBackslashIdx)
    let l:startOpenBraceIdx = l:startBackslashIdx + l:aux[1]
    " echom "full line: " . l:fullline
    echom "aux 1: " . l:aux[1]
    echom "start backslash idx: " . l:startBackslashIdx
    echom "start open brace idx: " . l:startOpenBraceIdx
    " if l:cursorColumn <= l:start " Return first entry key.
      " nothing to do, l:start at the right place
    if l:cursorColumn <= l:startOpenBraceIdx " Return first entry key.
      let l:start = l:startOpenBraceIdx + 1
    else
      let l:start = l:cursorColumn
      while l:start > 0
        if l:fullline[l:start - 1] == '{' || l:fullline[l:start - 1] == ','
              \ || l:fullline[l:start - 1] == ' '
          break
        endif
        let l:start -= 1
      endwhile
    endif

    if l:cursorColumn <= l:startOpenBraceIdx " Return first entry key.
      let l:stop = l:startOpenBraceIdx + 1
    else
      let l:stop = l:cursorColumn
      if l:fullline[l:stop] == '}'
        let l:stop -= 1
      endif
    endif

    while l:stop < len(l:fullline)
      if l:fullline[l:stop + 1] == '}' || l:fullline[l:stop + 1] == ','
              \ || l:fullline[l:stop + 1] == ' '
        break
      endif
      let l:stop += 1
    endwhile
    call tex_seven#omni#BibQuery(l:fullline[l:start:l:stop])
  endif
endfunction

" Inserts a LaTeX statement and starts omni completion. If the
" line already contains the statement and the statement is still
" incomplete, i.e. missing the closing delimiter, only omni
" completion is started.
function tex_seven#SmartInsert(keyword)
  if a:keyword == '\includeonly{' && expand('%:p') != tex_seven#omni#GetMainFile()
    echohl WarningMsg |
          \ call input("\\includeonly can only be used in main file! (Hit <Enter to continue>)")
  endif
  return a:keyword."}\<Esc>i"
endfunction

