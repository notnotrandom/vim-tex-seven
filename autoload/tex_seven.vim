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

" Matches \somecmd{foo} or \somecmd[bar]{foo}. When used with matchstr(),
" returns "somecmd", sans quotes.
let s:matchCommand = '\m^\\\zs\a\+\ze\(\[.\+\]\)\?{'

" Used for completion of sub and super scripts. See ftplugin/tex_seven.vim.
function tex_seven#IsLeft(lchar)
  let left = getline('.')[col('.')-2]
  return left == a:lchar ? 1 : 0
endfunction

" Used in visual mode, to change the selected text to bold, italic, etc. See
" ftplugin/tex_seven.vim.
function tex_seven#ChangeFontStyle(style)
  let str = 'di'
  let is_math = tex_seven#environments#Is_latex_math_environment()
  let str .= is_math ? '\math'.a:style : '\text'.a:style
  let str .= "{}\<Left>\<C-R>\""
  return str
endfunction

" For visual selection operators of inner or outer (current) environment. See
" ftplugin/tex_seven.vim.
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

" Brief: This function is called on expressions like:
" - \cite{key} or \nocite{key} or \cite[foo]{key}.
" - \ref{key} or \eqref{key}.
" - \include{filename}.
"
" For each case, it invokes functions that do, respectively:
" - open the bib source file, in the entry corresponding to key, e.g.
"   "@book{key,".
" - open the .tex file containing \label{key}
" - open filename.tex
" Param: preview. Boolean ("true" or "false"). If true, shows the target file
" in a preview (:pedit) window. Otherwise, uses :edit.
" Return: none.
function tex_seven#QueryKey(preview)
  " Array indexes starts at 0, but output of col() starts at 1.
  let l:cursorColumn = col('.') - 1
  let l:startBackslashIdx = ""
  let l:firstCharIdx = ""

  let l:keyword = ""
  let l:entryKeyToBeSearched = ""
  let l:res = ""

  " In this while loop, we start at the cursor's position, go backwards until
  " we find a backslash. Once we do (or the current cursor position is at a
  " backslash), then we test to see it matches the start of a command like:
  " \command[foo]{bar} (see this function's documentation above, as well as
  " the documentation for s:matchCommand at the beginning of the file).
  " If there was no match, then we again go backwards, to the previous
  " backslash. If there was a match, we test to see if "command" is one of
  " the commands mentioned above in this function's documentation. If not,
  " return an error. If there was a match, then we set l:keyword to "command",
  " and break the while loop, and proceed to extract the keyword that
  " command's argument.
  let l:line = getline('.')
  while 1
    if l:line[col('.') - 1] == '\'
      let l:startBackslashIdx = col('.') - 1
      let l:res = matchstr(l:line[ l:startBackslashIdx : ], s:matchCommand)
      if res == ""
        normal F\
        continue
      elseif l:res !~ '\m\(eq\)\?ref' &&
            \ l:res !~ '\m\(no\)\?cite.\?' &&
            \ l:res !~ '\minclude'
        echoerr "Pattern not found"
        return
      else
        " l:keyword will be ref, or eqref, or cite, or nocite, or include.
        let l:keyword = l:res
        break
      endif
    else
      normal F\
      continue
    endif
  endwhile

  let l:res = matchstrpos(l:line[ l:startBackslashIdx : ],
        \ '\m\\' . l:keyword . '\(\[.\+\]\)\?\zs{\ze')
  let l:firstCharIdx = l:startBackslashIdx + l:res[2]

  " let cmd=getreg()
  if l:keyword == 'include'
    normal! f}vi}y
    let inckey = getreg()
    call tex_seven#omni#QueryIncKey(inckey, a:preview)
  elseif l:keyword =~ '.*ref'
    normal! f}vi}y
    let refkey = getreg()
    call tex_seven#omni#QueryRefKey(refkey, a:preview)
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

    call tex_seven#omni#QueryBibKey(l:entryKeyToBeSearched, a:preview)
  endif
endfunction

" TODO rethink this function...
function tex_seven#SmartInsert(keyword)
  if a:keyword == '\includeonly{' && expand('%:p') != tex_seven#omni#GetMainFile()
    echohl WarningMsg |
          \ call input("\\includeonly can only be used in main file! (Hit <Enter to continue>)")
  endif
  return a:keyword."}\<Esc>i"
endfunction
