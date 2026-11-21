# PHP Security Hardener 一键安装器（自动获取最新稳定版）

适用目标：宝塔风格 PHP 7.4 安装目录 `/www/server/php/74`，Python 3.6+，CentOS 7 / RHEL 类系统。

## 固定的一键命令

先将本目录中的 `install.sh` 上传并提交到 GitHub 仓库 `719729765/PHP-Security-Hardener` 的 `main` 分支根目录，覆盖旧版 `install.sh`。然后用户执行：

```bash
curl -fsSL -o /root/install-php-hardener.sh https://raw.githubusercontent.com/719729765/PHP-Security-Hardener/main/install.sh && bash /root/install-php-hardener.sh
```

脚本会调用 GitHub `releases/latest` API，获取最新发布的正式 Release（GitHub API 不返回 draft 和 prerelease），识别项目 ZIP 资产并校验 SHA256，再安装与扫描。默认交互模式只有输入大写 `YES` 才会运行 `--apply`。

## 常用参数

```bash
bash /root/install-php-hardener.sh --scan-only
bash /root/install-php-hardener.sh --apply
bash /root/install-php-hardener.sh --status
bash /root/install-php-hardener.sh --rollback
bash /root/install-php-hardener.sh --version v0.1.1
```

## 发布新版本要求

1. 发布一个正式 GitHub Release，不要标记为 prerelease 或 draft。
2. 上传名称类似 `PHP74-Security-Hardener-vX.Y.Z.zip` 的项目 ZIP。
3. 确保 Release ZIP 有 SHA256 digest（GitHub Release API 的 asset `digest` 字段）。若无 digest，安装器会拒绝安装，避免无完整性校验地执行下载代码。
4. 把新版 `install.sh` 提交到 `main` 根目录。用户的一键命令无需变化。

## 安全行为

- 要求 root 运行；检查目标 PHP 7.4 文件布局和 Python 版本。
- 默认获取最新稳定 Release；也支持 `--version TAG` 固定版本。
- 下载后校验文件大小、SHA256 和 ZIP 完整性，并拒绝 ZIP 路径穿越条目。
- 自动备份已有加固器程序，再替换程序并执行只读扫描。
- 默认交互模式不会直接加固；只有输入 `YES` 或指定 `--apply/--yes` 才会修改 PHP 配置并重载 PHP-FPM。
- `--status` / `--rollback` 使用本地已安装程序，不访问网络。
