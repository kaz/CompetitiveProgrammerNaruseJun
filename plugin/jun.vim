if exists("g:loaded_jun")
	finish
endif
let g:loaded_jun = 1

let s:save_cpo = &cpo
set cpo&vim

command! -nargs=+ Jun call jun#run(<f-args>)

let &cpo = s:save_cpo
unlet s:save_cpo
