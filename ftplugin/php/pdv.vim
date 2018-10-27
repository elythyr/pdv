if get(b:, 'did_ftplugin', 0) " {{{
  finish
endif " }}}

if get(b:, 'loaded_pdv', 0) " {{{
" Allows to disable pdv ftplugin only
" And avoid to load it twice for the same buffer
  finish
endif " }}}
let b:loaded_pdv = 1

let s:save_cpo = &cpo
set cpo&vim

" Configurations {{{
if !exists('b:pdv_disable_ultisnips')
  let b:pdv_disable_ultisnips = 1 " For backwards compatibility
endif

if !exists('b:pdv_template_dir')
  let b:pdv_template_dir = {}
endif

if !exists('b:pdv_template_dir.vmustache')
  let b:pdv_template_dir.vmustache = expand('<sfile>:p:h:h:h') . '/templates'
endif

if !exists('b:pdv_template_dir.ultisnips')
  let b:pdv_template_dir.ultisnips = expand('<sfile>:p:h:h:h') . '/templates_snip'
endif
" }}}

" Commands {{{
command! -buffer -nargs=? PdvDocumentCurrentLine   call pdv#DocumentCurrentLine(<f-args>)
command! -buffer -nargs=? PdvDocumentLine          call pdv#DocumentLine(<f-args>)
command! -buffer -nargs=? PdvDocumentWithSnip      call pdv#DocumentWithSnip(<f-args>)
command! -bar -buffer -nargs=0 PdvEnableUltiSnips  call pdv#EnableUltiSnips()
command! -bar -buffer -nargs=0 PdvDisableUltiSnips call pdv#DisableUltiSnips()
command! -bar -buffer -nargs=0 PdvToggleUltiSnips  call pdv#ToggleUltiSnips()
" }}}

" Mappings {{{
nnoremap <silent> <Plug>PdvDocumentCurrentLine :PdvDocumentLine<CR>

if get(b:, 'no_pdv_mappings', 1)
  if !hasmapto('<Plug>PdvDocumentCurrentLine')
    nmap <buffer> <C-p> <Plug>PdvDocumentCurrentLine
  endif
endif
" }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:ts=2:sw=2:et:fdm=marker
