#!/bin/bash

# ==============================================================================
# NAS/服务器 GPU & FFmpeg 编解码能力检测脚本 (v3.0 - 表格版)
#
# 描述:
#   交叉对比 vainfo 和 ffmpeg 的能力，并以表格形式输出。
#   - 主表格: vainfo 和 ffmpeg 均支持的格式 (按色深/色度)
#   - 附表格: 仅 vainfo 支持 (ffmpeg 未识别) 的格式
#
# 依赖:
#   - 基础: pciutils (lspci), vdpau-utils (vdpauinfo), ffmpeg
#   - 核心解析: vainfo, python3
# ==============================================================================

# -------------------------- 配置区 --------------------------
# 颜色定义
declare -A COLORS=(
    [GREEN]="\033[0;32m"
    [YELLOW]="\033[0;33m"
    [RED]="\033[0;31m"
    [BLUE]="\033[0;34m"
    [CYAN]="\033[0;36m"
    [NC]="\033[0m"  # 重置颜色
)

# 硬件加速关键字
# 此变量将被导出，供 Python 脚本使用
export HW_KEYWORDS="vaapi|qsv|cuvid|nvenc|nvdec|amf"

# -------------------------- 工具函数 --------------------------
# 打印带颜色的文本
color_echo() {
    local color=$1
    local text=$2
    echo -e "${COLORS[$color]}${text}${COLORS[NC]}"
}

# 打印标题
echo_header() {
    echo -e "\n$(color_echo GREEN "=== $1 ===")"
}

# 状态提示函数
echo_success() { echo -e " $(color_echo GREEN "✔") $1"; }
echo_warning() { echo -e " $(color_echo YELLOW "⚠") $1"; }
echo_error() { echo -e " $(color_echo RED "❌") $1"; }
echo_info() { echo -e " $(color_echo BLUE "ⓘ") $1"; }

# 检查命令是否存在
check_command() {
    local cmd=$1
    local pkg=$2
    if command -v "$cmd" &> /dev/null; then
        echo_success "$cmd 已就绪"
        return 0
    else
        echo_warning "$cmd 未找到，相关功能将受限"
        echo_info "建议安装: sudo apt install $pkg"
        return 1
    fi
}

# 检查命令是否可用（静默版，用于流程控制）
is_available() {
    command -v "$1" &> /dev/null
}

