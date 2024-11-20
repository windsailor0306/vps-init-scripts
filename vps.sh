#!/bin/bash

# 颜色定义
green="\033[32m"
red="\033[31m"
yellow="\033[33m"
plain="\033[0m"

# 检查 Nginx 是否安装，如果没有安装则进行安装
install_nginx() {
    if! command -v nginx &>/dev/null; then
        echo -e "${yellow}Nginx 未安装，正在安装...${plain}"
        apt update && apt install -y nginx || {
            echo -e "${red}Nginx 安装失败，请检查您的系统设置或网络连接${plain}"
            exit 1
        }
        echo -e "${green}Nginx 安装成功${plain}"
    else
        echo -e "${green}Nginx 已安装${plain}"
    }
}

# 创建目录 /etc/nginx/sites-available 如果不存在
create_nginx_dirs() {
    if [! -d "/etc/nginx/sites-available" ]; then
        echo -e "${yellow}/etc/nginx/sites-available 目录不存在，正在创建...${plain}"
        mkdir -p /etc/nginx/sites-available
        if [ $? -eq 0 ]; then
            echo -e "${green}/etc/nginx/sites-available 目录创建成功${plain}"
        else
            echo -e "${red}创建 /etc/nginx/sites-available 目录失败${plain}"
            exit 1
        }
    else
        echo -e "${green}/etc/nginx/sites-available 目录已存在${plain}"
    }
}

# 主菜单
show_menu() {
    echo -e "${green}\t1.${plain} 防火墙管理"
    echo -e "${green}\t2.${plain} BBR 管理"
    echo -e "${green}\t3.${plain} 证书管理 (acme.sh)"
    echo -e "${green}\t4.${plain} Nginx管理"
    echo -e "${green}\t5.${plain} 生成 Nginx 配置文件并启动"
    echo -e "${green}\t6.${plain} 设置 80 端口重定向到 443"
    echo -e "${green}\t0.${plain} 退出脚本"
    read -p "请输入选项: " choice
    case "$choice" in
        0)
            echo -e "${green}退出脚本${plain}"
            exit 0
            ;;
        1)
            firewall_menu
            ;;
        2)
            bbr_menu
            ;;
        3)
            ssl_cert_menu
            ;;
        4)
            nginx_menu
            ;;
        5)
            generate_nginx_config
            ;;
        6)
            redirect_80_to_443
            ;;
        *)
            echo -e "${red}无效选项，请重新输入${plain}"
            ;;
    esac
}

# 防火墙菜单
firewall_menu() {
    echo -e "${green}\t1.${plain} 安装防火墙并开放端口"
    echo -e "${green}\t2.${plain} 查看已开放端口"
    echo -e "${green}\t3.${plain} 从列表中删除端口"
    echo -e "${green}\t4.${plain} 禁用防火墙"
    echo -e "${green}\t0.${plain} 返回主菜单"
    read -p "请输入选项: " choice
    case "$choice" in
        0)
            show_menu
            ;;
        1)
            open_ports
            ;;
        2)
            sudo ufw status
            ;;
        3)
            delete_ports
            ;;
        4)
            sudo ufw disable
            ;;
        *)
            echo "无效选项，请重试"
            ;;
    esac
}

# 启用端口功能
open_ports() {
    if! command -v ufw &>/dev/null; then
        echo "ufw 防火墙未安装，正在安装..."
        apt-get update && apt-get install -y ufw
    fi

    if! ufw status | grep -q "Status: active"; then
        ufw allow ssh
        ufw allow http
        ufw allow https
        ufw allow 2053/tcp
        ufw --force enable
    fi

    read -p "输入您要打开的端口（例如 80,443 或范围 400-500): " ports
    if [[ $ports =~ ^([0-9]+|[0-9]+-[0-9]+)(,([0-9]+|[0-9]+-[0-9]+))*$ ]]; then
        IFS=',' read -ra PORT_LIST <<<"$ports"
        for port in "${PORT_LIST[@]}"; do
            if [[ $port == *-* ]]; then
                start_port=$(echo "$port" | cut -d'-' -f1)
                end_port=$(echo "$port" | cut -d'-' -f2)
                for ((i = start_port; i <= end_port; i++)); do
                    ufw allow "$i"
                done
            else
                ufw allow "$port"
            endif
        done
        echo "指定端口已开放"
    else
        echo "输入格式无效"
    }
}

