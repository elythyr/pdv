" PDV (phpDocumentor for Vim)
" ===========================
"
" Version: 2.0.0alpha1
"
" Copyright 2005-2011 by Tobias Schlitt <toby@php.net>
"
" Provided under the GPL (http://www.gnu.org/copyleft/gpl.html).
"
" This script provides functions to generate phpDocumentor conform
" documentation blocks for your PHP code. The script currently
" documents:
"
" - Classes
" - Methods/Functions
" - Attributes
" - Consts
" - Interfaces
" - Traits
"
" All of those supporting PHP 5 syntax elements.
"
" Beside that it allows you to define default values for phpDocumentor tags
" like @version (I use $id$ here), @author, @license and so on.
"
" For function/method parameters and attributes, the script tries to guess the
" type as good as possible from PHP5 type hints or default values (array, bool,
" int, string...).

let s:old_cpo = &cpo
set cpo&vim

" Script variables {{{
let s:enable_ultisnips  = 0
let s:disable_ultisnips = 1

" Regular expressions {{{

let s:comment = ' *\*/ *'

let s:regex = {}

" (private|protected|public)
let s:regex["scope"] = '\(private\|protected\|public\)'
" (static)
let s:regex["static"] = '\(static\)'
" (abstract)
let s:regex["abstract"] = '\(abstract\)'
" (final)
let s:regex["final"] = '\(final\)'

" [:space:]*(private|protected|public|static|abstract)*[:space:]+[:identifier:]+\([:params:]\)
let s:regex["function"] = '^\(\s*\)\([a-zA-Z ]*\)function\s\+\([^ (]\+\)\s*('
" [:typehint:]*[:space:]*$[:identifier]\([:space:]*=[:space:]*[:value:]\)?
let s:regex["param"] = ' *\([^ &]*\)\s*\(&\?\)\$\([^ =)]\+\)\s*\(=\s*\(.*\)\)\?$'

" ^(?<indent>\s*)(?<scope>\s+)?const\s+(?<name>\S+)\s*=\s*(?<value>)
" 1:indent, 2:scope, 3:name, 4:value
let s:regex["const"] = '^\(\s*\)\%(' . s:regex.scope . '\s\+\)\?const\s\+\(\S\+\)\s*=\s*\([^;]\{-}\)\s*;$'

" [:space:]*(private|protected|public\)[:space:]*$[:identifier:]+\([:space:]*=[:space:]*[:value:]+\)*;
let s:regex["attribute"] = '^\(\s*\)\(\(private\s*\|public\s*\|protected\s*\|static\s*\)\+\)\s*\$\([^ ;=]\+\)[ =]*\(.*\);\?$'

" [:spacce:]*(abstract|final|)[:space:]*(class|interface)+[:space:]+\(extends ([:identifier:])\)?[:space:]*\(implements ([:identifier:][, ]*)+\)?

let s:regex["class"] = '^\(\s*\)\(\S*\)\s*\(class\)\s*\(\S\+\)\s*\([^{]*\){\?$'

" ^(?<indent>\s*)interface\s+(?<name>\S+)(\s+extends\s+(?<interface>\s+)(\s*,\s*(?<interface>\S+))*)?\s*{?\s*$
" 1:indent, 2:name, 4,6,8,...:extended interfaces
let s:regex["interface"] = '^\(\s*\)interface\s\+\(\S\+\)\(\s\+extends\s\+\(\S\+\)\(\s*,\s*\(\S\+\)\)*\)\?\s*{\?\s*$'

" ^(?<indent>\s*)trait\s+(?<name>\S+)\s*{?\s*$
" 1:indent, 2:name
let s:regex["trait"] = '^\(\s*\)trait\s\+\(\S\+\)\s*{\?\s*$'

let s:regex.types = {
  \ 'array':  '^\%(array([^)]*)\|\[[^\]]*\]\)$',
  \ 'float':  '^[0-9]*\.[0-9]\+$',
  \ 'int':    '^[0-9]\+$',
  \ 'string': "^['\"].*",
  \ 'bool':   '\(true\|false\)$',
  \ 'object': '^new\s\+\([^( ]\+\)',
\}

