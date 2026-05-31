# Claude Code Windows 一键安装服务

这是一个面向 Windows 用户的 Claude Code 一键安装脚本。目标是让用户复制一行 PowerShell 命令即可完成安装、PATH 配置、安装验证，并获得 cc-switch/第三方模型渠道的本地配置引导。

## 用户一键命令

把 `<你的GitHub用户名>` 替换成发布该仓库的 GitHub 用户名或组织名：

```powershell
irm https://raw.githubusercontent.com/<你的GitHub用户名>/claude-code-onekey/main/install.ps1 | iex
```

如果用户只想安装本体并跳过菜单：

```powershell
iex "& { $(irm https://raw.githubusercontent.com/<你的GitHub用户名>/claude-code-onekey/main/install.ps1) } -SkipMenu"
```

## 脚本做什么

- 检查 Windows、64 位系统、64 位 PowerShell、PowerShell 版本。
- 启用 TLS 1.2，检查 Claude Code 发布端点可访问。
- 从 Anthropic Claude Code 官方 GCS 发布地址获取 latest、manifest 和 Windows 二进制。
- 校验下载文件大小和 SHA256。
- 安装到当前用户目录：
  - `%USERPROFILE%\.local\share\claude\versions`
  - `%USERPROFILE%\.local\bin\claude.exe`
- 备份并更新 `%USERPROFILE%\.claude.json`。
- 写入用户级 PATH，并在当前 PowerShell 会话临时追加 PATH。
- 运行 `claude --version` 验证安装。
- 安装后显示菜单：
  - 只安装本体
  - 配置 cc-switch
  - 展示第三方 API 渠道配置引导

## 安全边界

- 脚本不会收集、上传或保存用户 API Key。
- 第三方渠道只做本地配置引导，用户应在 cc-switch 或自己的本地配置工具里输入 Key。
- 脚本不会绕过网络限制；如果官方发布地址不可达，会给出清晰错误提示。
- 脚本不需要管理员权限，只安装到当前用户目录。

## 发布步骤

1. 在 GitHub 新建仓库：`claude-code-onekey`。
2. 上传 `install.ps1` 和 `README.md` 到仓库根目录。
3. 打开 Raw URL，确认内容可访问：

   ```text
   https://raw.githubusercontent.com/<你的GitHub用户名>/claude-code-onekey/main/install.ps1
   ```

4. 用一台干净 Windows 11 测试机运行：

   ```powershell
   irm https://raw.githubusercontent.com/<你的GitHub用户名>/claude-code-onekey/main/install.ps1 | iex
   ```

5. 验证：

   ```powershell
   claude --version
   ```

## 常见排错

### 32 位 PowerShell

提示 `You are running 32-bit PowerShell on 64-bit Windows` 时，让用户从开始菜单打开正常的 Windows PowerShell，而不是 `Windows PowerShell (x86)`。

### 网络失败

脚本需要访问：

```text
https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases
```

如果失败，通常是网络、代理或防火墙问题。让用户截图安装脚本里显示的红色错误信息即可。

### 安装完成但找不到 claude

让用户关闭并重新打开 PowerShell，然后运行：

```powershell
claude --version
```

如果仍然失败，让用户把终端里的错误信息截图发回即可。

## 测试矩阵

- Windows 11 x64 + Windows PowerShell 5.1。
- Windows 11 x64 + PowerShell 7。
- Windows ARM64。
- 普通用户权限，无管理员权限。
- 重复运行安装脚本。
- 已存在 `.claude.json` 的环境。
- 网络失败、下载失败、SHA256 校验失败场景。
