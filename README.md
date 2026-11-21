# PHP Security Hardener 一键安装器

适配项目：`719729765/PHP-Security-Hardener`  
默认 Release：`v0.1.0`  
目标环境：宝塔风格目录 `/www/server/php/74`、CentOS 7、Python 3.6+

## 1. 安装器做什么

`install.sh` 会自动：

1. 检查 root 权限、Python 3.6+、curl、unzip 和宝塔 PHP 7.4 文件布局。
2. 通过 GitHub Release API 查找 `v0.1.0` 的项目 ZIP 资产，不依赖手写下载文件名。
3. 下载并校验文件大小；Release 提供 SHA256 digest 时同时验证 SHA256。
4. 检查 ZIP 完整性及压缩包路径，提取 `php74_hardener.py`。
5. 安装到 `/opt/php74-security-hardener/`。
6. 运行只读扫描。
7. 交互模式下明确询问是否执行加固；必须输入大写 `YES` 才会修改 PHP 配置。

默认行为不会直接修改 PHP 配置。执行正式加固需要明确确认；加固程序会备份 `php.ini` 和 `php-fpm.conf`、测试 FPM 配置、平滑重载并进行验证，失败时尝试恢复。

## 2. 发布安装脚本

将 `install.sh` 上传到 GitHub 仓库根目录：

`https://github.com/719729765/PHP-Security-Hardener`

提交到 `main` 分支。确认这个地址可以打开：

`https://raw.githubusercontent.com/719729765/PHP-Security-Hardener/main/install.sh`

## 3. 一键安装命令

SSH 使用 root 登录后复制执行：

```bash
curl -fsSL -o /root/install-php-hardener.sh https://raw.githubusercontent.com/719729765/PHP-Security-Hardener/main/install.sh && bash /root/install-php-hardener.sh
```

安装器首先扫描并显示结果。只有输入大写 `YES` 才执行正式加固；按回车或输入其他内容都只完成安装和扫描。

## 4. 常用参数

```bash
# 安装并只读扫描，不询问、不修改 PHP 配置
bash /root/install-php-hardener.sh --scan-only

# 安装后立即执行正式加固（会修改配置并平滑重载 PHP-FPM）
bash /root/install-php-hardener.sh --apply

# --yes 等同 --apply
bash /root/install-php-hardener.sh --yes

# 扫描已安装版本
bash /root/install-php-hardener.sh --status

# 回滚最近一次加固前的配置备份
bash /root/install-php-hardener.sh --rollback

# 指定其他 Release 标签
bash /root/install-php-hardener.sh --version v0.1.0
```

## 5. 安装位置与备份

- 程序：`/opt/php74-security-hardener/php74_hardener.py`
- 安装版本：`/opt/php74-security-hardener/VERSION`
- 配置备份：`/root/php74-hardener-backups/`
- 临时下载目录：`/var/tmp/php-security-hardener-installer/`（每次运行结束后清理本次临时目录）

## 6. 当前适配范围

当前 v0.1.0 加固程序是针对 `/www/server/php/74` 的宝塔 PHP 7.4 专用版本，不会自动修改其他 PHP 版本，也不会自动升级 PHP 或操作系统。对于不符合目录布局的服务器，脚本会停止并提示，不会猜测配置路径。

加固不是源码安全补丁的替代品。PHP 7.4 与 CentOS 7 均已结束常规官方支持，生产环境仍应规划迁移到受支持的操作系统和 PHP 分支。
