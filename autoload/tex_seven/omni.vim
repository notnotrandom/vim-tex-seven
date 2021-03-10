" LaTeX filetype plugin
" Languages:    Vimscript
" Maintainer:   Óscar Pereira
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
" @book{Shoup:2009,
" in BiBTeX source files. When used with matchstr(), it returns "Shoup:2009",
" sans quotes.
let s:bibtexEntryKeyPattern = '\m^@\a\+{\zs\S\+\ze,'

let s:bibEntryList = []
let s:epochSourceFileLastRead = ""

function tex_seven#omni#QueryBibKey(citekey, preview)
  let l:sourcesFile = tex_seven#SetSourcesFile()
  if l:sourcesFile == ""
    throw "BibSourceFileNotFound"
  endif

  " To preview, or not to preview.
  let l:to_p_or_nor_to_p = 'p'
  if a:preview == 0 | let l:to_p_or_nor_to_p = '' | endif

  execute l:to_p_or_nor_to_p . 'edit +/' . a:citekey . '/;normal\ zt ' . l:sourcesFile
  redraw
endfunction

" Brief:
function tex_seven#omni#GetBibEntries()
  let l:needToReadSourcesFile = "false"
  let l:sourcesFile = tex_seven#GetSourcesFile()

  if s:epochSourceFileLastRead == ""
    " We have not previously read s:sourcesFile. So first, discover if there
    " is one, to begin with...
    if l:sourcesFile == ""
      let l:sourcesFile = tex_seven#SetSourcesFile()
    endif

    " If s:sourcesFile is still empty, that means no bibliography file was
    " found. Hence just return an empty list of bib entries...
    if l:sourcesFile == "" | return [] | endif

    " Otherwise, we need to read the sources file, so:
    let l:needToReadSourcesFile = "true"

  else
    " We have previously read s:sourcesFile, so we just need to check if it
    " must be (re-)read. Note that the fact that s:sourcesFile has been read
    " means that s:bibEntryList has also previously been set.
    let l:epochSourceFileLastModified = str2nr(system("stat --format %Y " .
          \ tex_seven#GetSourcesFile()))

    if l:epochSourceFileLastModified > s:epochSourceFileLastRead
      let l:needToReadSourcesFile = "true"
    endif
  endif

  if l:needToReadSourcesFile == "true"
    let s:bibEntryList = []
    let s:epochSourceFileLastRead = str2nr(system("date +%s"))

    for line in readfile(l:sourcesFile)
      let entry_key = matchstr(line, s:bibtexEntryKeyPattern)
      if entry_key != ""
        call add(s:bibEntryList, entry_key)
      endif
    endfor
  endif
  return s:bibEntryList
endfunction

" Brief: Omni-completion for \includegraphics{prefix}, where the prefix is
" optional.
" Returns: a list of .jpg, .pdf, or .png files, recursively searched under
" s:path.
function tex_seven#omni#GetGraphicsList(prefix = '')
  let l:path = tex_seven#GetPath()

  " Find files. The -printf is to use relative paths. It also removes the
  " starting './' of the path of found files. The -path -prune thingy skips
  " files inside anydirectory which name contains the string "build".
  let l:graphicFiles = system("find " . fnameescape(l:path) . " -type f " .
        \ "-path \\*build\\*/\\* -prune -o " .
        \ "-iname \\*.jpg -printf \"%P\n\" -o " .
        \ "-iname \\*.pdf -printf \"%P\n\" -o " .
        \ "-iname \\*.png -printf \"%P\n\" " )

  if a:prefix == ''
    return split(l:graphicFiles, "\n")
  else
    return filter(split(l:graphicFiles, "\n"), 'v:val =~ "\\m^" . a:prefix')
  endif
endfunction

function tex_seven#omni#GetLabels(prefix = '')
  let l:mainFile = tex_seven#GetMainFile()

  let l:labelsFound = []

  " Since we need to read s:mainFile anayway, also check (and update) the \include's.
  let l:includedFilesList = []

  for line in readfile(l:mainFile)
    if line =~ g:tex_seven#emptyOrCommentLinesPattern
      continue " Skip comments or empty lines.
    endif

    let included_file = matchstr(line, g:tex_seven#includedFilePattern)
    if included_file != ""
      call add(l:includedFilesList, included_file)
      continue " I don't expect for there to be \label's anywhere near \include's...
    endif

    " This matches once per line; but there is no point in having two \label's
    " in the same line...
    let newlabel = matchstr(line,  '\m\\label{\zs\S\+\ze}')
    if newlabel != ""
      if a:prefix == '' || newlabel =~ '\m^' . a:prefix
        call add(l:labelsFound, newlabel)
      endif
    endif
  endfor
  call tex_seven#SetEpochMainFileLastReadForIncludes(str2nr(system("date +%s")))
  call tex_seven#SetIncludedFilesList(l:includedFilesList)

  " Now search the included files.
  for l:fname in tex_seven#GetIncludedFilesList()
    let l:fcontents = readfile(tex_seven#GetPath() . l:fname . '.tex')
    for l:line in l:fcontents
      let newlabel = matchstr(l:line,  '\m\\label{\zs\S\+\ze}')
      if newlabel != ""
        if a:prefix == '' || newlabel =~ '\m^' . a:prefix
          call add(l:labelsFound, newlabel)
        endif
      endif
    endfor
  endfor

  return l:labelsFound
endfunction

function tex_seven#omni#QueryIncKey(inckey, preview)
  " To preview, or not to preview.
  let l:to_p_or_nor_to_p = 'p'
  if a:preview == 0 | let l:to_p_or_nor_to_p = '' | endif

  execute l:to_p_or_nor_to_p . 'edit ' . a:inckey . '.tex'
endfunction

" For completion of say, \cite{}, the cursor is on '}'. Also remember that
" col() starts at 1, but lists (arrays) start at zero!
function tex_seven#omni#OmniCompletions(base)
  let l:cursorColumn = col('.') - 1
  let l:keyword = ""
  let l:line = getline('.')[: l:cursorColumn - 1] " Unlike Python, this includes the last index!
  let l:start = col('.') - 1
  while l:start > 0
    if l:line[l:start - 1] == '\'
      let l:keyword = matchstr(l:line[l:start:],
            \ '\m\zs\a\+\ze\(\[.\+\]\)\?{\(.\+,\s*\)*$')
      if l:keyword != ""
        break
      endif
    endif
    let l:start -= 1
  endwhile

  " Now that we have the l:keyword, if a:base is empty, then just search and
  " return the "proper thing" (bib entries, \labels, or \include'd) files. If
  " there is a a:base for completion, then filter the results to match that.
  " Note that both bib entries and included files are kept in internal list
  " variables (cf. autoload/tex_seven/omni.vim), and hence must be filtered
  " out here. \label's are searched when needed, and hence we pass a:base to
  " to the function that does that, so that filtering can happen on-the-fly.
  if l:keyword == 'cite'
    if a:base == ""
      return tex_seven#omni#GetBibEntries()
    else
      return filter(copy(tex_seven#omni#GetBibEntries()), 'v:val =~ "\\m^" . a:base')
    endif
  elseif l:keyword == 'includegraphics'
    return tex_seven#omni#GetGraphicsList(a:base)
  elseif l:keyword == 'includeonly'
    if a:base == ""
      return tex_seven#GetIncludedFilesList()
    else
      return filter(copy(tex_seven#GetIncludedFilesList()), 'v:val =~ "\\m^" . a:base')
    endif
  elseif l:keyword =~ '.*ref'
    return tex_seven#omni#GetLabels(a:base)
  else
    return []
  endif
endfunction

function tex_seven#omni#QueryRefKey(refkey, preview)
  let l:mainFile = tex_seven#GetMainFile()

  let l:includedFilesList = []

  let l:currentFileIsMain = 0 " False.
  if l:mainFile == expand('%:p')
    let l:currentFileIsMain = 1 " True.
  endif

  let l:linenum = 0
  for l:line in getline(1, line('$'))
    let l:linenum += 1
    if l:line =~ g:tex_seven#emptyOrCommentLinesPattern
      continue " Skip comments or empty lines.
    endif

    let l:column = match(l:line,  '\m\\label{' . a:refkey . '}')
    if l:column != -1 " -1 means no match.
      " To preview, or not to preview.
      let l:to_p_or_nor_to_p = 'p'
      if a:preview == 0 | let l:to_p_or_nor_to_p = '' | endif

      " echom "l c : " . l:linenum . ' ' . l:column
      execute l:to_p_or_nor_to_p . 'edit +call\ setpos(".",\ [0,\ '
            \ . l:linenum . ',\ ' . l:column . ',\ 0]) ' . expand('%:p')
      execute 'normal zz'
      return
    elseif l:currentFileIsMain == 1 " Current file is s:mainFile.
      let included_file = matchstr(line, g:tex_seven#includedFilePattern)
      if included_file != ""
        call add(l:includedFilesList, included_file)
      endif
    endif
  endfor

  " If reach here if we didn't find the \label we were looking for in the
  " current file. Now, if the loop above did not find \include'd files
  " (len(l:includedFilesList) == 0), that means it either searched for
  " \label's over some file OTHER than s:mainFile, or that it searched
  " s:mainFile, but found no \include statement. In the latter case there is
  " nothing more to do, but in former (i.e., current file is not s:mainFile),
  " we must search over s:mainFile for \include's, and then search these files
  " to see if any of them contain the \label we're after. In the following if
  " statement, we search s:mainFile, if the current file is not it.
  if len(l:includedFilesList) == 0 && l:currentFileIsMain == 0
    for line in readfile(l:mainFile)
      if l:line =~ g:tex_seven#emptyOrCommentLinesPattern
        continue " Skip comments or empty lines.
      endif

      let l:included_file = matchstr(l:line, g:tex_seven#includedFilePattern)
      if l:included_file != ""
        call add(tex_seven#GetIncludedFilesList(), l:included_file)
      endif
    endfor
    call tex_seven#SetEpochMainFileLastReadForIncludes(str2nr(system("date +%s")))
  endif

  if len(l:includedFilesList) > 0
    " Search over \include'd files. But first, update s:includedFilesList.
    call tex_seven#SetIncludedFilesList(l:includedFilesList)

    for l:fname in l:includedFilesList
      let l:fcontents = readfile(tex_seven#GetPath() . l:fname . '.tex')
      let l:linenum = 0
      for l:line in l:fcontents
        let l:linenum += 1
        if l:line =~ g:tex_seven#emptyOrCommentLinesPattern
          continue " Skip comments or empty lines.
        endif

        " This matches once per line; but there is no point in having two
        " \label's in the same line...
        let l:column = match(l:line,  '\m\\label{' . a:refkey . '}')
        if l:column != -1
          " To preview, or not to preview.
          let l:to_p_or_nor_to_p = 'p'
          if a:preview == 0 | let l:to_p_or_nor_to_p = '' | endif

          execute l:to_p_or_nor_to_p . 'edit +call\ setpos(".",\ [0,\ '
                \ . l:linenum . ',\ ' . l:column . ',\ 0]) ' . tex_seven#GetPath() .
                \ l:fname . '.tex'
          execute 'normal zz'
          return
        endif
      endfor
    endfor
  else
    echoerr "Pattern not found"
  endif
endfunction
