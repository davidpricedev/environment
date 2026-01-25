### Theme: davidpricedev ZSH Theme
# Based on the agnoster theme from oh-my-zsh

CURRENT_BG='NONE'

case ${SOLARIZED_THEME:-dark} in
    light)
      CURRENT_FG=${CURRENT_FG:-'white'}
      CURRENT_DEFAULT_FG=${CURRENT_DEFAULT_FG:-'white'}
      ;;
    *)
      CURRENT_FG=${CURRENT_FG:-'black'}
      CURRENT_DEFAULT_FG=${CURRENT_DEFAULT_FG:-'default'}
      ;;
esac

### Theme Configuration Initialization
#
# Override these settings in your ~/.zshrc

# Current working directory
: ${AGNOSTER_DIR_FG:=${CURRENT_FG}}
: ${AGNOSTER_DIR_BG:=blue}

# user@host
: ${AGNOSTER_CONTEXT_FG:=${CURRENT_DEFAULT_FG}}
: ${AGNOSTER_CONTEXT_BG:=black}

# Git related
: ${AGNOSTER_GIT_CLEAN_FG:=${CURRENT_FG}}
: ${AGNOSTER_GIT_CLEAN_BG:=green}
: ${AGNOSTER_GIT_DIRTY_FG:=black}
: ${AGNOSTER_GIT_DIRTY_BG:=yellow}

# Bazaar related
: ${AGNOSTER_BZR_CLEAN_FG:=${CURRENT_FG}}
: ${AGNOSTER_BZR_CLEAN_BG:=green}
: ${AGNOSTER_BZR_DIRTY_FG:=black}
: ${AGNOSTER_BZR_DIRTY_BG:=yellow}

# Mercurial related
: ${AGNOSTER_HG_NEWFILE_FG:=white}
: ${AGNOSTER_HG_NEWFILE_BG:=red}
: ${AGNOSTER_HG_CHANGED_FG:=black}
: ${AGNOSTER_HG_CHANGED_BG:=yellow}
: ${AGNOSTER_HG_CLEAN_FG:=${CURRENT_FG}}
: ${AGNOSTER_HG_CLEAN_BG:=green}

# VirtualEnv colors
: ${AGNOSTER_VENV_FG:=black}
: ${AGNOSTER_VENV_BG:=blue}

# AWS Profile colors
: ${AGNOSTER_AWS_PROD_FG:=yellow}
: ${AGNOSTER_AWS_PROD_BG:=red}
: ${AGNOSTER_AWS_FG:=black}
: ${AGNOSTER_AWS_BG:=green}

# Status symbols
: ${AGNOSTER_STATUS_RETVAL_FG:=red}
: ${AGNOSTER_STATUS_ROOT_FG:=yellow}
: ${AGNOSTER_STATUS_JOB_FG:=cyan}
: ${AGNOSTER_STATUS_FG:=${CURRENT_DEFAULT_FG}}
: ${AGNOSTER_STATUS_BG:=black}

## Non-Color settings - set to 'true' to enable
# Show the actual numeric return value rather than a cross symbol.
: ${AGNOSTER_STATUS_RETVAL_NUMERIC:=false}
# Show git working dir in the style "/git/root   master  relative/dir" instead of "/git/root/relative/dir   master"
: ${AGNOSTER_GIT_INLINE:=false}
# Show the git branch status in the prompt rather than the generic branch symbol
: ${AGNOSTER_GIT_BRANCH_STATUS:=true}


# Special Powerline characters

USE_POWERLINE=${USE_POWERLINE:-true}
if [[ "$USE_POWERLINE" == "true" ]]; then
  # echo "Using powerline symbols in prompt"
  local SEGMENT_SEPARATOR=$'\ue0b0'
else
  # echo "Using non-powerline symbols in prompt"
  local SEGMENT_SEPARATOR="$alt_separator"
fi

