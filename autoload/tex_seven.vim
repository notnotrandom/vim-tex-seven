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

" Matches lines like:
" \bibliography{bibfilename}
" in .tex files. When used with matchstr(), it returns bibfilename.
let g:tex_seven#bibtexSourcesFilePattern = '\m^\\\(bibliography\|addbibresources\){\zs\S\+\ze}'

let g:tex_seven#emptyOrCommentLinesPattern = '\m^\s*\(%\|$\)'
let s:epochMainFileLastReadForIncludes = ""

" Matches lines like:
" \include{chapter1}
" in .tex files. When used with matchstr(), it returns chapter1.
let g:tex_seven#includedFilePattern = '\m^\\include{\zs\S\+\ze}'
let s:includedFilesList = []

let s:mainFile = ""

" Matches \somecmd{foo} or \somecmd[bar]{foo}. When used with matchstr(),
" returns "somecmd", sans quotes.
let g:tex_seven#matchCommand = '\m^\\\zs\a\+\ze\(\[.\+\]\)\?{'

" Matches a modeline like:
" % mainfile: ../main.tex
let g:tex_seven#modelinePattern = '\m^\s*%\s*mainfile:\s*\zs\S\+\ze'

" This variable is set when s:mainFile is set.
let s:path = ""

let s:sourcesFile = ""

" Here, if we do NOT find a main file, we just continue, for it is possible
" that the main file does not exist yet.
function tex_seven#AddBuffer()
  if s:mainFile == ""
    call tex_seven#DiscoverMainFile()
  endif
endfunction

