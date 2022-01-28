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
"    Copyright Óscar Pereira, 2020-2022
"
"************************************************************************

let s:beginpat = '\m^.*\\begin{\zs\w\+\*\=\ze}'
let s:endpat = '\m^.*\\end{\zs\w\+\*\=\ze}'

let s:envSnippetsDict = {}

let s:joinedEnvironmentsList = ""

let s:snippetCommentLinePattern = '\m^#'

" Matches lines like 'snippet trigger "doc string"', with the doc string
" optional.
let s:snippetDeclarationLinePattern = '\m^snippet \zs\S\+\ze\(\s\|$\)'

let s:snippetEmptyLinePattern = '\m^$'
let s:snippetLinePattern = '\m^\t\zs.*\ze'

" Brief: starting with the given line number, search upwards for a \begin.
" Ignores nested \begin...\end pairs in between.
" Param: startlnum. The line number of where to start searching.
" Return: a tuple [ env name, linenum ], consisting of the environment name
" and the line number of where the \begin was found. If no such \begin was
" found, then returns []. If an error occurred, it is thrown.
"
" Synopsis: for every new line, see if it is an \end. If so, check to see if
" we had encountered a (still) unmatched \end before. In this case, throw
" error. Otherwise take note that we have an unmatched \end. If the line is
" not an \end, check to see if it is a \begin. If so, check for an unmatched
" \end, and if there is one, check if it pairs with the just found \begin. If
" so, then "forget" the unmatched \end, and continue searching. But if we
" found a \begin without an unmatched \end, then must be the \begin we were
" looking for! Otherwise, if the line matches neither \end nor \begin,
" continue searching...
function tex_seven#environments#FindBeginAbove(startlnum)
  let l:endsWithoutBeginList = []

" We start the search at line a:startlnum.
  let l:linenum = a:startlnum
  let l:line = getline(l:linenum)
  let l:envname = ""

  while 1
    let l:envname = matchstr(l:line, s:endpat)
    if l:envname != "" " Found an \end in the current line.
      " Found an \end in the current line. So append it, and continue
      " searching.
      call add(l:endsWithoutBeginList, l:envname)
      " After this line, control should go to line decrementing
      " l:linenum, below.
    else
      " The current line is not an \end, so see if it is a \begin.
      let l:envname = matchstr(l:line, s:beginpat)
      if l:envname != "" " Found a \begin in the current line.
        if len(l:endsWithoutBeginList) > 0
          " We have previous unmatched \end's, so check if the \begin we found
          " matches the last \end on the list. If so, remove that element from
          " the list, and continue searching. Otherwise, issue an error.
          if l:envname == l:endsWithoutBeginList[-1]
            call remove(l:endsWithoutBeginList, -1)
            " After this line, control should go to line incrementing
            " l:linenum, below.
          else
            throw "MismatchedBeginAndEnd"
          endif
        else
          " We found an \begin, and there is no unmatched \end. So this must be
          " the line we are looking for!
          return [ l:envname, l:linenum ]
        endif
      endif
    endif

    " If control reaches here, this means the current line is also not a
    " \begin. So keep searching...
    let l:linenum -= 1
    if l:linenum < 1 " ... unless we've reached beyond the first line.
      return []
    else
      let l:line = getline(l:linenum)
    endif
  endwhile
endfunction

" Brief: starting with the given line number, search downwards for an \end.
" Ignores nested \begin...\end pairs in between.
" Param: startlnum. The line number of where to start searching.
" Return: a tuple [ env name, linenum ], consisting of the environment name
" and the line number of where the \end was found. If no such \end was found,
" then returns []. If an error occurred, it is throw'n.
"
" Synopsis: for every new line, see if it is a \begin. If so, check to see if
" we had encountered a (still) unmatched \begin before. In this case, throw
" error. Otherwise take note that we have an unmatched \begin. If the line is
" not a \begin, check to see if it is an \end. If so, check for an unmatched
" \begin, and if there is one, check if it pairs with the just found \end. If
" so, then "forget" the unmatched \begin, and continue searching. But if we
" found a \end without an unmatched \begin, then must be the \end we were
" looking for! Otherwise, if the line matches neither \begin nor \end,
" continue searching...
function tex_seven#environments#FindEndBelow(startlnum)
  let l:numLines = line('$')
  let l:beginsWithoutEndList = []

