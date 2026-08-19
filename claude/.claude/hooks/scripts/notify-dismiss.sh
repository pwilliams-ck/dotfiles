#!/bin/sh
# Close visible Notification Center banners/alerts via UI scripting.
# Needs Accessibility + Automation (System Events) permission for the caller
# (karabiner_console_user_server on first use).
exec /usr/bin/osascript <<'EOF'
-- banner windows sit at window > group > group > scroll area > group (macOS 26);
-- "whose" filters don't work on AX actions, hence the explicit loop
tell application "System Events" to tell process "NotificationCenter"
	repeat with w in windows
		try
			repeat with g in groups of scroll area 1 of group 1 of group 1 of w
				repeat with a in actions of g
					if description of a is in {"Close", "Clear All"} then perform a
				end repeat
			end repeat
		end try
	end repeat
end tell
EOF
