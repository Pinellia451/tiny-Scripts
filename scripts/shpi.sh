# shpi — AI 命令生成器（环境感知 + JSON 输出）
#
# shpi xxxxx       → 复用上下文
# shpi -n xxxxx    → 重置后新对话
# shpi -r          → 刷新环境缓存
# shpi --version   → 查看版本

# 从 pi 的 JSON 输出中提取 cmd（jq 优先，缺失时用 python3 / node 兜底）
_shpi_parse_json_cmd() {
  local raw="$1" json out=""
  # 提取第一个 { 到最后一个 } 之间的 JSON 片段（容错围栏/前导文本/尾随注释）
  json=$(printf '%s' "$raw" | grep -o '{.*}' | head -1)
  [[ -z "$json" ]] && { printf '%s' ''; return; }
  if command -v jq &>/dev/null; then
    out=$(printf '%s' "$json" | jq -r '.cmd' 2>/dev/null)
  elif command -v python3 &>/dev/null; then
    out=$(printf '%s' "$json" | python3 -c 'import sys,json;print(json.load(sys.stdin)["cmd"])' 2>/dev/null)
  elif command -v node &>/dev/null; then
    out=$(printf '%s' "$json" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).cmd)}catch(e){}})' 2>/dev/null)
  fi
  printf '%s' "$out"
}

# 把命令插入当前命令行：zsh 用 print -z；bash 用 READLINE_LINE + 历史记录
_shpi_insert_line() {
  local cmd="$1"
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    print -z "$cmd"
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    READLINE_LINE="$cmd"           # 经 bind -x 绑定时生效
    READLINE_POINT=${#cmd}
    history -s "$cmd" 2>/dev/null  # 直接调用时至少进入历史，按 ↑ 取用
    echo "📋 $cmd"
  else
    echo "📋 $cmd"
  fi
}

shpi() {
  local SHPI_VERSION="1.2"
  local _shell_name="bash"
  [[ -n "${ZSH_VERSION:-}" ]] && _shell_name="zsh"

  # spinner 是内部实现，不应出现在交互 shell 的作业列表或提示中。
  # zsh 的 LOCAL_OPTIONS 会在函数返回时自动恢复。
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    setopt localoptions nomonitor
  fi

  case "$1" in
    --version) echo "shpi $SHPI_VERSION"; return 0 ;;
  esac

  if [[ -z "$SHPI_ENV_CACHE" ]]; then
    local _os _arch _shell _pm _tools="" _distro=""
    # 跨平台 OS 检测：macOS 用 sw_vers，Linux 用 /etc/os-release，其余用 uname
    if [[ "$(uname -s)" == "Darwin" ]]; then
      _distro="$(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
    elif [[ -f /etc/os-release ]]; then
      _distro="$(. /etc/os-release && echo "$PRETTY_NAME")"
    fi
    _os="$(uname -s) ${_distro:-$(uname -r)}"
    _arch="$(uname -m)"
    _shell="$_shell_name ${ZSH_VERSION:-${BASH_VERSION:-unknown}}"
    _pm=""
    command -v brew &>/dev/null && _pm+="brew, "
    command -v micromamba &>/dev/null && _pm+="micromamba, "
    command -v conda &>/dev/null && _pm+="conda, "
    command -v fnm &>/dev/null && _pm+="fnm, "
    command -v pip3 &>/dev/null && _pm+="pip3, "
    command -v npm &>/dev/null && _pm+="npm"
    for t in jq git rg python3 node; do
      command -v "$t" &>/dev/null && _tools+="$t, "
    done
    _tools="${_tools%, }"
    SHPI_ENV_CACHE="OS: ${_os}; Arch: ${_arch}; Shell: ${_shell}; PkgMgr: ${_pm}; Tools: ${_tools}"
  fi

  local PI_PROMPT
  PI_PROMPT=$(cat <<PROMPT
You are a shell command generator.
Environment: ${SHPI_ENV_CACHE}

Rules:
1. Output ONLY a JSON object, nothing else. Format: {"cmd":"the command here"}
2. NEVER execute the command. Your job is to provide the command text only
3. NEVER describe, explain, or predict what the command outputs or what will happen after running it
4. The command must be a single executable line for ${_shell_name}
5. CRITICAL for ${_shell_name}: ALL jq expressions, glob patterns, and special chars [] {} () ~ ! # MUST be escaped or quoted inside the JSON string
   Example: {"cmd":"jq -r '.envs[]' | while read -r env; do du -sh \"\$env\"; done | sort -hr"}
6. Prefer single quotes inside the command for string literals
7. Chain multi-step tasks with &&
PROMPT
)

  case "$1" in
    -r) unset SHPI_ENV_CACHE; echo "🔄 环境缓存已刷新"; return 0 ;;
    -n) shift; rm -f /tmp/.pi-shpi-session 2>/dev/null ;;
  esac
  [[ -z "$*" ]] && { echo "用法: shpi [-n|-r] <描述>"; return 0; }

  local PI_SESSION="/tmp/.pi-shpi-session"
  local args=(-p --system-prompt "$PI_PROMPT" --session "$PI_SESSION")
  [[ -f "$PI_SESSION" ]] && args+=(--continue)

  local raw cmd
  # 加载动画（六个点转圈）
  local spin_chars=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  local spin_pid=""
  
  # 清理函数
  _shpi_cleanup() {
    if [[ -n "$spin_pid" ]]; then
      kill "$spin_pid" 2>/dev/null
      wait "$spin_pid" 2>/dev/null
      spin_pid=""
    fi
    printf "\r%*s\r" 20 ""
  }
  trap _shpi_cleanup EXIT INT TERM
  
  # bash 会为每个后台任务立即打印作业编号，因此只显示静态提示。
  # zsh 使用函数本地的 nomonitor 选项，既保留动画也不会泄漏作业提示。
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    (
      while true; do
        for char in "${spin_chars[@]}"; do
          printf "\r%s" "$char"
          sleep 0.08
        done
      done
    ) 2>/dev/null &
    spin_pid=$!
  else
    printf "\r"
  fi

  raw=$(pi "${args[@]}" "$*" 2>/dev/null)
  
  # 停止动画
  _shpi_cleanup
  trap - EXIT INT TERM

  cmd=$(_shpi_parse_json_cmd "$raw")

  [[ -z "$cmd" || "$cmd" == "null" ]] && { echo "❌ 未生成命令"; echo "$raw"; return 1; }
  _shpi_insert_line "$cmd"
}
