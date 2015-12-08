let s:save_cpo = &cpo
set cpo&vim

let s:script = expand("<sfile>:p:h") . "/../plugin/jun.pl"
function! jun#run(cmd, ...)
	let s:exe = ["!perl", s:script, a:cmd] + a:000
	if a:cmd == "test" || a:cmd == "submit"
		call add(s:exe, "%")
	endif
	exec join(s:exe, " ") 
	if a:cmd == "make"
		e `ls -Ft \| grep -v / \| head -1`
	endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
