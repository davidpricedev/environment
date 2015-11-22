# Cygwin
The mintty container for cygwin64 is a bit sketchy yet and slow to start, so maybe cygwin32 is still the best option for now (June 2015)

## Fix the unreadable blue-on-black text
Open the ~/.minttyrc file and add the following (borrowed from https://github.com/karlin/mintty-colors-solarized/blob/master/.minttyrc--solarized-dark).
This essentially applies an entire color scheme to cygwin that really improves readability.

		BoldAsFont=yes
		Term=xterm-256color
		BoldAsColour=yes
		Black=7,54,66
		Red=220,50,47
		Green=133,153,0
		Yellow=181,137,0
		Blue=38,139,210
		Magenta=211,54,130
		Cyan=42,161,152
		White=238,232,213
		BoldBlack=0,43,54
		BoldRed=203,75,22
		BoldGreen=88,110,117
		BoldYellow=101,123,131
		BoldBlue=131,148,150
		BoldMagenta=108,113,196
		BoldCyan=147,161,161
		BoldWhite=253,246,227
		ForegroundColour=238,232,213
		BackgroundColour=0,43,54
		CursorColour=133,153,0
		Transparency=medium
		OpaqueWhenFocused=yes
		Columns=100
		Rows=60


		
## Tweaking
Also turn on a bit of transparency (especially when not in focus)
