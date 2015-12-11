let s:save_cpo = &cpo
set cpo&vim

let s:script = expand("<sfile>:p:h") . "/jun.pl"
function! jun#run(cmd, ...)
	let s:exe = ["!perl", s:script, a:cmd] + a:000
	if a:cmd == "test" || a:cmd == "submit"
		call add(s:exe, "%")
	endif
	exec join(s:exe, " ")
	if a:cmd == "make"
		let s:file = system(join(["perl", s:script, "_open"], " "))
		if v:shell_error == 0
			edit `=s:file`
		endif
	endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