# -------------------------- 核心解析函数 (Python) --------------------------
#
# 此函数将执行所有解析、交叉对比和表格打印
#
parse_and_cross_reference() {
    # 将 Shell 捕获的原始数据导出为环境变量
    # Python 脚本将从环境变量中读取这些数据
    export VAINFO_RAW
    export ALL_DECODERS_RAW
    export ALL_ENCODERS_RAW

    # 执行 Python 脚本
    python3 << EOF
import sys
import os
from collections import defaultdict

# --- 0. 定义 ---
# ANSI 颜色 (在 Python 内部硬编码，使表格着色更简单)
C = {
    "GREEN": "\033[0;32m",
    "YELLOW": "\033[0;33m",
    "CYAN": "\033[0;36m",
    "RED": "\033[0;31m",
    "NC": "\033[0m"
}

# --- 1. 解析 FFmpeg (获取支持的编解码器名称) ---

# vainfo 风格的编解码器名称映射
# (用于将 ffmpeg 的 'h264' 统一为 'H.264 (AVC)')
CODEC_MAP_FFMPEG = {
    "h264": "H.264 (AVC)",
    "hevc": "H.265 (HEVC)",
    "mpeg1": "MPEG-1",
    "mpeg2": "MPEG-2",
    "mpeg4": "MPEG-4",
    "mjpeg": "MJPEG",
    "vc1": "VC-1",
    "vp8": "VP8",
    "vp9": "VP9",
    "av1": "AV1"
}

def parse_ffmpeg_list(raw_output, hw_keywords):
    supported_codecs = set()
    if not raw_output or not hw_keywords:
        return supported_codecs
    
    keywords = hw_keywords.split('|')
    
    for line in raw_output.strip().splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
            
        codec_name = parts[1]
        
        # 检查是否为硬件加速器
        if not any(kw in codec_name for kw in keywords):
            continue
            
        # 提取基础编解码器 (例如 'hevc_vaapi' -> 'hevc')
        base_codec = codec_name.split('_')[0]
        if base_codec.endswith("video"):
            base_codec = base_codec[:-5]
        
        # 转换为友好名称
        friendly_name = CODEC_MAP_FFMPEG.get(base_codec, base_codec.upper())
        supported_codecs.add(friendly_name)
        
    return supported_codecs

# 从环境变量读取原始数据
raw_decoders = os.environ.get("ALL_DECODERS_RAW", "")
raw_encoders = os.environ.get("ALL_ENCODERS_RAW", "")
hw_keywords = os.environ.get("HW_KEYWORDS", "")

# 获取 FFmpeg 支持的编解码器集合
ffmpeg_decoders = parse_ffmpeg_list(raw_decoders, hw_keywords)
ffmpeg_encoders = parse_ffmpeg_list(raw_encoders, hw_keywords)

# --- 2. 解析 Vainfo (获取详细的配置文件) ---

# vainfo 配置文件名称到友好名称的映射
CODEC_MAP_VAINFO = {
    "H264": "H.264 (AVC)",
    "HEVC": "H.265 (HEVC)",
    "MPEG2": "MPEG-2",
    "VC1": "VC-1",
    "VP8": "VP8",
    "VP9": "VP9",
    "AV1": "AV1",
    "JPEGBaseline": "JPEG",
}

raw_vainfo = os.environ.get("VAINFO_RAW", "")
vainfo_profiles = [] # 存储解析结果的字典列表
seen_profiles = set() # 用于去重

for line in raw_vainfo.splitlines():
    if "VAProfile" not in line:
        continue
    parts = line.split(":", 1)
    if len(parts) < 2:
        continue
        
    profile_part = parts[0].strip().replace("VAProfile", "")
    entrypoint_part = parts[1].strip()
    
    for tech_name, common_name in CODEC_MAP_VAINFO.items():
        if profile_part.startswith(tech_name):
            # 默认值
            bit_depth = "8-bit"
            chroma = "4:2:0"
            
            # 检测位深
            if "Main10" in profile_part or "_10" in profile_part: bit_depth = "10-bit"
            elif "_12" in profile_part: bit_depth = "12-bit"
                
            # 检测色度
            if "422" in profile_part: chroma = "4:2:2"
            elif "444" in profile_part: chroma = "4:4:4"
                
            profile_data = (common_name, bit_depth, chroma)

            # 区分解码和编码
            if "VLD" in entrypoint_part:
                profile_key = (*profile_data, "解码 (Decode)")
                if profile_key not in seen_profiles:
                    vainfo_profiles.append({'codec': common_name, 'depth': bit_depth, 'chroma': chroma, 'type': '解码 (Decode)'})
                    seen_profiles.add(profile_key)
                    
            if "Enc" in entrypoint_part:
                profile_key = (*profile_data, "编码 (Encode)")
                if profile_key not in seen_profiles:
                    vainfo_profiles.append({'codec': common_name, 'depth': bit_depth, 'chroma': chroma, 'type': '编码 (Encode)'})
                    seen_profiles.add(profile_key)
            break

# --- 3. 交叉对比 ---

main_table_rows = []
vaapi_only_rows = []

for profile in vainfo_profiles:
    codec = profile['codec']
    if profile['type'] == '解码 (Decode)':
        if codec in ffmpeg_decoders:
            main_table_rows.append(profile)
        else:
            vaapi_only_rows.append(profile)
    elif profile['type'] == '编码 (Encode)':
        if codec in ffmpeg_encoders:
            main_table_rows.append(profile)
        else:
            vaapi_only_rows.append(profile)

# --- 4. 打印表格 ---

def print_table(title, rows, title_color):
    print(f"\n  {title_color}{title}{C['NC']}")
    
    if not rows:
        print(f"    {C['RED']}(无){C['NC']}")
        return

    # 计算列宽
    cols = ['codec', 'depth', 'chroma', 'type']
    headers = ['编解码器', '色深', '色度采样', '支持方向']
    
    # 初始化为标题宽度
    widths = {col: len(h) for col, h in zip(cols, headers)}
    
    # 找到数据中的最大宽度
    for row in rows:
        for col in cols:
            widths[col] = max(widths[col], len(row[col]))
            
    # 打印表头
    header_str = "    "
    for col, h in zip(cols, headers):
        header_str += f"{h:<{widths[col]}} | "
    print(f"  {C['CYAN']}{header_str.strip(' | ')}{C['NC']}")
    
    # 打印分隔线
    divider_str = "    "
    for col in cols:
        divider_str += f"{'-' * widths[col]}---"
    print(f"  {C['CYAN']}{divider_str.strip('-')}{C['NC']}")

    # 打印数据行
    for row in sorted(rows, key=lambda x: (x['codec'], x['type'], x['depth'], x['chroma'])):
        row_str = "    "
        for col in cols:
            row_str += f"{row[col]:<{widths[col]}} | "
        print(row_str.strip(' | '))

# 执行打印
print_table(
    "✅ 主支持列表 (VA-API & FFmpeg 均支持)", 
    main_table_rows, 
    C['GREEN']
)

print_table(
    "⚠ 仅 VA-API 支持 (FFmpeg 可能未正确配置或不支持该配置文件)", 
    vaapi_only_rows, 
    C['YELLOW']
)

EOF
}

