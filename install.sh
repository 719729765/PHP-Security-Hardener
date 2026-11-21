#!/usr/bin/env bash
# PHP Security Hardener one-click installer
# Target: aaPanel/BT-style CentOS 7 + PHP 7.4. Python 3.6+.
set -Eeuo pipefail

REPO="719729765/PHP-Security-Hardener"
TAG="v0.1.1"
PHP_ROOT="/www/server/php/74"
INSTALL_DIR="/opt/php74-security-hardener"
PROGRAM="${INSTALL_DIR}/php74_hardener.py"
WORK_ROOT="/var/tmp/php-security-hardener-installer"
MODE="interactive"

usage() {
  cat <<'EOF'
PHP Security Hardener 一键安装器

用法：
  bash install.sh                 安装、扫描，然后询问是否立即加固（默认不加固）
  bash install.sh --scan-only     安装并扫描，不修改 PHP 配置
  bash install.sh --apply         安装后立即备份、加固并重载 PHP-FPM
  bash install.sh --yes           等同 --apply
  bash install.sh --status        对已安装版本执行只读扫描
  bash install.sh --rollback      回滚最近一次加固前的配置备份
  bash install.sh --version TAG   指定 GitHub Release 标签（默认 v0.1.1）
  bash install.sh --help          显示帮助

默认目标：/www/server/php/74
安装目录：/opt/php74-security-hardener
备份目录：/root/php74-hardener-backups

注意：--apply/--yes 会修改 php.ini 和 php-fpm.conf，并平滑重载 PHP-FPM。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scan-only) MODE="scan"; shift ;;
    --apply|--yes) MODE="apply"; shift ;;
    --status) MODE="status"; shift ;;
    --rollback) MODE="rollback"; shift ;;
    --version)
      [[ $# -ge 2 ]] || { echo "错误：--version 后需要 Release 标签" >&2; exit 2; }
      TAG="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 2 ;;
  esac
done

say() { printf '\n[PHP Hardener] %s\n' "$*"; }
die() { printf '\n[错误] %s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || die "请使用 root 用户运行。"
[[ -d "$PHP_ROOT" ]] || die "没有找到宝塔 PHP 7.4 目录：$PHP_ROOT。此安装器当前只适配该目录。"
command -v python3 >/dev/null 2>&1 || die "没有找到 python3。请先安装 Python 3.6 或更高版本。"
command -v curl >/dev/null 2>&1 || die "缺少 curl，请先安装 curl。"
command -v unzip >/dev/null 2>&1 || die "缺少 unzip，请先安装 unzip。"

PYTHON="$(command -v python3)"
"$PYTHON" - <<'PY' || die "Python 版本过低，需要 Python 3.6 或更高版本。"
import sys
sys.exit(0 if sys.version_info >= (3, 6) else 1)
PY

mkdir -p "$INSTALL_DIR" "$WORK_ROOT"
chmod 700 "$WORK_ROOT"

# Existing install management commands do not need a network connection.
if [[ "$MODE" == "status" || "$MODE" == "rollback" ]]; then
  [[ -f "$PROGRAM" ]] || die "尚未安装程序，请先运行 bash install.sh。"
  if [[ "$MODE" == "status" ]]; then
    exec "$PYTHON" "$PROGRAM" --scan
  else
    say "准备回滚最近一次 PHP 配置加固。"
    exec "$PYTHON" "$PROGRAM" --rollback
  fi
fi

# Confirm the target PHP 7.4 runtime layout before downloading.
for f in "$PHP_ROOT/bin/php" "$PHP_ROOT/sbin/php-fpm" "$PHP_ROOT/etc/php.ini" "$PHP_ROOT/etc/php-fpm.conf" /etc/init.d/php-fpm-74; do
  [[ -e "$f" ]] || die "目标环境缺少文件：$f。未执行任何 PHP 配置修改。"
done

command -v sha256sum >/dev/null 2>&1 || die "缺少 sha256sum，无法校验下载文件。"

TMP_DIR="$(mktemp -d "${WORK_ROOT}/run.XXXXXX")"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

API_URL="https://api.github.com/repos/${REPO}/releases/tags/${TAG}"
say "正在获取 GitHub Release：${REPO} ${TAG}"
if ! curl -fsSL --retry 2 --connect-timeout 15 --max-time 90 \
  -H 'Accept: application/vnd.github+json' \
  -H 'User-Agent: PHP-Security-Hardener-Installer' \
  "$API_URL" -o "$TMP_DIR/release.json"; then
  die "无法访问 GitHub Release API。请检查服务器网络，或稍后重试。"
fi

# Select the project ZIP asset, not GitHub's automatically generated source archives.
ASSET_META="$($PYTHON - "$TMP_DIR/release.json" "$TAG" <<'PY'
import json, os, sys
path, tag = sys.argv[1:3]
try:
    data = json.load(open(path, 'r'))
except Exception as exc:
    sys.stderr.write('Release JSON 解析失败：%s\n' % exc)
    sys.exit(1)
assets = data.get('assets') or []
valid = [a for a in assets if str(a.get('name', '')).lower().endswith('.zip')]
# Prefer the exact project archive; then a project-named ZIP. Exclude source-code ZIPs.
preferred = []
for a in valid:
    n = str(a.get('name', '')).lower()
    if 'php74-security-hardener' in n or 'php-security-hardener' in n:
        preferred.append(a)
if not preferred:
    sys.stderr.write('Release %s 没有找到项目 ZIP 资产。当前资产：\n' % tag)
    for a in assets:
        sys.stderr.write(' - %s\n' % a.get('name', '(unnamed)'))
    sys.exit(2)
preferred.sort(key=lambda a: (0 if str(a.get('name','')).lower() == ('php74-security-hardener-' + tag + '.zip').lower() else 1,
                              str(a.get('name',''))))
a = preferred[0]
url = a.get('browser_download_url') or ''
size = int(a.get('size') or 0)
digest = a.get('digest') or ''
if not url.startswith('https://github.com/'):
    sys.stderr.write('Release 资产下载地址异常。\n')
    sys.exit(3)
print('%s\t%d\t%s\t%s' % (a.get('name',''), size, digest, url))
PY
)" || die "无法识别 Release ZIP 资产。请检查 GitHub Release 是否上传了项目 ZIP。"

ASSET_NAME="$(printf '%s' "$ASSET_META" | cut -f1)"
EXPECTED_SIZE="$(printf '%s' "$ASSET_META" | cut -f2)"
ASSET_DIGEST="$(printf '%s' "$ASSET_META" | cut -f3)"
ASSET_URL="$(printf '%s' "$ASSET_META" | cut -f4)"
ZIP_PATH="$TMP_DIR/$ASSET_NAME"

say "选中 Release 资产：$ASSET_NAME"
say "正在下载，请稍候……"
curl -fL --retry 2 --connect-timeout 15 --max-time 180 \
  -H 'User-Agent: PHP-Security-Hardener-Installer' \
  "$ASSET_URL" -o "$ZIP_PATH" || die "下载 Release ZIP 失败。"

ACTUAL_SIZE="$(wc -c < "$ZIP_PATH" | tr -d ' ')"
if [[ "$EXPECTED_SIZE" -gt 0 && "$ACTUAL_SIZE" -ne "$EXPECTED_SIZE" ]]; then
  die "下载文件大小校验失败（预期 ${EXPECTED_SIZE}，实际 ${ACTUAL_SIZE} 字节）。"
fi
ACTUAL_SHA="$(sha256sum "$ZIP_PATH" | awk '{print $1}')"
PINNED_SHA=""
if [[ "$TAG" == "v0.1.1" && "$ASSET_NAME" == "PHP74-Security-Hardener-v0.1.1.zip" ]]; then
  # Published checksum shown on the v0.1.1 GitHub Release page.
  PINNED_SHA="2791b6ef92a511acde7abb505af08e31eb7a04cf047f4f2e0f166ac15aa6af83"
fi
if [[ -n "$PINNED_SHA" ]]; then
  [[ "$ACTUAL_SHA" == "$PINNED_SHA" ]] || die "v0.1.1 固定 SHA256 校验失败，拒绝安装。"
  if [[ "$ASSET_DIGEST" == sha256:* && "${ASSET_DIGEST#sha256:}" != "$PINNED_SHA" ]]; then
    die "GitHub API 摘要与已固定的 v0.1.1 SHA256 不一致，拒绝安装。"
  fi
  say "v0.1.1 固定 SHA256 校验通过。"
elif [[ "$ASSET_DIGEST" == sha256:* ]]; then
  EXPECTED_SHA="${ASSET_DIGEST#sha256:}"
  [[ "$ACTUAL_SHA" == "$EXPECTED_SHA" ]] || die "SHA256 校验失败，拒绝安装。"
  say "GitHub Release SHA256 校验通过。"
else
  say "GitHub Release 未提供 SHA256 摘要，已完成资产大小校验及 ZIP 内容检查。"
fi

unzip -tq "$ZIP_PATH" >/dev/null || die "ZIP 文件损坏，拒绝安装。"
# Reject archive entries which could escape the extraction directory.
if unzip -Z1 "$ZIP_PATH" | awk 'BEGIN{bad=0} /^\// {bad=1} /(^|\/)\.\.($|\/)/ {bad=1} END{exit bad?0:1}'; then
  die "ZIP 内含不安全路径，拒绝解压。"
fi
mkdir -p "$TMP_DIR/extracted"
unzip -q "$ZIP_PATH" -d "$TMP_DIR/extracted"
SOURCE_PROGRAM="$(find "$TMP_DIR/extracted" -type f -name 'php74_hardener.py' -print -quit)"
[[ -n "$SOURCE_PROGRAM" ]] || die "ZIP 中没有找到 php74_hardener.py。"

"$PYTHON" -m py_compile "$SOURCE_PROGRAM" || die "Python 程序语法检查失败。"
"$PYTHON" "$SOURCE_PROGRAM" --help >/dev/null 2>&1 || die "程序命令行自检失败。"

# Back up an older installed copy before replacing the program itself.
if [[ -f "$PROGRAM" ]]; then
  OLD_BACKUP="${PROGRAM}.previous.$(date +%Y%m%d-%H%M%S)"
  cp -a "$PROGRAM" "$OLD_BACKUP"
  say "已备份旧版程序：$OLD_BACKUP"
fi
install -m 750 "$SOURCE_PROGRAM" "$PROGRAM"
printf '%s\n' "$TAG" > "$INSTALL_DIR/VERSION"
chmod 640 "$INSTALL_DIR/VERSION"

say "程序已安装：$PROGRAM"
say "正在执行 PHP 7.4 只读安全扫描（不会修改 PHP 配置）……"
set +e
"$PYTHON" "$PROGRAM" --scan
SCAN_RC=$?
set -e
if [[ "$SCAN_RC" -ne 0 ]]; then
  die "扫描未能正常完成（退出码 $SCAN_RC）。没有执行 PHP 配置修改。"
fi

if [[ "$MODE" == "scan" ]]; then
  say "扫描完成。没有修改 PHP 配置，也没有重载 PHP-FPM。"
  say "需要正式加固时执行：$PYTHON $PROGRAM --apply"
  exit 0
fi

if [[ "$MODE" == "apply" ]]; then
  DO_APPLY="yes"
elif [[ -t 0 ]]; then
  printf '\n是否现在执行低风险加固？\n'
  printf '将备份 php.ini/php-fpm.conf，修改配置并平滑重载 PHP-FPM。\n'
  printf '建议先确认网站有维护窗口。输入 YES 才会继续：'
  read -r ANSWER
  [[ "$ANSWER" == "YES" ]] && DO_APPLY="yes" || DO_APPLY="no"
else
  DO_APPLY="no"
fi

if [[ "$DO_APPLY" == "yes" ]]; then
  say "开始执行加固。程序将自动备份、测试配置、重载并验证；失败会尝试恢复。"
  "$PYTHON" "$PROGRAM" --apply
  exit $?
else
  say "已完成安装和只读扫描；没有修改 PHP 配置，也没有重载 PHP-FPM。"
  say "正式加固命令：$PYTHON $PROGRAM --apply"
  say "回滚命令：$PYTHON $PROGRAM --rollback"
fi
