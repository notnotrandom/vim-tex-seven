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

" Matches lines like:
" @book{Shoup:2009,
" in BiBTeX source files.
let s:bibtexEntryKeyPattern = '\m^@\a\+{\zs\S\+\ze,'

" Matches lines like:
" \bibliography{bibfilename}
" in .tex files. When used with matchstr(), it returns bibfilename.
let s:bibtexSourcesFilePattern = '\m^\\\(bibliography\|addbibresources\){\zs\S\+\ze}'

let s:bibEntryList = []
let s:emptyOrCommentLinesPattern = '\m^\s*\(%\|$\)'
let s:epochMainFileLastRead = ""
let s:epochSourceFileLastRead = ""

let s:includedFilePattern = '\m^\\include{\zs\S\+\ze}'
let s:includedFilesList = []

let s:mainFile = ""

" Matches a modeline like:
" % mainfile: ../main.tex
let s:modelinePattern = '\m^\s*%\s*mainfile:\s*\zs\S\+\ze'

let s:sourcesFile = ""

" Brief:
function tex_seven#omni#GetBibEntries()
  let l:needToReadSourcesFile = "false"

  if s:epochSourceFileLastRead == ""
    " We have not previously read s:sourcesFile. So first, discover if there
    " is one, to begin with...
    if s:sourcesFile == ""
      call tex_seven#omni#SetSourcesFile()
    endif

    " If s:sourcesFile is still empty, that means no bibliography file was
    " found. Hence just return an empty list of bib entries...
    if s:sourcesFile == "" | return [] | endif

    " Otherwise, we need to read the sources file, so:
    let l:needToReadSourcesFile = "true"

  else
    " We have previously read s:sourcesFile, so we just need to check if it
    " must be (re-)read. Note that the fact that s:sourcesFile has been read
    " means that s:bibEntryList has also previously been set.
    let l:epochSourceFileLastModified = str2nr(system("stat --format %Y " . s:sourcesFile))

    if l:epochSourceFileLastModified > s:epochSourceFileLastRead
      let l:needToReadSourcesFile = "true"
    endif
  endif

  if l:needToReadSourcesFile == "true"
    let s:bibEntryList = []
    let s:epochSourceFileLastRead = str2nr(system("date +%s"))

    for line in readfile(s:sourcesFile)
      let entry_key = matchstr(line, s:bibtexEntryKeyPattern)
      if entry_key != ""
        call add(s:bibEntryList, entry_key)
      endif
    endfor
  endif
  return s:bibEntryList
endfunction

function tex_seven#omni#GetIncludedFiles()
  if s:mainFile == ""
    throw "Main file is not set!"
  endif

  let l:needToReadMainFile = "false"

  if s:epochMainFileLastRead == "" || s:includedFilesList == []
    " We have not previously read s:mainFile, or we did read it, but not to
    " extract the \include'd files. (E.g. could have been read to find
    " bibliography source file.) So set the variable to read s:mainFile.
    let l:needToReadMainFile = "true"

  else
    " We have previously read s:mainFile, and extracted the list of \include'd
    " files, so we just need to check if it must be (re-)read.
    let l:epochMainFileLastModified = str2nr(system("stat --format %Y " . s:mainFile))

    if l:epochMainFileLastModified > s:epochMainFileLastRead
      let l:needToReadMainFile = "true"
    endif
  endif

  if l:needToReadMainFile == "true"
    let s:includedFilesList = []
    let s:epochMainFileLastRead = str2nr(system("date +%s"))

    for line in readfile(s:mainFile)
      let included_file = matchstr(line, s:includedFilePattern)
      if included_file != ""
        call add(s:includedFilesList, included_file)
      endif
    endfor
  endif
  return s:includedFilesList
endfunction

" For completion of say, \cite{}, the cursor is on '}'. Also remember that
" col() starts at 1, but lists (arrays) start at zero!
function tex_seven#omni#OmniCompletions()
  let l:line = getline('.')
  let l:start = col('.') - 1
  while l:start > 0 && l:line[l:start - 1] != '\'
    let l:start -= 1
  endwhile

  let l:keyword = l:line[l:start:col('.') - 3]
  if l:keyword == 'cite'
    return tex_seven#omni#GetBibEntries()
  elseif l:keyword == 'includeonly'
    return tex_seven#omni#GetIncludedFiles()
  else
    return []
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
function tex_seven#omni#SetMainFile()
  " If we already know the main file, no need to searching for it... (it is
  " very unlikely to change, after all).
  if s:mainFile != ""
    return " There is nothing to do.
  endif

  " Otherwise, first, check if the current buffer is the main file (should
  " be the most common case, i.e., where the TeX input is not split across
  " multiple files).
  for line in getline(1, line('$'))
    if line =~ s:emptyOrCommentLinesPattern
      continue " Skip comments or empty lines.
    endif

    if line =~ '\m^\\documentclass'
      let s:mainFile = expand('%:p')
      let s:epochMainFileLastRead = str2nr(system("stat --format %Y " . s:mainFile))
      continue
    endif

    " If the current buffer is indeed the main file, then it also
    " contains the bibliography file (if any). Since we already iterating over
    " its lines, also search for the bibliography pattern.
    let l:aux = matchstr(line, s:bibtexSourcesFilePattern)
    if l:aux != ""
      let s:sourcesFile = expand('%:p:h') . '/' . l:aux . ".bib"
      continue
    endif

    let l:aux = matchstr(line, s:includedFilePattern)
    if l:aux != ""
      call add(s:includedFilesList, l:aux)
      continue
    endif
  endfor

  " If the current buffer indeed turned out to be the main one, then there is
  " nothing else to do.
  if s:mainFile != "" | return | endif

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
    let l:mainfile = matchstr(line, s:modelinePattern)
    if l:mainfile != ""
      let s:mainFile = fnamemodify(expand('%:p:h') . '/' . l:mainfile, ':p')
      return
    endif
  endfor
  throw "Main file not found!"
endfunction

"Brief: If s:mainFile is set, then iterate through its lines, to discover
"the bibliography file, if any.
" Return: none.
function tex_seven#omni#SetSourcesFile()
  if s:sourcesFile != ""
    return " There is nothing to do.
  elseif s:mainFile == ""
    throw "Main is not set!"
  endif

  let s:epochMainFileLastRead = str2nr(system("date +%s"))
  for line in readfile(s:mainFile)
    let l:aux = matchstr(line, s:bibtexSourcesFilePattern)
    if l:aux != ""
      let s:sourcesFile = fnamemodify(s:mainFile, ':p:h') . '/' . l:aux . ".bib"
    endif
  endfor
endfunction