let s:regex["indent"] = '^\s*'

let s:mapping = [
    \ {"regex": s:regex["function"],
    \  "function": function("pdv#ParseFunctionData"),
    \  "template": "function"},
    \ {"regex": s:regex["attribute"],
    \  "function": function("pdv#ParseAttributeData"),
    \  "template": "attribute"},
    \ {"regex": s:regex["const"],
    \  "function": function("pdv#ParseConstData"),
    \  "template": "const"},
    \ {"regex": s:regex["class"],
    \  "function": function("pdv#ParseClassData"),
    \  "template": "class"},
    \ {"regex": s:regex["interface"],
    \  "function": function("pdv#ParseInterfaceData"),
    \  "template": "interface"},
    \ {"regex": s:regex["trait"],
    \  "function": function("pdv#ParseTraitData"),
    \  "template": "trait"},
\ ]
" }}}
" }}}

" I want to add is the possibility for the user to be able to choose
" between using UltiSnips or not and to have the possibility to let the plugin
" decides automaticaly.
" But I want the updated version to continue to work for users with the
" previous version.
"
" pdv#DocumentCurrentLine()
"   Is deprecated and only there for backwards compatibility.
"   Use pdv#DocumentWithoutSnip(...) instead.
"   It's behavior is preserved: it will only document the current line
"   without UltiSnips
"
" pdv#DocumentLine(linenr)
"   Will be intended to document a line and choose between UltiSnips or
"   VMustache automatically.
"   By default, UltiSnips autodetection will be disabled so the users
"   upgrading the plugin will not see any changes.
"
" pdv#DocumentWithSnip(...)
"   Will enforce the use of UltiSnips and fallback on VMustache if UltiSnips
"   is not installed.
"   It will take an optional argument which is the line number to document.
"   By default it will be the current line, to preserve the actual behavior.
"
" pdv#DocumentWithoutSnip(...)
"   Will disable UltiSnips detection.
"   The optional argument is the line number to document, default to the
"   current line.

" Global functions {{{
func! pdv#EnableUltiSnips() " {{{
  let b:pdv_disable_ultisnips = s:enable_ultisnips
endfunc " }}}

func! pdv#DisableUltiSnips() " {{{
  let b:pdv_disable_ultisnips = s:disable_ultisnips
endfunc " }}}

func! pdv#ToggleUltiSnips() " {{{
  let b:pdv_disable_ultisnips = !b:pdv_disable_ultisnips
endfunc " }}}

func! pdv#DocumentCurrentLine() " {{{
  call pdv#DocumentWithoutSnip(line('.'))
endfunc " }}}

func! pdv#DocumentWithSnip(...) " {{{
  call call('s:DocumentWith', [s:enable_ultisnips] + a:000)
endfunc " }}}

func! pdv#DocumentWithoutSnip(...) " {{{
  call call('s:DocumentWith', [s:disable_ultisnips] + a:000)
endfunc " }}}

func! pdv#DocumentLine(...) " {{{
  try
    let l:linenr = a:0 ? a:1 : line('.')
    let l:documentation = s:PrepareDocumentation(l:linenr)

    if s:IsUltiSnipsAvailable()
      put! =nr2char(10)
      call UltiSnips#Anon(join(l:documentation, nr2char(10)))
    else
      call append(l:linenr - 1, l:documentation)
    endif
  catch
    echohl ErrorMsg
    echo v:exception
    echohl NONE
  endtry
endfunc " }}}

func! pdv#ParseClassData(line) " {{{
  let l:text = getline(a:line)

  let l:data = {}
  let l:matches = matchlist(l:text, s:regex["class"])

  let l:data["indent"] = matches[1]
  let l:data["name"] = matches[4]
  let l:data["abstract"] = s:GetAbstract(matches[2])
  let l:data["final"] = s:GetFinal(matches[2])

  if (!empty(l:matches[5]))
    call s:ParseExtendsImplements(l:data, l:matches[5])
  endif
  " TODO: abstract? final?

  return l:data
