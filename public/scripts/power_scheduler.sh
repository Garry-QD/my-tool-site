#!/bin/bash
# interactive_power_pure.sh
# 每日电源定时调度工具 - 纯文本无表情版

WAKEALARM_FILE="/sys/class/rtc/rtc0/wakealarm"
WIFE_CONFIG=".wife_mode_config"

# --- 辅助函数：输入时间验证 ---
function get_valid_time() {
    local prompt_msg="$1"
    local time_str
    while true; do
        echo -n "$prompt_msg (格式 HH:MM，例如 22:30): " >&2
        if read -r time_str < /dev/tty; then
            time_str=$(echo "$time_str" | tr -d '[:space:]')
            if [[ $time_str =~ ^([01]?[0-9]|2[0-3]):([0-5][0-9])$ ]]; then
                echo "$time_str"
                break
            else
                echo "[错误] 格式不正确，请重试。" >&2
            fi
        else
            exit 1
        fi
    done
}

# --- 辅助函数：输入日期验证 ---
function get_valid_date() {
    local prompt_msg="$1"
    local date_str
    while true; do
        echo -n "$prompt_msg (格式 YYYY-MM-DD): " >&2
        if read -r date_str < /dev/tty; then
            date_str=$(echo "$date_str" | tr -d '[:space:]')
            if date -d "$date_str" >/dev/null 2>&1; then
                date -d "$date_str" +%F
                break
            else
                echo "[错误] 日期无效。" >&2
            fi
        else
            exit 1
        fi
    done
}

# --- 功能：设置定时关机 (含子菜单) ---
function set_shutdown_menu() {
    echo "--------------------------------"
    echo "       设置定时关机"
    echo "--------------------------------"
    echo "1. 每天循环执行 (Daily)"
    echo "2. 仅执行一次 (Once)"
    echo "--------------------------------"
    echo -n "请选择模式 (1/2): "
    
    read -r mode < /dev/tty
    
    # 获取时间
    local time_str=$(get_valid_time "请输入关机时间")
    local hour=$(echo "$time_str" | cut -d: -f1)
    local min=$(echo "$time_str" | cut -d: -f2)

    # 清理旧的关机任务 (防止冲突)
    (sudo crontab -l 2>/dev/null | grep -v "power_scheduler shutdown") | sudo crontab -

    if [ "$mode" == "1" ]; then
        # --- 每天循环 ---
        # 格式: 分 时 * * *
        (sudo crontab -l 2>/dev/null; echo "$min $hour * * * /sbin/shutdown -h now # power_scheduler shutdown_daily") | sudo crontab -
        echo "[成功] 已设置【每天】 $time_str 自动关机。"
        
    elif [ "$mode" == "2" ]; then
        # --- 仅一次 ---
        # 计算日期：如果设定时间还没过，就是今天；如果过了，就是明天
        local target_timestamp=$(date -d "$time_str" +%s)
        local now_timestamp=$(date +%s)
        
        if [ $target_timestamp -lt $now_timestamp ]; then
            # 时间已过，设为明天
            target_date=$(date -d "tomorrow $time_str" +%F)
        else
            # 还没过，设为今天
            target_date=$(date -d "$time_str" +%F)
        fi
        
        local cron_day=$(date -d "$target_date" +%d)
        local cron_month=$(date -d "$target_date" +%m)
        
        # 格式: 分 时 日 月 *
        (sudo crontab -l 2>/dev/null; echo "$min $hour $cron_day $cron_month * /sbin/shutdown -h now # power_scheduler shutdown_once (Target: $target_date)") | sudo crontab -
        echo "[成功] 已设置【单次】于 $target_date $time_str 自动关机。"
    else
        echo "[错误] 选择无效，取消操作。"
    fi
}

# --- 功能：设置循环开机 ---
function set_wakeup() {
    echo "--- 设置每天定时开机 ---"
    local time_str=$(get_valid_time "请输入开机时间")
    sudo sh -c "echo 0 > $WAKEALARM_FILE"
    local timestamp=$(date -d "tomorrow $time_str" +%s)
    sudo sh -c "echo $timestamp > $WAKEALARM_FILE"
    echo "[成功] 每天定时开机已设为: $time_str"
}

# --- 功能：疼媳妇模式 ---
function set_wife_mode() {
    echo "================================"
    echo "       [疼媳妇模式]"
    echo "================================"
    
    local last_date=$(get_valid_date "请输入上次经期开始日期")
    
    echo -n "请输入周期天数 (回车默认28): " >&2
    read -r cycle_days < /dev/tty
    if [[ -z "$cycle_days" ]]; then cycle_days=28; fi
    
    local next_period=$(date -d "$last_date + $cycle_days days" +%F)
    local shutdown_date=$(date -d "$next_period - 1 day" +%F)
    
    echo "--------------------------------"
    echo "预测下次经期: $next_period"
    echo "计划关机日期: $shutdown_date"
    echo "--------------------------------"

    local time_str=$(get_valid_time "请输入关机时间")
    local hour=$(echo "$time_str" | cut -d: -f1)
    local min=$(echo "$time_str" | cut -d: -f2)
    local cron_month=$(date -d "$shutdown_date" +%m)
    local cron_day=$(date -d "$shutdown_date" +%d)

    # 清理并写入
    (sudo crontab -l 2>/dev/null | grep -v "WIFE_MODE") | sudo crontab -
    (sudo crontab -l 2>/dev/null; echo "$min $hour $cron_day $cron_month * /sbin/shutdown -h now # WIFE_MODE (Target: $shutdown_date)") | sudo crontab -

    # 保存配置
    echo "NEXT_CARE_DATE=$shutdown_date" > $WIFE_CONFIG
    echo "SHUTDOWN_TIME=$time_str" >> $WIFE_CONFIG

    echo "[成功] 已设置疼媳妇模式，将在 $shutdown_date $time_str 关机。"
}

