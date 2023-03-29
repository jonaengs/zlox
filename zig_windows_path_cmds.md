Paste into powershell:
```
[Environment]::SetEnvironmentVariable(
   "Path",
   [Environment]::GetEnvironmentVariable("Path", "User") + ";C:\Users\jonatan\code\zig\zig-windows-x86_64-0.10.1",
   "User"
)
```

Or as admin:
```
[Environment]::SetEnvironmentVariable(
   "Path",
   [Environment]::GetEnvironmentVariable("Path", "Machine") + ";C:\Users\jonatan\code\zig\zig-windows-x86_64-0.10.1",
   "Machine"
)
```
