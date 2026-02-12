#!/bin/bash

# 功能说明：Swap管理工具 (已修改为支持 'curl | bash' 互动模式)
# ... (其他注释不变) ...

# 检查执行环境 (不变)
if [ -z "$BASH_VERSION" ]; then
    echo "错误：请使用bash执行此脚本！" >&2
    exit 1
fi
if [ "$(id -u)" -ne 0 ]; then
    echo "错误：此脚本需要root权限！请使用 'curl ... | sudo bash'" >&2
    exit 1
fi

# 定义颜色输出 (不变)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 添加首次运行标志 (不变)
FIRST_RUN=true

# 禁用Swap (不变)
disable_swap() {
    printf "${YELLOW}正在禁用Swap...${NC}\n"
    swapoff -a
    sed -i '/swap/s/^/#/' /etc/fstab
    rm -f /swapfile
    printf "${GREEN}Swap已成功禁用！${NC}\n"
    printf "${YELLOW}当前Swap状态：${NC}\n"
    free -h
}

# 设置Swap大小 (已修改)
set_swap_size() {
    printf "${YELLOW}当前Swap状态：${NC}\n"
    free -h
    
    # ⬇️ 关键修改 1：从键盘 /dev/tty 读取 ⬇️
    read -p "请输入新的Swap大小（例如：4G）：" swap_size < /dev/tty
    
    # 验证输入格式 (不变)
    if ! [[ $swap_size =~ ^[0-9]+[MG]$ ]]; then
        printf "${RED}错误：无效的大小格式！请使用数字+M或G（例如：4G）${NC}\n"
        return 1
    fi
    
    printf "${YELLOW}正在设置Swap大小...${NC}\n"
    
    # ... (设置 swap 的其余代码不变) ...
    swapoff -a
    rm -f /swapfile
    fallocate -l "$swap_size" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    else
        sed -i '/\/swapfile/d' /etc/fstab
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi
    printf "${GREEN}Swap大小已成功设置为 $swap_size！${NC}\n"
    printf "${YELLOW}当前Swap状态：${NC}\n"
    free -h
}

# 主菜单 (不变)
show_menu() {
    if [ "$FIRST_RUN" = true ]; then
        printf "${YELLOW}"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf " * * \n"
        printf " * 欢迎使用Swap管理工具                     * \n"
        printf " * * \n"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf "${NC}"
        FIRST_RUN=false
    fi
    printf "${BLUE}===================================\n"
    printf "         Swap管理工具\n"
    printf "===================================${NC}\n"
    printf "1. 禁用Swap\n"
    printf "2. 设置Swap大小\n"
    printf "0. 退出\n"
    printf "${BLUE}===================================${NC}\n"
}

# 主流程 (已修改)
while true; do
    show_menu
    
    # ⬇️ 关键修改 2：从键盘 /dev/tty 读取 ⬇️
    read -p "请输入选项数字 (0-2): " choice < /dev/tty
    
    case $choice in
        # ⬇️ 关键修改 3：从键盘 /dev/tty 读取 ⬇️
        1) disable_swap; read -p "按回车键继续..." dummy < /dev/tty ;;
        2) set_swap_size; read -p "按回车键继续..." dummy < /dev/tty ;;
        0) printf "${GREEN}已退出菜单。${NC}\n"; exit 0 ;;
        *) printf "${RED}无效选项，请输入0-2的数字！${NC}\n"; sleep 1 ;;
    esac
done