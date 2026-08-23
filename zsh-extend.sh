#!/bin/zsh

# ===================================================================================================
# ZSH 扩展配置文件
# 作者: rich1e
# 说明: 个人 Zsh 环境配置，包括环境变量、插件、别名、自定义函数等
# 本文件由 ~/.zshrc source 加载，密钥占位符 {{ ... }} 由 chezmoi 渲染
# ===================================================================================================

# 防护：必须在 zsh 中执行，且作为 source 加载（非独立脚本）
[[ -n "$ZSH_VERSION" ]] || { echo "Error: zsh-extend.sh 必须在 zsh 中加载"; return 1 2>/dev/null || exit 1; }

# 安全选项
setopt PIPE_FAIL              # 管道任一阶段失败即整体失败
# 注意：不启用 NO_UNSET —— autojump/forgit 等插件依赖 BASH 模式下的未设置变量判断
# 改用 ${VAR:-} 显式默认值作为防御写法

# ===================================================================================================
# 1. 基础环境变量配置
# ===================================================================================================

# 1.1 系统语言环境
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

# 1.2 用户信息
export USER_NAME="rich1e"

# 1.3 默认编辑器
export EDITOR='code -w'

# 1.4 系统路径
export PATH="/usr/local/sbin:$PATH"

# 1.5 密钥访问（按需从 macOS Keychain 读取，避免常驻在环境变量中）
getBase64Key() {
  local key_name="$1"
  local account_name="$2"
  local raw
  raw=$(security find-generic-password -w -s "$key_name" -a "$account_name" 2>/dev/null)
  # 去除 go-keyring-base64: 前缀(若有)
  raw="${raw#go-keyring-base64:}"
  # 解码
  echo -n "$raw" | base64 -d
}

openai_api_key() {
  getBase64Key "openai-api-key" "rich1e"
}

github_token() {
  getBase64Key "github-token" "rich1e"
}

stitch_api_key() {
  getBase64Key "stitch-api-key" "rich1e"
}

minimax_api_key() {
  getBase64Key "minimax-api-key" "rich1e"
}

# 1.6 GitHub 访问令牌（从 macOS Keychain 读取）
export GITHUB_TOKEN="{{ keyring "github-token" "rich1e" }}"

# 1.7 OpenAI API Key（从 macOS Keychain 读取）
export OPENAI_API_KEY="{{ keyring "openai-api-key" "rich1e" }}"

# 1.8 Stitch API Key（从 macOS Keychain 读取）
export STITCH_API_KEY="{{ keyring "stitch-api-key" "rich1e" }}"

# 1.9 Minimax API Key（从 macOS Keychain 读取）
export MINIMAX_API_KEY="{{ keyring "minimax-api-key" "rich1e" }}"

# ===================================================================================================
# 2. 应用程序配置
# ===================================================================================================

# 2.1 Homebrew 配置
export HOMEBREW_NO_AUTO_UPDATE=1  # 禁用自动更新

# 缓存 HOMEBREW_PREFIX，避免后续多处 brew --prefix 重复调用
if [[ -z "$HOMEBREW_PREFIX" ]] && type brew &>/dev/null; then
  HOMEBREW_PREFIX="$(brew --prefix)"
  export HOMEBREW_PREFIX
fi

# 2.2 代理配置
export PROXY_LOCAL_PATH="127.0.0.1:7897"

# ===================================================================================================
# 3. 开发环境管理器配置
# ===================================================================================================

# 3.1 Node.js 版本管理器 (nvm)
export NVM_DIR="$HOME/.nvm"
if [ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ]; then
  source "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
fi
if [ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ]; then
  source "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"
fi

# 3.2 Python 版本管理器 (pyenv)
export PYENV_ROOT="$HOME/.pyenv"
if [[ -d "$PYENV_ROOT/bin" ]]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init - zsh)"
fi

# 3.3 Java 版本管理器 (jenv)
export JENV_ROOT="$HOME/.jenv"
if [[ -d "$JENV_ROOT/bin" ]]; then
  export PATH="$JENV_ROOT/bin:$PATH"
  eval "$(jenv init -)"
fi

# 3.4 Go 版本管理器 (goenv)
export GOENV_ROOT="$HOME/.goenv"
if [[ -d "$GOENV_ROOT/bin" ]]; then
  export PATH="$GOENV_ROOT/bin:$PATH"
  eval "$(goenv init -)"
fi

# 3.5 Created by `pipx` on 2026-06-26 03:41:06
export PATH="$PATH:$HOME/.local/bin"