" We start the search at line a:startlnum.
  let l:linenum = a:startlnum
  let l:line = getline(l:linenum)
  let l:envname = ""

  while 1
    let l:envname = matchstr(l:line, s:beginpat)
    if l:envname != ""
      " Found a \begin in the current line. So append it, and continue
      " searching.
      call add(l:beginsWithoutEndList, l:envname)
      " After this line, control should go to line incrementing
      " l:linenum, below.
    else
      " The current line is not a \begin, so see if it is a \end.
      let l:envname = matchstr(l:line, s:endpat)
      if l:envname != "" " Found an \end in the current line.
        if len(l:beginsWithoutEndList) > 0
          " We have previous unmatched \begin's, so check if the \end we found
          " matches the last \begin on the list. If so, remove that element
          " from the list, and continue searching. Otherwise, issue an error.
          if l:envname ==# l:beginsWithoutEndList[-1]
            call remove(l:beginsWithoutEndList, -1)
            " After this line, control should go to line incrementing
            " l:linenum, below.
          else
            throw "MismatchedBeginAndEnd"
          endif
        else
          " We found an \end, and there is no unmatched \begin. So this must
          " be the line we are looking for!
          return [ l:envname, l:linenum ]
        endif
      endif
      " If control reaches here, this means the current line is also not a
      " \end. So keep searching...
    endif

    let l:linenum += 1
    if l:linenum > l:numLines " ... unless we've reached beyond the last line.
      return []
    else
      let l:line = getline(l:linenum)
    endif
  endwhile
endfunction

function tex_seven#environments#GetEnvironmentSnippet(envname)
  if len(s:envSnippetsDict) == 0
    try
      call tex_seven#environments#SlurpSnippetFile()
    catch
      echoerr "Caught exception when slurping snippets file."
    endtry
  endif

  if has_key(s:envSnippetsDict, a:envname)
    return s:envSnippetsDict[a:envname]
  else
    return ""
  endif
endfunction

" Brief: Discovers the name, and location (start and ending lines numbers) of
" the current environment, if any.
" Return: a list [ envname, startline num, endline num ] if there is an
" enclosing environment. Returns [] if one such environment cannot be
" found.
"
" Synopsis: if current line is \begin, then search downwards for a
" corresponding \end. If current line is an \end, search upwards for a
" corresponding \begin. Otherwise, search first above for a \begin, and then
" below for an \end, and if they match, return that environment.
"
" Note that this function deals with nested environments (e.g. an
" equation env inside a proof env). Cf. FindBeginAbove() and FindEndBelow().
function tex_seven#environments#Get_LaTeX_environment()
  let l:environment = ""

  let l:beginenv = ""
  let l:endenv = ""

  let l:beginenvline = ""
  let l:endenvline = ""

  let l:cline=getline('.')
  let l:clinenum=line('.')

  let l:beginenv = matchstr(l:cline, s:beginpat)
  if l:beginenv != ""
    " The current line \begin's an environment. So search downwards for said
    " environment's \end.
    let l:beginenvline = l:clinenum

    try
      let [ l:endenv, l:endenvline ] = 
          \ tex_seven#environments#FindEndBelow(l:beginenvline + 1)
    catch
      return []
    endtry

    if l:endenvline == "" || l:endenv != l:beginenv
      " We have a \begin, but no \end..., or a \begin and \end for different
      " environments...
      return []
    endif
    " Otherwise, return [ env name, start line, end line ]
    return [ l:beginenv, l:beginenvline, l:endenvline ]
  else
    " The current line did NOT match a \begin, so let's see if it matches an
    " \end.
    let l:endenv = matchstr(l:cline, s:endpat)
    if l:endenv != ""
      " The current line \end's an environment. So search upwards for said
      " environment's \begin.
      let l:endenvline = l:clinenum

      try
        let [ l:beginenv, l:beginenvline ] =
            \ tex_seven#environments#FindBeginAbove(l:endenvline - 1)
      catch
        return []
      endtry

      if l:beginenvline == "" || l:endenv != l:beginenv
        " We have an \end, but no \begin..., or a \begin and \end for
        " different environments...
        return []
      endif
      " Otherwise, return [ env name, start line, end line ]
      return [ l:beginenv, l:beginenvline, l:endenvline ]
    endif
  endif

  " If control reaches here, that means the current line is neither a \begin
  " nor an \end. So we must search upwards for a \begin, and \downwards for an
  " \end. First, search upwards for \begin.
  try
    let [ l:beginenv, l:beginenvline ] =
        \ tex_seven#environments#FindBeginAbove(l:clinenum - 1)
  catch
    return []
  endtry

  " Now search downwards for an \end.
  try
    let [ l:endenv, l:endenvline ] =
        \ tex_seven#environments#FindEndBelow(l:clinenum + 1)
  catch
    return []
  endtry

  if l:beginenvline == "" || l:endenvline == "" || l:endenv != l:beginenv
    " We have an \end, but no \begin, or  vice-versa, or we have a \begin and
    " \end for different environments...
    return []
  endif
  " Otherwise, return [ env name, start line, end line ].
  return [ l:beginenv, l:beginenvline, l:endenvline ]
