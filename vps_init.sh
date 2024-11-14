#!/bin/bash

# 函数：显示菜单
show_menu() {
    clear
    echo "VPS 初始化菜单"
    echo "-----------------"
    echo "1. 安装 UFW 防火墙"
    echo "2. 更改 SSH 端口"
    echo "3. 安装 Fail2Ban"
    echo "4. 开启 SSH 二次验证"
    echo "5. 安装 Nginx"
    echo "6. 安装哪吒面板"
    echo "7. 退出"
}

# 函数：安装 ufw 防火墙
install_ufw() {
    echo "正在安装 UFW..."
    apt update
    apt install -y ufw
    echo "UFW 安装完成。"
    read -p "是否设置 UFW 开机自启? (y/n): " enable_startup
    if [[ "$enable_startup" == "y" || "$enable_startup" == "Y" ]]; then
        systemctl enable ufw
        echo "UFW 已设置为开机自启。"
    fi
    ufw enable
    echo "UFW 已启用。"
}

# 函数：更改 SSH 端口
change_ssh_port() {
    read -p "请输入新的 SSH 端口号: " new_port
    if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
        echo "无效的端口号，请输入一个有效的端口号（1024-65535）。"
        return
    fi
    # 修改 SSH 配置文件
    sed -i "s/#Port 22/Port $new_port/" /etc/ssh/sshd_config
    # 重启 SSH 服务
    systemctl restart sshd
    echo "SSH 端口已更改为 $new_port，请通过新端口登录。"
}

# 函数：安装 Fail2Ban
install_fail2ban() {
    echo "正在安装 Fail2Ban..."
    apt update
    apt install -y fail2ban
    echo "Fail2Ban 安装完成。"
    read -p "请输入错误登录次数后 Ban IP (默认是3次): " max_retry
    max_retry=${max_retry:-3}  # 默认为 3 次
    # 配置 Fail2Ban
    echo -e "[sshd]\nenabled = true\nport = ssh\nlogpath = /var/log/auth.log\nmaxretry = $max_retry" > /etc/fail2ban/jail.d/defaults-debian.conf
    systemctl restart fail2ban
    echo "Fail2Ban 配置完成，已启用 SSH 防护。"
}

# 函数：开启 SSH 二次验证
enable_ssh_2fa() {
    echo "正在安装 Google Authenticator..."
    apt update
    apt install -y libpam-google-authenticator

    # 配置 PAM 以启用二次验证
    echo "启用 SSH 二次验证..."
    echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd

    # 配置 SSH 服务
    sed -i "s/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/" /etc/ssh/sshd_config
    sed -i "s/#UsePAM yes/UsePAM yes/" /etc/ssh/sshd_config
    systemctl restart sshd

    # 设置 Google Authenticator
    echo "为每个用户设置 Google Authenticator..."
    read -p "请输入要启用二次验证的用户名: " username
    sudo -u $username google-authenticator

    echo "SSH 二次验证已启用。请根据提示完成 Google Authenticator 的配置。"
}

# 函数：安装 Nginx
install_nginx() {
    echo "正在安装 Nginx..."
    apt update
    apt install -y nginx
    echo "Nginx 安装完成。"
    
    # 启动并设置 Nginx 开机自启
    systemctl start nginx
    systemctl enable nginx
    echo "Nginx 已启动并设置为开机自启。"
    
    # 配置防火墙允许 HTTP 和 HTTPS 流量
    ufw allow 'Nginx Full'
    echo "已允许 Nginx 通过防火墙。"
    
    # 检查 Nginx 是否运行
    systemctl status nginx
}

# 函数：安装哪吒面板
install_nezha() {
    echo "正在安装哪吒面板..."
    curl -L https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -o nezha.sh && chmod +x nezha.sh && sudo ./nezha.sh install_agent
    echo "哪吒面板安装完成。"
}

# 主函数：处理用户选择
while true; do
    show_menu
    read -p "请选择操作（1-7）: " choice
    case $choice in
        1)
            install_ufw
            ;;
        2)
            change_ssh_port
            ;;
        3)
            install_fail2ban
            ;;
        4)
            enable_ssh_2fa
            ;;
        5)
            install_nginx
            ;;
        6)
            install_nezha
            ;;
        7)
            echo "退出程序。"
            exit 0
            ;;
        *)
            echo "无效的选择，请重新选择。"
            ;;
    esac
    read -p "按任意键继续..." -n 1 -s
done
