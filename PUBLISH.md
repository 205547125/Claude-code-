# 发布清单

## 仓库

仓库名固定为：

```text
claude-code-onekey
```

需要上传的文件：

```text
install.ps1
README.md
PUBLISH.md
```

## 用户端文案

Windows 用户复制下面一行到 PowerShell：

```powershell
irm https://raw.githubusercontent.com/<你的GitHub用户名>/claude-code-onekey/main/install.ps1 | iex
```

安装完成后，如果提示找不到 `claude`，关闭并重新打开 PowerShell，再执行：

```powershell
claude --version
```

## 客服排错

让用户重新运行安装命令，并把终端里的红色错误信息截图发回即可。