endfunc " }}}

func! pdv#ParseInterfaceData(line) " {{{
" ^(?<indent>\s*)interface\s+(?<name>\S+)(\s+extends\s+(?<interface>\s+)(\s*,\s*(?<interface>\S+))*)?\s*{?\s*$
" 1:indent, 2:name, 4,6,8,...:extended interfaces
  let l:text = getline(a:line)

  let l:data = {}
  let l:matches = matchlist(l:text, s:regex["interface"])

  let l:data["indent"] = matches[1]
  let l:data["name"] = matches[2]

  let l:data["parents"] = []

  let i = 2
  while !empty(l:matches[i+2])
    let i += 2
    let l:data["parents"] += [{"name":matches[i]}]
  endwhile

  return l:data
endfunc " }}}

func! pdv#ParseTraitData(line) " {{{
" ^(?<indent>\s*)trait\s+(?<name>\S+)\s*{?\s*$
" 1:indent, 2:name
  let l:text = getline(a:line)

  let l:data = {}
  let l:matches = matchlist(l:text, s:regex["trait"])

  let l:data["indent"] = matches[1]
  let l:data["name"] = matches[2]

  return l:data
endfunc " }}}

func! pdv#ParseConstData(line) " {{{
" 1:indent, 2:scope, 3:name, 4:value
  let l:text = getline(a:line)

  let l:data = {}
  let l:matches = matchlist(l:text, s:regex['const'])

  let l:data['indent'] = l:matches[1]
  let l:data['name']   = l:matches[3]
  let l:data['type']   = s:GuessType(l:matches[4])

  return l:data
endfunc " }}}

func! pdv#ParseAttributeData(line) " {{{
  let l:text = getline(a:line)

  let l:data = {}
  let l:matches = matchlist(l:text, s:regex["attribute"])

  let l:data["indent"] = l:matches[1]
  let l:data["scope"] = s:GetScope(l:matches[2])
  let l:data["static"] = s:GetStatic(l:matches[2])
  let l:data["name"] = l:matches[4]
  " TODO: Cleanup ; and friends
  let l:data["default"] = get(l:matches, 5, '')
  let l:data["type"] = s:GuessType(l:data["default"])

  return l:data
endfunc " }}}

func! pdv#ParseFunctionData(line) " {{{
  let l:text = getline(a:line)

  let l:data = s:ParseBasicFunctionData(l:text)
  let l:data["parameters"] = []

  let l:parameters = parparse#ParseParameters(a:line)

  for l:param in l:parameters
    call add(l:data["parameters"], s:ParseParameterData(l:param))
  endfor

  return l:data
endfunc " }}}
" }}}

" Script functions {{{
func! s:DocumentWith(disable_ultisnips, ...) " {{{
  let l:disable_ultisnips_save = b:pdv_disable_ultisnips

  try
    let b:pdv_disable_ultisnips = a:disable_ultisnips

    call pdv#DocumentLine(a:0 ? a:1 : line('.'))
  finally
    let b:pdv_disable_ultisnips = l:disable_ultisnips_save
  endtry
endfunc " }}}

func! s:PrepareDocumentation(linenr) " {{{
  let l:parseconfig   = s:DetermineParseConfig(getline(a:linenr))
  let l:data          = s:ParseDocData(a:linenr, l:parseconfig)
  let l:documentation = s:GenerateDocumentation(l:parseconfig, l:data)

  return s:ApplyIndent(l:documentation, l:data['indent'])
endfunc " }}}

func! s:DetermineParseConfig(line) " {{{
  for l:parseconfig in s:mapping
    if match(a:line, l:parseconfig["regex"]) > -1
      return l:parseconfig
    endif
  endfor
  throw "Could not detect parse config for '" . a:line . "'"
endfunc " }}}

func! s:ParseDocData(docline, config) " {{{
  let l:Parsefunction = a:config["function"]
  return l:Parsefunction(a:docline)
