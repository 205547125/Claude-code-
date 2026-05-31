# Publish Checklist

Repository:

```text
https://github.com/205547125/Claude-code-
```

Files to publish:

```text
install.ps1
README.md
PUBLISH.md
```

Primary user command:

```powershell
irm https://raw.githubusercontent.com/205547125/Claude-code-/main/install.ps1 | iex
```

Mainland China fallback entry:

```powershell
irm https://cdn.jsdelivr.net/gh/205547125/Claude-code-@main/install.ps1 | iex
```

Post-install verification:

```powershell
claude --version
```

Support workflow:

Ask users to rerun the install command and send a screenshot of the red terminal
error message. Do not ask users to send their API key.
