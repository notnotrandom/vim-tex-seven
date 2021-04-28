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

let s:beginpat = '\m^\s*\\begin{\zs\w\+\ze}'
let s:endpat = '\m^\s*\\end{\zs\w\+\ze}'
let s:joinedEnvironmentsList = ""

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
  echom l:numLines

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

function tex_seven#environments#InsertEnvironment()
  let l:env = input('Environment: ', '', 'custom,ListEnvCompletions')
  return "\\begin{" . l:env . "}\n\\end{" . l:env . "}\<Esc>O"
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
  if len(l:getEnv) != 3
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
