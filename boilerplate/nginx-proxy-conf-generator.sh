#!/bin/bash

# 定义变量
BOILERPLATE_DIR=$(dirname "$(readlink -f "$0")")
NGINX_CONF_DIR="/etc/nginx"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --prefix)
        NGINX_CONF_DIR="$2"
        shift
        shift
        ;;
        -h|--hostname)
        HOSTNAME="$2"
        shift
        shift
        ;;
        -p|--proxy)
        PROXY_ADDRESS="$2"
        shift
        shift
        ;;
        --cert)
        SSL_CERT_PATH="$2"
        shift
        shift
        ;;
        --key)
        SSL_CERT_KEY_PATH="$2"
        shift
        shift
        ;;
        -w|--websocket)
        WEBSOCKET_SUPPORT="true"
        shift
        ;;
        -u|--upload)
        UPLOAD_SUPPORT="true"
        shift
        ;;
        --dry-run)
        DRY_RUN="true"
        shift
        ;;
        --help)
        cat "$BOILERPLATE_DIR/help.txt"
        exit 0
        ;;
        *)
        echo "未知参数: $1"
        exit 1
        ;;
    esac
done

# 生成目标文件
TEMP_FILE="$NGINX_CONF_DIR/sites-available/temp-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1).conf"
cp "$BOILERPLATE_DIR/reverse-proxy-template.conf" "$TEMP_FILE"

# 替换模板文件中的变量
sed -i "s#BOILERPLATE_PATH#${BOILERPLATE_DIR}#g" "$TEMP_FILE"
sed -i "s/HOSTNAME/${HOSTNAME}/g" "$TEMP_FILE"
sed -i "s#SSL_CERT_PATH#${SSL_CERT_PATH}#g" "$TEMP_FILE"
sed -i "s#SSL_CERT_KEY_PATH#${SSL_CERT_KEY_PATH}#g" "$TEMP_FILE"
sed -i "s#PROXY_ADDRESS#${PROXY_ADDRESS}#g" "$TEMP_FILE"

# 根据WEBSOCKET_SUPPORT参数决定是否添加websocket支持
if [ "$WEBSOCKET_SUPPORT" = "true" ]; then
    sed -i '/#include BOILERPLATE_PATH\/websocket.conf/s/^#//' "$TEMP_FILE"
fi

# 根据UPLOAD_SUPPORT参数决定是否添加文件上传支持
if [ "$UPLOAD_SUPPORT" = "true" ]; then
    sed -i '/#include BOILERPLATE_PATH\/uploads.conf/s/^#//' "$TEMP_FILE"
fi

# 如果包含 --dry-run 参数，则输出目标文件路径并结束
if [ "$DRY_RUN" = "true" ]; then
    echo "目标文件路径: $TEMP_FILE"
    exit 0
fi

# 重命名目标文件
NEW_FILE="$NGINX_CONF_DIR/sites-available/${HOSTNAME}.conf"
mv "$TEMP_FILE" "$NEW_FILE"

# 创建软链接
ln -s "$NEW_FILE" "$NGINX_CONF_DIR/sites-enabled/"

# 校验Nginx配置文件是否有效
nginx -t
