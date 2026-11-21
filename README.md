# PHP Security Hardener v0.1.1 一键安装器

适配宝塔风格 CentOS 7 + PHP 7.4，支持 Python 3.6+。

## v0.1.1 修复

修复 v0.1.0 将 `php-fpm -tt` 输出中未回显 `php_admin_flag[...]` 误判为配置无效的问题。新版安装器默认下载并校验 `PHP74-Security-Hardener-v0.1.1.zip`。

## 一键安装

将 `install.sh` 上传到 GitHub 仓库根目录 `main` 分支后，执行：

```bash
curl -fsSL -o /root/install-php-hardener.sh https://raw.githubusercontent.com/719729765/PHP-Security-Hardener/main/install.sh && bash /root/install-php-hardener.sh
```

默认下载程序、安装、只读扫描，然后询问是否执行加固。输入大写 `YES` 才会修改 PHP 配置并 reload PHP-FPM。

## 参数

```bash
bash install.sh --scan-only
bash install.sh --apply
bash install.sh --status
bash install.sh --rollback
```

安装目录：`/opt/php74-security-hardener/`
备份目录：`/root/php74-hardener-backups/`

首次运行前请先阅读扫描报告，并确保有维护窗口及可用备份。
