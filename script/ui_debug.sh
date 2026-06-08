#!/bin/bash
set -euo pipefail

APP_NAME="Codex Switch"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL=false
OPEN_APP=true
OPEN_PREVIEW=false
BUILD_PREVIEW=false

usage() {
    cat <<'EOF'
用法: script/ui_debug.sh [选项]

选项:
  --local          构建并重启本地 app bundle，这是默认行为。
  --install        构建后复制到 /Applications 并启动。
  --preview        打开 Xcode Canvas 专用的 PreviewPackage。
  --build-preview  构建 PreviewPackage，用于提前发现 Canvas 编译错误。
  --no-open        只构建，不启动应用。
  -h, --help       显示帮助。

常用流程:
  script/ui_debug.sh
  script/ui_debug.sh --install
  script/ui_debug.sh --preview
  script/ui_debug.sh --build-preview --preview
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --local)
            INSTALL=false
            ;;
        --install)
            INSTALL=true
            ;;
        --preview)
            OPEN_PREVIEW=true
            OPEN_APP=false
            ;;
        --build-preview)
            BUILD_PREVIEW=true
            ;;
        --no-open)
            OPEN_APP=false
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
    echo "未知选项: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-${TMPDIR:-/tmp}/codex-switch-module-cache}"

if [[ "$BUILD_PREVIEW" == true ]]; then
    echo "正在构建预览包..."
    (cd "$ROOT_DIR/PreviewPackage" && swift build --disable-sandbox -c debug)
fi

if [[ "$OPEN_PREVIEW" == true ]]; then
    echo "正在打开 Xcode Canvas 专用 PreviewPackage..."
    /usr/bin/open "$ROOT_DIR/PreviewPackage/Package.swift"
    echo "在 Xcode 中选择 scheme: CodexSwitchPreview"
    echo "打开文件: Sources/CodexSwitchPreview/PopoverView.swift"
    exit 0
fi

echo "正在构建 ${APP_NAME}..."
(cd "$ROOT_DIR" && bash build.sh)

if [[ "$OPEN_APP" != true ]]; then
    echo "构建完成。"
    exit 0
fi

/usr/bin/pkill -x "$APP_NAME" 2>/dev/null || true

if [[ "$INSTALL" == true ]]; then
    echo "正在安装到 /Applications/${APP_NAME}.app..."
    /bin/rm -rf "/Applications/${APP_NAME}.app"
    /usr/bin/ditto "$ROOT_DIR/${APP_NAME}.app" "/Applications/${APP_NAME}.app"
    /usr/bin/open "/Applications/${APP_NAME}.app"
else
    echo "正在打开本地 app bundle..."
    /usr/bin/open "$ROOT_DIR/${APP_NAME}.app"
fi
