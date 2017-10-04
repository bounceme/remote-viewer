augroup dirvishRemote
  au!
augroup END
function! s:curl_encode(str)
  return substitute(a:str, "[][?#!$&'()*+,;=]"
        \ , '\="%".printf("%02X",char2nr(submatch(0)))', 'g')
endfunction
function! s:Lsr(dir)
  let paths = systemlist('curl -g -s '.fnameescape(s:curl_encode(a:dir)).' -X MLSD')
  " filter response & sort dotfiles lower
  let [visi, dots] = [[], []]
  for line in paths
    let [info; path] = split(line, ' ', 1)
    let [path, type] = [join(path), matchstr(info, '\c\<type=\zs\%(dir\|file\)\ze;')]
    if type is ''
      continue
    endif
    call add(path[0] == '.' ? dots : visi, a:dir . path . (type ==? 'dir' ? '/' : ''))
  endfor
  let paths = sort(visi) + sort(dots)
  " return listed directory
  return paths
endfunction
function! s:PrepD(...)
  if a:0 && a:1 =~ '^\a\+:\/\/[^/]'
    let dir = tempname()
    call mkdir(dir,'p')
    call call('dirvish#open',[dir] + (a:0 > 1 ? a:000[1:] : []))
    delfunc dirvish#open
    call setline(1,s:Lsr(a:1))
    au dirvishRemote funcundefined dirvish#open redir => g:remote_out | call feedkeys(":\<C-U>redir END | call g:Refunc() | echo\<CR>",'n')
  else
    call call('dirvish#open',a:000)
  endif
endfunction
if v:vim_did_enter
  command! -bar -nargs=? -complete=dir Dirvish call <SID>PrepD(<q-args>)
else
  au dirvishRemote Vimenter * command! -bar -nargs=? -complete=dir Dirvish call <SID>PrepD(<q-args>)
endif
function! Refunc()
  for l in filter(split(g:remote_out,"\n"),'v:val =~# "^dirvish:"')
    let l = substitute(l,'.*\s\ze\a\+:\/\/[^/]','','')
    if l =~ '\/\s*$'
      exe 'Dirvish' fnameescape(l)
    else
      let thf = tempname()
      call writefile(systemlist("curl -g -s ".shellescape(l)),thf)
      exe 'e' thf
    endif
  endfor
endfunction
