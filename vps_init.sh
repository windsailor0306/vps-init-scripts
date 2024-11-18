#!/bin/bash

# 定义颜色
green="\e[32m"
red="\e[31m"
reset="\e[0m"

# 函数：显示菜单
show_menu() {
    clear
    echo -e "${green}VPS 初始化菜单${reset}"
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
    echo -e "${green}UFW 安装完成。${reset}"
    
    read -p "是否设置 UFW 开机自启? (y/n): " enable_startup
    if [[ "$enable_startup" =~ ^[yY]$ ]]; then
        systemctl enable ufw
        echo -e "${green}UFW 已设置为开机自启。${reset}"
    fi
    ufw enable
    echo -e "${green}UFW 已启用。${reset}"
}

# 函数：更改 SSH 端口
change_ssh_port() {
    read -p "请输入新的 SSH 端口号: " new_port
    if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
        echo -e "${red}无效的端口号，请输入一个有效的端口号（1024-65535）。${reset}"
        return
    fi
    sed -i "s/^#Port 22/Port $new_port/" /etc/ssh/sshd_config
    sed -i "s/^Port [0-9]*/Port $new_port/" /etc/ssh/sshd_config
    systemctl restart sshd
    echo -e "${green}SSH 端口已更改为 $new_port，请通过新端口登录。${reset}"
    
    if ufw status | grep -q "active"; then
        ufw allow "$new_port"
        ufw reload
        echo -e "${green}新端口 $new_port 已通过 UFW 放行。${reset}"
    fi
}

# 函数：安装 Fail2Ban
install_fail2ban() {
    echo "正在安装 Fail2Ban..."
    apt update
    apt install -y fail2ban
    echo -e "${green}Fail2Ban 安装完成。${reset}"
    
    read -p "请输入错误登录次数后 Ban IP (默认是3次): " max_retry
    max_retry=${max_retry:-3}
    
    if [ -f /etc/fail2ban/jail.d/defaults-debian.conf ]; then
        cp /etc/fail2ban/jail.d/defaults-debian.conf /etc/fail2ban/jail.d/defaults-debian.conf.bak
    fi
    
    echo -e "[sshd]\nenabled = true\nport = ssh\nlogpath = /var/log/auth.log\nmaxretry = $max_retry" > /etc/fail2ban/jail.d/defaults-debian.conf
    systemctl restart fail2ban
    echo -e "${green}Fail2Ban 配置完成，已启用 SSH 防护。${reset}"
}

# 函数：开启 SSH 二次验证
enable_ssh_2fa() {
    echo "正在安装 Google Authenticator..."
    apt update
    apt install -y libpam-google-authenticator
    echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd

    sed -i "s/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/" /etc/ssh/sshd_config
    sed -i "s/#UsePAM yes/UsePAM yes/" /etc/ssh/sshd_config
    systemctl restart sshd
    
    read -p "请输入要启用二次验证的用户名: " username
    if id "$username" &>/dev/null; then
        su - "$username" -c "google-authenticator"
        echo -e "${green}SSH 二次验证已为用户 $username 启用。${reset}"
    else
        echo -e "${red}用户名 $username 不存在，请重试。${reset}"
    fi
}

# 函数：安装 Nginx
install_nginx() {
    echo "正在安装 Nginx..."
    apt update
    apt install -y nginx
    echo -e "${green}Nginx 安装完成。${reset}"
    
    systemctl start nginx
    systemctl enable nginx
    echo -e "${green}Nginx 已启动并设置为开机自启。${reset}"
    
    ufw allow 'Nginx Full'
    echo -e "${green}已允许 Nginx 通过防火墙。${reset}"
    systemctl status nginx
}

# 函数：安装哪吒面板
install_nezha() {
    echo "正在安装哪吒面板..."
    nezha_install_url="https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh"
    curl -L "$nezha_install_url" -o nezha.sh
    chmod +x nezha.sh
    ./nezha.sh install_agent
    echo -e "${green}哪吒面板安装完成。${reset}"
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
            echo -e "${green}退出程序。${reset}"
            exit 0
            ;;
        *)
            echo -e "${red}无效的选择，请重新选择。${reset}"
            ;;
    esac
    read -p "按任意键继续..." -n 1 -s
done
