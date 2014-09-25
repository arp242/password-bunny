"
" password bunny: Manage passwords with Vim
"
" http://code.arp242.net/password-bunny
"
" Copyright © 2014 Martin Tournoij <martin@arp242.net>
" See below for full copyright
"


"""
""" Keybinds
"""

nnoremap <Leader>a :call PwbunnyAddEntry()<CR>
nnoremap <Leader>c :call PwbunnyCopyPassword()<CR>
nnoremap <Leader>u :call PwbunnyCopyUserAndPassword()<CR>
nnoremap <Leader>C :call PwbunnyEmptyClipboard()<CR>
nnoremap <Leader>p :echo PwbunnyMakePassword()<CR>
nnoremap <Leader>P :put=PwbunnyMakePassword()<CR>
nnoremap <Leader>s :call PwbunnySort()<CR>


"""
""" Settings
"""

" Default username to use
let s:defaultuser = 'martin@arp242.net'

" Use the clipboard contents as default site
let s:site_from_clipboard = 1

" Empty the clipboard after this many seconds after calling
" PwbunnyCopyPassword(), set to 0 to disable
let s:emptyclipboard = 10

" Length of generated passwords
let s:passwordlength = 15

" Sort entries after adding a new one
let s:autosort = 1

" Try and see if we can access the clipboard
" You could set this manually for a better startup time if you're using a
" commandline utility`
" TODO: Are clipboard *and* xterm_clipboard really required? Figure out the
" difference...
let s:copymethod = has('clipboard') && has('xterm_clipboard')

" TODO: Also test if these tools actually work
if s:copymethod == '0'
	if system('which xclip > /dev/null && echo -n 0 || echo -n 1') == '0'
		let s:copymethod = 'xclip'
	elseif system('which xcopy > /dev/null && echo -n 0 || echo -n 1') == '0'
		let s:copymethod = 'xcopy'
	elseif system('which xsel > /dev/null && echo -n 0 || echo -n 1') == '0'
		let s:copymethod = 'xsel'

		" Newer xsel, which is an `improved' version, but has incompatible
		" switches..! (why do people do this sort of thing...!?!?)
		if system('xsel --version > /dev/null && echo -n 0 || echo -n 1') == '0'
			let s:copymethod = 'xsel-new'
		endif
	endif
endif

" Only open fold explicitly (with zo or insert commands)
setlocal foldopen=

" Close folds as soon as we move out of them
setlocal foldclose=all

" Display less info on closed folds
setlocal foldtext=getline(v:foldstart)
setlocal fillchars=""


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
""" You probably don't want to change the settings below this """
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


" Default is zip (insecure!)
if !has('cryptv')
	echoerr "Your Vim doesn't support encrypting files -- DO NOT USE THIS PROGRAM BEFORE FIXING THIS!"
endif
setlocal cryptmethod=blowfish

" VimInfo file isn't encrypted, and may possible leak data
setlocal viminfo=

" Make sure we keep the backup & swap file in the same directory, they're
" encrypted, but we don't want them dangling around in tmp dirs
setlocal backupdir=.
setlocal dir=.

" We disabled swap on startup (-n), re-enable it (it will now be created in the
" correct directory, instead of whatever is in ~/.vimrc)
setlocal updatecount=200


