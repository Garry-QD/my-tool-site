#!/bin/bash

# 功能说明：Docker重置工具 (已修改为支持 'curl | bash' 互动模式)
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

# 重置Docker数据 (已修改)
reset_docker_data() {
    printf "${YELLOW}正在重置Docker数据...${NC}\n"
    
    # 检查Docker服务状态
    if ! systemctl is-active --quiet docker; then
        printf "${RED}Docker服务未运行${NC}\n"
        
        # ⬇️ 关键修改 1：从键盘 /dev/tty 读取 ⬇️
        read -p "是否启动Docker服务？(y/N): " start_docker < /dev/tty
        
        if [ "$start_docker" = "y" ] || [ "$start_docker" = "Y" ]; then
            systemctl start docker
        else
            return
        fi
    fi
    
    # 警告信息
    printf "${RED}警告：此操作将删除所有Docker容器、镜像、网络和卷！${NC}\n"
    
    # ⬇️ 关键修改 2：从键盘 /dev/tty 读取 ⬇️
    read -p "确定要继续吗？(y/N): " confirm < /dev/tty
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        printf "${YELLOW}已取消重置操作${NC}\n"
        return
    fi
    
    # 停止所有容器 (不变)
    printf "${YELLOW}正在停止所有容器...${NC}\n"
    docker stop $(docker ps -aq) 2>/dev/null || true
    
    # 删除所有容器 (不变)
    printf "${YELLOW}正在删除所有容器...${NC}\n"
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    # ... (其他 docker prune 和 rm 命令不变) ...
    printf "${YELLOW}正在删除所有镜像...${NC}\n"
    docker rmi $(docker images -q) 2>/dev/null || true
    printf "${YELLOW}正在删除所有网络...${NC}\n"
    docker network prune -f
    printf "${YELLOW}正在删除所有卷...${NC}\n"
    docker volume prune -f
    printf "${YELLOW}正在删除Docker数据目录...${NC}\n"
    rm -rf /var/lib/docker/*
    
    # 重启Docker服务 (不变)
    printf "${YELLOW}正在重启Docker服务...${NC}\n"
    systemctl restart docker
    
    printf "${GREEN}Docker数据已重置到出厂设置！${NC}\n"
}

# 主菜单 (不变)
show_menu() {
    if [ "$FIRST_RUN" = true ]; then
        printf "${YELLOW}"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf " * * \n"
        printf " * 欢迎使用Docker重置工具                   * \n"
        printf " * * \n"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf "${NC}"
        FIRST_RUN=false
    fi
    printf "${BLUE}===================================\n"
    printf "        Docker重置工具\n"
    printf "===================================${NC}\n"
    printf "1. 重置Docker数据到出厂设置\n"
    printf "0. 退出\n"
    printf "${BLUE}===================================${NC}\n"
}

# 主流程 (已修改)
while true; do
    show_menu
    
    # ⬇️ 关键修改 3：从键盘 /dev/tty 读取 ⬇️
    read -p "请输入选项数字 (0-1): " choice < /dev/tty
    
    case $choice in
        # ⬇️ 关键修改 4：从键盘 /dev/tty 读取 ⬇️
        1) reset_docker_data; read -p "按回车键继续..." dummy < /dev/tty ;;
        0) printf "${GREEN}已退出菜单。${NC}\n"; exit 0 ;;
        *) printf "${RED}无效选项，请输入0-1的数字！${NC}\n"; sleep 1 ;;
    esac
done