# 3.6 Google Cloud SDK
export PATH=/opt/homebrew/share/google-cloud-sdk/bin:"$PATH"

# ===================================================================================================
# 4. Android 开发环境配置
# ===================================================================================================

# 4.1 Android 通用环境变量
export ANDROID_USER_HOME="$HOME/.android"
export ANDROID_EMULATOR_HOME="$ANDROID_USER_HOME"
export ANDROID_AVD_HOME="$ANDROID_USER_HOME/avd"
export REPO_OS_OVERRIDE="macosx"

# 4.2 Android PATH 配置辅助函数（内部使用）
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

# 4.3 切换到 Android Studio SDK（推荐用于模拟器和图形界面）
use-android-studio() {
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  _android_path_setup
  echo "✅ Android SDK: Android Studio ($ANDROID_HOME)"
}

# 4.4 切换到 Homebrew SDK（推荐用于命令行和 CI）
use-android-brew() {
  if [[ -n "$HOMEBREW_PREFIX" ]]; then
    export ANDROID_HOME="$HOMEBREW_PREFIX/share/android-commandlinetools"
    _android_path_setup
    echo "✅ Android SDK: Homebrew ($ANDROID_HOME)"
  else
    echo "❌ Homebrew 未安装或 HOMEBREW_PREFIX 未设置"
    return 1
  fi
}

# 4.5 默认 SDK（优先使用 Android Studio，备选 Homebrew）
if [ -d "$HOME/Library/Android/sdk/platform-tools" ]; then
  use-android-studio
elif [[ -n "$HOMEBREW_PREFIX" && -d "$HOMEBREW_PREFIX/share/android-commandlinetools" ]]; then
  use-android-brew
fi

# 4.6 Android 工具别名（避免 PATH 歧义）
if [[ -n "$ANDROID_HOME" ]]; then
  alias adb="$ANDROID_HOME/platform-tools/adb"
  alias emulator="$ANDROID_HOME/emulator/emulator"
fi

# 4.7 Android SDK 管理工具函数
_android_sdk_tool() {
  # 用法: _android_sdk_tool <relative_tool_path> <display_name> "$@"
  local tool_rel="$1" name="$2"
  shift 2
  local tool_path="$ANDROID_HOME/$tool_rel"
  if [[ -n "$ANDROID_HOME" && -f "$tool_path" ]]; then
    "$tool_path" "$@"
  else
    echo "❌ $name 未找到，请检查 ANDROID_HOME 配置"
    return 1
  fi
}

sdkmanagerFn() { _android_sdk_tool "cmdline-tools/latest/bin/sdkmanager" "sdkmanager" "$@"; }
avdmanagerFn() { _android_sdk_tool "cmdline-tools/latest/bin/avdmanager" "avdmanager" "$@"; }

alias sdkmanager='sdkmanagerFn'
alias avdmanager='avdmanagerFn'

# 4.8 AVD（Android 虚拟设备）创建函数
create-avd() {
  local mode="$1"

  # AVD 管理必须使用 Homebrew SDK
  if [[ -z "$ANDROID_HOME" || "$ANDROID_HOME" != "$HOMEBREW_PREFIX/share/android-commandlinetools" ]]; then
    use-android-brew || return 1
  fi

  if [[ -z "$mode" ]]; then
    echo "用法: create-avd dev"
    return 1
  fi

  case "$mode" in
    dev)
      local AVD_NAME="Pixel_36_Dev"
      local PKG="system-images;android-36;google_apis;arm64-v8a"
      local DEVICE="pixel_9"
      local SKIN="pixel_9_pro"

      echo "▶ [DEV] 安装系统镜像: $PKG"
      sdkmanagerFn "$PKG" || { echo "❌ sdkmanager 失败"; return 1; }

      echo "▶ [DEV] 创建 AVD: $AVD_NAME"
      echo "no" | avdmanagerFn create avd \
        -n "$AVD_NAME" \
        -k "$PKG" \
        -d "$DEVICE" \
        --skin "$SKIN" || { echo "❌ avdmanager 失败"; return 1; }

      echo "✅ [DEV] AVD 创建成功: $AVD_NAME"
      ;;
    *)
      echo "未知模式: $mode"
      echo "支持的模式: dev"
      return 1
      ;;
  esac
}

# ===================================================================================================
# 5. fzf 模糊搜索工具配置
# ===================================================================================================

# 5.1 fzf 基础配置（必须在加载 fzf 之前设置）
export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude={.git,.idea,.vscode,.sass-cache,node_modules,build}"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_COMPLETION_TRIGGER="**"

