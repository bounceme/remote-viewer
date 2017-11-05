augroup dirvishRemote
  au!
augroup END

if exists('s:expect')
  finish
endif
let s:expect = fnamemodify(fnamemodify(expand('<sfile>'),':p:h:h'),':p').'ssh.exp'

function! s:curl_encode(str)
  return substitute(a:str, "[][?#!$&'()*+,;=]"
        \ , '\="%".printf("%02X",char2nr(submatch(0)))', 'g')
endfunction

function! s:Lsr(dir)
  let [visi, dots, ssh] = [[], [], a:dir =~# '^ssh:']
  for path in filter(s:ls(a:dir,ssh),'v:val =~ "\\S"')
    if !ssh
      let [info; path] = split(path, ' ', 1)
      let [path, type] = [join(path), matchstr(info, '\c\Wtype=\zs\%(dir\|file\)\ze;')]
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

function! s:Catr(fname,ssh)
  return a:ssh ? s:ssh_ls_cat(a:fname) : s:sys("curl -g -s ".shellescape(s:curl_encode(a:fname)))
endfunction

function! s:sys(cmd)
  return systemlist('LC_ALL=C '.a:cmd)
endfunction

function! s:ssh_ls_cat(rl)
  let [it,path] = matchlist(a:rl,'^.\{6}\([^/]\+\)\(.*\)')[1:2]
  return s:sys(join(['expect -f', s:expect] +
        \ reverse(split(it,'@')) + [shellescape('$HOME'.path)]))
endfunction

function! s:ls(dir,ssh)
  return a:ssh ? s:ssh_ls_cat(a:dir) : s:sys('curl -g -s '.shellescape(s:curl_encode(a:dir)).' -X MLSD')
endfunction

let s:cache_url = {}

function! s:PrepD(...)
  let path = a:0 ? substitute(a:1,'[^/]$','&/','') : ''
  let in_cache = has_key(s:cache_url,path)
  if a:0 && (path =~ '^\a\+:\/\/[^/]' || in_cache)
    if in_cache
      let dir = path
    else
      let bn = get(filter(items(s:cache_url),'v:val[1] ==# '
            \ .string(substitute(path,'[^/]\+/$','',''))),0,[0])[0]
      if bn isnot 0
        let dir = bn . matchstr(bn,'[^/]\+/$')
      else
        let dir = fnamemodify(tempname(),':p').'/'
      endif
      let s:cache_url[dir] = path
      silent! call mkdir(dir,'p')
    endif
    call call('dirvish#open',[dir] + (a:0 > 1 ? a:000[1:] : []))
    delfunc dirvish#open
    call setline(1,s:Lsr(in_cache ? s:cache_url[path] : path))
    exe 'au! dirvishRemote funcundefined dirvish#open if bufname("%") ==#' string(bufname('%'))
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
      let thf = fnamemodify(expand('%'),':p').matchstr(tempname(),'[^/]\+$')
      exe 'badd' thf '|b' thf
      set buftype=nofile
      call setline(1,s:Catr(l,l =~# '^ssh:'))
    endif
  endfor
endfunction