" Brief: Set s:mainFile, the file which contains a line beginning with:
" \documentclass.
" Return: none.
"
" Synopsis: First, assume that the current file IS the main file. If so, set
" s:mainFile, and also looks for a bibliography file, if any (since we
" already iterating over the main file's lines...).
" If the current file is not the main one, then, search for a modeline, which
" will tell us the location of the main file, relative to the current file. It
" should be near the top of the file, and it is usually something like:
" % mainfile: ../main.tex
" Note that in this case, we will not search for a bibliography file.
function tex_seven#DiscoverMainFile()
  " If we already know the main file, no need to searching for it... (it is
  " very unlikely to change, after all).
  if s:mainFile != ""
    return
  endif

  " Otherwise, first, check if the current buffer is the main file (should
  " be the most common case, i.e., where the TeX input is not split across
  " multiple files).
  for line in getline(1, line('$'))
    if line =~ g:tex_seven#emptyOrCommentLinesPattern
      continue " Skip comments or empty lines.
    endif

    if line =~ '\m^\\documentclass'
      let s:mainFile = expand('%:p')
      let s:path = fnamemodify(s:mainFile, ':p:h') . '/'
      continue
    endif

    " If the current buffer is indeed the main file, then it also
    " contains the bibliography file (if any). Since we already iterating over
    " its lines, also search for the bibliography pattern.
    let l:aux = matchstr(line, g:tex_seven#bibtexSourcesFilePattern)
    if l:aux != ""
      let s:sourcesFile = expand('%:p:h') . '/' . l:aux . ".bib"
      continue
    endif

    " Similarly to the comment above, since we already iterating over the main
    " file's lines, we also search for \include'd files, if any. Note that as
    " we are setting the main file, s:includedFilesList should be empty.
    let l:aux = matchstr(line, g:tex_seven#includedFilePattern)
    if l:aux != ""
      call add(s:includedFilesList, l:aux)
      continue
    endif
  endfor

  " If the current buffer indeed turned out to be the main one, then there is
  " nothing else to do (other than updating the time it was last read, which
  " is just now).
  if s:mainFile != ""
    let s:epochMainFileLastReadForIncludes = str2nr(system("date +%s"))
    return
  endif

  " If the current buffer is not the main file, then go look for a modeline.
  " We start looking at the top of the file, and continue downwards (stopping
  " as soon as we find a non-comment line).
  for line in getline(1, line('$'))
    if line !~ '\m^%'
      break
    endif

    " We found the main file. As it is a relative path (e.g.,
    " "../main.tex"), we concatenate the full path (minus filename) of
    " the current file with that relative path, and then use the fnamemodify()
    " function to get the full path of the main file. For example, suppose the
    " full path of the current file is:
    " /home/user/latexProj/chapters/introduction.tex
    " If the modeline of that file is "../main.tex", then concatenation
    " yields:
    " /home/user/latexProj/chapters/../main.tex
    " The fnamemodify() function turns this into:
    " /home/user/latexProj/main.tex
    " Which is the correct main file, according to the modeline.
    let l:mainfile = matchstr(line, g:tex_seven#modelinePattern)
    if l:mainfile != ""
      let s:mainFile = fnamemodify(expand('%:p:h') . '/' . l:mainfile, ':p')
      return
    endif
  endfor
  " We have not found the main .tex file. This might not be a mistake, if the
  " user has just begun writing his LaTeX document.
endfunction

function tex_seven#DiscoverMainFileOrThrowUp()
  call tex_seven#DiscoverMainFile()
  if s:mainFile == ""
    throw "MainFileIsNotSet"
  endif
  return s:mainFile
endfunction

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

function tex_seven#GetIncludedFilesList()
  call tex_seven#DiscoverMainFileOrThrowUp()

  let l:needToReadMainFile = "false"

  if s:epochMainFileLastReadForIncludes == ""
    " We have not previously read s:mainFile. So set the l:needToReadMainFile
    " variable to read s:mainFile.
    let l:needToReadMainFile = "true"
  else
    " We have previously read s:mainFile for \include'd files extraction, so
    " we just need to check if it must be (re-)read (i.e. if that \include'd
    " file list needs to be updated).
    let l:epochMainFileLastModified = str2nr(system("stat --format %Y " . s:mainFile))

    if l:epochMainFileLastModified > s:epochMainFileLastReadForIncludes
      let l:needToReadMainFile = "true"
    endif
  endif

  if l:needToReadMainFile == "true"
    let s:includedFilesList = []

    for line in readfile(s:mainFile)
      if line =~ g:tex_seven#emptyOrCommentLinesPattern
        continue " Skip comments or empty lines.
      endif
      let included_file = matchstr(line, g:tex_seven#includedFilePattern)
      if included_file != ""
        call add(s:includedFilesList, included_file)
      endif
    endfor
    let s:epochMainFileLastReadForIncludes = str2nr(system("date +%s"))
  endif
  return s:includedFilesList
endfunction

function tex_seven#GetEpochMainFileLastReadForIncludes()
  return s:epochMainFileLastReadForIncludes
endfunction

function tex_seven#GetMainFile()
  call tex_seven#DiscoverMainFileOrThrowUp()

  " If control is still here, s:mainFile is properly set -- so return it.
  return s:mainFile
endfunction

function tex_seven#GetPath()
  return s:path
endfunction

function tex_seven#GetSourcesFile()
  return s:sourcesFile
endfunction

" This function is called when, in a .bib file, the user presses 'gm' (sans
" quotes, normal mode. Cf. ftplugin/bib_seven.vim). If s:mainFile is not set,
" then do nothing (this may not be an error; for instance, the .bib file may
" not be a part of a LaTeX project.)
function tex_seven#GoToMainFileIfSet()
  try
    let l:mainFile = tex_seven#GetMainFile()
    if l:mainFile != ""
      execute "edit " . l:mainFile
    endif
  catch "MainFileIsNotSet"
    echoerr "Cannot return to main file, as it is not set!"
  endtry
endfunction

function tex_seven#InsertEnv()
  let l:res = "\\begin{equation}\n\n\\end{equation}"
  return "" . l:res
endfunction

" For completion of \ref's, \cite's, etc.
function tex_seven#OmniCompletion(findstart, base)
  if a:findstart
    let l:cursorCurrIdx = col('.') - 1
    let l:line = getline('.')[: l:cursorCurrIdx ]
    let l:start = l:cursorCurrIdx - 1
    while l:line[l:start] != '{' &&
          \ l:line[l:start] != ',' &&
          \ l:line[l:start] != ' '
      let l:start -= 1
    endwhile
    return l:start + 1
  else
    return tex_seven#omni#OmniCompletions(a:base)
  endif
endfunction

" Brief: This function is called when the cursor is on expressions like:
" - \cite{key} or \nocite{key} or \cite[foo]{key} or \cite[foo]{key1, key2}.
" - \ref{key} or \eqref{key}.
" - \include{filename}.
"
" For each case, it invokes functions that do, respectively, the following:
" - open the bib source file, at the line corresponding to key, e.g.
"   "@book{key,". The case when there is more than key is dealt with like
"   follows: use the first one, unless the cursor is placed on top of any of
"   the other bibliographic keys. If the cursor is on top a comma or a space
"   (e.g. \cite:{a, b}), use the key immediately before. comments below.
" - open the .tex file containing \label{key}.
" - open filename.tex.
" Param: preview. Boolean (0 or 1). If true, shows the target file in a
" preview (:pedit) window. Otherwise, uses :edit.
" Return: none.
function tex_seven#QueryKey(preview)
  " Array indexes starts at 0, but output of col() starts at 1.
  let l:cursorColumn = col('.') - 1
  let l:startBackslashIdx = ""

  let l:keyword = ""
  let l:res = ""

  " In the next while loop below, we start at the cursor's position, go
  " backwards until we find a backslash. Once we do (or the current cursor
  " position is at a backslash), then we test to see it matches the start of a
  " command like: \command[foo]{bar} (see this function's documentation above,
  " as well as the documentation for s:matchCommand at the beginning of the
  " file). If there was no match, then we again go backwards, to the previous
  " backslash. If there was a match, we test to see if "command" is one of the
  " commands mentioned above in this function's documentation. If not, return
  " an error. If there was a match, then we set l:keyword to "command", and
  " break the while loop, and proceed to extract the keyword that command's
  " argument.
  "
  " We start by obtaining the entire line where the expression like \ref{key}
  " or whatever shows up.
  let l:line = getline('.')
  while 1
    if l:line[col('.') - 1] == '\' " Test if char in current cursor pos is '\'
      let l:startBackslashIdx = col('.') - 1
      let l:res = matchstr(l:line[ l:startBackslashIdx : ], g:tex_seven#matchCommand)
      if res == ""
        normal F\
        continue
      elseif l:res !~ '\m\(eq\)\?ref' &&
            \ l:res !~ '\m\(no\)\?cite.\?' &&
            \ l:res !~ '\minclude' && l:res !~ '\minput'
        echoerr "Pattern not found"
        return
      else
        " l:keyword will be ref, or eqref, or cite, or nocite, or include, or
        " input.
        let l:keyword = l:res
        break
      endif
    else
      normal F\
      continue
    endif
  endwhile

  " Ok, so we now have the "command" part in \command[whatever]{else}, stored
  " in the variable l:keyword. The \ref \eqref and \include cases are easy:
  " just select the "else" part, and call the relevant function (see
  " autoload/tex_seven/omni.vim). The \cite and \nocite are the tricky ones.
  " (Note 1: The getreg() function returns the text that was last yanked.)
  " (Note 2: We have to reset the cursor's position in the current buffer
  " inside each case. It cannot be done before this if/else, because for
  " keywords other than \cite or \nocite, we still need to move the cursor.
  " And it cannot be done after this if/else block, because we will already
  " have left the current buffer...)
  if l:keyword == 'include' || l:keyword == 'input'
    normal! f}vi}y
    let inckey = getreg()

    " Before opening a new window, set the cursor in the current window, to
    " its original position.
    call setpos(".", [0, line("."), l:cursorColumn + 1, 0])

    call tex_seven#omni#QueryIncKey(inckey, a:preview)
  elseif l:keyword =~ '.*ref'
    normal! f}vi}y
    let refkey = getreg()

    " Before opening a new window, set the cursor in the current window, to
    " its original position.
    call setpos(".", [0, line("."), l:cursorColumn + 1, 0])

    call tex_seven#omni#QueryRefKey(refkey, a:preview)
  else
    " This is the thorny case of \cite or \nocite. Suppose that this function
    " was called with the cursor somewhere on the expression "\cite[foo\
    " bar]{baz, xpto}". The code above (before the current if-then-else chain)
    " puts the byte index of the leftmost backslash in the variable
    " l:startBackslashIdx (recall that the start of the line is index 0). What
    " the next three lines below do, is to recover the byte index of first
    " curly brace, '{', in '{baz, xpto}'.
    "   For this, we use the function matchstrpos(), which returns a list as
    " follows:
    "   [ "string matched", startidx, endidx ]
    " where startidx and endidx are the byte indexes of the first character of
    " "string matched", and of the character TO THE RIGHT OF the last
    " character of "string matched".
    "   However, there is a catch: there might be more than \cite command in
    " the same line! (The same holds for \ref, etc.) Hence, to ensure we
    " process the right command the match must not start at the beginning of
    " the line, but at the index of the backslash that starts the current
    " command, viz. l:startBackslashIdx. Hence, after the match, this value
    " must be added to endidx -- to obtain the index of the same character in
    " the entire line.
    let l:res = matchstrpos(l:line[ l:startBackslashIdx : ],
          \ '\m\\' . l:keyword . '\(\[.\+\]\)\?\zs{\ze')
    let l:firstCharIdx = l:startBackslashIdx + l:res[2]

    " OK, so now the variable l:firstCharIdx contains the byte index of 'b'
    " (the character right of '{') in the whole line that contains
    " "\cite[foo\ bar]{baz, xpto}".
    " The algorithm is has follows: discover the (indexes of the) borders of
    " the first key (in this case b and z), and then discover the start of the
    " next of one (in this case, x). If there is no next one (i.e. we find
    " '}'), or if the cursor position is before the start of the first key,
    " return that first key. Otherwise, find the borders of that next key, and
    " the start of the one after that, if it exists, and check that start
    " against the cursor position. If the cursor is before that next start,
    " return the second key. And so on...
    let l:entryKeyToBeSearched = ""
    let l:nextStart = l:firstCharIdx
    while 1
      let l:start = l:nextStart
      let l:stop  = l:nextStart

      " Discover the stop of the current entry.
      while l:line[l:stop] != ',' && l:line[l:stop] != '}' && l:line[l:stop] != ' '
        let l:stop += 1
      endwhile
      let l:stop -= 1
      let l:entryKeyToBeSearched = l:line[l:start:l:stop]

      " Discover start of next entry...
      let l:nextStart = l:stop + 1
      while l:line[l:nextStart] == ',' || l:line[l:nextStart] == ' '
          let l:nextStart += 1
      endwhile

      " ... unless there isn't a next entry, in which case we are done.
      if l:line[l:nextStart] == '}' | break | endif

      " We are also done when the next key start's past (i.e. to the right) of
      " the current cursor position.
      if l:cursorColumn < l:nextStart
        break
      endif
    endwhile

    " Before opening a new window, set the cursor in the current window, to
    " its original position.
    call setpos(".", [0, line("."), l:cursorColumn + 1, 0])

    " Now that we have the correct bibkey, give it to the correct function.
    call tex_seven#omni#QueryBibKey(l:entryKeyToBeSearched, a:preview)
  endif
endfunction

function tex_seven#SetEpochMainFileLastReadForIncludes(value)
  let s:epochMainFileLastReadForIncludes = a:value
endfunction

" XXX check if there are deep copy issues!
function tex_seven#SetIncludedFilesList(value)
  let s:includedFilesList = a:value
endfunction

"Brief: If s:mainFile is set, then iterate through its lines, to discover
"the bibliography file, if any.
" Return: full path of sources file, or empty if there is no such file.
function tex_seven#SetSourcesFile()
  if s:sourcesFile != ""
    return s:sourcesFile
  endif

  call tex_seven#DiscoverMainFileOrThrowUp()

  " Since we are reading the main file, we also update the \include'd file
  " list.
  let s:includedFilesList = []

  for line in readfile(s:mainFile)
    let l:aux = matchstr(line, g:tex_seven#bibtexSourcesFilePattern)
    if l:aux != ""
      let s:sourcesFile = fnamemodify(s:mainFile, ':p:h') . '/' . l:aux . ".bib"
      continue
    endif

    " As mentioned above, since we are reading the main file anyway, we also
    " check the \include'd files list.
    let l:aux = matchstr(line, g:tex_seven#includedFilePattern)
    if l:aux != ""
      call add(s:includedFilesList, l:aux)
      continue
    endif
  endfor
  let s:epochMainFileLastReadForIncludes = str2nr(system("date +%s"))
  return s:sourcesFile
endfunction

" TODO rethink this function...
function tex_seven#SmartInsert(keyword)
  if a:keyword == '\includeonly{' && expand('%:p') != tex_seven#GetMainFile()
    echohl WarningMsg |
          \ call input("\\includeonly can only be used in main file! (Hit <Enter to continue>)")
  endif
  return a:keyword."}\<Esc>i"
endfunction
