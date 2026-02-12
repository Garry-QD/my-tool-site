#!/bin/bash

# ==============================================================================
#  功能：全面分析 ARM (Rockchip) V4L2 视频编解码能力 (修正版)
# ==============================================================================

# 颜色定义
ERROR_COLOR='\033[0;31m'
WARN_COLOR='\033[0;33m'
OK_COLOR='\033[0;32m'
INFO_COLOR='\033[0;36m'
NO_COLOR='\033[0m'

declare -A DEV_IN_COMPRESSED
declare -A DEV_OUT_COMPRESSED
declare -A DEV_IN_RAW
declare -A DEV_OUT_RAW

declare -A CODEC_DECODE_RAW
declare -A CODEC_ENCODE_RAW

ALL_CODECS=""

str_add_word() {
    local var_name=$1
    local word=$2
    local cur="${!var_name}"
    if [[ " $cur " == *" $word "* ]]; then
        return
    fi
    if [ -z "$cur" ]; then
        printf -v "$var_name" "%s" "$word"
    else
        printf -v "$var_name" "%s %s" "$cur" "$word"
    fi
}

map_add_word() {
    local map_name=$1
    local key=$2
    local word=$3
    local cur
    eval "cur=\"\${$map_name[\"\$key\"]}\""
    if [[ " $cur " == *" $word "* ]]; then
        return
    fi
    if [ -z "$cur" ]; then
        eval "$map_name[\"\$key\"]=\"\$word\""
    else
        eval "$map_name[\"\$key\"]=\"\$cur \$word\""
    fi
}

raw_info() {
    local fourcc=$1
    case "$fourcc" in
        NV12|NM12|NV21|YU12|YV12|I420|YUV420|YM12|YM21)
            echo "8 4:2:0"
            ;;
        P010|P010M)
            echo "10 4:2:0"
            ;;
        P012|P012M)
            echo "12 4:2:0"
            ;;
        P016|P016M)
            echo "16 4:2:0"
            ;;
        NV16|NV61|YUYV|UYVY|VYUY|YVYU|Y42B|YUV422P|YUV422M)
            echo "8 4:2:2"
            ;;
        NV24|Y444|YUV444|YUV444M)
            echo "8 4:4:4"
            ;;
        XR24|AR24|XB24|AB24|RGB3|BGR3|RGBP|BGRP)
            echo "8 RGB"
            ;;
        RG10|BA10|BG10|GB10)
            echo "10 RGB"
            ;;
        *)
            echo "-- --"
            ;;
    esac
}

codec_label() {
    local codec=$1
    case "$codec" in
        H264) echo "H.264/AVC" ;;
        HEVC) echo "H.265/HEVC" ;;
        VP8) echo "VP8" ;;
        VP9) echo "VP9" ;;
        AV1) echo "AV1" ;;
        JPEG) echo "JPEG" ;;
        MPEG2) echo "MPEG-2" ;;
        MPEG4) echo "MPEG-4" ;;
        H263) echo "H.263" ;;
        *) echo "$codec" ;;
    esac
}

format_classify() {
    local fourcc=$1
    local raw_desc=$2

    local kind="其他"
    local canon="$fourcc"
    local depth="--"
    local chroma="--"
    local display_desc="$raw_desc"
    local should_print=false

    local raw_desc_lc
    raw_desc_lc=$(echo "$raw_desc" | tr '[:upper:]' '[:lower:]')

    case "$fourcc" in
        H264|AVC1|S264)
            kind="压缩"
            canon="H264"
            display_desc="H.264 / AVC"
            should_print=true
            ;;
        H265|HEVC)
            kind="压缩"
            canon="HEVC"
            display_desc="H.265 / HEVC"
            should_print=true
            ;;
        VP8|VP80)
            kind="压缩"
            canon="VP8"
            display_desc="VP8"
            should_print=true
            ;;
        VP9|VP90)
            kind="压缩"
            canon="VP9"
            display_desc="VP9"
            should_print=true
            ;;
        AV1|AV10|AV1F)
            kind="压缩"
            canon="AV1"
            display_desc="AV1"
            should_print=true
            ;;
        MJPG|JPEG)
            kind="压缩"
            canon="JPEG"
            display_desc="JPEG"
            should_print=true
            ;;
        MPG2|MPG2M|MP2V)
            kind="压缩"
            canon="MPEG2"
            display_desc="MPEG-2"
            should_print=true
            ;;
        MPG4|MPG4M|MPEG|MP4V)
            kind="压缩"
            canon="MPEG4"
            display_desc="MPEG-4"
            should_print=true
            ;;
        H263)
            kind="压缩"
            canon="H263"
            display_desc="H.263"
            should_print=true
            ;;
        NV12|NM12|NV21|NV16|NV24|YU12|YV12|I420|YUV420|YM12|YM21|P010|P010M|P012|P012M|P016|P016M|YUYV|UYVY|VYUY|YVYU|Y42B|Y444|YUV444|YUV422P|YUV422M|YUV444M|XR24|AR24|XB24|AB24|RGB3|BGR3|RGBP|BGRP|RG10|BA10|BG10|GB10)
            kind="RAW"
            IFS=' ' read -r depth chroma < <(raw_info "$fourcc")
            display_desc="$raw_desc"
            should_print=true
            ;;
        *)
            if [[ "$raw_desc_lc" == *"compressed"* ]]; then
                kind="压缩"
                canon="$fourcc"
                display_desc="$raw_desc"
                should_print=true
            fi
            ;;
    esac

    echo "$kind|$canon|$depth|$chroma|$display_desc|$should_print"
}

