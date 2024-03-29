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
"    Copyright Óscar Pereira, 2020-2023
"
"************************************************************************

let s:bibEntryList = []

" Matches lines like:
" @book{Shoup:2009,
" in BiBTeX source files. When used with matchstr(), it returns "Shoup:2009",
" sans quotes.
let s:bibtexEntryKeyPattern = '\m^@\a\+{\zs\S\+\ze,'

" The keys are proper filenames (i.e. that exist to the OS). For each key, its
" value is another dict, like so: { 'last_read_epoch' => '', 'labels' => [] }.
let s:fileLabelsDict = {}

let s:epochSourceFileLastRead = ""

let s:labelList = []

" Perl script that is used to initially parse (in the background) the main
" file, as well as any \include'd files, for \label's.
let s:labelScriptPath = fnameescape(expand('<sfile>:h') . "/../../scripts/labels.pl")

" Brief: Callback on closure of the Perl script execution process. Basically
" read its output from the communication channel, until there is no more data,
" and then send that data to tex_seven#omni#SetupFilesLabelsDict().
"
" Return: None.
function HandleText(channel) abort
  let l:text = ""
  while ch_status(a:channel, {'part': 'out'}) == 'buffered'
    let l:text .= ch_read(a:channel)
  endwhile
  call tex_seven#omni#SetupFilesLabelsDict(l:text)
endfunction

" Brief:
" Throws: SourcesFileNotReadable
function tex_seven#omni#GetBibEntries()
  let l:needToReadSourcesFile = "false"
  let l:sourcesFile = tex_seven#GetSourcesFile()

  if s:epochSourceFileLastRead == ""
    " We have not previously read s:sourcesFile. If s:sourcesFile is empty,
    " that means no bibliography file was found (and hence, could have been
    " read before). So just return an empty list of bib entries...
    if l:sourcesFile == ""
      throw "BibSourceFileNotFound"
    endif

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

    for line in tex_seven#GetLinesListFromFile(l:sourcesFile)
      let entry_key = matchstr(line, s:bibtexEntryKeyPattern)
      if entry_key != ""
        call add(s:bibEntryList, entry_key)
      endif
    endfor
  endif
  return s:bibEntryList
endfunction

" Brief: Omni-completion for \includegraphics{base}, where the base is
" optional.
" Returns: a list of .jpg, .pdf, or .png files, recursively searched under
" s:path.
function tex_seven#omni#GetGraphicsList(base = '')
  let l:path = tex_seven#GetPath()

  " Find files. The -printf is to use relative paths. It also removes the
  " starting './' of the path of found files (that what the -printf string is
  " for). The -path -prune thingy skips files inside anydirectory which name
  " contains the string "build".
  let l:graphicFiles = system("find " . fnameescape(l:path) . " -type f " .
        \ "-path \\*build\\*/\\* -prune -o " .
        \ "-iname \\*.jpg -printf \"%P\n\" -o " .
        \ "-iname \\*.pdf -printf \"%P\n\" -o " .
        \ "-iname \\*.png -printf \"%P\n\" " )

  if a:base == ''
    return split(l:graphicFiles, "\n")
  else
    return filter(split(l:graphicFiles, "\n"), 'v:val =~? "\\m" . a:base')
  endif
endfunction

function tex_seven#omni#GetLabels()
  " The user requested \labels, so first of all, check if there are any new
  " ones.
  let l:needToRegenerateLabelList = tex_seven#omni#UpdateFilesLabelsDict()

  " If the list of labels for the user has not been generated yet, then we
  " must do so, regardless of what tex_seven#omni#UpdateFilesLabelsDict()
  " says.
  if s:labelList == []
    let l:needToRegenerateLabelList = "true"
  endif

  if l:needToRegenerateLabelList ==# "true"
    let s:labelList = []
    for value in values(s:fileLabelsDict)
      let s:labelList = s:labelList + value['labels']
    endfor
    call sort(s:labelList) " Sort in-place.
  endif
  return s:labelList
endfunction

function tex_seven#omni#GetLabelsNoScript(base = '')
  let l:mainFile = tex_seven#GetMainFile()

  let l:labelsFound = []

  " Since we need to read s:mainFile anayway, also check (and update) the \include's.
  let l:includedFilesList = []

  for line in tex_seven#GetLinesListFromFile(l:mainFile)
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
      if a:base == '' || newlabel =~? '\m' . a:base
        call add(l:labelsFound, newlabel)
      endif
    endif
  endfor
  call tex_seven#SetEpochMainFileLastReadForIncludes(str2nr(system("date +%s")))
  call tex_seven#SetIncludedFilesList(l:includedFilesList)

  " Now search the included files.
  for l:fname in tex_seven#GetIncludedFilesList()
    let l:fcontents =
          \ tex_seven#GetLinesListFromFile(tex_seven#GetPath() . l:fname . '.tex')
    for l:line in l:fcontents
      let newlabel = matchstr(l:line,  '\m\\label{\zs\S\+\ze}')
      if newlabel != ""
        if a:base == '' || newlabel =~? '\m' . a:base
          call add(l:labelsFound, newlabel)
        endif
      endif
    endfor
  endfor

  return sort(l:labelsFound) " Sort in-place.
