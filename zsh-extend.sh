#!/bin/zsh

# =-=-=-=-=-=-=-=-=-= Homebrew Configs =-=-=-=-=-=-=-=-=-=
export HOMEBREW_NO_AUTO_UPDATE=1

# =-=-=-=-=-=-=-=-=-= Claude Code Configs =-=-=-=-=-=-=-=-=-=

export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1
export DISABLE_NON_ESSENTIAL_MODEL_CALLS=1
export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1
export MAX_THINKING_TOKENS=0
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
export CLAUDE_CODE_DISABLE_COMMAND_INJECTION_CHECK=1

# =-=-=-=-=-=-=-=-=-= General Configs =-=-=-=-=-=-=-=-=-=

export PROXY_LOCAL_PATH="127.0.0.1:7897"

# EDITOR
export EDITOR='code -w'

# Owner
export USER_NAME="rich1e"

export LANG='en_US.UTF-8';
export LC_ALL='en_US.UTF-8';

export PATH="/usr/local/sbin:$PATH"

# FileSearch
function f() { find . -iname "*$1*" ${@:2} }
function r() { grep "$1" ${@:2} -R . }
function ff() { find * -type f | fzf > selected }

# mkdir and cd
function mkcd() { mkdir -p "$@" && cd "$_"; }

# Lazygit
lg()
{
  export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir

  lazygit "$@"

  if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
    cd "$(cat $LAZYGIT_NEW_DIR_FILE)"
    rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
  fi
}

# Git from Homebrew
export PATH="/opt/homebrew/bin/git:$PATH"

# Proxy
function setProxy() {
  export no_proxy="localhost,127.0.0.1,localaddress,.localdomain.com"
  export https_proxy="http://$PROXY_LOCAL_PATH" http_proxy="http://$PROXY_LOCAL_PATH" all_proxy="socks5://$PROXY_LOCAL_PATH"

  echo -e "已开启代理"
}

function unProxy(){
  unset http_proxy
  unset https_proxy
  unset all_proxy
  echo -e "已关闭代理"
}

# =-=-=-=-=-=-=-=-=-= Android SDK (Unified & Switchable) =-=-=-=-=-=-=-=-=-=

# Common Android env
export ANDROID_USER_HOME="$HOME/.android"
export ANDROID_EMULATOR_HOME="$ANDROID_USER_HOME"
export ANDROID_AVD_HOME="$ANDROID_USER_HOME/avd"
export REPO_OS_OVERRIDE="macosx"

# Internal helper: setup PATH for current ANDROID_HOME
_android_path_setup() {
  path=(
    "$ANDROID_HOME/platform-tools"
    "$ANDROID_HOME/emulator"
    "$ANDROID_HOME/cmdline-tools/latest/bin"
    "$ANDROID_HOME/build-tools/36.1.0"
    $path
  )
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
}

# Use Android Studio SDK (recommended for emulator / GUI)
use-android-studio() {
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  _android_path_setup
  echo "✅ Android SDK: Android Studio ($ANDROID_HOME)"
}

# Use Homebrew-installed commandline-tools (recommended for CLI / CI)
use-android-brew() {
  export ANDROID_HOME="$HOMEBREW_PREFIX/share/android-commandlinetools"
  _android_path_setup
  echo "✅ Android SDK: Homebrew ($ANDROID_HOME)"
}

# Default SDK (Android Studio first, fallback to Homebrew)
if [ -d "$HOME/Library/Android/sdk/platform-tools" ]; then
  use-android-studio
else
  use-android-brew
fi

# Explicit tool aliases (avoid PATH ambiguity)
alias adb="$ANDROID_HOME/platform-tools/adb"
alias emulator="$ANDROID_HOME/emulator/emulator"
# sdkmanager / avdmanager (runtime-resolved, SDK-switch safe)
sdkmanagerFn() {
  "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" "$@"
}

avdmanagerFn() {
  "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" "$@"
}

# Compatibility aliases (map common commands to safe functions)
alias sdkmanager='sdkmanagerFn'
alias avdmanager='avdmanagerFn'

# =-=-=-=-=-=-=-=-=-= AVD Creator (zsh native) =-=-=-=-=-=-=-=-=-=

create-avd() {
  local mode="$1"

  # AVD management must use Homebrew SDK (cmdline-tools)
  if [[ -z "$ANDROID_HOME" || "$ANDROID_HOME" != "$HOMEBREW_PREFIX/share/android-commandlinetools" ]]; then
    use-android-brew
  fi

  if [[ -z "$mode" ]]; then
    echo "Usage: create-avd dev"
    return 1
  fi

  case "$mode" in
    dev)
      local AVD_NAME="Pixel_36_Dev"
      local PKG="system-images;android-36;google_apis;arm64-v8a"
      local DEVICE="pixel_9"
      local SKIN="pixel_9_pro"

      echo "▶ [DEV] Installing system image:"
      echo "    $PKG"
      sdkmanagerFn "$PKG"
      if [[ $? -ne 0 ]]; then
        echo "❌ sdkmanager failed"
        return 1
      fi

      echo "▶ [DEV] Creating AVD: $AVD_NAME"
      echo "no" | avdmanagerFn create avd \
        -n "$AVD_NAME" \
        -k "$PKG" \
        -d "$DEVICE" \
        --skin "$SKIN"
      if [[ $? -ne 0 ]]; then
        echo "❌ avdmanager failed"
        return 1
      fi

      echo "✅ [DEV] AVD ready: $AVD_NAME"
      ;;
    *)
      echo "Unknown mode: $mode"
      echo "Supported modes: dev"
      return 1
      ;;
  esac
}