get_pr_git_spec_char() {
  local type="$1"
  if [[ "$USE_POWERLINE" == "true" ]]; then
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    local PL_BRANCH_CHAR_ANB=$'\u21c5' # Both ahead and behind
    local PL_BRANCH_CHAR_A=$'\u21b1' # Ahead
    local PL_BRANCH_CHAR_B=$'\u21b0' # Behind
    local PL_BRANCH_CHAR_IND=$'\ue0a0'  # branch indicator 
  else
    local PL_BRANCH_CHAR_ANB="↕" # Both ahead and behind
    local PL_BRANCH_CHAR_A="↑" # Ahead
    local PL_BRANCH_CHAR_B="↓" # Behind
    local PL_BRANCH_CHAR_IND="🔀"  # Emoji for branch indicator
  fi

  case "$type" in
    anb) echo -n "$PL_BRANCH_CHAR_ANB" ;;
    a) echo -n "$PL_BRANCH_CHAR_A" ;;
    b) echo -n "$PL_BRANCH_CHAR_B" ;;
    ind) echo -n "$PL_BRANCH_CHAR_IND" ;;
  esac
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

prompt_end2() {
  echo -n "%{%f%k%}"
  CURRENT_BG=''
}

git_toplevel() {
	local repo_root=$(git rev-parse --show-toplevel)
	if [[ $repo_root = '' ]]; then
		# We are in a bare repo. Use git dir as root
		repo_root=$(git rev-parse --git-dir)
		if [[ $repo_root = '.' ]]; then
			repo_root=$PWD
		fi
	fi
	echo -n $repo_root
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_user_context() {
  if [[ "$USERNAME" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    prompt_segment "$AGNOSTER_CONTEXT_BG" "$AGNOSTER_CONTEXT_FG" "%(!.%{%F{$AGNOSTER_STATUS_ROOT_FG}%}.)%m"
  fi
}

prompt_git_relative() {
  local repo_root=$(git_toplevel)
  local path_in_repo=$(pwd | sed "s/^$(echo "$repo_root" | sed 's:/:\\/:g;s/\$/\\$/g')//;s:^/::;s:/$::;")
  if [[ $path_in_repo != '' ]]; then
    prompt_segment "$AGNOSTER_DIR_BG" "$AGNOSTER_DIR_FG" "$path_in_repo"
  fi;
}

# git_prompt_status () {
#   if [[ -n "${_OMZ_ASYNC_OUTPUT[_omz_git_prompt_status]}" ]]; then
#     echo -n "${_OMZ_ASYNC_OUTPUT[_omz_git_prompt_status]}"
#   fi
# }

# Git: branch/detached head, dirty status
prompt_git() {
  (( $+commands[git] )) || return
  if [[ "$(command git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]]; then
    return
  fi

  local PL_BRANCH_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR="$(get_pr_git_spec_char ind)"
  }

  local ref dirty mode repo_path

  if [[ "$(command git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]]; then
    repo_path=$(command git rev-parse --git-dir 2>/dev/null)
    dirty=$(parse_git_dirty)
    ref=$(command git symbolic-ref HEAD 2> /dev/null) || \
    ref="◈ $(command git describe --exact-match --tags HEAD 2> /dev/null)" || \
    ref="➦ $(command git rev-parse --short HEAD 2> /dev/null)"

    if [[ -n $dirty ]]; then
      prompt_segment "$AGNOSTER_GIT_DIRTY_BG" "$AGNOSTER_GIT_DIRTY_FG"
    else
      prompt_segment "$AGNOSTER_GIT_CLEAN_BG" "$AGNOSTER_GIT_CLEAN_FG"
    fi

    if [[ $AGNOSTER_GIT_BRANCH_STATUS == 'true' ]]; then
      local ahead behind
      ahead=$(command git log --oneline @{upstream}.. 2>/dev/null)
      behind=$(command git log --oneline ..@{upstream} 2>/dev/null)
      if [[ -n "$ahead" ]] && [[ -n "$behind" ]]; then
        PL_BRANCH_CHAR="$(get_pr_git_spec_char anb)"
      elif [[ -n "$ahead" ]]; then
        PL_BRANCH_CHAR="$(get_pr_git_spec_char a)"
      elif [[ -n "$behind" ]]; then
        PL_BRANCH_CHAR="$(get_pr_git_spec_char b)"
      fi
    fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' stagedstr '✚'
    zstyle ':vcs_info:*' unstagedstr '±'
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats ' %u%c'
    vcs_info
    echo -n "${${ref:gs/%/%%}/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}"
    [[ $AGNOSTER_GIT_INLINE == 'true' ]] && prompt_git_relative
  fi
}

# Dir: current working directory
prompt_dir() {
  if [[ $AGNOSTER_GIT_INLINE == 'true' ]] && $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    # Git repo and inline path enabled, hence only show the git root
    prompt_segment "black" "red" "$(git_toplevel | sed "s:^$HOME:~:")"
  else
    prompt_segment "black" "red" '%~'
  fi
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  if [ -n "$CONDA_DEFAULT_ENV" ]; then
    prompt_segment magenta $CURRENT_FG "🐍 $CONDA_DEFAULT_ENV"
  fi
  if [[ -n "$VIRTUAL_ENV" && -n "$VIRTUAL_ENV_DISABLE_PROMPT" ]]; then
    prompt_segment "$AGNOSTER_VENV_BG" "$AGNOSTER_VENV_FG" "(${VIRTUAL_ENV:t:gs/%/%%})"
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local -a symbols

  if [[ $AGNOSTER_STATUS_RETVAL_NUMERIC == 'true' ]]; then
    [[ $RETVAL -ne 0 ]] && symbols+="%{%F{$AGNOSTER_STATUS_RETVAL_FG}%}$RETVAL"
  else
    [[ $RETVAL -ne 0 ]] && symbols+="%{%F{$AGNOSTER_STATUS_RETVAL_FG}%}✘"
  fi
  [[ $UID -eq 0 ]] && symbols+="%{%F{$AGNOSTER_STATUS_ROOT_FG}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{$AGNOSTER_STATUS_JOB_FG}%}⚙"

  [[ -n "$symbols" ]] && prompt_segment "$AGNOSTER_STATUS_BG" "$AGNOSTER_STATUS_FG" "$symbols"
}

prompt_aws() {
  [[ -z "$AWS_PROFILE" || "$SHOW_AWS_PROMPT" = false ]] && return
  case "$AWS_PROFILE" in
    *) prompt_segment "$AGNOSTER_AWS_BG" "$AGNOSTER_AWS_FG" "🔸 ${AWS_PROFILE:gs/%/%%}" ;;
  esac
}

function prompt_date() {
  # date format like "Wed-Jan21"
  local prompt_date_part="%D{%a-%b%d}"
  prompt_segment blue black "$prompt_date_part"
}

function prompt_time() {
  local prompt_time_part="%D{%H:%M:%S}"
  prompt_segment black yellow "$prompt_time_part"
}

function prompt_sysinfo() {
  # show arch (and rename aarch64 to arm64)
  local raw_arch="$(uname -m)"
  case "$raw_arch" in
    amd64) local arch="x86_64" ;;  # Linux x86_64
    x86_64) local arch="x86_64" ;;  # Linux x86_64
    arm64) local arch="arm64" ;;    # macOS arm64
    aarch64) local arch="arm64" ;;  # Linux arm64
    *) local arch="$raw_arch" ;;
  esac

  if [[ "$(uname)" == "Darwin" ]]; then
    prompt_segment black gray " $arch"
  elif [[ "$(uname)" == "Linux" ]]; then
    prompt_segment black green "🐧 $arch"
  else
    prompt_segment black yellow "$arch"
  fi
}

## Main prompt
build_prompt() {
  RETVAL=$?
  prompt_status
  prompt_virtualenv
  prompt_aws
  prompt_sysinfo
  prompt_date
  prompt_dir
  prompt_git
  prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt)
$(prompt_time)$(prompt_end2) » '
export PROMPT
