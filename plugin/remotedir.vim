augroup dirvishRemote
  au!
augroup END

let s:pdir = fnamemodify(expand('<sfile>'),':p:h:h')
let s:expect = s:pdir.'/ssh.exp'

function! s:curl_encode(str)
  return substitute(a:str, "[][?#!$&'()*+,;=]"
        \ , '\="%".printf("%02X",char2nr(submatch(0)))', 'g')
endfunction

function! s:Lsr(dir)
  let [visi, dots] = [[], []]
  for path in filter(s:ls(a:dir,a:dir =~# '^s\%(sh\|cp\):'),'v:val =~ "\\S"')
    if a:dir !~# '^s\%(sh\|cp\):'
      let [info; path] = split(path, ' ', 1)
      let [path, type] = [join(path), matchstr(info, '\c\<type=\zs\%(dir\|file\)\ze;')]
      if type is ''
        continue
      elseif type ==? 'dir'
        let path .= '/'
      endif
    endif
    call add(path[0] == '.' ? dots : visi, substitute(a:dir,'[^/]$','&/','') . path)
  endfor
  " return listed directory
  return sort(visi) + sort(dots)
endfunction

function! s:Catr(fname,...)
  if a:1
    return s:ssh_ls_cat(a:fname)
  else
    return systemlist("curl -g -s ".shellescape(s:curl_encode(a:fname)))
  endif
endfunction

function! s:ssh_ls_cat(rl)
  let [it,path] = matchlist(a:rl,'^.\{6}\([^/]\+\)\(.*\)')[1:2]
  return systemlist(join(['LC_ALL=C expect -f', s:expect] +
        \ (exists('b:changed_remote') ? split(it,'@') : reverse(split(it,'@'))) +
        \ [shellescape('$HOME'.path)]))
endfunction

function! s:ls(dir,...)
  if a:1
    return s:ssh_ls_cat(a:dir)
  else
    return systemlist('curl -g -s '.shellescape(s:curl_encode(a:dir)).' -X MLSD')
  endif
endfunction

function! s:PrepD(...)
  if a:0 && a:1 =~ '^\a\+:\/\/[^/]'
    let dir = tempname()
    call mkdir(dir,'p')
    call call('dirvish#open',[dir] + (a:0 > 1 ? a:000[1:] : []))
    delfunc dirvish#open
    call setline(1,s:Lsr(a:1))
    exe 'au dirvishRemote funcundefined dirvish#open if bufname("%") ==#' string(bufname('%'))
          \ '| redir => g:remote_out | call feedkeys(":\<C-U>ec|redi END|cal g:Refunc()\<CR>","n") | endif'
  else
    call call('dirvish#open',a:000)
  endif
endfunction

if get(v:,'vim_did_enter')
  command! -bar -nargs=? -complete=dir Dirvish call <SID>PrepD(<q-args>)
else
  au dirvishRemote Vimenter * command! -bar -nargs=? -complete=dir Dirvish call <SID>PrepD(<q-args>)
endif

function! Refunc()
  for l in filter(split(g:remote_out,"\n"),'v:val =~# "^dirvish:"')
    let l = substitute(l,'.*\s\ze\a\+:\/\/[^/]','','')
    if l =~ '\/\s*$'
      let b:changed_remote = 1
      exe 'Dirvish' fnameescape(l)
    else
      let thf = tempname()
      call writefile(s:Catr(l,l =~# '^s\%(sh\|cp\):'),thf)
      exe 'e' thf
    endif
  endfor
endfunction
