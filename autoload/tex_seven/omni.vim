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
" in BiBTeX source files. When used with matchstr(), it returns "Shoup:2009",
" sans quotes.
let s:bibtexEntryKeyPattern = '\m^@\a\+{\zs\S\+\ze,'

" Matches lines like:
" \bibliography{bibfilename}
" in .tex files. When used with matchstr(), it returns bibfilename.
let s:bibtexSourcesFilePattern = '\m^\\\(bibliography\|addbibresources\){\zs\S\+\ze}'

let s:bibEntryList = []
let s:emptyOrCommentLinesPattern = '\m^\s*\(%\|$\)'
let s:epochMainFileLastReadForIncludes = ""
let s:epochSourceFileLastRead = ""

let s:includedFilePattern = '\m^\\include{\zs\S\+\ze}'
let s:includedFilesList = []

let s:mainFile = ""

" Matches a modeline like:
" % mainfile: ../main.tex
let s:modelinePattern = '\m^\s*%\s*mainfile:\s*\zs\S\+\ze'

" This variable is set when s:mainFile is set.
let s:path = ""

let s:sourcesFile = ""

function tex_seven#omni#AddBuffer()
  if s:mainFile == ""
    call tex_seven#omni#SetMainFile()
  endif
endfunction

function tex_seven#omni#BibQuery(citekey, preview)
  if s:sourcesFile == ""
    call tex_seven#omni#SetSourcesFile()
  endif

  " To preview, or not to preview.
  let l:to_p_or_nor_to_p = 'p'
  if a:preview == "false" | let l:to_p_or_nor_to_p = '' | endif

  execute l:to_p_or_nor_to_p . 'edit +/' . a:citekey . ' ' . s:sourcesFile
  windo if &previewwindow | execute 'normal zR zz' | endif
  redraw
endfunction

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
      if line =~ s:emptyOrCommentLinesPattern
        continue " Skip comments or empty lines.
      endif
      let included_file = matchstr(line, s:includedFilePattern)
      if included_file != ""
        call add(s:includedFilesList, included_file)
      endif
    endfor
    let s:epochMainFileLastReadForIncludes = str2nr(system("date +%s"))
  endif
  return s:includedFilesList
endfunction

function tex_seven#omni#GetLabels()
  let l:labelsFound = []

  " Since we need to read s:mainFile anayway, also check the \include's.
  let s:includedFilesList = []

  for line in readfile(s:mainFile)
    if line =~ s:emptyOrCommentLinesPattern
      continue " Skip comments or empty lines.
    endif

    let included_file = matchstr(line, s:includedFilePattern)
    if included_file != ""
      call add(s:includedFilesList, included_file)
      continue " I don't expect for there to be \label's anywhere near \include's...
    endif

    " This matches once per line; but here is no point in having two \label's
    " in the same line...
    let newlabel = matchstr(line,  '\m\\label{\zs\S\+\ze}')
    if newlabel != ""
      call add(l:labelsFound, newlabel)
    endif
  endfor

  let s:epochMainFileLastReadForIncludes = str2nr(system("date +%s"))
  return l:labelsFound
endfunction

function tex_seven#omni#GetMainFile()
  if s:mainFile == ""
    throw "Main file is not set!"
  endif
  return s:mainFile
endfunction

" For completion of say, \cite{}, the cursor is on '}'. Also remember that
" col() starts at 1, but lists (arrays) start at zero!
function tex_seven#omni#OmniCompletions()
  let l:cursorColumn = col('.') - 1
  let l:keyword = ""
  let l:line = getline('.')[: l:cursorColumn - 1] " Unlike Python, this includes the last index!
  let l:start = col('.') - 1
  while l:start > 0
    if l:line[l:start - 1] == '\'
      echom l:line[l:start:] . '|'
      let l:keyword = matchstr(l:line[l:start:],
            \ '\m\zs\a\+\ze\(\[.\+\]\)\?{\(.\+,\s*\)*$')
      if l:keyword != ""
        break
      endif
    endif
    let l:start -= 1
  endwhile

  echom "keyword: " . l:keyword
  if l:keyword == 'cite'
    return tex_seven#omni#GetBibEntries()
  elseif l:keyword == 'includeonly'
    return tex_seven#omni#GetIncludedFiles()
  elseif l:keyword =~ '.*ref'
    return tex_seven#omni#GetLabels()
  else
    return []
  endif
endfunction