# 删除端口功能
delete_ports() {
    read -p "输入要删除的端口（例如 80,443 或范围 400-500): " ports
    if [[ $ports =~ ^([0-9]+|[0-9]+-[0-9]+)(,([0-9]+|[0-9]+-[0-9]+))*$ ]]; then
        IFS=',' read -ra PORT_LIST <<<"$ports"
        for port in "${PORT_LIST[@]}"; do
            if [[ $port == *-* ]]; then
                start_port=$(echo "$port" | cut -d'-' -f1)
                end_port=$(print "$port" | cut -d'-' -f2)
                for ((i = start_port; i <= end_port; i++)); do
                    ufw delete allow "$i"
                done
            else
                ufw delete allow "$port"
            endif
        done
        echo "指定端口已删除"
    else
        echo "输入格式无效"
    }
}

# BBR 菜单
bbr_menu() {
    echo -e "${green}\t1.${plain} 启用 BBR"
    echo -e "${green}\t2.${plain} 禁用 BBR"
    echo -e "${green}\t0.${plain} 返回主菜单"
    read -p "请输入选项: " choice
    case "$choice" in
        0)
            show_menu
            ;;
        1)
            enable_bbr
            ;;
        2)
            disable_bbr
            ;;
        *)
            echo "无效选项，请重试"
            ;;
    esac
}

# 启用 BBR 功能
enable_bbr() {
    if grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf && grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        echo "BBR 已经启用"
        return
    endif

    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p

    if [[ $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}') == "bbr" ]]; then
        echo "BBR 启用成功"
    else
        echo "BBR 启用失败"
    }
}

# 禁用 BBR 功能
disable_bbr() {
    if! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf ||! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        echo "BBR 当前未启用"
        return
    endif

    sed -i 's/net.core.default_qdisc=fq/net.core.default_qdisc=pfifo_fast/' /etc/sysctl.conf
    sed -i 's/net.ipv4.tcp_congestion_control=bbr/net.ipv4.tcp_congestion_control=cubic/' /etc/sysctl.conf
    sysctl -p

    if [[ $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}') == "cubic" ]]; then
        echo "BBR 已成功禁用"
    else
        echo "禁用 BBR 失败"
    }
}

# 证书管理菜单（原有的）
ssl_cert_menu() {
    echo -e "${green}\t1.${plain} 安装 acme.sh"
    echo -e "${green}\t2.${plain} 使用 Cloudflare 颁发 SSL 证书"
    echo -e "${green}\t0.${plain} 返回主菜单"
    read -p "请输入选项: " choice
    case "$choice" in
        0)
            show_menu
            ;;
        1)
            install_acme
            ;;
        2)
            ssl_cert_issue_CF
            ;;
        *)
            echo "无效选项，请重试"
            ;;
    esac
}

# 安装 acme.sh
install_acme() {
    echo "正在安装 acme.sh..."
    curl https://get.acme.sh | sh
    if [ $? -eq 0 ]; then
        echo -e "${green}acme.sh 安装成功${plain}"
    else
        echo -e "${red}acme.sh 安装失败，请检查网络或权限${plain}"
        return 1
    }
}