endfunc " }}}

func! s:GenerateDocumentation(config, data) " {{{
  let l:template = s:GetTemplate(a:config["template"] . '.tpl')
  return s:ProcessTemplate(l:template, a:data)
endfunc " }}}

func! s:GetTemplateDirectory() " {{{
  if exists('g:pdv_template_dir') " For backward compatibility
    return g:pdv_template_dir
  endif

  let l:type = s:IsUltiSnipsAvailable() ? 'ultisnips' : 'vmustache'

  return b:pdv_template_dir[l:type]
endfunc " }}}

func! s:GetTemplate(filename) " {{{
  return s:GetTemplateDirectory() . '/' . a:filename
endfunc " }}}

func! s:ProcessTemplate(file, data) " {{{
  return vmustache#RenderFile(a:file, a:data)
endfunc " }}}

func! s:ApplyIndent(text, indent) " {{{
  let l:lines = split(a:text, "\n")
  return map(l:lines, '"' . a:indent . '" . v:val')
endfunc " }}}

func! s:ParseExtendsImplements(data, text) " {{{
  let l:tokens = split(a:text, '\(\s*,\s*\|\s\+\)')

  let l:extends = 0
  for l:token in l:tokens
    if (tolower(l:token) == "extends")
      let l:extends = 1
      continue
    endif
    if l:extends
      let a:data["parent"] = [{"name": l:token}]
      break
    endif
  endfor

  let l:implements = 0
  let l:interfaces = []
  for l:token in l:tokens
    if (tolower(l:token) == "implements")
      let l:implements = 1
      continue
    endif
    if (l:implements && tolower(l:token) == "extends")
      break
    endif
    if (l:implements)
      call add(l:interfaces, {"name": l:token})
    endif
  endfor
  let a:data["interfaces"] = l:interfaces

endfunc " }}}

func! s:ParseParameterData(text) " {{{
  let l:data = {}

  let l:matches = matchlist(a:text, s:regex["param"])

  let l:data["reference"] = (l:matches[2] == "&")
  let l:data["name"] = l:matches[3]
  let l:data["default"] = l:matches[5]

  if (!empty(l:matches[1]))
    let l:data["type"] = l:matches[1]
  elseif (!empty(l:data["default"]))
    let l:data["type"] = s:GuessType(l:data["default"])
  endif

  return l:data
endfunc " }}}

func! s:ParseBasicFunctionData(text) " {{{
  let l:data = {}

  let l:matches = matchlist(a:text, s:regex["function"])

  let l:data["indent"] = l:matches[1]
  let l:data["scope"] = s:GetScope(l:matches[2])
  let l:data["static"] = s:GetStatic(l:matches[2])
  let l:data["name"] = l:matches[3]

  return l:data
endfunc " }}}

func! s:GetScope(modifiers) " {{{
  return matchstr(a:modifiers, s:regex["scope"])
endfunc " }}}

func! s:GetStatic(modifiers) " {{{
  return tolower(a:modifiers) =~ s:regex["static"]
endfunc " }}}

func! s:GetAbstract(modifiers) " {{{
  return tolower(a:modifiers) =~ s:regex["abstract"]
endfunc " }}}

func! s:GetFinal(modifiers) " {{{
  return tolower(a:modifiers) =~ s:regex["final"]
endfunc " }}}

func! s:GuessType(value) " {{{
  " Will work as long as the order does not matter
  for [l:type, l:pattern] in items(s:regex.types)
    let l:matches = matchlist(a:value, l:pattern)

    if !empty(l:matches)
      return !empty(l:matches[1]) ? l:matches[1] : l:type
    endif
  endfor
endfunc " }}}

func! s:IsUltiSnipsAvailable() " {{{
  if get(b:, 'pdv_disable_ultisnips', 0)
    return
  endif

  return 2 == exists(':UltiSnipsEdit')
endfunc " }}}
" }}}

let &cpo = s:old_cpo
unlet s:old_cpo

" vim:ts=2:sw=2:et:fdm=marker