endfunction

" Return: empty.
function tex_seven#environments#GoToBeginAbove()
  " We start the search at line the cursor is in.
  let l:linenum = line(".")

  while 1
    if l:linenum == 1
      return
    endif

    let l:prevLineNum = l:linenum - 1
    if match(getline(l:prevLineNum), s:beginpat) != -1
      execute "normal :" . l:prevLineNum . "\<CR>"
      normal 0f\
      return
    endif
    let l:linenum -= 1
  endwhile
endfunction

" Return: empty.
function tex_seven#environments#GoToEndBelow()
  " We start the search at line the cursor is in.
  let l:linenum = line(".")
  let l:lastLineNum = line("$")

  while 1
    if l:linenum == l:lastLineNum
      return
    endif

    let l:nextLineNum = l:linenum + 1
    if match(getline(l:nextLineNum), s:endpat) != -1
      execute "normal :" . l:nextLineNum . "\<CR>"
      normal 0f\
      return
    endif
    let l:linenum += 1
  endwhile
endfunction

" XXX deal with expandtab/retab of snippet lines...
function tex_seven#environments#InsertEnvironment()
  let l:env = input('Environment: ', '', 'custom,ListEnvCompletions')

  " If environment name is empty, then there is nothing more to do...
  if l:env == ""
    return ""
  endif

  let l:envLinesList = tex_seven#environments#GetEnvironmentSnippet(l:env)

  let l:snipNumLines = len(l:envLinesList)
  if l:snipNumLines == 0
    " By default, return a simple begin/end skeleton.
    let l:envLinesList = [ "\\begin{" . l:env . "}", "\\end{" . l:env . "}" ]
  endif

  let l:envString = join(l:envLinesList, "\n")

  if &expandtab " Expand tabs to spaces if 'expandtab' is set.
    let l:envString = substitute(l:envString, '\t',
          \ repeat(' ', &softtabstop ? &softtabstop : &shiftwidth), 'g')
  endif

  let l:envLinesList = split(l:envString, '\n', 1)

  let l:col = charcol(".")
  let l:line = getline(".") " Current line.
  let l:currLineNum = line(".") " Current line number.

  " charcol() starts at 1, but slice() takes array indexes, which start at 0.
  " Hence we use l:col - 1.
  let l:before = slice(l:line, 0, l:col - 1)
  let l:after = slice(l:line, l:col - 1)

  call setline(".", l:before . l:envLinesList[0])

  let l:numOfLastSnipLine = l:currLineNum + len(l:envLinesList) - 1

  let l:indent = matchend(l:line, '^.\{-}\ze\(\S\|$\)')
  call append(l:currLineNum,
        \ map(l:envLinesList[1:], "'".strpart(l:line, 0, l:indent)."'.v:val"))
  call setline(l:numOfLastSnipLine,
        \ getline(l:numOfLastSnipLine) . l:after)

  " Call :retab over the newly inserted lines, and then place the cursor at
  " the end of the last inserted line.
  if l:snipNumLines == 0
    return "\<Esc>:" . l:numOfLastSnipLine . "\<CR>O"
  else
    return "\<Esc>:" . l:numOfLastSnipLine . "\<CR>$"
  endif
endfunction

" Brief: Returns 1 (true) if current line is inside a math environment, and 0
" (false) otherwise.
function tex_seven#environments#Is_LaTeX_math_environment()
  let l:mathenvpat = '\mmatrix\|cases\|math\|equation\|align\|array'
  let l:ce = tex_seven#environments#Get_LaTeX_environment() " Get the name of current LaTeX env.
  if len(l:ce) == 3
    let [ l:curr_environment, l:startline, l:endline ] = l:ce

    if match(l:curr_environment, l:mathenvpat) != -1 " -1 means no match.
      return 1 " We are inside math environment.
    endif
  endif

  " Otherwise, if we are not inside a math env, we can either be inside
  " another, non-math, env, or can be inside of no environment at all... In
  " either case, we return false (0).
  return 0
endfunction

