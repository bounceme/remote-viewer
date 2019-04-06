augroup dirvishRemote
  au!
augroup END

if exists('*s:curl_encode')
  finish
endif

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

let s:shls = "{ cd %s && find . -type d -maxdepth 1 | sed -e 's/$/\\//' ".
      \ "&& find . \\! \\( -type d \\) -maxdepth 1 ; } ".
      \ "| sed -e 's/^\\.\\///' ; exit"
let s:shcat = "cat %s ; exit"

function! s:Catr(fname,ssh)
  return a:ssh ? s:ssh_ls_cat(a:fname) : s:sys("curl -g -s ".shellescape(s:curl_encode(a:fname)))
endfunction

function! s:sys(cmd,...)
  return call('systemlist',['LC_ALL=C '.a:cmd] + a:000)
endfunction

function! s:ssh_ls_cat(rl)
  let [it,path] = matchlist(a:rl[6:],'^[^/]\+\ze\(.*\)')[:1]
  let parts = split(it,'@')
  if len(parts) == 2
    let [user,host] = parts
    let ssh_cmd = printf('ssh %s -l %s ',host,user)
  elseif len(parts) == 1
    let host = parts[0]
    let ssh_cmd = printf('ssh %s ',host)
  else
    throw printf('remotedir: could not parse user/host from %s', it)
  endif
  let output = s:sys(ssh_cmd.
        \ shellescape(printf(path[-1:] == '/' ? s:shls : s:shcat, '$HOME'.path)))
  redraw!
  return output
endfunction

function! s:ls(dir,ssh)
  return a:ssh ? s:ssh_ls_cat(a:dir) : s:sys('curl -g -s '.shellescape(s:curl_encode(a:dir)).' -X MLSD')
endfunction

let s:cache_url = {}

function! s:PrepD(...)
  let path = a:0 ? substitute(a:1,'[^/]$','&/','') : ''
  let in_cache = has_key(s:cache_url,path)
  if a:0 && (path =~# '^\%(ftp\|ssh\)://[^/]' || in_cache)
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
    call setline(1,s:Lsr(in_cache ? s:cache_url[path] : path))
    exe 'au! dirvishRemote funcundefined dirvish#open if bufname("%") ==#' string(bufname('%'))
          \ '| redir => g:remote_out | call feedkeys(":\<C-U>echon ''''|redi END|cal g:Refunc()\<CR>","n") | endif'
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
  for l in filter(split(g:remote_out,"\n"),'v:val =~# "^dirvish:.*\\s\\%(ftp\\|ssh\\)://[^/]"')
    let l = substitute(l,'\C.*\s\ze\%(ftp\|ssh\)://[^/]','','')
    if l[-1:] == '/'
      exe 'Dirvish' fnameescape(l)
    else
      let thf = fnamemodify(expand('%'),':p').matchstr(tempname(),'[^/]\+$')
      exe 'badd' thf '|b' thf
      set buftype=nowrite bufhidden=wipe
      call setline(1,s:Catr(l,l =~# '^ssh:'))
    endif
  endfor
endfunction