# -------------------------- 主检测流程 --------------------------
main() {
    # 1. 依赖工具检查
    echo_header "1. 依赖工具检查"
    dependencies=(
        "lspci:pciutils"
        "vainfo:vainfo"
        "python3:python3"
        "vdpauinfo:vdpau-utils"
        "ffmpeg:ffmpeg"
    )
    
    for item in "${dependencies[@]}"; do
        local cmd=${item%:*}
        local pkg=${item#*:}
        check_command "$cmd" "$pkg"
    done

    # 2. GPU硬件检测
    echo_header "2. GPU 硬件检测 (lspci)"
    local GPU_TYPE="Unknown"
    if is_available "lspci"; then
        local LSPCI_OUTPUT=$(lspci | grep -iE 'VGA|3D|Display')
        if [[ -z "$LSPCI_OUTPUT" ]]; then
            echo_error "未找到任何显示控制器"
        else
            color_echo BLUE "$LSPCI_OUTPUT"
            if echo "$LSPCI_OUTPUT" | grep -iq "NVIDIA"; then GPU_TYPE="NVIDIA"
            elif echo "$LSPCI_OUTPUT" | grep -iq "Intel"; then GPU_TYPE="Intel"
            elif echo "$LSPCI_OUTPUT" | grep -iqE "AMD|Advanced Micro Devices|ATI"; then GPU_TYPE="AMD"
            fi
            echo_success "检测到 GPU 类型: $GPU_TYPE"
        fi
    else
        echo_warning "未安装 lspci，跳过 GPU 类型检测"
    fi

    # 3. VA-API & FFmpeg 交叉对比表
    #    这是新的核心检测步骤
    echo_header "3. VA-API & FFmpeg 交叉对比表"
    if is_available "vainfo" && is_available "python3" && is_available "ffmpeg"; then
        
        # 捕获 vainfo 输出
        VAINFO_RAW=$(vainfo 2>/dev/null)
        
        if [[ $? -ne 0 || ! "$VAINFO_RAW" =~ "VA-API version" ]]; then
            echo_error "vainfo 运行失败（驱动可能未正确加载）"
            echo_info "Intel用户建议安装: intel-media-va-driver"
            echo_info "AMD用户建议安装: mesa-va-drivers"
        else
            echo_success "vainfo 运行成功。正在与 FFmpeg 交叉对比..."
            
            # 捕获 FFmpeg 输出
            ALL_DECODERS_RAW=$(ffmpeg -decoders 2>/dev/null)
            ALL_ENCODERS_RAW=$(ffmpeg -encoders 2>/dev/null)

            # 调用 Python 核心解析器
            # (数据通过 export 的环境变量传递)
            parse_and_cross_reference
            
            # 清理环境变量
            unset VAINFO_RAW ALL_DECODERS_RAW ALL_ENCODERS_RAW
        fi
    else
        if ! is_available "vainfo"; then echo_warning "未安装 vainfo，跳过"
        elif ! is_available "python3"; then echo_warning "未安装 python3，跳过"
        elif ! is_available "ffmpeg"; then echo_warning "未安装 ffmpeg，跳过"
        fi
    fi

    # 4. VDPAU 编解码能力检测 (保持独立)
    echo_header "4. VDPAU 编解码能力 (vdpauinfo)"
    if [[ "$GPU_TYPE" =~ ^(NVIDIA|AMD)$ ]]; then
        if is_available "vdpauinfo"; then
            local VDPAU_RAW=$(vdpauinfo 2>/dev/null)
            if [[ $? -eq 0 && "$VDPAU_RAW" =~ "VDPAU API version" ]]; then
                echo_success "vdpauinfo 运行成功，摘要如下:"
                echo -e "\n  $(color_echo CYAN "--- 解码器 (Decoder) ---")"
                echo "$VDPAU_RAW" | grep -A 10 "Decoder" | grep 'VDP_DECODER' | awk '{print "    - " $1}' | sort -u
                
                echo -e "\n  $(color_echo CYAN "--- 编码器 (Encoder) ---")"
                echo "$VDPAU_RAW" | grep -A 10 "Encoder" | grep 'VDP_ENCODER' | awk '{print "    - " $1}' | sort -u
            else
                echo_warning "vdpauinfo 运行失败（驱动可能未正确加载）"
                echo_info "NVIDIA用户请主要关注交叉对比表中的结果"
            fi
        else
            echo_warning "未安装 vdpauinfo，跳过 VDPAU 检测"
        fi
    else
        echo_info "非NVIDIA/AMD GPU，跳过VDPAU检测"
    fi

    # 5. FFmpeg 硬件加速格式总结 (此部分已被合并到第3节)
    # echo_header "5. FFmpeg 支持总结（仅代表软件支持）"
    # (已移除)

    echo -e "\n--- $(color_echo GREEN "检测完成") （共建团QD_青团制作） ---\n"
}

# 启动主流程
main