" See :h command-completion-custom.
function! ListEnvCompletions(ArgLead, CmdLine, CursorPos)
  if s:joinedEnvironmentsList != ""
    return s:joinedEnvironmentsList
  endif

  if filereadable(b:env_list)
    let s:joinedEnvironmentsList =
          \ join(tex_seven#GetLinesListFromFile(b:env_list), "\<nl>")
    return s:joinedEnvironmentsList
  else
    return ""
  endif
endfunction

function tex_seven#environments#RenameEnvironment()
  let l:getEnv = tex_seven#environments#Get_LaTeX_environment()
  if len(l:getEnv) != 3 || l:getEnv[0] == 'document'
    " There is no surrounding environment, and hence there is nothing to do
    " (other than warning the user).
    echohl WarningMsg | echo  "No surrounding environment found!" | echohl None
    return
  endif

  let [ l:origEnvName, l:origEnvStartLineNum, l:origEnvEndLineNum ] = l:getEnv

  " Ask the user for the new environment name.
  let l:newEnvName = input('Rename env ['. l:origEnvName .'] to: ', '',
        \ 'custom,ListEnvCompletions')

  " If new environment name is empty, then there is nothing more to do...
  if l:newEnvName == ""
    return
  endif

  " The new environments' names may contain an asterisk; we need to escape it,
  " for otherwise the calls to substitute() will not work.
  let l:origEnvName = escape(l:origEnvName, "*")
  let l:newEnvName = escape(l:newEnvName, "*")

  " Substitute the environment name in the \begin line.
  let l:line = getline(l:origEnvStartLineNum)
  let l:newBeginLine = substitute(l:line, '\\begin{'. l:origEnvName .'}',
        \ '\\begin{'. l:newEnvName .'}', "")

  " Substitute the environment name in the \end line.
  let l:line = getline(l:origEnvEndLineNum)
  let l:newEndLine = substitute(l:line, '\\end{'. l:origEnvName .'}',
        \ '\\end{'. l:newEnvName .'}', "")

  " Actually replace those lines in the file.
  call setline(l:origEnvStartLineNum, l:newBeginLine)
  call setline(l:origEnvEndLineNum, l:newEndLine)
endfunction

function tex_seven#environments#SlurpSnippetFile()
  let l:currentSnippetKey = ""
  let l:snippetLinesList = []

  for line in tex_seven#GetLinesListFromFile(b:env_snippets)
    if line =~ s:snippetEmptyLinePattern
      throw "EmptyLineOnSnippetFile"
    elseif line =~ s:snippetCommentLinePattern
      continue " Skip comments.
    endif

    let l:aux = matchstr(line, s:snippetDeclarationLinePattern)
    if l:aux != ""
      " We found a "snippet trigger" line. So first, check to see if we have
      " found that trigger before. If so, throw up error, has multiple snips
      " are not supported.
      if has_key(s:envSnippetsDict, l:aux) == v:true
        throw "DuplicateSnippetKeyFound"
        return
      endif

      " Next, if we had previously found a trigger, then the new trigger marks
      " the end of the previous trigger's expansion.
      if l:currentSnippetKey != ""
        if len(l:snippetLinesList) > 0
          let s:envSnippetsDict[l:currentSnippetKey] = l:snippetLinesList
        else
          " Control reaches when there is a previous trigger, but no expansion
          " for it. Hence, throw error.
          throw "FoundTriggerWithoutExpansion"
        endif
      endif

      " Finally, as we have found a new trigger, the array (List) where we
      " collect the expansion line(s) is reset to empty.
      let l:snippetLinesList = []
      " And the current snippet key takes the value of trigger we found with
      " the matchstr() above.
      let l:currentSnippetKey = l:aux
    else
      " We didn't find a line like "^snippet trigger ...", so look for other
      " possibilities...

      let l:aux = matchstrpos(line, s:snippetLinePattern)
      if ! (l:aux[1] == -1 && l:aux[2] == -1)
        " We found a line that starts with a <Tab>; i.e., it is part of the
        " expansion of a snippet. So add it to the list of expansion lines,
        " and continue onto to the next line.
        call add(l:snippetLinesList, l:aux[0])
        continue
      else
        " We found a line that is not a comment, is not a "snippet trigger"
        " line, and does not start with a <Tab>. So throw error.
        throw "InvalidLineFound"
      endif
    endif
  endfor

  " When we reach the end of the .snippet file, check if there is any pending
  " trigger with body. If so, add them to the g:snipper#snippets dictionary.
  if l:currentSnippetKey != ""
    if len(l:snippetLinesList) > 0
      let s:envSnippetsDict[l:currentSnippetKey] = l:snippetLinesList
    else
      " Control reaches when there is a previous trigger, but no expansion
      " for it. Hence, throw error.
      throw "FoundTriggerWithoutExpansion"
    endif
  endif
endfunction
