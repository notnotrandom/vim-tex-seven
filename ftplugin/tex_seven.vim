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

" Let the user have the last word
if exists('g:tex_seven_config') && has_key(g:tex_seven_config, 'disable')
  if g:tex_seven_config.disable
    redraw
    echomsg("TeX-7: Disabled by user.")
    finish
  endif
endif

" Load Vimscript only once per buffer
if exists('b:init_tex_seven')
  finish
endif
let b:init_tex_seven = 1

" ************************ Common Settings ************************
" Defaults
let b:tex_seven_config = {
      \    'debug'            : 0,
      \    'diamond_tex'      : 1,
      \    'disable'          : 0,
      \    'environment_list' : '',
      \    'leader'           : '',
      \    'verbose'          : 0,
      \    'viewer'           : 'xdg-open' ,
      \    'viewer_images'    : 'xdg-open' ,
      \}

" Override values with user preferences.
if exists('g:tex_seven_config')
  call extend(b:tex_seven_config, g:tex_seven_config)
endif

" Configure the leader. First, save the previous <LocalLeader>, if any.
if exists('g:maplocalleader')
  let s:maplocalleader_saved = g:maplocalleader
endif
" Then, if the user specified a <LocalLeader>, use that. If not, use ':' as
" <LocalLeader>.
if b:tex_seven_config.leader != ''
  let g:maplocalleader = b:tex_seven_config.leader
else
  let g:maplocalleader = ':'
endif

" Save the value of g:maplocalleader that will used by TeX-7. This allows,
" e.g., ~/.vim/after/ scripts to remap maps that use <LocalLeader>. See this
" plugin's documention for further details.
let b:tex_seven_leader = g:maplocalleader

if b:tex_seven_config.environment_list == ''
  let b:env_list = fnameescape(expand('<sfile>:h') . '/environments.txt')
else
  let b:env_list = fnameescape(expand(b:tex_seven_config.environment_list))
endif

" Completion.
setlocal completeopt=longest,menuone
setlocal fo=tcq
setlocal omnifunc=tex_seven#OmniCompletion
setlocal completefunc=tex_seven#MathCompletion
" *****************************************************************

call tex_seven#AddBuffer()

