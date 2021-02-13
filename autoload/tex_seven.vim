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

function tex_seven#QueryMap(preview)
  let l:cursorColumn = col('.') - 1 " Array idx starts at 0, unlike columns.
  let l:startBackslashIdx = ""
  echom l:cursorColumn
  let l:keyword = ""
  let l:firstCharIdx = ""
  let l:line = getline('.')
  let l:entryKeyToBeSearched = ""
  let l:res = ""

  " echom "l:line[col('.') - 1 : ]:" . l:line[col('.') - 1 : ]
  while 1
    if l:line[col('.') - 1] == '\'
      let l:startBackslashIdx = col('.') - 1
      let l:res = matchstr(l:line[ l:startBackslashIdx : ], '\m^\\\zs\a\+\ze\(\[.\+\]\)\?{')
      if res == ""
        normal F\
        continue
      elseif l:res !~ '\m\(eq\)\?ref' &&
            \ l:res !~ '\m\(no\)\?cite.\?'
        echom "res: " . l:res
        echoerr "Pattern not found"
        return
      else
        let l:keyword = l:res
        break
      endif
    else
      normal F\
      continue
    endif
  endwhile

  echom "keyword: " . l:keyword
  let l:res = matchstrpos(l:line[ l:startBackslashIdx : ],
        \ '\m\\' . l:keyword . '\(\[.\+\]\)\?\zs{\ze')
  let l:firstCharIdx = l:startBackslashIdx + l:res[2]
  echom "first char: " . l:firstCharIdx

  " let cmd=getreg()
  if l:keyword =~? '\\.*ref{'
    normal! f}vi}y
    let refkey = getreg()
    echom refkey
    call tex_seven#RefQuery(refkey)
  else
    let l:nextStart = l:firstCharIdx
    while 1
      " echom "foo"
      let l:start = l:nextStart
      let l:stop  = l:nextStart
      while l:line[l:stop] != ',' && l:line[l:stop] != '}' && l:line[l:stop] != ' '
        let l:stop += 1
      endwhile
      let l:stop -= 1
      let l:entryKeyToBeSearched = l:line[l:start:l:stop]

      " Discover start of next entry, if there is one.
      let l:nextStart = l:stop + 1
      while l:line[l:nextStart] == ',' || l:line[l:nextStart] == ' '
          let l:nextStart += 1
      endwhile
      if l:line[l:nextStart] == '}' | break | endif

      if l:cursorColumn < l:nextStart
        break
      endif
    endwhile

    echom "l:entryKeyToBeSearched: " . l:entryKeyToBeSearched
    call tex_seven#omni#BibQuery(l:entryKeyToBeSearched, a:preview)
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

