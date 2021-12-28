#!/bin/zsh
# adapted from https://stackoverflow.com/a/16771593/567493

NONE="\033[0m"
FG="38;5"
BG="48;5"

for COLOR in {0..255}
do
    FGCOLOR="$FG;$COLOR"
    FGTAG="\033[${FGCOLOR}m"
    FGSTR="foreground: ${FGCOLOR}"
    echo -ne "${FGTAG}${FGSTR}${NONE} "
    BGCOLOR="$BG;$COLOR"
    BGTAG="\033[${BGCOLOR}m"
    BGSTR="background: ${BGCOLOR}"
    echo -ne "${BGTAG} ${BGSTR} ${NONE}"
    echo
done

echo "To use \\\033[<color_code>m<text>\\\033[0m"
echo "Example \\\033[48;5;88m\\\033[38;5;250mHello World!\\\033[0m"
echo "To use in zsh prompt use just the 0..255 number inside %F/%f or %K/%k"
echo "Example: PROMPT=\"%K{88}%F{250}Hello World!%f%k $ \""
