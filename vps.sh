#!/bin/bash

# 定义颜色变量
green="\033[32m"
yellow="\033[33m"
red="\033[31m"
plain="\033[0m"

# 主菜单
show_menu() {
    echo -e "${green}\t1.${plain} 防火墙管理"
    echo -e "${green}\t2.${plain} BBR 管理"
    echo -e "${green}\t3.${plain} 证书管理 (acme.sh)"
    echo -e "${green}\t0.${plain} 退出脚本"
    read -p "请输入选项: " choice
    case "$choice" in
    1)
        firewall_menu
        ;;
    2)
        bbr_menu
        ;;
    3)
        ssl_cert_menu
        ;;
    0)
        echo -e "${green}退出脚本${plain}"
        exit 0
        ;;
    *)
        echo -e "${red}无效选项，请重新输入${plain}"
        ;;
    esac
}

# 防火墙管理功能略（保持不变）

# BBR 管理功能略（保持不变）

# 证书管理菜单
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
    fi
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
    if [[ $confirm != "y" ]]; then
        echo "已取消操作"
        return
    fi

    # 检查 acme.sh 是否已安装
    if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        echo "未找到 acme.sh，正在安装..."
        install_acme || exit 1
    fi

    local CF_Domain=""
    local CF_GlobalKey=""
    local CF_AccountEmail=""
    local certPath="/root/cert"

    # 创建或清空证书路径
    mkdir -p "$certPath" && rm -rf "${certPath:?}/*"

    # 获取用户输入
    while [[ -z $CF_Domain ]]; do
        read -p "请输入您的域名: " CF_Domain
    done
    echo "您的域名为: $CF_Domain"

    while [[ -z $CF_GlobalKey ]]; do
        read -p "请输入您的 CF Global API Key: " CF_GlobalKey
    done
    echo "您的 API 密钥是: $CF_GlobalKey"

    while [[ -z $CF_AccountEmail ]]; do
        read -p "请输入您的邮箱: " CF_AccountEmail
    done
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

# 执行主菜单
show_menu