# =-=-=-=-=-=-=-=-=-= Alias Tables =-=-=-=-=-=-=-=-=-=

# Use vscode for editing config files
alias editconfig="code -a $HOME/zsh-extend.sh"
alias zshconfig="code -a $HOME/.zshrc"

# Download by axel
alias dl="axel -o ~/Downloads"

# source .zshrc
alias reload="source ~/.zshrc"

# Easier navigation
alias ..='cd ..'
alias ~="cd ~" # `cd` is probably faster to type though
alias -- -="cd -"

# Useful aliases
alias cls="clear"
alias ext="exit"
alias ssh="ssh -X"
alias grep='grep --color'
alias egrep='egrep --color'
alias fgrep='fgrep --color'

alias ws='web_search'
alias rm='trash'
alias cpp='copypath'
alias cpf='copyfile'

alias rec='asciinema rec'
alias recp='asciinema play'
alias recc='asciinema cat'
alias recup='asciinema upload'
alias reca='asciinema auth'
alias rech='asciinema -h'

alias ls='eza'
alias ll='eza -lh'
alias la='eza -lha'
alias lr='eza -lR'

# IP addresses
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias localip="ipconfig getifaddr en0"
alias ips="ifconfig -a | grep -o 'inet6\? \(addr:\)\?\s\?\(\(\([0-9]\+\.\)\{3\}[0-9]\+\)\|[a-fA-F0-9:]\+\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'"

# Show active network interfaces
alias ifactive="ifconfig | pcregrep -M -o '^[^\t:]+:([^\n]|\n\t)*status: active'"

# Flush Directory Service cache
alias flush="dscacheutil -flushcache && killall -HUP mDNSResponder"

# Active Cursor
alias activeCursor="curl -fsSL https://raw.githubusercontent.com/yeongpin/cursor-free-vip/main/scripts/install.sh -o install.sh && chmod +x install.sh && ./install.sh"

# Beyond Compare reset
alias bcreset="launchctl start com.rich1e.beyondcompare.reset"

# =-=-=-=-=-=-=-=-=-= Plugins Begin =-=-=-=-=-=-=-=-=-=

# zsh-completions
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

  autoload -Uz compinit
  compinit
fi

# zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=165"
source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-syntax-highlighting
source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# autojump
[ -f $HOMEBREW_PREFIX/etc/profile.d/autojump.sh ] && . $HOMEBREW_PREFIX/etc/profile.d/autojump.sh

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# forgit
[ -f $HOMEBREW_PREFIX/share/forgit/forgit.plugin.zsh ] && source $HOMEBREW_PREFIX/share/forgit/forgit.plugin.zsh

# =-=-=-=-=-=-=-=-=-= Plugins End =-=-=-=-=-=-=-=-=-=

# =-=-=-=-=-=-=-=-=-= Other Configs =-=-=-=-=-=-=-=-=-=

# trash
export PATH="/opt/homebrew/opt/trash/bin:$PATH"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"  # This loads nvm
[ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

# jenv
export JENV_ROOT="$HOME/.jenv"
export PATH="$HOME/.jenv/bin:$PATH"
eval "$(jenv init -)"

# goenv
export GOENV_ROOT="$HOME/.goenv"
export PATH="$GOENV_ROOT/bin:$PATH"
eval "$(goenv init -)"

# web_search
ZSH_WEB_SEARCH_ENGINES=(
  bi "https://search.bilibili.com/all?keyword="
  douban "https://search.douban.com/book/subject_search?search_text="
  reddit "https://www.reddit.com/search/?q="
)

# thefuck
eval $(thefuck --alias)

# navi
# @see https://github.com/denisidoro/navi/blob/master/docs/installation.md#installing-the-shell-widget
eval "$(navi widget zsh)"

# The following lines have been added by Docker Desktop to enable Docker CLI completions.
# End of Docker CLI completions
fpath=(/Users/${USER_NAME}/.docker/completions $fpath)

# tdl - Telegram Downloader, but more than a downloader
# source <(tdl completion zsh)

function tock_info() {
  # Returns empty string if no activity is running
  tock current --format "{{.Project}}: {{.Duration}}" 2>/dev/null
}

# =-=-=-=-=-=-=-=-=-=-= Bind Key =-=-=-=-=-=-=-=-=-=

sudo-command-line() {
  [[ -z $BUFFER ]] && zle up-history
  [[ $BUFFER != sudo\ * ]] && BUFFER="sudo $BUFFER"
  zle end-of-line
}
zle -N sudo-command-line
bindkey "\e\e" sudo-command-line

# zsh autosuggest (option + j)
bindkey '∆' autosuggest-toggle

# =-=-=-=-=-=-=-=-=-= Zsh Config =-=-=-=-=-=-=-=-=-=

# Stop auto updates
zstyle ':omz:update' mode disabled
# This will check for updates every 7 days
zstyle ':omz:update' frequency 7
# This will check for updates every time you open the terminal (not recommended)
zstyle ':omz:update' frequency 0

# Command prompt
autoload -U promptinit && promptinit

# Start Starship
STARSHIP_CONFIG=${HOME}/.config/starship.toml
eval "$(starship init zsh)"