function tex_seven#omni#RefQuery(refkey, preview)
  if s:mainFile == ""
    throw "Main file is not set!"
  endif

  let l:includedFilesList = []

  let l:currentFileIsMain = 0 " False.
  if s:mainFile == expand('%:p')
    let l:currentFileIsMain = 1 " True.
  endif

  let l:linenum = 0
  for line in getline(1, line('$'))
    let l:linenum += 1
    let column = match(line,  '\m\\label{' . a:refkey . '}')
    if column != -1 " -1 means no match.
      " To preview, or not to preview.
      let l:to_p_or_nor_to_p = 'p'
      if a:preview == "false" | let l:to_p_or_nor_to_p = '' | endif

      " echom a:refkey . ' expand ' . expand('%:p')
      " echom 'edit +/\\label{' . a:refkey . '} ' . expand('%:p')
      " execute 'edit +/\\label{' . a:refkey . '} ' . expand('%:p')
      execute l:to_p_or_nor_to_p . 'edit +/\\label{' . a:refkey . '} ' . expand('%:p')
      call setpos('.', [0, l:linenum, column, 0])
      windo if &previewwindow | execute 'normal zR zz' | endif
      return
    elseif l:currentFileIsMain == 1 " Current file is s:mainFile.
      let included_file = matchstr(line, s:includedFilePattern)
      if included_file != ""
        call add(l:includedFilesList, included_file)
      endif
    endif
  endfor

  " So we didn't find the \label we were looking for in the current file. Now,
  " if the loop above did not find \include'd files (len(l:includedFilesList)
  " == 0), that means it either searched for \label's over some file OTHER
  " than s:mainFile, or that it searched s:mainFile, but found no \include
  " statement. In the latter case there is nothing more to do, but in former
  " (i.e., current file is not s:mainFile), we must search over s:mainFile for
  " \include's, and then search these files to see if any of them contain the
  " \label we're after. In the following if statement, we search s:mainFile,
  " if the current file is not it.
  if len(l:includedFilesList) == 0 && l:currentFileIsMain == 0
    for line in readfile(s:mainFile)
      if line =~ s:emptyOrCommentLinesPattern
        continue " Skip comments or empty lines.
      endif

      let included_file = matchstr(line, s:includedFilePattern)
      if included_file != ""
        call add(l:includedFilesList, included_file)
      endif
    endfor
  endif

  if len(l:includedFilesList) > 0
    " Search over \include'd files. But first, update s:includedFilesList, and
    " s:epochMainFileLastReadForIncludes.
    let s:epochMainFileLastReadForIncludes = str2nr(system("date +%s"))
    let s:includedFilesList = l:includedFilesList

    for fname in l:includedFilesList
      let fcontents = readfile(s:path . fname . '.tex')
      for line in fcontents

        " This matches once per line; see similar remark above.
        let column = match(line,  '\m\\label{' . a:refkey . '}')
        if column != -1
          " To preview, or not to preview.
          let l:to_p_or_nor_to_p = 'p'
          if a:preview == "false" | let l:to_p_or_nor_to_p = '' | endif

          execute l:to_p_or_nor_to_p . 'edit +/' . a:citekey . ' ' . s:path . fname . '.tex'
          call setpos('.', [0, index(fcontents, line), column, 0])
          windo if &previewwindow | execute 'normal zR zz' | endif
          return
        endif
      endfor
    endfor
  else
    echoerr "Pattern not found"
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
      let s:path = fnamemodify(s:mainFile, ':p:h') . '/'
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

    " Similarly to the comment above, since we already iterating over the main
    " file's lines, we also search for \include'd files, if any. Note that as
    " we are setting the main file, s:includedFilesList should be empty.
    let l:aux = matchstr(line, s:includedFilePattern)
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

  " Since we are reading the main file, we also update the \include'd file
  " list.
  let s:includedFilesList = []

  for line in readfile(s:mainFile)
    let l:aux = matchstr(line, s:bibtexSourcesFilePattern)
    if l:aux != ""
      let s:sourcesFile = fnamemodify(s:mainFile, ':p:h') . '/' . l:aux . ".bib"
      continue
    endif

    " As mentioned above, since we are reading the main file anyway, we also
    " check the \include'd files list.
    let l:aux = matchstr(line, s:includedFilePattern)
    if l:aux != ""
      call add(s:includedFilesList, l:aux)
      continue
    endif
  endfor
  let s:epochMainFileLastReadForIncludes = str2nr(system("date +%s"))
endfunction
