" LaTeX filetype plugin
" Languages:    Vimscript
" Author:       Óscar Pereira
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

" Matches lines like:
" \bibliography{bibfilename} or \addbibresources{bibfilename}
" in .tex files. When used with matchstr(), it returns bibfilename.
let g:tex_seven#bibtexSourcesFilePattern = '\m^\s*\\\(bibliography\|addbibresources\){\zs\S\+\ze}'

" Self-explanatory.
let g:tex_seven#emptyOrCommentLinesPattern = '\m^\s*\(%\|$\)'

" Matches lines like:
" \include{chapter1}
" in .tex files. When used with matchstr(), it returns chapter1.
let g:tex_seven#includedFilePattern = '\m^\\include{\zs\S\+\ze}'

let g:tex_seven#labelCommandPattern = '\m\\label{\zs\S\+\ze}'

" Matches \somecmd{foo} or \somecmd[bar]{foo}. When used with matchstr(),
" returns "somecmd", sans quotes.
let g:tex_seven#matchCommand = '\m^\\\zs[A-Za-z0-9]\+\ze\(\[.\+\]\)\?{'

" Same as g:tex_seven#matchCommand regexp above, but matches the "foo" part,
" sans quotes.
let g:tex_seven#matchCommandArg = '\m\\[A-Za-z0-9]\+\(\[.\+\]\)\?{\zs\S\+\ze}'

" Matches a modeline like:
" % mainfile: ../main.tex
let g:tex_seven#modelinePattern = '\m^\s*%\s*mainfile:\s*\zs\S\+\ze'

" Last timestamp (UNIX epoch) of when s:includedFilesList was updated.
let s:epochMainFileLastReadForIncludes = ""

" List of files \include'd in the main .tex file.
let s:includedFilesList = []

" The full path of the main .tex file (the one that contains a \documentclass
" line).
let s:mainFile = ""

" Variables used to back up the mappings overwritten by
" tex_seven#InsertCommand().
let s:mappings_are_saved_b = v:false
let s:mappings_i = []
let s:mappings_s = []
let s:mappings_v = []

let s:old_default_register = ""
let s:old_default_register_type = ""

" This variable is set when s:mainFile is set. Is is the full path of
" s:mainFile.tex, without the name. I.e., if the full path of s:mainFile is
" /path/to/LaTeX/project/mainfile.tex then s:path is /path/to/LaTeX/project/.
let s:path = ""

" Source (.bib) file for bibliographic entries.
let s:sourcesFile = ""

" Brief: Basically, whenever the user edits a .tex file, try do discover if
" there exists a main .tex file.
"
" Here, if we do NOT find a main file, we just continue, for it is possible
" that the main file does not exist yet.
function tex_seven#AddBuffer()
  if s:mainFile == ""
    call tex_seven#DiscoverMainFile()
  endif
endfunction

" Brief: Used in visual mode, to change the selected text to bold, italic,
" etc. See ftplugin/tex_seven.vim.
function tex_seven#ChangeFontStyle(style)
  let str = 'di'
  let is_math = tex_seven#environments#Is_LaTeX_math_environment()
  let str .= is_math ? '\math'.a:style : '\text'.a:style
  let str .= "{}\<Left>\<C-R>\""
  return str
endfunction

function tex_seven#CheckViewerImages()
  if has_key(g:tex_seven_config, 'viewer_images')
    return v:true
  endif
  return v:false
endfunction

function tex_seven#CheckViewerPDF()
  " XXX check that the value is a valid program...
  if has_key(g:tex_seven_config, 'viewer')
    return v:true
  endif
  return v:false
endfunction

