#!/usr/bin/env bash
# tiny-scripts installer
# Usage:
#   ./install.sh                    # 交互式安装
#   ./install.sh -y                # 安装全部
#   ./install.sh shpi              # 安装指定脚本
#   curl -fsSL https://pi.dev/install.sh | bash -s -- -y  # 远程静默安装

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_URL="${REPO_URL:-https://raw.githubusercontent.com/Pinellia451/tiny-Scripts/main}"
INSTALL_DIR="$HOME/.local/share/tiny-scripts"
SCRIPTS=(shpi)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }

# 检测 shell配置文件
detect_rc_file() {
  local shell_name
  shell_name=$(basename "$SHELL")
  case "$shell_name" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash) 
      [[ -f "$HOME/.bashrc" ]] && echo "$HOME/.bashrc" || echo "$HOME/.bash_profile"
      ;;
    *)    echo "$HOME/.profile" ;;
  esac
}

# 从本地或远程获取脚本内容
fetch_script() {
  local name="$1"
  local local_path="${SCRIPT_DIR}/scripts/${name}.sh"
  
  if [[ -f "$local_path" ]]; then
    cat "$local_path"
  else
    curl -fsSL "${REPO_URL}/scripts/${name}.sh" 2>/dev/null || return 1
  fi
}

# 安装单个脚本
install_script() {
  local name="$1"
  local dest="$INSTALL_DIR/${name}.sh"
  
  info "安装 ${name}.sh ..."
  
  local content
  if ! content=$(fetch_script "$name"); then
    error "无法获取 ${name}.sh"
    return 1
  fi
  
  mkdir -p "$INSTALL_DIR"
  echo "$content" > "$dest"
  chmod +x "$dest"
  success "已安装到 $dest"
}

# 更新 shell配置
update_rc() {
  local rc_file
  rc_file=$(detect_rc_file)
  
  local load_block="# tiny-scripts
if [[ -d \"$INSTALL_DIR\" ]]; then
  for script in \"$INSTALL_DIR\"/*.sh; do
    [[ -f \"\$script\" ]] && source \"\$script\"
  done
fi"
  
  # 移除旧配置
  if [[ -f "$rc_file" ]]; then
    # 使用 awk 移除 tiny-scripts 块
    awk '/^# tiny-scripts$/,/^fi$/' "$rc_file" | grep -q "tiny-scripts" && {
      local tmp="$rc_file.tmp.$$"
      awk '/^# tiny-scripts$/{skip=1} /^fi$/ && skip{skip=0;next} !skip{print}' "$rc_file" > "$tmp"
      mv "$tmp" "$rc_file"
    }
  fi
  
  # 追加新配置
  echo "" >> "$rc_file"
  echo "$load_block" >> "$rc_file"
  success "已更新 $rc_file"
}

# 显示菜单
show_menu() {
  echo ""
  echo -e "${CYAN}📦 tiny-scripts 安装器${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "可安装的脚本:"
  
  local i=1
  for name in "${SCRIPTS[@]}"; do
    local status=""
    [[ -f "$INSTALL_DIR/${name}.sh" ]] && status="${GREEN}[已安装]${NC}" || status="${YELLOW}[未安装]${NC}"
    echo -e "  ${CYAN}$i)${NC} $name  $status"
    ((i++))
  done
  
  echo ""
  echo -e "  ${CYAN}a)${NC} 全部安装"
  echo -e "  ${CYAN}q)${NC} 退出"
  echo ""
}

# 交互模式
interactive_mode() {
  while true; do
    show_menu
    read -rp "请选择 [1-${#SCRIPTS[@]}/a/q]: " choice
    
    case "$choice" in
      q|Q) 
        info "已退出"
        exit 0
        ;;
      a|A)
        for name in "${SCRIPTS[@]}"; do
          install_script "$name"
        done
        update_rc
        echo ""
        success "全部安装完成！"
        echo -e "运行 ${CYAN}source $(detect_rc_file)${NC} 或重新打开终端生效"
        exit 0
        ;;
      [0-9]*)
        if (( choice >= 1 && choice <= ${#SCRIPTS[@]} )); then
          local selected="${SCRIPTS[$((choice-1))]}"
          install_script "$selected"
          update_rc
          echo ""
          success "安装完成！"
          echo -e "运行 ${CYAN}source $(detect_rc_file)${NC} 或重新打开终端生效"
          exit 0
        else
          warn "无效选择"
        fi
        ;;
      *)
        warn "无效选择"
        ;;
    esac
  done
}

# 解析参数
YES_MODE=false
TARGET_SCRIPTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) YES_MODE=true; shift ;;
    -h|--help)
      echo "用法: install.sh [选项] [脚本名...]"
      echo "  -y, --yes    静默安装全部"
      echo "  -h, --help   显示帮助"
      echo ""
      echo "示例:"
      echo "  ./install.sh              # 交互式"
      echo "  ./install.sh -y          # 全部安装"
      echo "  ./install.sh shpi        # 安装指定脚本"
      exit 0
      ;;
    *)
      # 检查是否是有效脚本名
      valid=false
      for name in "${SCRIPTS[@]}"; do
        [[ "$1" == "$name" ]] && valid=true && break
      done
      if $valid; then
        TARGET_SCRIPTS+=("$1")
      else
        warn "未知脚本: $1"
      fi
      shift
      ;;
  esac
done

# 主逻辑
if $YES_MODE; then
  # 静默模式：安装全部
  for name in "${SCRIPTS[@]}"; do
    install_script "$name"
  done
  update_rc
  success "全部安装完成！"
elif [[ ${#TARGET_SCRIPTS[@]} -gt 0 ]]; then
  # 指定脚本模式
  for name in "${TARGET_SCRIPTS[@]}"; do
    install_script "$name"
  done
  update_rc
  success "安装完成！"
else
  # 交互模式
  interactive_mode
fi
