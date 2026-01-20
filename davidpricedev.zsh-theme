# Rough goal here is to get a theme that is similar to agnoster,
#  but with 2 lines of prompt instead of just 1 (similar to jonathan).
# This gives more flexibility to display more information 
#   such as: dates & times, git info, aws profile, etc

# TODOs:
# - Add an AWS Region section
# - fix up the transitions between colors
# - pick a better color for the path

function theme_precmd {
  local TERMWIDTH=$(( COLUMNS - ${ZLE_RPROMPT_INDENT:-1} ))

  PR_FILLBAR=""
  PR_PWDLEN=""

  local promptsize=${#${(%):-__--(_AWS:__)---()--}}
  local rubypromptsize=${#${(%)$(ruby_prompt_info)}}
  local pwdsize=${#${(%):-%~}}
  local venvpromptsize=$((${#$(virtualenv_prompt_info)}))
  local awsprofilesize=${#${AWS_PROFILE}}

  # Truncate the path if it's too long.
  if (( promptsize + rubypromptsize + pwdsize + venvpromptsize + awsprofilesize > TERMWIDTH )); then
    (( PR_PWDLEN = TERMWIDTH - promptsize ))
  elif [[ "${langinfo[CODESET]}" = UTF-8 ]]; then
    PR_FILLBAR="\${(l:$(( TERMWIDTH - (promptsize + rubypromptsize + pwdsize + venvpromptsize + awsprofilesize ) ))::${PR_HBAR}:)}"
  else
    PR_FILLBAR="${PR_SHIFT_IN}\${(l:$(( TERMWIDTH - (promptsize + rubypromptsize + pwdsize + venvpromptsize + awsprofilesize ) ))::${altchar[q]:--}:)}${PR_SHIFT_OUT}"
  fi
}

function theme_preexec {
  setopt local_options extended_glob
  if [[ "$TERM" = "screen" ]]; then
    local CMD=${1[(wr)^(*=*|sudo|-*)]}
    echo -n "\ek$CMD\e\\"
  fi
}

autoload -U add-zsh-hook
add-zsh-hook precmd  theme_precmd
add-zsh-hook preexec theme_preexec


# Set the prompt

# Need this so the prompt will work.
setopt prompt_subst

# See if we can use colors.
autoload zsh/terminfo
for color in RED GREEN YELLOW BLUE MAGENTA CYAN WHITE GREY; do
  typeset -g PR_$color="%{$terminfo[bold]$fg[${(L)color}]%}"
  typeset -g PR_LIGHT_$color="%{$fg[${(L)color}]%}"
done
PR_NO_COLOUR="%{$terminfo[sgr0]%}"

# %{$bg%}%{$fg%}
# Modify Git prompt
PR_BRANCH_CHAR=$'\ue0a0'         # 
ZSH_THEME_GIT_PROMPT_PREFIX=" ${PR_BRANCH_CHAR}"
# ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_SUFFIX=""
ZSH_THEME_GIT_PROMPT_DIRTY=""
ZSH_THEME_GIT_PROMPT_CLEAN=""

ZSH_THEME_GIT_PROMPT_ADDED="%{$fg[green]%} %{%G✚%}"
ZSH_THEME_GIT_PROMPT_MODIFIED="%{$fg[blue]%} %{%G✹%}"
ZSH_THEME_GIT_PROMPT_DELETED="%{$fg[red]%} %{%G✖%}"
ZSH_THEME_GIT_PROMPT_RENAMED="%{$fg[magenta]%} %{%G➜%}"
ZSH_THEME_GIT_PROMPT_UNMERGED="%{$fg[yellow]%} %{%G═%}"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[cyan]%} %{%G✭%}"

# Use extended characters to look nicer if supported.
if [[ "${langinfo[CODESET]}" = UTF-8 ]]; then
  PR_SET_CHARSET=""
  PR_HBAR="─"
  PR_ULCORNER="┌"
  PR_LLCORNER="└"
  PR_URCORNER="┐"
  PR_LRCORNER="┘"
else
  typeset -g -A altchar
  set -A altchar ${(s..)terminfo[acsc]}
  # Some stuff to help us draw nice lines
  PR_SET_CHARSET="%{$terminfo[enacs]%}"
  PR_SHIFT_IN="%{$terminfo[smacs]%}"
  PR_SHIFT_OUT="%{$terminfo[rmacs]%}"
  PR_HBAR="${PR_SHIFT_IN}${altchar[q]:--}${PR_SHIFT_OUT}"
  PR_ULCORNER="${PR_SHIFT_IN}${altchar[l]:--}${PR_SHIFT_OUT}"
  PR_LLCORNER="${PR_SHIFT_IN}${altchar[m]:--}${PR_SHIFT_OUT}"
  PR_LRCORNER="${PR_SHIFT_IN}${altchar[j]:--}${PR_SHIFT_OUT}"
  PR_URCORNER="${PR_SHIFT_IN}${altchar[k]:--}${PR_SHIFT_OUT}"
fi

# Decide if we need to set titlebar text.
case $TERM in
  xterm*)
    PR_TITLEBAR=$'%{\e]0;%(!.-=*[ROOT]*=- | .)%n@%m:%~ | ${COLUMNS}x${LINES} | %y\a%}'
    ;;
  screen)
    PR_TITLEBAR=$'%{\e_screen \005 (\005t) | %(!.-=[ROOT]=- | .)%n@%m:%~ | ${COLUMNS}x${LINES} | %y\e\\%}'
    ;;
  *)
    PR_TITLEBAR=""
    ;;
esac

# Decide whether to set a screen title
if [[ "$TERM" = "screen" ]]; then
  PR_STITLE=$'%{\ekzsh\e\\%}'
else
  PR_STITLE=""
fi

PR_dateColor="%{$fg[black]%}%{$bg[blue]%}"
PR_awsProfileColor="%{$fg[black]%}%{$bg[green]%}"
PR_gitColor="%{$fg[black]%}%{$bg[yellow]%}"
PR_pathColor="%{$fg[red]%}%{$bg[black]%}"
PR_sep=$'\ue0b0' # 
PR_rsep=$'\ue0b2' # 
PR_tblueyellow="%{$fg[blue]%}%{$bg[yellow]%}${PR_sep}"

# cap the size of the aws profile name
# nonemptyAwsProfile="${AWS_PROFILE:=-none-}"
# truncatedAwsProfile="${AWS_PROFILE:0:20}"
# paddedAwsProfile="${(r:20:)AWS_PROFILE}"
# prefixedAwsProfile="AWS: ${paddedAwsProfile}"

# Finally, the prompt.
PROMPT='${PR_SET_CHARSET}${PR_STITLE}${(e)PR_TITLEBAR}\
${PR_CYAN}${PR_ULCORNER}${PR_HBAR}\
${PR_rsep}${PR_pathColor} %${PR_PWDLEN}<...<%~%<< %{$reset_color%}${PR_CYAN}${PR_sep}\
%{$reset_color%}${PR_GREY}$(virtualenv_prompt_info)$(ruby_prompt_info)${PR_CYAN}${PR_HBAR}${PR_HBAR}${(e)PR_FILLBAR}${PR_HBAR}\
${PR_rsep}${PR_awsProfileColor} AWS: ${AWS_PROFILE} %{$reset_color%}${PR_CYAN}${PR_sep}\
${PR_HBAR}${PR_URCORNER}\

${PR_CYAN}${PR_LLCORNER}${PR_BLUE}${PR_HBAR}${PR_rsep}\
${PR_dateColor} %D{%H:%M:%S} ${PR_tblueyellow}\
${PR_gitColor}$(git_prompt_info)$(git_prompt_status) %{$reset_color%}\
${PR_CYAN}${PR_sep}${PR_HBAR}${PR_HBAR}\
>${PR_NO_COLOUR} '

# display exitcode on the right when > 0
return_code="%(?..%{$fg[red]%}%? ↵ %{$reset_color%})"
RPROMPT=' $return_code${PR_CYAN}${PR_HBAR}${PR_BLUE}${PR_HBAR}\
(${PR_YELLOW}%D{%a,%b%d}${PR_BLUE})${PR_HBAR}${PR_CYAN}${PR_LRCORNER}${PR_NO_COLOUR}'

PS2='${PR_CYAN}${PR_HBAR}\
${PR_BLUE}${PR_HBAR}(\
${PR_LIGHT_GREEN}%_${PR_BLUE})${PR_HBAR}\
${PR_CYAN}${PR_HBAR}${PR_NO_COLOUR} '
