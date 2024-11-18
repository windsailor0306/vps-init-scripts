#!/bin/bash

# 彩色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 没有颜色

# 显示菜单
show_menu() {
    clear
    echo -e "${GREEN}Debian VPS 初始化菜单${NC}"
    echo "---------------------------"
    echo "1. 安装 UFW 防火墙并启用"
    echo "2. 更改 SSH 端口"
    echo "3. 安装并配置 Fail2Ban"
    echo "4. 启用 SSH 二次验证"
    echo "5. 安装并配置 Nginx"
    echo "6. 禁用 SSH 密码登录"
    echo "7. 启用 SSH 密钥登录"
    echo "8. 退出"
}

# 安装 UFW 防火墙
install_ufw() {
    echo -e "${YELLOW}安装 UFW 防火墙...${NC}"
    apt update && apt install -y ufw
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow OpenSSH
    ufw enable
    echo -e "${GREEN}UFW 已安装并启用，默认规则已设置。${NC}"
}

# 更改 SSH 端口
change_ssh_port() {
    current_port=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}')
    current_port=${current_port:-22}
    echo -e "${YELLOW}当前 SSH 端口: $current_port${NC}"
    read -p "请输入新的 SSH 端口号（1024-65535）: " new_port

    if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
        echo -e "${RED}无效端口号，请输入 1024-65535 之间的数字！${NC}"
        return
    fi

    sed -i "s/^#*Port.*/Port $new_port/" /etc/ssh/sshd_config
    ufw allow "$new_port"
    systemctl restart sshd
    echo -e "${GREEN}SSH 端口已更改为 $new_port，请立即测试新端口连接！${NC}"
}

# 安装并配置 Fail2Ban
install_fail2ban() {
    echo -e "${YELLOW}安装 Fail2Ban...${NC}"
    apt update && apt install -y fail2ban
    cat <<EOT > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOT
    systemctl restart fail2ban
    echo -e "${GREEN}Fail2Ban 已安装并启用默认配置。${NC}"
}

# 启用 SSH 二次验证
enable_ssh_2fa() {
    echo -e "${YELLOW}安装 Google Authenticator...${NC}"
    apt update && apt install -y libpam-google-authenticator
    echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd
    sed -i "s/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/" /etc/ssh/sshd_config
    systemctl restart sshd
    echo -e "${GREEN}SSH 二次验证已启用，请为用户配置 Google Authenticator。${NC}"
    read -p "请输入用户名进行配置: " username
    if id "$username" &>/dev/null; then
        sudo -u "$username" google-authenticator
        echo -e "${GREEN}为用户 $username 启用二次验证成功！${NC}"
    else
        echo -e "${RED}用户 $username 不存在，请检查后重试！${NC}"
    fi
}

# 安装并配置 Nginx
install_nginx() {
    echo -e "${YELLOW}安装 Nginx...${NC}"
    apt update && apt install -y nginx
    systemctl enable nginx
    systemctl start nginx
    ufw allow 'Nginx Full'
    echo -e "${GREEN}Nginx 已安装并启用！${NC}"
}

# 禁用 SSH 密码登录
disable_password_login() {
    sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
    sed -i "s/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/" /etc/ssh/sshd_config
    systemctl restart sshd
    echo -e "${GREEN}SSH 密码登录已禁用！请确保已配置密钥登录！${NC}"
}

# 启用 SSH 密钥登录
enable_key_login() {
    if [ ! -f "$HOME/.ssh/id_rsa" ]; then
        echo -e "${YELLOW}正在生成 SSH 密钥对...${NC}"
        mkdir -p "$HOME/.ssh"
        ssh-keygen -t rsa -b 2048 -f "$HOME/.ssh/id_rsa" -N ""
        echo -e "${GREEN}密钥对生成成功，保存路径: $HOME/.ssh/id_rsa${NC}"
    else
        echo -e "${YELLOW}密钥已存在: $HOME/.ssh/id_rsa${NC}"
    fi

    read -p "是否将公钥添加到当前服务器？(y/n): " add_key
    if [[ "$add_key" == "y" || "$add_key" == "Y" ]]; then
        cat "$HOME/.ssh/id_rsa.pub" >> "$HOME/.ssh/authorized_keys"
        chmod 600 "$HOME/.ssh/authorized_keys"
        echo -e "${GREEN}公钥已添加到服务器，可通过密钥登录！${NC}"
    fi
}

# 主循环
while true; do
    show_menu
    read -p "请选择操作（1-8）: " choice
    case $choice in
        1) install_ufw ;;
        2) change_ssh_port ;;
        3) install_fail2ban ;;
        4) enable_ssh_2fa ;;
        5) install_nginx ;;
        6) disable_password_login ;;
        7) enable_key_login ;;
        8) echo -e "${GREEN}退出程序。${NC}" && exit 0 ;;
        *) echo -e "${RED}无效选项，请重新输入！${NC}" ;;
    esac
    read -p "按任意键继续..." -n 1 -s
done
