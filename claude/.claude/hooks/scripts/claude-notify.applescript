-- Dual-entry applet: notify.sh launches it with a "pending" state file to post
-- the banner; clicking the banner relaunches it, where "posted" state means
-- jump tmux to the saved pane and focus iTerm2.
on run
	set stateFile to (POSIX path of (path to home folder)) & ".cache/claude-notify-click"
	try
		set stateText to do shell script "cat " & quoted form of stateFile
	on error
		return
	end try
	set parts to paragraphs of stateText
	if (count of parts) < 3 then return
	set phase to item 1 of parts
	set pane to item 2 of parts
	set msg to item 3 of parts
	if phase is "pending" then
		do shell script "printf 'posted\\n%s\\n%s\\n' " & quoted form of pane & " " & quoted form of msg & " > " & quoted form of stateFile
		display notification msg with title "Claude Code — waiting"
		-- quitting too fast can drop the async notification
		delay 1
	else
		do shell script "rm -f " & quoted form of stateFile
		if pane is not "" then
			do shell script "export PATH=/opt/homebrew/bin:$PATH; for c in $(tmux list-clients -F '#{client_tty}'); do tmux switch-client -c \"$c\" -t '" & pane & "'; done; tmux select-window -t '" & pane & "'; tmux select-pane -t '" & pane & "'; true"
		end if
		do shell script "open -a iTerm"
	end if
end run