# --- 核心判定函数：检查环境 ---
check_requirements() {
    # 1. 检查工具
    if ! command -v v4l2-ctl &> /dev/null; then
        echo -e "${WARN_COLOR}[警告] 未找到 v4l2-ctl，尝试安装...${NO_COLOR}"
        if [ "$EUID" -eq 0 ]; then
            apt-get update && apt-get install -y v4l-utils
        else
            echo -e "${ERROR_COLOR}[错误] 请手动安装：sudo apt-get install v4l-utils${NO_COLOR}"
            exit 1
        fi
    fi

    # 2. 检查设备
    shopt -s nullglob
    video_devices=(/dev/video*)
    shopt -u nullglob
    if [ ${#video_devices[@]} -eq 0 ]; then
        echo -e "${ERROR_COLOR}[错误] 未检测到 /dev/video* 设备，驱动可能未加载。${NO_COLOR}"
        exit 1
    fi
}

# --- 打印表头 ---
print_header() {
    echo "----------------------------------------------------------------------------------------------------------------------------"
    printf "%-12s | %-12s | %-6s | %-12s | %-6s | %-18s | %-8s | %-8s | %-15s\n" "设备" "方向" "索引" "格式代码" "类别" "格式说明" "色深" "色度" "支持分辨率"
    echo "----------------------------------------------------------------------------------------------------------------------------"
}

size_pretty() {
    local sizes_blob=$1
    local stepwise
    stepwise=$(echo "$sizes_blob" | grep -m 1 -E "Stepwise")
    if [ -n "$stepwise" ]; then
        echo "$stepwise" | awk '{print $3 " -> " $5}'
        return
    fi

    local discrete_lines
    discrete_lines=$(echo "$sizes_blob" | grep -E "Discrete" | head -n 3 | awk '{print $3}' | paste -sd "," -)
    if [ -n "$discrete_lines" ]; then
        echo "$discrete_lines"
        return
    fi

    echo "--"
}

dump_v4l2_formats() {
    local device=$1
    local direction=$2

    local tmp_output
    tmp_output=$(mktemp)

    local cmd_candidates=()
    if [ "$direction" = "in" ]; then
        cmd_candidates=(--list-formats-out-ext --list-formats-out --list-formats-out-mplane)
    else
        cmd_candidates=(--list-formats-ext --list-formats --list-formats-mplane)
    fi

    local cmd
    for cmd in "${cmd_candidates[@]}"; do
        local tmp_one
        tmp_one=$(mktemp)
        v4l2-ctl -d "$device" "$cmd" 2>/dev/null > "$tmp_one" || true
        if [ -s "$tmp_one" ] && grep -qE "^\s*\[[0-9]+\]" "$tmp_one" && ! grep -q "Inappropriate ioctl" "$tmp_one"; then
            cat "$tmp_one" > "$tmp_output"
            rm "$tmp_one"
            echo "$tmp_output"
            return
        fi
        rm "$tmp_one"
    done

    rm "$tmp_output"
    echo ""
}

dev_add_format() {
    local device=$1
    local direction=$2
    local kind=$3
    local canon=$4

    if [ "$kind" = "压缩" ]; then
        if [ "$direction" = "in" ]; then
            map_add_word DEV_IN_COMPRESSED "$device" "$canon"
        else
            map_add_word DEV_OUT_COMPRESSED "$device" "$canon"
        fi
        str_add_word ALL_CODECS "$canon"
    elif [ "$kind" = "RAW" ]; then
        if [ "$direction" = "in" ]; then
            map_add_word DEV_IN_RAW "$device" "$canon"
        else
            map_add_word DEV_OUT_RAW "$device" "$canon"
        fi
    fi
}

# --- 核心解析逻辑 ---
parse_device_formats() {
    local device=$1
    local direction=$2
    local direction_label=$3

    local tmp_output
    tmp_output=$(dump_v4l2_formats "$device" "$direction")
    if [ -z "$tmp_output" ] || [ ! -s "$tmp_output" ]; then
        return 1
    fi

    local index=""
    local fourcc=""
    local raw_desc=""
    local sizes_blob=""
    local printed_any=false

    emit_one() {
        local e_index=$1
        local e_fourcc=$2
        local e_raw_desc=$3
        local e_sizes_blob=$4
        if [ -z "$e_fourcc" ]; then
            return
        fi

        local kind canon depth chroma display_desc should_print
        IFS='|' read -r kind canon depth chroma display_desc should_print < <(format_classify "$e_fourcc" "$e_raw_desc")

        if [ "$kind" = "压缩" ]; then
            depth="压缩流"
            chroma="--"
        fi

        if [ "$should_print" = "true" ]; then
            dev_add_format "$device" "$direction" "$kind" "$canon"
            local resolutions
            resolutions=$(size_pretty "$e_sizes_blob")

            printf "%-12s | %-12s | %-6s | %-12s | %-6s | %-18s | %-8s | %-8s | %-15s\n" "$device" "$direction_label" "$e_index" "$e_fourcc" "$kind" "${display_desc:0:18}" "$depth" "$chroma" "${resolutions:0:20}"
            printed_any=true
        fi
    }

    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*\[([0-9]+)\]:[[:space:]]\'([^\']+)\'[[:space:]]\((.*)\) ]]; then
            emit_one "$index" "$fourcc" "$raw_desc" "$sizes_blob"
            index="${BASH_REMATCH[1]}"
            fourcc="${BASH_REMATCH[2]}"
            raw_desc="${BASH_REMATCH[3]}"
            sizes_blob=""
            continue
        fi
        if [[ $line =~ Size:\ (.*) ]]; then
            local s="${BASH_REMATCH[1]}"
            if [ -z "$sizes_blob" ]; then
                sizes_blob="$s"
            else
                sizes_blob+=$'\n'"$s"
            fi
        fi
    done < "$tmp_output"

    emit_one "$index" "$fourcc" "$raw_desc" "$sizes_blob"
    rm -f "$tmp_output"
    if [ "$printed_any" = true ]; then
        return 0
    fi
    return 1
}

summarize_raw_set() {
    local raw_set=$1
    local depths=""
    local chromas=""

    local f
    for f in $raw_set; do
        local bits chroma
        IFS=' ' read -r bits chroma < <(raw_info "$f")
        if [ "$bits" != "--" ]; then
            str_add_word depths "${bits}-bit"
        fi
        if [ "$chroma" != "--" ]; then
            str_add_word chromas "$chroma"
        fi
    done

    if [ -z "$depths" ]; then depths="--"; fi
    if [ -z "$chromas" ]; then chromas="--"; fi
    echo "$depths|$chromas"
}

build_codec_summary() {
    local dev
    for dev in /dev/video*; do
        if [ ! -e "$dev" ]; then continue; fi

        local in_comp out_comp in_raw out_raw
        in_comp="${DEV_IN_COMPRESSED[$dev]}"
        out_comp="${DEV_OUT_COMPRESSED[$dev]}"
        in_raw="${DEV_IN_RAW[$dev]}"
        out_raw="${DEV_OUT_RAW[$dev]}"

        local c r
        if [ -n "$in_comp" ] && [ -n "$out_raw" ]; then
            for c in $in_comp; do
                for r in $out_raw; do
                    map_add_word CODEC_DECODE_RAW "$c" "$r"
                done
            done
        fi

        if [ -n "$out_comp" ] && [ -n "$in_raw" ]; then
            for c in $out_comp; do
                for r in $in_raw; do
                    map_add_word CODEC_ENCODE_RAW "$c" "$r"
                done
            done
        fi
    done
}

print_codec_summary() {
    build_codec_summary

    echo ""
    echo "============================================================================================================================"
    echo "                                             编解码能力汇总 (基于 V4L2)                                            "
    echo "============================================================================================================================"
    printf "%-12s | %-18s | %-18s | %-18s | %-18s\n" "格式" "解码:色深/色度" "解码:RAW(输出)" "编码:色深/色度" "编码:RAW(输入)"
    echo "----------------------------------------------------------------------------------------------------------------------------"

    local codec
    for codec in $(printf "%s\n" $ALL_CODECS | sort -u); do
        local decode_raw encode_raw
        decode_raw="${CODEC_DECODE_RAW[$codec]}"
        encode_raw="${CODEC_ENCODE_RAW[$codec]}"

        local decode_summary encode_summary
        decode_summary="--/--"
        encode_summary="--/--"

        if [ -n "$decode_raw" ]; then
            IFS='|' read -r d_depths d_chromas < <(summarize_raw_set "$decode_raw")
            decode_summary="${d_depths}/${d_chromas}"
        fi

        if [ -n "$encode_raw" ]; then
            IFS='|' read -r e_depths e_chromas < <(summarize_raw_set "$encode_raw")
            encode_summary="${e_depths}/${e_chromas}"
        fi

        printf "%-12s | %-18s | %-18s | %-18s | %-18s\n" "$(codec_label "$codec")" "${decode_summary:0:18}" "${decode_raw:0:18}" "${encode_summary:0:18}" "${encode_raw:0:18}"
    done
}

print_optional_runtime() {
    if command -v ffmpeg >/dev/null 2>&1; then
        echo ""
        echo "============================================================================================================================"
        echo "                                               FFmpeg 硬件编解码探测                                               "
        echo "============================================================================================================================"
        echo "可用 hwaccel:"
        ffmpeg -hide_banner -hwaccels 2>/dev/null | sed 's/^\s*//'
        echo ""
        echo "硬件相关 Decoder/Encoder (包含 v4l2m2m/rkmpp/vaapi/omx):"
        ffmpeg -hide_banner -decoders 2>/dev/null | grep -E "v4l2m2m|rkmpp|vaapi|omx" || true
        ffmpeg -hide_banner -encoders 2>/dev/null | grep -E "v4l2m2m|rkmpp|vaapi|omx" || true
    fi

    if command -v gst-inspect-1.0 >/dev/null 2>&1; then
        echo ""
        echo "============================================================================================================================"
        echo "                                            GStreamer 硬件编解码相关元素                                             "
        echo "============================================================================================================================"

        local any_found=false
        local e
        for e in v4l2h264dec v4l2h265dec v4l2vp8dec v4l2vp9dec v4l2av1dec v4l2h264enc v4l2h265enc rkmppdec rkmppenc mppvideodec mpph264enc mpph265enc; do
            if gst-inspect-1.0 "$e" >/dev/null 2>&1; then
                echo "$e"
                any_found=true
            fi
        done
        if [ "$any_found" = false ]; then
            echo "--"
        fi
    fi

    if command -v vainfo >/dev/null 2>&1; then
        echo ""
        echo "============================================================================================================================"
        echo "                                                  VAAPI 能力 (vainfo)                                                 "
        echo "============================================================================================================================"
        vainfo 2>/dev/null | grep -E "VAProfile|VAEntrypoint" || true
    fi
}

print_v4l2_devices() {
    echo ""
    echo "============================================================================================================================"
    echo "                                                  V4L2 设备信息                                                  "
    echo "============================================================================================================================"
    printf "%-12s | %-14s | %-28s | %-24s\n" "设备" "驱动" "卡名称" "设备能力"
    echo "----------------------------------------------------------------------------------------------------------------------------"

    local dev
    for dev in /dev/video*; do
        if [ ! -e "$dev" ]; then continue; fi
        local di
        di=$(v4l2-ctl -d "$dev" -D 2>/dev/null) || true
        if [ -z "$di" ]; then
            continue
        fi
        local driver card dev_caps
        driver=$(echo "$di" | awk -F: '/Driver name/{gsub(/^[ \t]+/,"",$2); print $2; exit}')
        card=$(echo "$di" | awk -F: '/Card type/{gsub(/^[ \t]+/,"",$2); print $2; exit}')
        dev_caps=$(echo "$di" | awk -F: '/Device Caps/{gsub(/^[ \t]+/,"",$2); print $2; exit}')
        [ -z "$driver" ] && driver="--"
        [ -z "$card" ] && card="--"
        [ -z "$dev_caps" ] && dev_caps="--"
        printf "%-12s | %-14s | %-28s | %-24s\n" "$dev" "${driver:0:14}" "${card:0:28}" "${dev_caps:0:24}"
    done
}

# ==================== 主程序 ====================

check_requirements

echo ""
echo "============================================================================================================================"
echo "                                   ARM 视频硬件能力全览 (Bi-Directional)                                  "
echo "============================================================================================================================"
print_header

# 遍历所有 video 设备
for dev in /dev/video*; do
    if [ ! -e "$dev" ]; then continue; fi
    
    v4l2-ctl -d "$dev" -D >/dev/null 2>&1 || continue

    device_printed=false
    if parse_device_formats "$dev" "in" "输入(Input)"; then
        device_printed=true
    fi
    if parse_device_formats "$dev" "out" "输出(Output)"; then
        device_printed=true
    fi
    if [ "$device_printed" = true ]; then
        echo "----------------------------------------------------------------------------------------------------------------------------"
    fi
done

print_v4l2_devices
print_codec_summary
print_optional_runtime

echo "说明:"
echo "1. 解码器(vdec)：输入(Input)应包含 H264/HEVC，输出(Output)应包含 NV12。"
echo "2. 编码器(venc)：输入(Input)应包含 NV12/YM12，输出(Output)应包含 H264/HEVC。"
echo "3. 本脚本由青团制作有事情请加群613835409。"
echo "============================================================================================================================"
