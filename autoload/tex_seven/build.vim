" LaTeX filetype plugin
" Languages:    LaTeX
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
"    Copyright Óscar Pereira, 2020-2023
"
"************************************************************************

" Set to 1 when starting compilation. Set back to 0 on the callback function
" of the compilation job.
let s:compilationIsRunning = 0

let s:compiler_cmd = []
let s:compiler_cmd_double = []

function tex_seven#build#CheckCompilerIsSet()
  " If there is already a compiler set, then do nothing more.
  if s:compiler_cmd != []
    return
  endif

  " Otherwise, check settings to see if there is a compiler defined. If so,
  " also check for compiler options.
  if has_key(g:tex_seven_config, 'compiler_cmd')
        \ && g:tex_seven_config.compiler_cmd != []
    let s:compiler_cmd = g:tex_seven_config.compiler_cmd
    if has_key(g:tex_seven_config, 'compiler_cmd_double')
        \ && g:tex_seven_config.compiler_cmd_double != []
      let s:compiler_cmd_double = g:tex_seven_config.compiler_cmd_double
    endif
  else
    throw "CompilerNotDefined"
  endif
endfunction

" Brief: Build the TeX project in background.
function tex_seven#build#WriteAndBuild(double_build = 0)
  write
  try
    call tex_seven#build#CheckCompilerIsSet()
  catch /^CompilerNotDefined$/
    echoerr "Cannot compile document, as there is no compiler set!"
    return
  endtry

  " If there is another LaTeX process running, then skip build.
	if s:compilationIsRunning == 1
    echohl WarningMsg | echo "LaTeX compilation already running! Not interrupting!" | echohl None
		return
	endif

  let l:mainFile = tex_seven#GetMainFile()

  " Change to directory that contains the main .tex file, attempt to build the
  " project (background), and cd back (just ot be sure).
	execute 'lcd' tex_seven#GetPath()

  if a:double_build == 0
    let job = job_start(s:compiler_cmd,
          \ {'close_cb': 'CloseHandler' , 'exit_cb': 'ExitHandler' })
    let s:compilationIsRunning = 1
    lcd -
  else " Double build.
    if s:compiler_cmd_double != []
      " There is a command for double compilation.
      let job = job_start(s:compiler_cmd_double,
            \ {'close_cb': 'CloseHandler' , 'exit_cb': 'ExitHandler' })
      let s:compilationIsRunning = 1
      lcd -
    else " There is no command for double compilation, so do two single compiles.
      let job = job_start(s:compiler_cmd,
            \ {'close_cb': 'CloseHandler' , 'exit_cb': 'ExitHandler' })
      let s:compilationIsRunning = 1

      " Wait for the previous job to finish...
      let job_status = job_status(job)
      while job_status == "run"
        sleep 100m
        let job_status = job_status(job)
      endwhile

      " Previous job finished, so now do second compile.
      let job = job_start(s:compiler_cmd,
            \ {'close_cb': 'CloseHandler' , 'exit_cb': 'ExitHandler' })
      let s:compilationIsRunning = 1
      lcd -
    endif
  endif
endfunction

" This is needed because without this, the exit callback, ExitHandler, always
" returns immediately, and with an exit code of -1...
function CloseHandler(channel)
  return
endfunction

function ExitHandler(job, exitStatus)
  let s:compilationIsRunning = 0
  if a:exitStatus != 0
    echohl WarningMsg | echo  "LaTeX compilation FAILED!" | echohl None
  endif
endfunction