"""
""" Functions
"""

fun! PwbunnyFindCopyClose(name)
	let l:sstr = "/^\\n" . a:name
	try
		execute l:sstr
	catch /^Vim\%((\a\+)\)\=:E385/
		" TODO: ideally, I'd like to exit with status 2, and do this in the
		" shell script... exiting Vim with an exit status other than 0 or 1
		" doesn't seem possible, though...
		try
			echohl ErrorMsg | echo "Entry not found"
			call input('press enter to exit')
		finally
			execute ":q"
		endtry
	endtry

	normal j
	try
		call PwbunnyCopyPassword()
	finally
		execute ":q"
	endtry
endfun

" Make folds
fun! PwbunnyFold()
	normal zE
	for e in PwbunnyGetEntries()
		execute e[0] . "," . e[1] . "fold"
	endfor
	normal zc
endfun


" Generate a random password
fun! PwbunnyMakePassword()
	if !exists("s:passwordlength")
		let s:passwordlength = 15
	endif

	" http://arp242.net/weblog/Generate_passwords_from_the_commandline.html
	return system("strings -n1 < /dev/urandom | tr -d '[:space:]' | head -c" . s:passwordlength)
endfun


" Add a new entry
fun! PwbunnyAddEntry()
	if exists("s:site_from_clipboard") && s:site_from_clipboard
		let l:defaultsite = PwbunnyGetClipboard()
		" Strip spaces and stuff
		let l:defaultsite = substitute(l:defaultsite, '\r', '', 'g')
		let l:defaultsite = substitute(l:defaultsite, '^\s*\|\s*$', '', 'g')
		let l:defaultsite = strpart(l:defaultsite, 0, 30)
		let l:defaultsite = substitute(l:defaultsite, '^\s*\|\s*$', '', 'g')
		
		" Get just the domain part
		let l:defaultsite = substitute(l:defaultsite, '^\w*://', '', '')
		let l:defaultsite = substitute(l:defaultsite, '/.*', '', '')

		if l:defaultsite != ''
			let l:site = input("Site (enter for " . l:defaultsite . "): ")
		else
			let l:site = input("Site: ")
		end
		if l:site == ""
			let l:site = l:defaultsite
		endif
	else
		let l:site = input("Site: ")
	endif

	if l:site == ""
		echoerr "Site is required"
		return
	endif

	if exists('s:defaultuser') && s:defaultuser != ""
		let l:user = input("User (enter for " . s:defaultuser . "): ")
		if l:user == ""
			let l:user = s:defaultuser
		end
	else
		let l:user = input("User: ")
	endif

	let l:pass = input("Password (enter for random): ")
	if l:pass == ""
		let l:pass = PwbunnyMakePassword()
	endif

	if line("$") > 1
		let l:first = 0
		call append("$", "")
	else
		let l:first = 1
	endif
	let l:start = line("$")
	call append("$", l:site)
	call append("$", l:user)
	call append("$", l:pass)
	call append("$", "")
	if l:first
		normal dd
	endif

	call PwbunnyFold()

	if exists("s:autosort") && s:autosort
		call PwbunnySort()
	endif
	execute "w"
endfun


" Get the site of the current entry
fun! PwbunnyGetSite()
	return PwbunnyGetLine(1)
endfun


" Get the username of the current entry
fun! PwbunnyGetUser()
	return PwbunnyGetLine(2)
endfun


" Get the password of the current entry
fun! PwbunnyGetPassword()
	return PwbunnyGetLine(3)
endfun


" Get line number n of an entry
fun! PwbunnyGetLine(n)
	let l:folded = foldclosed(".")

	if search("^$", "Wb") == 0
		normal 1G
	else
		normal j
	endif

	if l:folded > -1
		normal zo
	endif

	let l:i = 1
	while l:i < a:n
		normal j
		let l:i += 1
	endwhile

	let l:val = getline(".")

	if l:folded > -1
		normal zc
	endif

	let l:val = substitute(l:val, "\n$", "", "")
	return l:val
endfun


" Copy username to clipboard
fun! PwbunnyCopyUserAndPassword()
	if !PwbunnyCopyToClipboard(PwbunnyGetUser())
		return
	endif

	let l:pw = input("User copied; copy password (Esc or ^C for no)? ", "yes")
	if l:pw == "yes"
		call PwbunnyCopyPassword()
	endif
endfun


" Copy password to clipboard
fun! PwbunnyCopyPassword()
	if !PwbunnyCopyToClipboard(PwbunnyGetPassword())
		return
	endif

	if exists("s:emptyclipboard") && s:emptyclipboard > 0
		let l:i = 0
		let l:wait = s:emptyclipboard * 10

		" If we sleep in steps of 1s, pasting has a delay of 1s
		while l:i < l:wait
			echon "\rClipboard will be emptied in " . ((l:wait - l:i) / 10) . " seconds (^C to cancel, Enter to empty now)"
			execute "sleep 100m"
			if getchar(0) == 10
				break
			endif
			let l:i += 1
		endwhile

		call PwbunnyEmptyClipboard()
	endif
endfun


" Clear the clipboard
fun! PwbunnyEmptyClipboard()
	" Using an empty clipboard doesn't seem to work with:
	" let @* = a:str
	if !PwbunnyCopyToClipboard(' ')
		return
	endif
	
	echo "Clipboard cleared"
endfun


" Sort entries
fun! PwbunnySort()
	" We need everything to be folded for this to work
	" TODO: Ideally, this shouldn't really be required
	call PwbunnyFold()

	let l:names = []
	for e in PwbunnyGetEntries()
		call cursor(e[0], 0)
		call add(l:names, [PwbunnyGetSite(), e[0], e[1]])
	endfor

	fun! s:sort(a, b)
		return a:a[0] == a:b[0] ? 0 : a:a[0] > a:b[0] ? 1 : -1
	endfun
	call sort(l:names, "s:sort")

	let l:new = []
	for e in l:names
		let l:new += getline(e[1], e[2])

		" Add a newline to the last entry, if it isn't there (see Issue #1)
		if e[2] == line("$") && getline(e[2]) != ""
			let l:new += ['']
		endif
	endfor

	normal 1Gd100%
	call append(".", l:new)

	if getline(1) == ''
		normal 1Gdd
	endif
	call PwbunnyFold()
endfun


" Get list of all entries, as [startline, endline]
" TODO: This has the side-effect of moving the cursor to line 1
fun! PwbunnyGetEntries()
	let l:ret = []

	normal 1G
	while 1
		let l:start = line(".")

		let [l:emptyline, l:col] = searchpos("^$", "W")
		let [l:nemptyline, l:col] = searchpos("^[^$]", "W")

		" Last entry
		if l:emptyline == 0 || l:nemptyline == 0
			call add(l:ret, [l:start, line("$")])
			break
		endif

		call add(l:ret, [l:start, l:nemptyline - 1])
	endwhile

	normal 1G
	return l:ret
endfun


" Copy str to clipboard
fun! PwbunnyCopyToClipboard(str)
	if s:copymethod == '1'
		let @* = a:str
	elseif s:copymethod == 'xclip'
		call system("echo -n " . shellescape(a:str) . " | xclip")
	elseif s:copymethod == 'xcopy'
		call system("echo -n " . shellescape(a:str) . " | xcopy")
	elseif s:copymethod == 'xsel'
		call system("echo -n " . shellescape(a:str) . " | xsel -c")
	elseif s:copymethod == 'xsel-new'
		call system("echo -n " . shellescape(a:str) . " | xsel -i")
	else
		echoerr "Can't access clipboard; please see the `Clipboard support' in the README file"
		return 0
	endif

	return 1
endfun


" Get clipboard contents
" TODO: We could also use xprop -root
fun! PwbunnyGetClipboard()
	if s:copymethod == '1'
		let l:contents = @*
	elseif s:copymethod == 'xclip'
		let l:contents = system("xclip -o")
	elseif s:copymethod == 'xcopy'
		let l:contents = system("xcopy -r")
	elseif s:copymethod == 'xsel'
		let l:contents = system("xsel")
	elseif s:copymethod == 'xsel-new'
		let l:contents = system("xsel")
	else
		echoerr "Can't access clipboard; please see the `Clipboard support' in the README file"
		return -1
	endif

	if v:shell_error > 0
		return ''
	else
		return l:contents
	end
endfun


" If there are less than 3 + (bytes / 100) newlines, we assume the password
" is incorrect, and we're displaying a bunch of gibberish. Quit, and try
" again
fun! PwbunnyOpen()
	if getline(1) != '' && line("$") < 3 + (line2byte(line("$")) / 100)
		" User pressed ^C
		if strpart(getline("."), 0, 12) == "VimCrypt~02!"
			quit!
		else
			cquit!
		endif
	endif
endfun


" Let's go!
call PwbunnyOpen()
call PwbunnyFold()


" The MIT License (MIT)
"
" Copyright © 2014 Martin Tournoij
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to
" deal in the Software without restriction, including without limitation the
" rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
" sell copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" The software is provided "as is", without warranty of any kind, express or
" implied, including but not limited to the warranties of merchantability,
" fitness for a particular purpose and noninfringement. In no event shall the
" authors or copyright holders be liable for any claim, damages or other
" liability, whether in an action of contract, tort or otherwise, arising
" from, out of or in connection with the software or the use or other dealings
" in the software.