endfunction

function tex_seven#omni#GetTeXFilesList(base = '')
  let l:path = tex_seven#GetPath()

  " Find files. The -printf is to use relative paths. It also removes the
  " starting './' of the path of found files (that what the -printf string is
  " for). The -path -prune thingy skips files inside any directory which name
  " contains the string "build". The sed command removes the .tex extension.
  " This is because \include{filename} *requires* no extension be given. For
  " \input{} it doesn't matter but no extension also works.
  let l:texFiles = system("find " . fnameescape(l:path) . " -type f " .
        \ "-path \\*build\\*/\\* -prune -o -iname \\*.tex " .
        \ "-printf \"%P\n\" | sed 's/\.tex$//'" )

  if a:base == ''
    return split(l:texFiles, "\n")
  else
    return filter(split(l:texFiles, "\n"), 'v:val =~? "\\m" . a:base')
  endif
endfunction

" Brief: Say you have \cite{foo}, with the cursor on '}', when the user
" triggers completion (i.e., hits  ^X^O). This function retrieves all the
" bibliographic keys, and returns a completion list with only the keys that
" contain the string "foo".
"   This function is not limited to \cite, of course: \ref, \include, etc also
"   work.
"
" (Also remember col() starts at 1, but lists (arrays) start at zero!)
function tex_seven#omni#OmniCompletions(base)

 " First, determine the keyword (i.e., cite, ref, or whatever...)
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
  " return the "proper thing" (bib entries, \labels, or \include'd files). If
  " there is a a:base for completion, then filter the results to match that.
  " Note that both bib entries and included files and \label's are kept in
  " internal list variables, and hence must be filtered out here.
  if l:keyword == 'cite'
    try
      if a:base == ""
        return tex_seven#omni#GetBibEntries()
      else
        return filter(copy(tex_seven#omni#GetBibEntries()), 'v:val =~? "\\m" . a:base')
      endif
    catch /^BibSourceFileNotFound$/
      echoerr "Bib source file not found..."
    catch
      echoerr "Retrieving bib entries failed."
    endtry
  elseif l:keyword == 'includegraphics'
    try
      return tex_seven#omni#GetGraphicsList(a:base)
    catch
      echoerr "Retrieving \\includegraphics' list failed."
    endtry
  elseif l:keyword == 'include' || l:keyword == 'input'
    try
      return tex_seven#omni#GetTeXFilesList(a:base)
    catch
      echoerr "Retrieving .tex files list failed."
    endtry
  elseif l:keyword == 'includeonly'
    try
      return tex_seven#GetIncludedFilesList(a:base)
    catch
      echoerr "Retrieving \\include'd files' list failed."
    endtry
  elseif l:keyword =~ '.*ref' || l:keyword == 'label'
    try
      if has_key(g:tex_seven_config, 'label_retrieval_use_script')
            \ && g:tex_seven_config['label_retrieval_use_script'] == 1

        if a:base == ""
          return tex_seven#omni#GetLabels()
        else
          return filter(copy(tex_seven#omni#GetLabels()), 'v:val =~? "\\m" . a:base')
        endif
      else
        " Not using external script for \label retrieval.
        return tex_seven#omni#GetLabelsNoScript(a:base)
      endif
    catch
      echoerr "Retrieving \\labels failed."
    endtry
  else
    return []
  endif

  return [] " Just in case one of the conditions above fails without returning anything...
endfunction

function tex_seven#omni#QueryBibFile(bibkey, preview)
  " To preview, or not to preview.
  let l:to_p_or_not_to_p = 'p'
  if a:preview == 0 | let l:to_p_or_not_to_p = '' | endif

  if a:bibkey =~ '\m\.\w\+$'
    " If the argument filename has an extension, don't appened one. This is
    " the case with \addbibresources{}.
    execute l:to_p_or_not_to_p . 'edit ' . a:bibkey
  else
    " If the argument filename does not have an extension, then appened
    " '.bib'. This is the case with \bibliography{}.
    execute l:to_p_or_not_to_p . 'edit ' . a:bibkey . '.bib'
  endif

  if a:preview == 1 | execute 'normal! p' | endif
endfunction

function tex_seven#omni#QueryBibKey(citekey, preview)
  let l:sourcesFile = tex_seven#GetSourcesFile()
  if l:sourcesFile == ""
    throw "BibSourceFileNotFound"
  endif

  " To preview, or not to preview.
  let l:to_p_or_not_to_p = 'p'
  if a:preview == 0 | let l:to_p_or_not_to_p = '' | endif

  " :edit or :pedit the bib sources file, and search for a:citekey.
  execute l:to_p_or_not_to_p . 'edit +/' . a:citekey . ' ' . l:sourcesFile
  " The redraw command is needed to avoid a "Press here to continue" message
  " from being shown...
  redraw
  " Center the line the cursor is at in the older (original) buffer.
  execute 'normal! zz'
  " If opening a preview window, then move the cursor there (^Wp). It will be
  " placed on the line containing a:citekey; the zt positions the window so
  " that that line is shown near the top of the preview window.
  if a:preview == 1 | execute 'normal! pzt' | endif
endfunction

function tex_seven#omni#QueryIncKey(inckey, preview)
  " To preview, or not to preview.
  let l:to_p_or_not_to_p = 'p'
  if a:preview == 0 | let l:to_p_or_not_to_p = '' | endif

  execute l:to_p_or_not_to_p . 'edit ' . tex_seven#GetPath()
        \ . '/' . a:inckey . '.tex'
  if a:preview == 1 | execute 'normal! p' | endif
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
      " So if control reaches here, this means that we have a match.

      " To preview, or not to preview.
      let l:to_p_or_not_to_p = 'p'
      if a:preview == 0 | let l:to_p_or_not_to_p = '' | endif

      " Do an :edit, or a :pedit (preview window edit), setting the viewing
      " position to that of the matched text.
      execute l:to_p_or_not_to_p . 'edit +call\ setpos(".",\ [0,\ '
            \ . l:linenum . ',\ ' . l:column . ',\ 0]) ' . expand('%:p')
      " In the old (original) window, also vertically center the line where
      " the cursor is placed.
      execute 'normal! zz'
      " And if we are opening a preview window, move the cursor to that
      " window, to the position of the match, and also vertically center that
      " line.
      if a:preview == 1 | execute 'normal! pzz' | endif
      return
    elseif l:currentFileIsMain == 1 " Current file is s:mainFile.
      " Control reaches here if there was no match, but we are in the main
      " file -- in which case, we search for \include'd files (see below why).
      let included_file = matchstr(line, g:tex_seven#includedFilePattern)
      if included_file != ""
        call add(l:includedFilesList, included_file)
      endif
    endif
  endfor

  " Control reaches here if we didn't find the \label we were looking for in
  " the current file. Now, if the loop above did not find \include'd files
  " (len(l:includedFilesList) == 0), that means it either searched for
  " \label's over some file OTHER than s:mainFile, or that it searched
  " s:mainFile, but found no \include statement. In the latter case there is
  " nothing more to do, but in former (i.e., current file is not s:mainFile),
  " we must search over s:mainFile for \include's, and then search these files
  " to see if any of them contain the \label we're after. In the following if
  " statement, we search s:mainFile, if the current file is not it.
  if len(l:includedFilesList) == 0 && l:currentFileIsMain == 0
    for line in tex_seven#GetLinesListFromFile(l:mainFile)
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
      let l:fcontents =
            \ tex_seven#GetLinesListFromFile(tex_seven#GetPath() . l:fname . '.tex')
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
          " If we have match, then we show it (:edit or :pedit) to the user.
          " The code below, until the return statement, is similar what has
          " been used above; see the comments therein.
          let l:to_p_or_not_to_p = 'p'
          if a:preview == 0 | let l:to_p_or_not_to_p = '' | endif

          execute l:to_p_or_not_to_p . 'edit +call\ setpos(".",\ [0,\ '
                \ . l:linenum . ',\ ' . l:column . ',\ 0]) ' . tex_seven#GetPath() .
                \ l:fname . '.tex'
          execute 'normal! zz'
          if a:preview == 1 | execute 'normal! pzz' | endif
          return
        endif
      endfor
    endfor
  else
    echoerr "Label " . a:refkey . " not found."
  endif
endfunction

" Brief: Runs the Perl script (in the background) to retrieve the \label's in
" the main file, and in \include'd files, if any. Those \label's are returned
" in a JSON structure equal to that of s:fileLabelsDict. See the documentation
" of the closure callback, HandleText(), for more information.
"
" Return: None.
function tex_seven#omni#RetrieveAllLabels()
  let l:mainFile = ""

  " If there is no main file, e.g. if we are reading a .cls style file, then
  " finding \label's makes no sense...
  try
    let l:mainFile = tex_seven#GetMainFile()
  catch /^MainFileIsNotSet$/
    return
  endtry

  let l:inc_files_list = []
  try
    let l:inc_files_list = tex_seven#GetIncludedFilesListProperFNames()
  catch /^MainFileIsNotReadable$/
    echoerr "Main file could not be read (could a modeline be wrong?)."
    return
  catch
    echoerr "Could not retrieve list of \include'd files."
    return
  endtry

  let l:job_list = [ "/usr/bin/perl", s:labelScriptPath ] + [ l:mainFile ]
        \ + l:inc_files_list

  let l:job = job_start(l:job_list, { 'close_cb': 'HandleText' })
endfunction

" Brief: Receive in JSON format the dict containing the \label's retrieved by
" the Perl script, decode it, and store it in s:fileLabelsDict.
"
" Return: None.
function tex_seven#omni#SetupFilesLabelsDict(dict_json)
  let l:decoded_json = ""
  try
    let l:decoded_json = json_decode(a:dict_json)
  catch
  endtry

  if type(l:decoded_json) != v:t_dict
    echohl WarningMsg |
          \ echo "JSON did not decode correctly (check output of external script)."
          \ | echohl None
    return
  endif

  let s:fileLabelsDict = deepcopy(l:decoded_json)
endfunction

" Brief: Updates (or fills, if empty), the file information in
" s:fileLabelsDict. Tacitly assumes that the keys in that Dict still
" correspond to the \include'd files.
" Return: "true" if there dirty files found. "false" otherwise.
function tex_seven#omni#UpdateFilesLabelsDict()
  let l:dirtFound = "false"

  for fname in keys(s:fileLabelsDict)
    " See if file is dirty.
    let l:dirty = "false"

    if s:fileLabelsDict[fname]['last_read_epoch'] == ''
      " File is new, so we have to read it (i.e., it is 'dirty').
      let l:dirty = "true"
    else
      let l:epochFileLastModified = str2nr(system("stat --format %Y " . fname))
      if l:epochFileLastModified > s:fileLabelsDict[fname]['last_read_epoch']
        let l:dirty = "true"
      endif
    endif

    " Now, if it turned out that the file was indeed dirty, re-read its
    " \label's again.
    if l:dirty ==# "true"
      if l:dirtFound ==# "false" | let l:dirtFound = "true" | endif

      let s:fileLabelsDict[fname]['labels'] = []

      for line in tex_seven#GetLinesListFromFile(fname)
        if line =~ g:tex_seven#emptyOrCommentLinesPattern
          continue " Skip comments or empty lines.
        endif

        let newlabel = matchstr(line, g:tex_seven#labelCommandPattern)
        if newlabel != ""
          call add(s:fileLabelsDict[fname]['labels'], newlabel)
        endif
      endfor " line in tex_seven#GetLinesListFromFile(fname)

      " Update the timestamp of when the current file was last read (i.e. just now).
      let s:fileLabelsDict[fname]['last_read_epoch'] = str2nr(system("date +%s"))
    endif " if l:dirty ==# "true"
  endfor " fname in keys(s:fileLabelsDict)

  return l:dirtFound
endfunction

" Brief: This function is nmapped (by default to the <F5> key) in
" ftplugin/tex_seven.vim. Its purpose is for the user to call it, after
" changing the list of \include'd files.
"
" The rationale is as follows: when running
" tex_seven#omni#RetrieveAllLabels(), the list of \include'd files is
" refreshed, and then the search for \label's is done both on the main file,
" and on \include'd files, if any. But the list of \include'd files does not
" change very often. So when looking for \label's during omni-completion, for
" efficiency's sake, we just assume that that list remain the same (cf.
" tex_seven#omni#UpdateFilesLabelsDict(), which is called from
" tex_seven#omni#GetLabels()). The purpose of this function is for the user,
" after changing the list of \include'd files, to be able to force an update
" of the list of \include'd files, and then to go find \label's in them. The
" simplest way of achieving the latter task, is simply to call
" tex_seven#omni#RetrieveAllLabels(), in which the retrieval process runs in
" the background, to search everything (main file plus \include'd) for \label
" commands.
"
function tex_seven#omni#UpdateIncludedFilesList()
  let s:fileLabelsDict = {}
  let s:labelList = []

  " This will call tex_seven#GetIncludedFilesListProperFNames(), which will
  " re-read s:mainFile if necessary, obtain a new list of \include'd files,
  " and (re-)setup s:fileLabelsDict.
  call tex_seven#omni#RetrieveAllLabels()

  " The advantage of having this separate function for the user to call --
  " instead of, for instance, mapping tex_seven#omni#RetrieveAllLabels() to
  " <F5> -- is that we can show a message afterwords, but show no message when
  " that is called initially (cf. ftplugin/tex_seven.vim).
  echo "TeX-7: \include'd file list refreshed."
endfunction
