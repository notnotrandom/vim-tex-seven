" LaTeX filetype plugin
" Languages:    LaTeX
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

" Set to 1 when starting compilation. Set back to 0 on the callback function
" of the compilation job.
let s:compilationIsRunning = 0

" Run `./CompileTeX.sh` on background. Obviously, ignore include files...
" NOTA BENE: if a main TeX file exists, the CompileTeX script is expected to
" exist in the same directory.
"
function! tex_seven#build#BuildOnWrite()
	" Check pre-conditions to build file
	" let l:tex_build_pid = trim(system("./CompileTeX.sh get_compiler_pid")) " TODO handle case of more than 1 pid returned

  " If file is in includes/ dir, then skip build.
	let l:filedirectory = expand("%:p:h")
	if l:filedirectory =~ 'includes$'
    echohl WarningMsg | echo "File is in includes/ dir, so skipping build!" | echohl None
		return
	endif

  " If there is another LaTeX process running, then skip build.
	if s:compilationIsRunning == 1
    echohl WarningMsg | echo "LaTeX compilation already running! Not interrupting!" | echohl None
    " echom "Process ID: " . l:tex_build_pid
		return
	endif

	" Get path of main TeX file, if it exists.
	" To do so, check if exists "mainfile" modline, like so:
	" % mainfile: ../thesis.tex
	let l:mainfile = ""
	let l:head = getline(1, 3)
	for line in l:head
		if line =~ '^%\s\+mainfile:\s\+\(\S\+\.tex\)'
			let l:mainfile = matchstr(line, '\(\S\+\.tex\)')
			break
		endif
	endfor

	" Initially, set path of Makefile to path of current file
	let l:makefile_path = expand("%:p:h")
	" Then, append *relative* path of main TeX file, which if exists, is where
	" Makefile must be
	if mainfile !~ '^$' 
		let l:makefile_path .= "/" . fnamemodify(l:mainfile, ":h") 
	endif

	" cd to dir that has Makefile, run CompileTeX.sh, and cd back
	if !filereadable(l:makefile_path . "/CompileTeX.sh") | return | endif
	execute 'lcd' fnameescape(l:makefile_path)
  let job = job_start(["/bin/bash", "CompileTeX.sh"],
        \ {'close_cb': 'CloseHandler' ,
        \  'exit_cb': 'ExitHandler' })
  let s:compilationIsRunning = 1
	lcd -
endfunction

" This is needed because without this, the exit callback, ExitHandler, always
" returns immediately, and with an exit code of -1...
function CloseHandler(channel)
  return
endfunc

function ExitHandler(job, exitStatus)
  let s:compilationIsRunning = 0
  if a:exitStatus != 0
    echohl WarningMsg | echo  "LaTeX compilation FAILED!" | echohl None
  endif
endfunc