""" Mappings

" Normal mode mappings.
nnoremap <buffer><silent> <LocalLeader>B :call tex_seven#environments#GoToBeginAbove()<CR>
nnoremap <buffer><silent> <LocalLeader>E :call tex_seven#environments#GoToEndBelow()<CR>
nnoremap <buffer><silent> <LocalLeader>V :call tex_seven#ViewDocument()<CR>

nnoremap <buffer><silent> gm :execute "edit " . tex_seven#GetMainFile()<CR>

" Go from \ref to \label, or from \cite bib entry. If argument is true (1),
" use preview window; if false (0), use normal window (i.e. :edit).
" gb in normal mode closes the preview window, if it is opened.
nnoremap <buffer><silent> gp :call tex_seven#QueryKey(1)<CR>
nnoremap <buffer><silent> gb :pclose<CR>
nnoremap <buffer><silent> gd :call tex_seven#QueryKey(0)<CR>

" Visual mode and operator mappings.

" Robust inner/outer environment operators.
vmap <buffer><expr> ae tex_seven#EnvironmentOperator('outer')
omap <buffer><silent> ae :normal vae<CR>
vmap <buffer><expr> ie tex_seven#EnvironmentOperator('inner')
omap <buffer><silent> ie :normal vie<CR>

" As these are visual mode mappings, they interfere with other usages of
" visual mode, notoriously the snippets plugin. Using <Leader> hopefully
" minimises the problem...
vmap <buffer><expr> <Leader>bf tex_seven#ChangeFontStyle('bf')
vmap <buffer><expr> <Leader>it tex_seven#ChangeFontStyle('it')
vmap <buffer><expr> <Leader>rm tex_seven#ChangeFontStyle('rm')
vmap <buffer><expr> <Leader>sf tex_seven#ChangeFontStyle('sf')
vmap <buffer><expr> <Leader>tt tex_seven#ChangeFontStyle('tt')
vmap <buffer>       <Leader>up di\text{}<Left><C-R>"

" Insert mode mappings.

inoremap <buffer> <LocalLeader><LocalLeader> <LocalLeader>
inoremap <buffer> <LocalLeader>" ``''<Left><Left>
inoremap <buffer> <LocalLeader>' `'<Left><Left>

inoremap <buffer><expr> <LocalLeader><Space> tex_seven#InsertCommand()
inoremap <buffer><expr> <LocalLeader>A tex_seven#SmartInsert('\includeonly{')
inoremap <buffer><expr> <LocalLeader>B tex_seven#environments#InsertEnv()
inoremap <buffer><expr> <LocalLeader>C tex_seven#SmartInsert('\cite{')
inoremap <buffer><expr> <LocalLeader>E tex_seven#SmartInsert('\eqref{')
inoremap <buffer> <LocalLeader>K 

" Start mathmode completion.
inoremap <buffer> <LocalLeader>M 

inoremap <buffer><expr> <LocalLeader>R tex_seven#SmartInsert('\ref{')
inoremap <buffer><expr> <LocalLeader>Z tex_seven#SmartInsert('\includegraphics{')

" Greek.
inoremap <buffer> <LocalLeader>a \alpha
inoremap <buffer> <LocalLeader>b \beta
inoremap <buffer> <LocalLeader>c \chi
inoremap <buffer> <LocalLeader>d \delta
inoremap <buffer> <LocalLeader>e \epsilon
inoremap <buffer> <LocalLeader>f \phi
inoremap <buffer> <LocalLeader>g \gamma
inoremap <buffer> <LocalLeader>h \eta
inoremap <buffer> <LocalLeader>i \iota
inoremap <buffer> <LocalLeader>k \kappa
inoremap <buffer> <LocalLeader>l \lambda
inoremap <buffer> <LocalLeader>m \mu
inoremap <buffer> <LocalLeader>n \nu
inoremap <buffer> <LocalLeader>o \omega
inoremap <buffer> <LocalLeader>p \pi
inoremap <buffer> <LocalLeader>q \theta
inoremap <buffer> <LocalLeader>r \rho
inoremap <buffer> <LocalLeader>s \sigma
inoremap <buffer> <LocalLeader>t \tau
inoremap <buffer> <LocalLeader>u \upsilon
inoremap <buffer> <LocalLeader>w \varpi
inoremap <buffer> <LocalLeader>x \xi
inoremap <buffer> <LocalLeader>y \psi
inoremap <buffer> <LocalLeader>z \zeta
inoremap <buffer> <LocalLeader>D \Delta
inoremap <buffer> <LocalLeader>F \Phi
inoremap <buffer> <LocalLeader>G \Gamma
inoremap <buffer> <LocalLeader>L \Lambda
inoremap <buffer> <LocalLeader>O \Omega
inoremap <buffer> <LocalLeader>P \Pi
inoremap <buffer> <LocalLeader>Q \Theta
inoremap <buffer> <LocalLeader>U \Upsilon
inoremap <buffer> <LocalLeader>X \Xi
inoremap <buffer> <LocalLeader>Y \Psi
inoremap <buffer> <LocalLeader>_e \varepsilon
inoremap <buffer> <LocalLeader>_q \vartheta
inoremap <buffer> <LocalLeader>_r \varrho
inoremap <buffer> <LocalLeader>_s \varsigma
inoremap <buffer> <LocalLeader>_f \varphi

" Math.
inoremap <buffer> <LocalLeader>\ \setminus
inoremap <buffer> <LocalLeader>½ \sqrt{}<Left>
inoremap <buffer> <LocalLeader>N \nabla
inoremap <buffer> <LocalLeader>S \sum_{}^{}<Esc>2F{a
inoremap <buffer> <LocalLeader>_S \prod_{}^{}<Esc>2F{a
inoremap <buffer> <LocalLeader>V \vec{}<Left>
inoremap <buffer> <LocalLeader>I \int\limits_{}^{}<Esc>2F{a
inoremap <buffer> <LocalLeader>0 \emptyset
inoremap <buffer> <LocalLeader>_0 \varnothing
inoremap <buffer> <LocalLeader>6 \partial
inoremap <buffer> <LocalLeader>Q \infty
inoremap <buffer> <LocalLeader>/ \frac{}{}<Esc>2F{a
inoremap <buffer> <LocalLeader>\| \lor
inoremap <buffer> <LocalLeader>& \land
inoremap <buffer> <LocalLeader>\|\| \bigvee
inoremap <buffer> <LocalLeader>&& \bigwedge
inoremap <buffer> <LocalLeader>@ \circ
inoremap <buffer> <LocalLeader>* \not
inoremap <buffer> <LocalLeader>! \neq
inoremap <buffer> <LocalLeader>~ \neg
inoremap <buffer> <LocalLeader>= \equiv
inoremap <buffer> <LocalLeader>- \cap
inoremap <buffer> <LocalLeader>+ \cup
inoremap <buffer> <LocalLeader>-- \bigcap
inoremap <buffer> <LocalLeader>-+ \bigcup
if exists('g:tex_seven_config')
      \ && has_key(g:tex_seven_config, 'diamond_tex')
      \ && g:tex_seven_config['diamond_tex'] == 0
  inoremap <buffer> <LocalLeader>< \leq
  inoremap <buffer> <LocalLeader>> \geq
else
  inoremap <buffer> <LocalLeader>> <><Left>
  " <LocalLeader>< is mapped as an enlarged delimiter, below.
endif
inoremap <buffer> <LocalLeader>~ \widetilde{}<Left>
inoremap <buffer> <LocalLeader>^ \widehat{}<Left>
inoremap <buffer> <LocalLeader>_ \overline{}<Left>
inoremap <buffer> <LocalLeader>. \cdot<Space>
inoremap <buffer> <LocalLeader><CR> \nonumber\\<CR>

" For angle brackets.
inoremap <buffer> <LocalLeader>« \langle
inoremap <buffer> <LocalLeader>» \rangle

" Enlarged delimiters.
inoremap <buffer> <LocalLeader>( \left(  \right)<Esc>F(la
inoremap <buffer> <LocalLeader>[ \left[  \right]<Esc>F[la
inoremap <buffer> <LocalLeader>{ \left\{  \right\}<Esc>F{la
" If the user did not explicitly disable the 'diamond_tex' setting, also map
" <LocalLeader>< to an enlarged delimiter.
if ! (exists('g:tex_seven_config')
      \ && has_key(g:tex_seven_config, 'diamond_tex')
      \ && g:tex_seven_config['diamond_tex'] == 1 )
  inoremap <buffer> <LocalLeader>< \langle  \rangle<Esc>F\hi
endif

" Neat insertion of various LaTeX constructs by tapping keys.
inoremap <buffer><expr> _ tex_seven#IsLeft('_') ? '{}<Left>' : '_'
inoremap <buffer><expr> ^ tex_seven#IsLeft('^') ? '{}<Left>' : '^'
inoremap <buffer><expr> = tex_seven#IsLeft('=') ? '<BS>&=' : '='
inoremap <buffer><expr> ~ tex_seven#IsLeft('~') ? '<BS>\approx' : '~'

if exists('s:maplocalleader_saved')
  let g:maplocalleader = s:maplocalleader_saved
else
  unlet g:maplocalleader
endif