" Brief: Set s:mainFile, the file which contains a line beginning with:
" \documentclass. Also sets s:path.
" Return: none.
"
" Synopsis: First, look for the modeline, in the first three lines of the
" current file, and then on the last three lines of the same file. It should
" tell us the location of the main file, relative to the current file. It
" should be near the top of the file, and it is usually something like:
" % mainfile: ../main.tex
"
" If no modeline can be found, assume that the current file IS the main file,
" and iterate over its lines to confirm. If a \\documentclass line is found,
" set s:mainFile to the full path of the current file, and also look for a
" bibliography file, if any (since we already iterating over the main file's
" lines...).
function tex_seven#DiscoverMainFile()
  " If we already know the main file, no need to searching for it... (it is
  " very unlikely to change, after all).
  if s:mainFile != ""
    return
  endif

  let l:lines = [1, 2, 3, line('$') - 2, line('$') - 1, line('$')]
  for lnum in lines
    let l:line = getline(lnum)
    let l:mainfile = matchstr(line, g:tex_seven#modelinePattern)
    if l:mainfile != ""
      " We found the main file. As it is a relative path (e.g.,
      " "../main.tex"), we concatenate the full path (minus filename) of the
      " current file with that relative path, and then use the fnamemodify()
      " function to get the full path of the main file. For example, suppose
      " the full path of the current file is:
      " /home/user/latexProj/chapters/introduction.tex
      " If the modeline of that file is "../main.tex", then concatenation
      " yields:
      " /home/user/latexProj/chapters/../main.tex
      " The fnamemodify() function turns this into:
      " /home/user/latexProj/main.tex
      " Which is the correct main file, according to the modeline.
      let s:mainFile = fnamemodify(expand('%:p:h') . '/' . l:mainfile, ':p')
      let s:path = fnamemodify(s:mainFile, ':p:h') . '/'
      " call tex_seven#omni#SetupFilesLabelsDict({})
      return
    endif
  endfor

  " Control reaches this point if no modeline has been found, neither in the
  " first three lines, nor in the last three lines. So iterate over the entire
  " file, to see if we are the main file or not.

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
  endif

  " If control reaches here, then we have not found the main .tex file. This
  " might not be a mistake, if the user has just begun writing his LaTeX
  " document.
endfunction

" For visual selection operators of inner or outer (current) environment. See
" ftplugin/tex_seven.vim.
function tex_seven#EnvironmentOperator(mode)
  let l:pos = tex_seven#environments#Get_LaTeX_environment()
  if len(l:pos) == 0
    return "\<Esc>"
  endif
  if a:mode == 'inner'
    let l:pos[1] += 1
    let l:pos[2] -= 1
  endif
  if l:pos[2] < l:pos[1]
    echoerr "Env start position cannot be bigger than end position."
  elseif l:pos[2] == l:pos[1]
    return "\<Esc>:".l:pos[1]."\<Enter>V"
  else
    return "\<Esc>:".l:pos[1]."\<Enter>V".(l:pos[2]-l:pos[1])."j"
endfunction

" Brief: Parse the main file, and return the list of \include'd files. Note
" that what is returned is what would go into a \include{} command, and not
" the full paths of those files -- for this, see
" tex_seven#GetIncludedFilesListProperFNames().
"
" Return: A list containing \include'd files, filtered to match to a:base, if
" provided (this is used by omni-completion).
" Throw: MainFileIsNotReadable, if the main file could not be read.
function tex_seven#GetIncludedFilesList(base = '')
  call tex_seven#GetMainFile()

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

    try
      for line in tex_seven#GetLinesListFromFile(s:mainFile)
        if line =~ g:tex_seven#emptyOrCommentLinesPattern
          continue " Skip comments or empty lines.
        endif
        let included_file = matchstr(line, g:tex_seven#includedFilePattern)
        if included_file != ""
          call add(s:includedFilesList, included_file)
        endif
      endfor
    catch /^FileIsNotReadable$/
      throw "MainFileIsNotReadable"
    endtry
    let s:epochMainFileLastReadForIncludes = str2nr(system("date +%s"))
  endif

  if a:base == ''
    return s:includedFilesList
  else
    return filter(copy(s:includedFilesList), 'v:val =~? "\\m" . a:base')
  endif
endfunction

" Brief: Calls tex_seven#GetIncludedFilesList(), and returns a copy of
" s:includedFilesList, but containing the full paths of those \include'd
" files.
function tex_seven#GetIncludedFilesListProperFNames()
  let l:path = tex_seven#GetPath()
  let l:fnamesList = tex_seven#GetIncludedFilesList()
  return map(copy(l:fnamesList), "l:path . v:val . '.tex'")
endfunction

" Brief: Allow external scripts to retrieve that value of
" s:epochMainFileLastReadForIncludes.
function tex_seven#GetEpochMainFileLastReadForIncludes()
  return s:epochMainFileLastReadForIncludes
endfunction

function tex_seven#GetLinesListFromFile(fname)
  " readfile() shows an error message when the file cannot be read.
  " Surrounding it with a try/catch turns that error message into an
  " exception.
  try
    return readfile(a:fname)
  catch
    " XXX put a debug message here
    throw "FileIsNotReadable"
  endtry
endfunction

" Brief: This function basically calls tex_seven#DiscoverMainFile(), but
" throws an exception if the main .tex file is not set, and cannot be found.
" One purpose is for this function to be called at places where control should
" reach *only after* the main .tex file has been set. The other purpose is to
" allow external scripts to retrieve that value of s:mainFile.
function tex_seven#GetMainFile()
  call tex_seven#DiscoverMainFile()
  if s:mainFile == ""
    throw "MainFileIsNotSet"
  endif
  return s:mainFile
endfunction

" Brief: Allow external scripts to retrieve that value of s:path.
function tex_seven#GetPath()
  call tex_seven#GetMainFile()
  return s:path
endfunction

" Brief: Allow external scripts to retrieve that value of s:sourcesFile.
function tex_seven#GetSourcesFile()
  if s:sourcesFile == ""
    call tex_seven#SetSourcesFile()
  endif
  return s:sourcesFile
endfunction

" This function is called when, in a .bib file, the user presses 'gm' (sans
" quotes, normal mode. Cf. ftplugin/bib_seven.vim). If s:mainFile is not set,
" then warn the user that there the mainfile could not be found.
function tex_seven#GoToMainFileIfSet()
  try
    call tex_seven#GetMainFile()
    if s:mainFile != ""
      execute "edit " . s:mainFile
    endif
  catch /^MainFileIsNotSet$/
    echoerr "Cannot return to main file, as it is not set!"
  endtry
endfunction

""""" INSERT COMMAND MACRO """""

" This first function inserts:
" \cmd{arg}
" selects the "cmd" word, and lets the user change it to whatever he wants (by
" visually selecting the "cmd" string, and then entering select-mode with ^G).
" It also temporarily maps the Tab key to the function InsertCommandGotoArg(),
" so that the user can press it and move to the argument part.
"   (The Esc and Ctrl-c keymaps are explained further below; cf. the comment
" block after the function tex_seven#InsertCommandUnmapTab()).
function tex_seven#InsertCommand()
  " Save previous mappings only once (this allows nested cmd insertion to
  " work).
  if s:mappings_are_saved_b == v:false
    let s:mappings_i = tex_seven#SaveBufferMappings(['<Tab>', '<Esc>', '<C-c>'], 'i')
    let s:mappings_s = tex_seven#SaveBufferMappings(['<BS>', '<Esc>', '<C-c>'], 's')
    let s:mappings_v = tex_seven#SaveBufferMappings(['p', 'P'], 'v')
    let s:mappings_are_saved_b = v:true
  endif

  " Either the name of command, or its argument, might come from something the
  " user has yanked. So save it (otherwise it is overwritten when the user
  " replaces the text in select-mode).
  let s:old_default_register = getreg("\"")
  let s:old_default_register_type = getregtype("\"")

  " This <BS> map is here because if the user, having a visually selected
  " placeholder (select mode), hits backspace, the placeholder text is
  " deleted, *but the user is left in normal mode*. To fix this, I map the
  " backspace to actually delete the previous char, and then go to insert
  " mode.
  snoremap <buffer> <BS> <BS>i

  " Visual mode only! (vnoremap works for both select and visual mode.)
  xnoremap <buffer> p pa
  xnoremap <buffer> P Pa

  inoremap <buffer><expr> <Esc> tex_seven#InsertCommandUnmapTab()
  snoremap <buffer><expr> <Esc> tex_seven#InsertCommandUnmapTab()

  inoremap <buffer><expr> <C-c> tex_seven#InsertCommandUnmapTab()
  snoremap <buffer><expr> <C-c> tex_seven#InsertCommandUnmapTab()

  inoremap <buffer><expr> <Tab> tex_seven#InsertCommandGoToArg()
  return "\\cmd{arg}\<Esc>Fcviw"
endfunction

" Here, the user has inserted the command name (see above comment), thus now
" we move him to the arg part, which we leave selected, so that the user only
" has to type the argument. And map the Tab key so that, once the user has
" finished typing up said argument, he can press Tab to exit the finished
" command; see below comment.
function tex_seven#InsertCommandGoToArg()

  " We get here when the visually selected "cmd", in "\cmd{arg}", has been
  " replaced with some other text, by the user. So the contents of the "
  " register now contain "cmd". The following line restores its old contents
  " (text yanked by the user), if any.
  call setreg("\"", s:old_default_register, s:old_default_register_type)

  " See tex_seven#InsertCommandExitArg() for the use of these two s:
  " variables. charcol(".") is the column of the '{' in \foo{bar}. So in this
  " example, it would be 4.
  let s:startCol = charcol(".")
  let s:startLine = line(".")

  inoremap <buffer><expr> <Tab> tex_seven#InsertCommandExitArg()
  return "\<Esc>f{lviw"
endfunction

" Here the user has finished inserting both the command name, and its
" argument. So if the finished command is, e.g., \somecmd{somearg}, pressing
" Tab will now move him to the right of the '}', so that he can continue to
" type his LaTeX document. And since we are finished, also unmap our
" buffer-local mappings of the Tab key, inter alia (see next function).
"   However, after inserting the argument, the user might take the cursor
" elsewhere and continue typing. (I often do the following: use the
" <Tab>-jumps to type \foo{bar|}, and then use a map for <Right> to take the
" cursor after the '}', and continue writing.) In this scenario, if the user
" presses <Tab>, we must return an actual <Tab> character. To ensure that this
" <Tab> character will trigger any custom user maps, we use the feedkeys()
" function.
function tex_seven#InsertCommandExitArg()
  " First, unmap <Tab> etc., because it is no longer needed.
  call tex_seven#InsertCommandUnmapTab()

  let l:lineNum = line(".")
  let l:ret = ""

  if l:lineNum != s:startLine
    " If we are on a different line from that in which the command was
    " inserted, then assume we are no longer in command insertion mode...
    let l:ret = "\<Tab>"
  else
    " The next two lines obtain the substring "arg}" in "\cmd{arg}" (sans
    " quotes). Recall that slice() takes index (0-based) positions, while
    " column numbers start at 1. So even though s:startCol has the column
    " position of '{', the return string starts at the next char ('a'). The
    " same goes for charcol("."), which returns the col position  of '}'. In
    " slice(), the end pos is *not* included. Thus, as an index, charcol(".")
    " is the position to the right of '}', and hence the return string ends at
    " that '}'. Assuming, of course, that the user pressed <Tab> after typing
    " the argument to the command...
    let l:col = charcol(".")
    let l:line = slice(getline("."), s:startCol, l:col)

    if l:line[-1:-1] == '}'
      " If the last character of the slice'd subline ends with a '}', then
      " user hit <Tab> after typing the command argument. So just place the
      " cursor after the '}' that closes the command.
      let l:ret = "\<Esc>la"
    else
      " Otherwise, return (i.e., simulate that the user pressed; cf. below) a
      " <Tab> character.
      let l:ret = "\<Tab>"
    endif
  endif

  " Clear the position variables.
  let s:startCol = ""
  let s:startLine = ""

  " The feedkeys() simulates that the user actually pressed the keys in l:ret.
  " This way, any maps associated with them are triggered.
  call feedkeys(l:ret)
  return ""
endfunction

" Here we restore -- or unmap, if they didn't previously exist -- the saved
" mappings that were overwritten above (function tex_seven#InsertCommand()).
function tex_seven#InsertCommandUnmapTab()
  call tex_seven#RestoreBufferMappings(s:mappings_i)
  call tex_seven#RestoreBufferMappings(s:mappings_s)
  call tex_seven#RestoreBufferMappings(s:mappings_v)

  " Also restore whatever the user had yanked, before starting the insertion
  " of the current command, if anything.
  call setreg("\"", s:old_default_register, s:old_default_register_type)

  let s:mappings_i = []
  let s:mappings_s = []
  let s:mappings_v = []
  let s:mappings_are_saved_b = v:false

  return "\<Esc>"
endfunction

" <Esc> and <C-c> mappings:
"   As for the <Esc> mapping, it may so happen that the command insertion is
" interrupted before the InsertCommandExitArg() function is called. This would
" have the side effect of leaving the Tab key mapped either to
" InsertCommandGotoArg(), or to InsertCommandExitArg(). To avoid this, the
" first thing done in the InsertCommand() function, is to locally map the Esc
" key to this function, InsertCommandUnmaptab(), that clears any local
" mappings of the Tab key. It also clears the local Esc map, because after
" clearing the Tab map, it is no longer necessary.
"   The above considerations for the Esc key mapping, apply verbatim to the
" Ctrl-c mapping.

""""" END INSERT COMMAND MACRO """""

" Used for completion of sub and super scripts. See ftplugin/tex_seven.vim.
function tex_seven#IsLeft(lchar)
  let left = getline('.')[col('.')-2]
  return left == a:lchar ? 1 : 0
endfunction

function tex_seven#InsertBibEntry()
  let s:env = input('Bib entry type: ', '', 'custom,ListBibTypesCompletions')
  if s:env == "url"
		let l:res = "@misc{bibkey,\n" .
          \ "title  = \"XXX\",\n" .
          \ "author = \"XXX\",\n" .
          \ "note   = \"\url{XXX} (last accessed: XXX)\",\n" .
          \ "year   = \"XXX\"\n" .
          \ "}\<Esc>%lviw"
  else
		let l:res = "@generic{bibkey,\n" .
          \ "title     = \"XXX\",\n" .
          \ "author    = \"XXX\",\n" .
          \ "address   = \"XXX\",\n" .
          \ "edition   = \"XXX\",\n" .
          \ "isbn      = \"XXX\",\n" .
          \ "note      = \"\url{XXX} (last accessed: XXX)\",\n" .
          \ "number    = \"XXX\",\n" .
          \ "origdate  = \"XXX\",\n" .
          \ "publisher = \"XXX\",\n" .
          \ "volume    = \"XXX\",\n" .
          \ "year      = \"XXX\"\n" .
          \ "}\<Esc>%hviw"
  endif
  return l:res
endfunction

" See :h command-completion-custom.
function! ListBibTypesCompletions(ArgLead, CmdLine, CursorPos)
  return "generic\<nl>url"
endfunction

" Brief: For completion of math symbols, arrows, etc.
" Parameters: a:findstart and a:base, see :help complete-functions.
function tex_seven#MathCompletion(findstart, base)
  if g:tex_seven_config.debug | echom "find start: |" . a:findstart . "|" | endif
  if g:tex_seven_config.debug | echom "base: |" . a:base . "|" | endif

  if a:findstart
    " According to :help complete-functions, if the above if-clause matched,
    " then a:findstart = 1. Thus, we have to find the pre-existing text (if
    " any) to be used as a basis for completion. We start by obtaining the
    " current line.
    let line = getline('.')

    " Then, place on the l:start variable the (0-based) index of the cursor's
    " current position.
    let l:start = col('.') - 1

    " Then, we go back (i.e., left-wise), until we find one of the characters
    " that (in principle) show the start of the completion the user entered.
    " We do this by checking if the character to the left of the current
    " cursor position, which sits at index l:start - 1, is any of those. If
    " not, we decrement l:start, and continue searching.
    "   If, on the other hand, we find any of those terminating characters, or
    " we reach the start of the line, then we break out of the loop.
    while l:start > 0
          \ && line[l:start - 1] != '\'
          \ && line[l:start - 1] != ' '
          \ && line[l:start - 1] != '$'
          \ && line[l:start - 1] != '{'
      " if line[start] == '\' | echom "oops" | endif
      " if line[start] == '\' | return -2 | endif
      let l:start -= 1
    endwhile

    " At this point, l:start contains the index of the first character of the
    " completion basis, if there is one. If there is not one, then l:start
    " continues with the index (0-based) of the cursor position. And it is
    " this value that we return -- except for a small caveat, discussed next.

    " If the character preceeding the fist character of the completion basis,
    " is a backslash ('\'), then we decrement l:start once more, because ALL
    " of the completion results INCLUDE the starting backslash (cf.
    " autoload/tex_seven/omniMath.vim).
    if line[l:start - 1] == '\' | let l:start -= 1 | endif

    return l:start
  else
    " The above else-clause matches when a:findstart = 0 (cf. :help
    " complete-functions). Hence, we need to find and return the completion
    " hypothesis that match a:base, if it is nonempty. (If a:base is empty,
    " then we just return ALL possible completion hypothesis.)
    if a:base != ""
      if a:base == '\' | return g:tex_seven#omniMath#symbols | endif

      " Filter completion. Check that a:base (what the user has typed) matches
      " either the word (i.e. the math command, like \setminus, or whatever),
      " or, check if a:base mathches the info entry, if it exists.
      let compl = copy(g:tex_seven#omniMath#symbols)
      call filter(compl, 'v:val.word =~? "\\m' . a:base .
            \ '" || (has_key(v:val, "info") && v:val.info =~? "\\m' . a:base . '")')
      return compl
    else
      " a:base is empty, so just return all possible completion hypothesis.
      return g:tex_seven#omniMath#symbols
    endif
  endif
  
  " Control should never reach here, but anyway, if it does, return an empty
  " list.
  return []
endfunction

" For completion of \ref's, \cite's, etc. Run ":help complete-functions" to
" understand how this function is invoked.
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
" - \includeonly{filename}.
" - \includegraphics{filename.(jpg|pdf|png)}.
"
" For each case, it invokes functions that do, respectively, the following:
" - open the bib source file, at the line corresponding to key, e.g.
"   "@book{key,". The case when there is more than key is dealt with like
"   follows: use the first one, unless the cursor is placed on top of any of
"   the other bibliographic keys. If the cursor is on top a comma or a space
"   (e.g. \cite:{a, b}), use the key immediately before. comments below.
" - open the .tex file containing \label{key}.
" - open filename.tex.
" - idem.
" - open filename.(jpg|pdf|png).
" Param: preview. Boolean (0 or 1). (Used only with .tex files.) If true,
" shows the target file in a preview (:pedit) window. Otherwise, uses :edit.
" Return: none.
function tex_seven#QueryKey(preview)
  " First, check that the current buffer is saved. If not, warn the user to
  " save it. This is needed, because otherwise some of functions invoked below
  " will throw an error. [bufname() returns the :ls number of the current
  " buffer.]
  if getbufvar(bufname(), "&modified") == v:true
    echohl WarningMsg | echo  "Please save the file before using gd|gf|gp."
    return
  endif

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
  " file). If there was no match, then we again go backwards, till the previous
  " backslash. If there was a match, we test to see if "command" is one of the
  " commands mentioned above in this function's documentation. If not, return
  " an error. If there was a match, then we set l:keyword to "command", and
  " break the while loop, and proceed to extract the keyword that command's
  " argument.
  "
  " We start by obtaining the entire line where the expression like \ref{key}
  " or whatever shows up.
  let l:line = getline('.')

  " If we reach 100 iterations before finding the start of \command[foo]{bar},
  " then assume there is no such string on the current line. I.e., give up.
  let l:count = 0
  while l:count < 100
    let l:count += 1

    if l:line[col('.') - 1] == '\' " Test if char in current cursor pos is '\'
      let l:startBackslashIdx = col('.') - 1
      let l:res = matchstr(l:line[ l:startBackslashIdx : ], g:tex_seven#matchCommand)
      if res == ""
        normal F\
        continue
      elseif l:res !~ '\m\(eq\)\?ref' &&
            \ l:res !~ '\m\(no\)\?cite.\?' &&
            \ l:res !~ '\m\(bibliography\|addbibresources\)\?' &&
            \ l:res !~ '\minclude\(graphics\|only\)\?' && l:res !~ '\minput'
        echoerr "Pattern not found: " . l:res . "."
        return
      else
        " l:keyword will be ref, or eqref, or cite, or nocite, or include, or
        " includeonly, orinput, or includegraphics.
        let l:keyword = l:res
        break
      endif
    else
      normal F\
      continue
    endif
  endwhile

  " l:count == 100 is true, that means the command was not found. So revert
  " the cursor to its original position, and we are done.
  if l:count == 100
    call setpos(".", [0, line("."), l:cursorColumn + 1, 0, l:cursorColumn + 1])
    return
  endif

  " Ok, so we now have the "command" part in \command[whatever]{else}, stored
  " in the variable l:keyword. The \ref \eqref and \include(only)? cases are
  " easy: just select the "else" part, and call the relevant function (see
  " autoload/tex_seven/omni.vim). The \includegraphics is a bit more
  " complicated, but not terribly so. The \cite and \nocite are the tricky
  " ones.
  " (Note 1: The getreg() function returns the text that was last
  " yanked.)
  " (Note 2: We have to reset the cursor's position in the current buffer
  " inside each case. It cannot be done before this if/else, because for
  " keywords other than \cite or \nocite, we still need to move the cursor.
  " And it cannot be done after this if/else block, because we will already
  " have left the current buffer...)
  if l:keyword == 'input' || l:keyword == 'include' || l:keyword == 'includeonly'
    let inckey = matchstr(l:line[ l:startBackslashIdx : ], g:tex_seven#matchCommandArg)
    if inckey == "" | throw "EmptyTeXCommandArg" | endif

    " Before opening a new window, set the cursor in the current window, to
    " its original position.
    call setpos(".", [0, line("."), l:cursorColumn + 1, 0])

    call tex_seven#omni#QueryIncKey(inckey, a:preview)
  elseif l:keyword == 'bibliography' || l:keyword == 'addbibresources'
    let bibkey = matchstr(l:line[ l:startBackslashIdx : ], g:tex_seven#bibtexSourcesFilePattern)
    if bibkey == "" | throw "EmptyTeXCommandArg" | endif

    " Before opening a new window, set the cursor in the current window, to
    " its original position.
    call setpos(".", [0, line("."), l:cursorColumn + 1, 0])

    call tex_seven#omni#QueryBibFile(bibkey, a:preview)
  elseif l:keyword == 'includegraphics'
    " Important: this only functions if in the .tex, the argument of
    " \includegraphics includes the extension! E.g. \includegraphics{fname.ext}

    let l:graphicFilename =
          \ matchstr(l:line[ l:startBackslashIdx : ], g:tex_seven#matchCommandArg)
    if l:graphicFilename == "" | throw "EmptyTeXCommandArg" | endif

    let l:viewer = ''
    let l:extension = matchstr(l:graphicFilename, '\m\.\zs\S\S\S$')
    if l:extension == ''
      echoerr "No extension found for image file " . l:graphicFilename
      return
    elseif l:extension =~? 'pdf' " Match ignoring case.
      if tex_seven#CheckViewerPDF() == v:true
        let l:viewer = g:tex_seven_config.viewer
      else
        echoerr "Cannot view document, as there is no PDF viewer set!"
        return
      endif
    elseif l:extension =~? '\(jpg\|png\)' " Match ignoring case.
      if tex_seven#CheckViewerImages() == v:true
        let l:viewer = g:tex_seven_config.viewer_images
      else
        echoerr "Cannot view image, as there is no JPG/PNG viewer set!"
        return
      endif
    else
      echoerr "Unknown extension: " . l:extension . "."
      return
    endif

    " Reset cursor to its original position.
    call setpos(".", [0, line("."), l:cursorColumn + 1, 0])

    echo "TeX-7: Viewing the image file...\r"
    call system(l:viewer . " " . shellescape(l:graphicFilename) . " &")
  elseif l:keyword =~ '.*ref'
    let refkey = matchstr(l:line[ l:startBackslashIdx : ], g:tex_seven#matchCommandArg)
    if refkey == "" | throw "EmptyTeXCommandArg" | endif

    " Before opening a new window, set the cursor in the current window, to
    " its original position.
    call setpos(".", [0, line("."), l:cursorColumn + 1, 0])

    call tex_seven#omni#QueryRefKey(refkey, a:preview)
  elseif l:keyword =~ '.*cite'
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

" Brief: Restore the previously saved value (if any) of the mappings that were
" overwritten by the tex_seven#InsertCommand() function.
"
" Adapted from:
" https://vi.stackexchange.com/questions/7734/how-to-save-and-restore-a-mapping
function tex_seven#RestoreBufferMappings(mappings) abort
  for l:mapping in a:mappings
    if !has_key(l:mapping, 'unmapped')
      call mapset(l:mapping.mode, 0, l:mapping)
    else " has_key(mapping, 'unmapped') == true
      silent! execute l:mapping.mode.'unmap '
            \ .(l:mapping.buffer ? ' <buffer> ' : '')
            \ . l:mapping.lhs
    endif
  endfor
endfunction

" Brief: Temporarily save the previous value (if any) of the mappings that are
" overwritten by the tex_seven#InsertCommand() function.
"
" Adapted from:
" https://vi.stackexchange.com/questions/7734/how-to-save-and-restore-a-mapping
function tex_seven#SaveBufferMappings(keys, mode) abort
  let l:mappings = []

  for l:key in a:keys
    let l:map_info = maparg(l:key, a:mode, 0, 1)

    " If maparg() returns not empty, but it is not a local map (i.e., it is a
    " global map; map_info.buffer == 0), it still means that the no local map
    " for the given exists. So treat it like empty. (The local mappings shadow
    " the global ones.)
    if empty(l:map_info) == v:true || map_info.buffer == 0
      call add(l:mappings, {
            \ 'unmapped' : 1,
            \ 'buffer'   : 1,
            \ 'lhs'      : l:key,
            \ 'mode'     : a:mode,
            \ })
      continue
    endif

    " Otherwise, add the Dict returned by maparg().
    call add(l:mappings, l:map_info)
  endfor

  return l:mappings
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
" Return: none.
function tex_seven#SetSourcesFile()
  if s:sourcesFile != ""
    return
  endif

  call tex_seven#GetMainFile()

  " Since we are reading the main file, we also update the \include'd file
  " list.
  let s:includedFilesList = []

  for line in tex_seven#GetLinesListFromFile(s:mainFile)
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
endfunction

" Brief: Receive a keyword -- e.g., '\includeonly{' -- and start
" omni-completion. That is, add the closing '}', place the cursor inside the
" curly brackets, and show menu with completion options.
function tex_seven#SmartInsert(keyword)
  if a:keyword == '\includeonly{' && expand('%:p') != tex_seven#GetMainFile()
    echohl WarningMsg |
          \ call input("\\includeonly can only be used in main file! (Hit <Enter to continue>)")
  endif
  return a:keyword."}\<Esc>i"
endfunction

" Brief: First, replace ''. with .'' (for dots, commas, colons, and question
" and exclamation marks). Then replace '. with .' (idem). Works even when the
" punctuation mark ends the line. Because some say this looks neater...
function tex_seven#SwapQuotesPunctuation()
  let l:winsave = winsaveview()
  %s/''\(\.\|,\|:\|?\|!\)\(\s\|$\)/\1''\2/ge

  %s/'\(\.\|,\|:\|?\|!\)\(\s\|$\)/\1'\2/ge
  call winrestview(l:winsave)
endfunction

" Brief: Open PDF viewer and show the PDF document corresponding to the
" current LaTeX project. Caughs up an error if there is no PDF viewer set.
function tex_seven#ViewDocument()
  try
    call tex_seven#GetMainFile()
  catch /^MainFileIsNotSet$/
    echoerr "Cannot view document, as there is no mainfile set!"
    return
  endtry

  if tex_seven#CheckViewerPDF() == v:true
    let l:viewer = g:tex_seven_config.viewer
  else
    echoerr "Cannot view document, as there is no PDF viewer set!"
    return
  endif

  echo "Viewing the document...\r"
  call system(g:tex_seven_config.viewer . " " . shellescape(s:mainFile[:-4] . "pdf") . " &")
endfunction