# 使用 Cloudflare 颁发 SSL 证书
ssl_cert_issue_CF() {
    echo ""
    echo "****** 使用说明 ******"
    echo "此 Acme 脚本需要以下数据："
    echo "1. Cloudflare 注册邮箱"
    echo "2. Cloudflare 全局 API 密钥"
    echo "3. Cloudflare 已解析 DNS 到当前服务器的域名"
    echo "4. 脚本申请证书，默认安装路径为 /root/cert"
    read -p "确认申请? [y/n]: " confirm
    if [[ $confirm!= "y" ]]; then
        echo "已取消操作"
        return
    }

    # 检查 acme.sh 是否已安装
    if! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        echo "未找到 acme.sh，正在安装..."
        install_acme || exit 1
    }

    local CF_Domain=""
    local CF_GlobalKey=""
    local CF_AccountEmail=""
    local certPath="/root/cert"

    # 创建或清空证书路径
    mkdir -p "$certPath" && rm -rf "${certPath:?}/*"

    # 获取用户输入
    while [[ -z $CF_Domain ]]; then
        read -p "请输入您的域名: " CF_DDdomain
    done
    echo "您的域名为: $CF_Domain"

    while [[ -z $CF_GlobalKey ]]; then
        read -p "请输入您的 CF Global API Key: " CF_GlobalKey
    end
    echo "您的 API 密钥是: $CF_GlobalKey"

    while [[ -z $CF_AccountEmail ]]; then
        read -p "请输入您的邮箱: " CF_AccountEmail
    end
    echo "您的账号邮箱地址是: $CF_AccountEmail"

    # 设置默认 CA
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt || {
        echo -e "${red}设置默认 CA: Lets'Encrypt 失败，脚本退出...${plain}"
        exit 1
    }

    export CF_Key="$CF_GlobalKey"
    export CF_Email="$CF_AccountEmail"

    # 申请证书
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d "$CF_Domain" -d "*.$CF_Domain" --log || {
        echo -e "${red}证书颁发失败，脚本退出...${plain}"
        exit 1
    }

    echo -e "${green}证书颁发成功，正在安装...${plain}"

    # 安装证书
    ~/.acme.sh/acme.sh --installcert -d "$CF_Domain" -d "*.$CF_Domain" \
        --ca-file "$certPath/ca.cer" \
        --cert-file "$certPath/${CF_Domain}.cer" \
        --key-file "$certPath/${CF_Domain}.key" \
        --fullchain-file "$certPath/fullchain.cer" || {
        echo -e "${red}证书安装失败，脚本退出...${plain}"
        exit 1
    }

    echo -e "${green}证书安装成功，开启自动更新...${plain}"
    echo "请确保 80 和 443 端口已打开放行"

    # 开启自动更新
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade || {
        echo -e "${yellow}自动更新设置失败，请手动检查...${plain}"
        chmod 755 "$certPath"
        exit 1
    }

    echo -e "${green}证书已安装并开启自动续订，证书信息如下:${plain}"
    ls -lah "$certPath"
    chmod 755 "$certPath"
    echo -e "${yellow}请确保 80 和 443 端口已打开放行${plain}"
}

# Nginx管理菜单
nginx_menu() {
    echo -e "${green}\t1.${plain} 检查并安装Nginx"
    echo -e "${green}\t2.${plain} 创建Nginx相关目录"
    echo -e "${green}\t0.${plain} 返回主菜单"
    read -p "请输入选项: " choice
    case "$choice" in
        0)
            show_menu
            ;;
        1)
            install_nginx
            ;;
        2)
            create_nginx_dirs
            ;;
        *)
            echo "无效选项，请重试"
            ;;
    esac
}

# 生成 Nginx 配置文件并启动
generate_nginx_config() {
    # 创建 Nginx 必要的目录
    create_nginx_dirs

    # 检查 Nginx 是否安装
    install_nginx

    read -p "请输入您的域名: " DOMAIN
    read -p "您要设置的外网访问端口 (如: 443): " EXTERNAL_PORT
    read -p "您要设置的内网服务端口 (如: 7001): " INTERNAL_PORT

    CONF_PATH="/etc/nginx/sites-available/${DOMAIN}.conf"

    cat > "$CONF_PATH" <<EOF
server {
    listen $EXTERNAL_PORT ssl;
    server_name $DOMAIN;

    ssl_certificate /root/cert/${DOMAIN}.cer;
    ssl_certificate_key /root/cert/${DOMAIN}.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://127.0.0.1:$INTERNAL_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    # 测试 Nginx 配置
    nginx -t
    if [ $? -ne 0 ]; then
        echo "Nginx 配置测试失败，请检查生成的文件：$CONF_PATH"
        exit 1
    }

    # 重载 Nginx 服务
    systemctl reload nginx

    echo "Nginx 配置已完成，文件位置：$CONF_PATH"
    echo "已将 $DOMAIN 的外网 $EXTERNAL_PORT 端口的访问请求转发到内网服务端口 $INTERNAL_PORT。"
}

# 设置 80 端口重定向到 443
redirect_80_to_443() {
    echo "待实现：设置 80 端口重定向到 443 的具体逻辑"
}

# 执行主菜单
show_menu