# --- 功能：取消任务 ---
function cancel_task() {
    echo "--- 取消任务 ---"
    echo "1. 取消 [定时关机] (所有)"
    echo "2. 取消 [定时开机]"
    echo "3. 取消 [疼媳妇模式]"
    echo "4. 取消 [所有任务]"
    echo "q. 返回"
    echo -n "请选择: "
    read -r choice < /dev/tty

    case "$choice" in
        1) (sudo crontab -l | grep -v "power_scheduler shutdown") | sudo crontab -; echo "[OK] 已取消定时关机";;
        2) sudo sh -c "echo 0 > $WAKEALARM_FILE"; echo "[OK] 已取消定时开机";;
        3) (sudo crontab -l | grep -v "WIFE_MODE") | sudo crontab -; rm -f $WIFE_CONFIG; echo "[OK] 已取消疼媳妇模式";;
        4) 
           (sudo crontab -l | grep -v "power_scheduler" | grep -v "WIFE_MODE") | sudo crontab -
           sudo sh -c "echo 0 > $WAKEALARM_FILE"
           rm -f $WIFE_CONFIG
           echo "[OK] 已取消所有任务"
           ;;
        q) return;;
    esac
    echo -n "按回车继续..."
    read -r dummy < /dev/tty
}

# --- 功能：状态查询 ---
function status() {
    echo "--------- 当前任务状态 ---------"
    
    # 检查关机任务 (区分每天和单次)
    local cron_output=$(sudo crontab -l 2>/dev/null)
    
    local daily_off=$(echo "$cron_output" | grep "daily_shutdown")
    local once_off=$(echo "$cron_output" | grep "shutdown_once")
    local wife_off=$(echo "$cron_output" | grep "WIFE_MODE")

    if [ -n "$daily_off" ]; then
        echo "[定时关机 - 每天]: 开启 (时间 $(echo "$daily_off" | cut -d' ' -f2):$(echo "$daily_off" | cut -d' ' -f1))"
    elif [ -n "$once_off" ]; then
        # 提取目标日期
        local target_date=$(echo "$once_off" | grep -o "Target: [0-9-]*" | cut -d' ' -f2)
        echo "[定时关机 - 单次]: 开启 ($target_date $(echo "$once_off" | cut -d' ' -f2):$(echo "$once_off" | cut -d' ' -f1))"
    else
        echo "[定时关机]: 未设置"
    fi

    # 检查开机
    local rtc_time=$(cat $WAKEALARM_FILE 2>/dev/null)
    if [ "$rtc_time" != "0" ] && [ -n "$rtc_time" ]; then
        echo "[定时开机]: 下次执行于 $(date -d "@$rtc_time")"
    else
        echo "[定时开机]: 未设置"
    fi

    # 检查媳妇模式
    if [ -n "$wife_off" ]; then
        echo "[疼媳妇模式]: 已开启"
        if [ -f "$WIFE_CONFIG" ]; then
            source "$WIFE_CONFIG"
            echo " -> 目标日期: $NEXT_CARE_DATE"
        fi
    fi
    echo "--------------------------------"
    echo -n "按回车返回..."
    read -r dummy < /dev/tty
}

# --- 主菜单 ---
function main_menu() {
    while true; do
        clear
        echo "=================================="
        echo "      定时开关机工具"
        echo "=================================="
        echo "1. 设置 [定时关机] (每天/单次)"
        echo "2. 设置 [定时开机]"
        echo "3. 启用 [疼媳妇模式（单身生物无缘此功能）]"
        echo "4. 取消任务"
        echo "5. 查看状态"
        echo "q. 退出"
        echo "----------------------------------"
        echo -n "请输入选项: "
        
        if ! read -r choice < /dev/tty; then exit 1; fi

        case "$choice" in
            1) set_shutdown_menu; echo -n "按回车继续..."; read -r dummy < /dev/tty;;
            2) set_wakeup; echo -n "按回车继续..."; read -r dummy < /dev/tty;;
            3) set_wife_mode; echo -n "按回车继续..."; read -r dummy < /dev/tty;;
            4) cancel_task;;
            5) status;;
            q) exit 0;;
            *) echo "输入无效"; sleep 1;;
        esac
    done
}

main_menu