augroup dirvishRemote
  au!
augroup END

function! s:curl_encode(str)
  return substitute(a:str, "[][?#!$&'()*+,;=]"
        \ , '\="%".printf("%02X",char2nr(submatch(0)))', 'g')
endfunction

function! s:Lsr(dir)
  let [visi, dots] = [[], []]
  for path in filter(s:Sshls(a:dir),'v:val =~ "\\S"')
    if a:dir !~# '^s\%(sh\|cp\)\A'
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

let s:this = fnamemodify(expand('<sfile>'),':p:h:h').'/ssh.exp'
let s:passcache = {}
function! s:Sshls(dir)
  if a:dir =~# '^s\%(sh\|cp\)\A'
    let [it,path] = matchlist(a:dir,'^.\{6}\([^/]\+\)\(.*\)')[1:2]
    let path = path is '' ? '/' : path
    let pass = get(s:passcache,it,'')
    if pass is ''
      call inputsave()
      let pass = inputsecret('')
      call inputrestore()
      let s:passcache[it] = pass
    endif
    return systemlist(join([s:this]+reverse(split(it,'@'))+[pass,path]))
  endif
  return systemlist('curl -g -s '.shellescape(s:curl_encode(a:dir)).' -X MLSD')
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
      exe 'Dirvish' fnameescape(l)
    else
      let thf = tempname()
      call writefile(systemlist("curl -g -s ".shellescape(s:curl_encode(l))),thf)
      exe 'e' thf
    endif
  endfor
endfunction
