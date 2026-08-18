# tiny-scripts

一组轻量级 Shell 脚本集合，提供交互式安装器与开箱即用的命令行工具。

## 脚本列表

| 脚本 | 说明 |
| --- | --- |
| `shpi` | AI 命令生成器：环境感知 + JSON 输出，把自然语言描述转成可直接执行的 shell 命令 |

## 快速开始

### 方式一：交互式安装

```bash
git clone https://github.com/Pinellia451/tiny-Scripts.git
cd tiny-Scripts
./install.sh
```

### 方式二：远程静默安装

```bash
curl -fsSL https://raw.githubusercontent.com/Pinellia451/tiny-Scripts/main/install.sh | bash -s -- -y
```

安装完成后，运行 `source ~/.zshrc`（或对应 shell 配置文件），或重新打开终端即可生效。

## 安装器用法

```bash
./install.sh                    # 交互式安装（菜单选择）
./install.sh -y                 # 静默安装全部脚本
./install.sh shpi               # 只安装指定脚本
./install.sh -h                 # 查看帮助
```

脚本会安装到 `~/.local/share/tiny-scripts/`，并在 shell 配置文件中自动追加加载配置，便于后续更新。

## shpi 使用示例

`shpi` 是环境感知的 AI 命令生成器，基于当前操作系统、架构、Shell 和已安装工具自动生成贴合环境的命令：

```bash
shpi 查看当前目录下最大的 5 个文件    # 复用上下文
shpi -n 列出所有 docker 容器          # 重置后新对话
shpi -r                               # 刷新环境缓存
shpi --version                        # 查看版本
```

生成结果会直接插入当前命令行，按回车即可执行。

## 目录结构

```
tiny-scripts/
├── install.sh        # 交互式安装器
├── scripts/
│   └── shpi.sh       # AI 命令生成器
└── README.md
```

## License

MIT