# 5.2 fzf 路径补全配置
export FZF_COMPLETION_PATH_OPTS='--walker file,dir,hidden,follow --scheme=path'

# 公共 preview 命令：目录用 eza 树、文件用 bat
_fzf_preview_cmd='if [ -d {} ]; then eza --tree --level=2 --color=always --icons {}; else bat --style=numbers --color=always --line-range :500 {}; fi'

# 5.3 fzf 补全界面配置
export FZF_COMPLETION_OPTS="
--height 80%
--layout reverse
--border
--select-1
--exit-0
--preview '$_fzf_preview_cmd'
"

# 5.4 fzf 默认界面配置
export FZF_DEFAULT_OPTS="
--height=80%
--layout=reverse
--border
--preview-window=right:60%:wrap
--preview '$_fzf_preview_cmd'
"

# 5.5 fzf CTRL+T 快捷键配置
export FZF_CTRL_T_OPTS="
--preview '$_fzf_preview_cmd'
"

# ===================================================================================================
# 6. 自定义函数
# ===================================================================================================

# 6.1 文件搜索函数
f() {
  find . -iname "*${1:-}*" "${@:2}"
}

# 6.2 内容递归搜索函数
r() {
  command grep -R -- "${1:-}" "${@:2}" .
}

# 6.3 fzf 文件选择函数（输出到 /tmp，避免污染当前目录）
ff() {
  find . -type f | fzf > "/tmp/ff_selected.$$"
  echo "已选择文件已保存到 /tmp/ff_selected.$$"
}

# 6.4 ripgrep + fzf 交互式内容搜索（带预览和 vim 打开）
rgf() {
  rg --color=always --line-number --no-heading --smart-case "$@" \
  | fzf --ansi --delimiter : \
        --preview 'bat --style=numbers --color=always {1} --highlight-line {2}' \
        --bind 'enter:become(vim +{2} {1})'
}

# 6.5 ripgrep + fzf 交互式文件名搜索
rgfn() {
  rg --files "$@" | \
    fzf --preview='bat --color=always {}' \
        --bind='enter:become(vim {})'
}

# 6.6 创建目录并进入
mkcd() {
  mkdir -p "$@" && cd "$_"
}

# 6.7 Lazygit 增强（支持目录切换）
lg() {
  export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir
  lazygit "$@"
  if [ -f "$LAZYGIT_NEW_DIR_FILE" ]; then
    cd "$(cat $LAZYGIT_NEW_DIR_FILE)"
    # 使用 command rm 绕过 trash wrapper，避免临时文件污染回收站
    command rm -f "$LAZYGIT_NEW_DIR_FILE" > /dev/null
  fi
}

# 6.8 代理管理函数
setProxy() {
  export no_proxy="localhost,127.0.0.1,localaddress,.localdomain.com"
  export https_proxy="http://$PROXY_LOCAL_PATH"
  export http_proxy="http://$PROXY_LOCAL_PATH"
  export all_proxy="socks5://$PROXY_LOCAL_PATH"
  echo "✅ 代理已开启: $PROXY_LOCAL_PATH"
}

unProxy() {
  unset http_proxy https_proxy all_proxy no_proxy
  echo "✅ 代理已关闭"
}

# 6.9 Tock 时间追踪信息（用于 Starship 等提示符）
tock_info() {
  tock current --format '{{`{{.Project}}: {{.Duration}}`}}' 2>/dev/null
}

# obsidian-wiki terminal notification
# source /Users/rich1e/.local/pipx/venvs/obsidian-wiki/lib/python3.14/site-packages/obsidian_wiki/_data/scripts/wiki-notify.sh

# ===================================================================================================
# 7. 别名配置
# ===================================================================================================

# 7.1 配置文件编辑
alias editconfig="code -a $HOME/zsh-extend.sh"
alias zshconfig="code -a $HOME/.zshrc"

# 7.2 配置重载
alias reload="source ~/.zshrc"

# 7.3 目录导航
alias ..='cd ..'
alias ~="cd ~"
alias -- -="cd -"

