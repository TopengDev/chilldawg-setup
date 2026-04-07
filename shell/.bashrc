#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
unalias c 2>/dev/null
c() {
  if [[ "$1" == "-M" ]]; then
    shift
    WHATSAPP=1 claude --dangerously-load-development-channels plugin:whatsapp@TopengDev -d "channel" --debug-file /tmp/claude-debug.log --dangerously-load-development-channels plugin:attn@s0nderlabs --dangerously-skip-permissions --resume "$@"
  elif [[ "$1" == "-D" ]]; then
    shift
    claude --dangerously-skip-permissions "$@"
  else
    claude "$@"
  fi
}
PS1='[\u@\h \W]\$ '

eval "$(oh-my-posh init bash --config ~/Documents/chris.omp.json)"

export PATH="/usr/bin"
export PATH="/usr/local/bin:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# flutter
export PATH="/home/christopher/flutter/bin:$PATH"

# chrome
export PATH="/opt/google/chrome:$PATH"

# webstorm
export PATH="/home/christopher/Programs/WebStorm/bin:$PATH"

# tor browser
export PATH="/home/christopher/Programs/tor-browser/Browser:$PATH"

# go
export PATH="$(go env GOPATH)/bin:$PATH"

# gpt
export PATH="/home/christopher/Programs/ChatGPT_1.1.0:$PATH"

# droid & local bin
export PATH="/home/christopher/.local/bin:$PATH"

# homebrew
export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

export PATH="/home/christopher/.cargo/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

eval "$(ssh-agent -s)" > /dev/null
ssh-add ~/.ssh/id_ed25519 > /dev/null 2>&1

export PATH="$PATH:/home/christopher/.foundry/bin"

# Tell tmux the current working directory on every prompt (OSC 7)
__osc7_ps1() {
  printf '\e]7;file://%s%s\e\\' "$HOSTNAME" "$PWD"
}
PROMPT_COMMAND="__osc7_ps1${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

# secrets — keeps API keys/tokens/passwords out of this file (and out of dotfiles repo)
[ -f ~/.claude/secrets.env ] && source ~/.claude/secrets.env