# 7.4 系统命令增强
# （cls/ext 已删除：cls 与 Ctrl+L 重复，ext 极少使用）
# ssh 改用函数：避免 alias 劫持（如 git+ssh 内部调用），同时配置保活
ssh() { command ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=3 "$@" }
# rm 包装为 trash（第三方 trash-cli，软删除到 ~/.local/share/Trash，可恢复）
# 用函数而非 alias，避免破坏脚本中的 rm 语义；保留 command rm 作为最后兜底
rm() {
  if [[ $# -eq 0 ]]; then
    echo "用法: rm <file>..." >&2
    return 1
  fi
  # 危险参数防护：拒绝 rm -rf / 或 rm -- 选项
  if [[ "$1" == "-rf" || "$1" == "--" ]]; then
    echo "❌ 已禁止直接调用 rm，请显式使用 'command rm' 或 'trash -F' 清空回收站" >&2
    return 1
  fi
  trash "$@"
}

# 7.5 搜索增强
alias grep='grep --color'
alias egrep='egrep --color'
alias fgrep='fgrep --color'
alias ws='web_search'

# 7.6 文件操作
alias cpp='copypath'
alias cpf='copyfile'
alias dl="axel -o ~/Downloads"

# 7.7 录屏工具 (asciinema)
alias rec='asciinema rec'
alias recp='asciinema play'
alias recc='asciinema cat'
alias recup='asciinema upload'
alias reca='asciinema auth'
alias rech='asciinema -h'

# 7.8 列表命令 (eza)
alias ls='eza'
alias ll='eza -lh'
alias la='eza -lha'
alias lr='eza -lR'

# 7.9 网络工具
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias localip="ipconfig getifaddr en0"
alias ips="ifconfig -a | grep -o 'inet6\? \(addr:\)\?\s\?\(\(\([0-9]\+\.\)\{3\)[0-9]\+\)\|[a-fA-F0-9:]\+\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'"
alias ifactive="ifconfig | pcregrep -M -o '^[^\t:]+:([^\n]|\n\t)*status: active'"
alias flush="dscacheutil -flushcache && killall -HUP mDNSResponder"

# 7.10 应用程序快捷方式
alias bcompare-reset="launchctl start com.$USER_NAME.beyondcompare.reset"
alias bcreset='bcompare-reset'  # 向后兼容旧名

# ===================================================================================================
# 8. Zsh 插件加载
# 加载顺序：补全 → 功能插件 → 语法高亮（高亮必须最后加载）
# ===================================================================================================

# 8.1 zsh-completions（命令补全增强）
if [[ -d "${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src" ]]; then
  fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
fi

if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
  autoload -Uz compinit
  compinit
fi

# 8.2 zsh-autosuggestions（命令建议）
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=165"
if [[ -f "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# 8.3 autojump（智能目录跳转）
if [[ -f "$HOMEBREW_PREFIX/etc/profile.d/autojump.sh" ]]; then
  source "$HOMEBREW_PREFIX/etc/profile.d/autojump.sh"
fi

# 8.4 fzf（模糊搜索工具加载）
# 注意：必须在设置 FZF_* 环境变量之后加载
if type brew &>/dev/null; then
  FZF_SHELL_DIR="$(brew --prefix)/opt/fzf/shell"
  [[ -f "$FZF_SHELL_DIR/completion.zsh" ]] && source "$FZF_SHELL_DIR/completion.zsh"
  [[ -f "$FZF_SHELL_DIR/key-bindings.zsh" ]] && source "$FZF_SHELL_DIR/key-bindings.zsh"
fi

# 8.5 forgit（git 操作增强）
if [[ -f "$HOMEBREW_PREFIX/share/forgit/forgit.plugin.zsh" ]]; then
  source "$HOMEBREW_PREFIX/share/forgit/forgit.plugin.zsh"
fi

# 8.6 thefuck（命令纠错）
if type thefuck &>/dev/null; then
  eval $(thefuck --alias)
fi

# 8.7 navi（交互式命令备忘单）
if type navi &>/dev/null; then
  eval "$(navi widget zsh)"
fi

# 8.8 Google Cloud SDK（gcloud 命令补全）
if [[ -d "$HOMEBREW_PREFIX/share/google-cloud-sdk" ]]; then
  source "$HOMEBREW_PREFIX/share/google-cloud-sdk/completion.zsh.inc"
  source "$HOMEBREW_PREFIX/share/google-cloud-sdk/path.zsh.inc"
fi

# 8.9 iTerm2 Shell Integration（增强终端功能）
export ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX=1

if [[ -f ~/.iterm2_shell_integration.zsh ]]; then
  source ~/.iterm2_shell_integration.zsh
fi

# 8.10 zsh-autopair（自动括号补全）
if [[ -f "${HOMEBREW_PREFIX}/share/zsh-autopair/autopair.zsh" ]]; then
  source "${HOMEBREW_PREFIX}/share/zsh-autopair/autopair.zsh"
fi

# 8.11 zsh-syntax-highlighting（语法高亮）—— 必须最后加载
if [[ -f "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  ZSH_HIGHLIGHT_HIGHLIGHTERS+=(brackets pattern cursor)
fi

# ===================================================================================================
# 9. 其他工具配置
# ===================================================================================================

# 9.1 trash（安全删除工具）
if [[ -d "$HOMEBREW_PREFIX/opt/trash/bin" ]]; then
  export PATH="$HOMEBREW_PREFIX/opt/trash/bin:$PATH"
fi

# 9.2 Git（使用 Homebrew 版本）
if [[ -f "$HOMEBREW_PREFIX/bin/git" ]]; then
  export PATH="$HOMEBREW_PREFIX/bin/git:$PATH"
fi

# 9.3 web_search（自定义搜索引擎）
export ZSH_WEB_SEARCH_ENGINES=(
  bi "https://search.bilibili.com/all?keyword="
  douban "https://search.douban.com/book/subject_search?search_text="
  reddit "https://www.reddit.com/search/?q="
)

# 9.4 Docker 补全
if [[ -d "/Users/${USER_NAME}/.docker/completions" ]]; then
  fpath=(/Users/${USER_NAME}/.docker/completions $fpath)
fi

# ===================================================================================================
# 10. 快捷键绑定
# ===================================================================================================

# 10.1 ESC ESC 快速添加 sudo
sudo-command-line() {
  [[ -z $BUFFER ]] && zle up-history
  [[ $BUFFER != sudo\ * ]] && BUFFER="sudo $BUFFER"
  zle end-of-line
}
zle -N sudo-command-line
bindkey "\e\e" sudo-command-line

# 10.2 Option+J 切换自动建议
bindkey '∆' autosuggest-toggle

# 10.3 Zsh surround（Vi 模式）
# 提供类似 Vim surround.vim 的 cs / ds / ys 操作
autoload -Uz surround
zle -N delete-surround surround
zle -N add-surround surround
zle -N change-surround surround

bindkey -a cs change-surround
bindkey -a ds delete-surround
bindkey -a ys add-surround
bindkey -M visual S add-surround

# 10.4 Zsh select-quoted（Vi text object）
# 提供 i"/a"、i'/a'、i`/a` 等 Vim 风格文本对象
autoload -Uz select-quoted
zle -N select-quoted

for m in visual viopp; do
  for c in {a,i}{\',\",\`}; do
    bindkey -M $m $c select-quoted
  done
done

# 10.5 Zsh select-bracketed（Vi text object）
# 提供 i(/a)、i[/a]、i{/a}、i</a> 等 Vim 风格文本对象
autoload -U select-bracketed
zle -N select-bracketed
# ${(s..)^:-'()[]{}<>bB'} 把 '()[]{}<>bB' 拆成单字符数组，再 ^ 转大写得 'bB' 也参与
# 最终循环 i/( i/[ i/{ i/< i/b i/B 等 12 个 text object
for m in visual viopp; do
	for c in {a,i}${(s..)^:-'()[]{}<>bB'}; do
	  bindkey -M $m $c select-bracketed
	done
done

# ===================================================================================================
# 11. Zsh 行为配置
# ===================================================================================================

# 11.1 禁用 Oh My Zsh 自动更新
zstyle ':omz:update' mode disabled
zstyle ':omz:update' frequency 7

# 11.2 命令提示符初始化
autoload -U promptinit && promptinit

# 11.3 Starship 提示符
if type starship &>/dev/null; then
  STARSHIP_CONFIG=${HOME}/.config/starship.toml
  eval "$(starship init zsh)"
fi

# 11.4 inshellisense（shell 提供 IDE 风格的实时补全，600+ CLI 规范）
# 注意：inshellisense 官方要求必须放在配置最末尾，否则会被其他 init（如 starship）破坏
# reload 守卫：inshellisense 是 shell wrapper 模式（source → 启动 is daemon → exit 接管）。
# 已在 is daemon 内时（ISTERM 已设）重复 source 会破坏 daemon 状态，因此守卫跳过。
# 如需重载 inshellisense 配置，请 exit 当前会话后重新进入终端。
# 当前状态：临时禁用

# _is_init="$HOME/.local/share/inshellisense/init/zsh/init.zsh"
# [[ -z "${ISTERM}" && -f "$_is_init" ]] && source "$_is_init"

# ===================================================================================================
# 配置文件结束
# ===================================================================================================
