#!/bin/bash

# ==============================================================================
#  功能：Rockchip 视频编码能力表 (V4L2 可选 + FFmpeg/GStreamer)
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

declare -A CODEC_DECODE_BACKENDS
declare -A CODEC_ENCODE_BACKENDS

ALL_CODECS=""
SOC_VENDOR="unknown"
SOC_COMPAT=""
QUIET="true"

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

codec_add_backend() {
    local codec=$1
    local dir=$2
    local backend=$3

    if [ -z "$codec" ] || [ -z "$backend" ]; then
        return
    fi

    str_add_word ALL_CODECS "$codec"
    if [ "$dir" = "decode" ]; then
        map_add_word CODEC_DECODE_BACKENDS "$codec" "$backend"
    else
        map_add_word CODEC_ENCODE_BACKENDS "$codec" "$backend"
    fi
}

rkmpp_present() {
    if [ -e /dev/mpp_service ] || [ -e /dev/rkvenc ] || [ -e /dev/rkvenc2 ]; then
        :
    fi

    shopt -s nullglob
    local libs=(
        /usr/lib*/librockchip_mpp.so*
        /usr/local/lib*/librockchip_mpp.so*
        /vendor/lib*/librockchip_mpp.so*
        /usr/lib*/librkmpp.so*
        /usr/local/lib*/librkmpp.so*
        /vendor/lib*/librkmpp.so*
        /usr/lib*/libmpp.so*
        /usr/local/lib*/libmpp.so*
        /vendor/lib*/libmpp.so*
    )
    shopt -u nullglob

    if [ ${#libs[@]} -gt 0 ]; then
        return 0
    fi

    if command -v ldconfig >/dev/null 2>&1; then
        ldconfig -p 2>/dev/null | grep -Eqi "rockchip_mpp|rkmpp|\blibmpp\.so" && return 0
    fi

    if command -v gst-inspect-1.0 >/dev/null 2>&1; then
        gst-inspect-1.0 rkmppenc >/dev/null 2>&1 && return 0
        gst-inspect-1.0 mpph264enc >/dev/null 2>&1 && return 0
        gst-inspect-1.0 mpph265enc >/dev/null 2>&1 && return 0
    fi

    if command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -hide_banner -encoders 2>/dev/null | grep -Eqi "rkmpp" && return 0
    fi

    command -v mpi_enc_test >/dev/null 2>&1 && return 0
    command -v mpp_info >/dev/null 2>&1 && return 0

    return 1
}

install_rkmpp() {
    if [ "$SOC_VENDOR" != "rockchip" ]; then
        return 0
    fi
    rkmpp_present && return 0

    echo -e "${WARN_COLOR}[警告] 检测到 Rockchip 平台但缺少 RKMPP 运行时，尝试安装...${NO_COLOR}"

    if [ "$EUID" -ne 0 ]; then
        echo -e "${WARN_COLOR}[警告] 当前非 root，无法自动安装。请使用 sudo 运行本脚本或手动安装 rockchip-mpp。${NO_COLOR}"
        return 0
    fi

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update || true
        local pkg
        for pkg in rockchip-mpp librockchip-mpp1 librockchip-mpp-dev librkmpp0 librkmpp-dev libmpp0 mpp; do
            apt-get install -y "$pkg" >/dev/null 2>&1 && break
        done
        rkmpp_present && echo -e "${OK_COLOR}[OK] RKMPP 安装/补齐完成。${NO_COLOR}" || echo -e "${WARN_COLOR}[警告] RKMPP 安装未成功或仓库无对应包。${NO_COLOR}"
        return 0
    fi

    if command -v opkg >/dev/null 2>&1; then
        opkg update || true
        local pkg
        for pkg in rockchip-mpp librkmpp libmpp mpp; do
            opkg install "$pkg" >/dev/null 2>&1 && break
        done
        rkmpp_present && echo -e "${OK_COLOR}[OK] RKMPP 安装/补齐完成。${NO_COLOR}" || echo -e "${WARN_COLOR}[警告] RKMPP 安装未成功或 feed 无对应包。${NO_COLOR}"
        return 0
    fi

    echo -e "${WARN_COLOR}[警告] 未识别包管理器(apt/opkg)，请按平台 SDK 手动安装 RKMPP。${NO_COLOR}"
}

detect_soc_vendor() {
    SOC_VENDOR="unknown"
    SOC_COMPAT=""

    if [ -r /proc/device-tree/compatible ]; then
        SOC_COMPAT=$(tr '\000' '\n' < /proc/device-tree/compatible 2>/dev/null | tr -d '\r' | head -n 6 | paste -sd ',' -)
        if echo "$SOC_COMPAT" | tr '[:upper:]' '[:lower:]' | grep -q "rockchip"; then
            SOC_VENDOR="rockchip"
            return 0
        fi
    fi

    local cpuinfo
    cpuinfo=$(cat /proc/cpuinfo 2>/dev/null || true)
    if echo "$cpuinfo" | grep -qi "rockchip"; then
        SOC_VENDOR="rockchip"
        return 0
    fi
}

print_platform_summary() {
    detect_soc_vendor

    local vendor_label="Unknown"
    case "$SOC_VENDOR" in
        rockchip) vendor_label="Rockchip" ;;
    esac

    echo ""
    echo "============================================================================================================================"
    echo "                                              平台识别 (Rockchip)                                               "
    echo "============================================================================================================================"
    echo "SoC: $vendor_label"
    if [ "$SOC_VENDOR" != "rockchip" ]; then
        echo -e "${WARN_COLOR}[警告] 当前脚本仅面向 Rockchip 编码能力表，非 Rockchip 平台结果可能不准确。${NO_COLOR}"
    fi
    if [ -n "$SOC_COMPAT" ]; then
        echo "DT compatible: ${SOC_COMPAT:0:180}"
    else
        local hw
        hw=$(grep -m 1 -E '^Hardware[[:space:]]*:' /proc/cpuinfo 2>/dev/null | awk -F: '{gsub(/^[ \t]+/,"",$2); print $2}' || true)
        [ -z "$hw" ] && hw=$(uname -a 2>/dev/null || true)
        [ -n "$hw" ] && echo "CPU info: ${hw:0:180}"
    fi
}

print_rkmpp_summary() {
    echo ""
    echo "============================================================================================================================"
    echo "                                               RKMPP 组件探测                                                  "
    echo "============================================================================================================================"

    local found_any=false

    if [ -e /dev/mpp_service ] || [ -e /dev/rkvenc ] || [ -e /dev/rkvenc2 ]; then
        echo "设备节点: /dev/mpp_service /dev/rkvenc*"
        found_any=true
    else
        echo "设备节点: --"
    fi

    local libs=()
    shopt -s nullglob
    libs+=(/usr/lib*/librockchip_mpp.so*)
    libs+=(/usr/local/lib*/librockchip_mpp.so*)
    libs+=(/vendor/lib*/librockchip_mpp.so*)
    libs+=(/usr/lib*/librkmpp.so*)
    libs+=(/usr/local/lib*/librkmpp.so*)
    libs+=(/vendor/lib*/librkmpp.so*)
    libs+=(/usr/lib*/libmpp.so*)
    libs+=(/usr/local/lib*/libmpp.so*)
    libs+=(/vendor/lib*/libmpp.so*)
    shopt -u nullglob

    if [ ${#libs[@]} -gt 0 ]; then
        echo "库文件:"
        printf "%s\n" "${libs[@]}" | sort -u | head -n 8
        found_any=true
    else
        if command -v ldconfig >/dev/null 2>&1; then
            local ld
            ld=$(ldconfig -p 2>/dev/null | grep -Ei "rockchip_mpp|rkmpp|\blibmpp\.so" | head -n 8 || true)
            if [ -n "$ld" ]; then
                echo "ldconfig:"
                echo "$ld"
                found_any=true
            else
                echo "库文件: --"
            fi
        else
            echo "库文件: --"
        fi
    fi

    local tools=""
    command -v mpi_enc_test >/dev/null 2>&1 && str_add_word tools "mpi_enc_test"
    command -v mpp_info >/dev/null 2>&1 && str_add_word tools "mpp_info"
    command -v mpi_enc_mt_test >/dev/null 2>&1 && str_add_word tools "mpi_enc_mt_test"
    if [ -n "$tools" ]; then
        echo "工具: $tools"
        found_any=true
    else
        echo "工具: --"
    fi

    if [ "$found_any" = false ]; then
        echo -e "${WARN_COLOR}[警告] 未检测到 RKMPP 相关节点/库/工具，可能只安装了用户态封装或驱动未加载。${NO_COLOR}"
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
    HAVE_V4L2=true
    shopt -s nullglob
    video_devices=(/dev/video*)
    shopt -u nullglob
    if [ ${#video_devices[@]} -eq 0 ]; then
        HAVE_V4L2=false
        echo -e "${WARN_COLOR}[警告] 未检测到 /dev/video*，将跳过 V4L2 探测，仅做 FFmpeg/GStreamer/节点探测。${NO_COLOR}"
        return 0
    fi

    if ! command -v v4l2-ctl &> /dev/null; then
        echo -e "${WARN_COLOR}[警告] 未找到 v4l2-ctl，尝试安装...${NO_COLOR}"
        if [ "$EUID" -eq 0 ]; then
            apt-get update && apt-get install -y v4l-utils
        else
            echo -e "${WARN_COLOR}[警告] 缺少 v4l2-ctl，将跳过 V4L2 探测。${NO_COLOR}"
            HAVE_V4L2=false
            return 0
        fi
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

            if [ "$QUIET" != "true" ]; then
                printf "%-12s | %-12s | %-6s | %-12s | %-6s | %-18s | %-8s | %-8s | %-15s\n" "$device" "$direction_label" "$e_index" "$e_fourcc" "$kind" "${display_desc:0:18}" "$depth" "$chroma" "${resolutions:0:20}"
            fi
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
        if [ -n "$out_comp" ] && [ -n "$in_raw" ]; then
            for c in $out_comp; do
                for r in $in_raw; do
                    map_add_word CODEC_ENCODE_RAW "$c" "$r"
                done
                codec_add_backend "$c" "encode" "v4l2"
            done
        fi
    done
}

ffmpeg_name_to_codec() {
    local name=$1
    case "$name" in
        h264*|avc*) echo "H264" ;;
        hevc*|h265*) echo "HEVC" ;;
        vp8*) echo "VP8" ;;
        vp9*) echo "VP9" ;;
        av1*) echo "AV1" ;;
        mjpeg*|jpeg*) echo "JPEG" ;;
        mpeg2*) echo "MPEG2" ;;
        mpeg4*|mpeg4video*) echo "MPEG4" ;;
        h263*) echo "H263" ;;
        *) echo "" ;;
    esac
}

detect_ffmpeg_backends() {
    command -v ffmpeg >/dev/null 2>&1 || return 0

    local encoders
    encoders=$(ffmpeg -hide_banner -encoders 2>/dev/null || true)

    local line name codec backend
    while IFS= read -r line; do
        [[ $line =~ ^[[:space:]]*[A-Z\.]{6}[[:space:]]+ ]] || continue
        name=$(echo "$line" | awk '{print $2}')
        [ -z "$name" ] && continue

        backend=""
        case "$name" in
            *_rkmpp|rkmpp*) backend="rkmpp(ffmpeg)" ;;
        esac
        [ -z "$backend" ] && continue

        codec=$(ffmpeg_name_to_codec "$name")
        [ -z "$codec" ] && continue
        codec_add_backend "$codec" "encode" "$backend"
    done <<< "$encoders"
}

gst_caps_to_codecs() {
    local blob=$1
    local codecs=""

    echo "$blob" | grep -qiE "video/x-h264" && str_add_word codecs "H264"
    echo "$blob" | grep -qiE "video/x-h265" && str_add_word codecs "HEVC"
    echo "$blob" | grep -qiE "video/x-vp8" && str_add_word codecs "VP8"
    echo "$blob" | grep -qiE "video/x-vp9" && str_add_word codecs "VP9"
    echo "$blob" | grep -qiE "video/x-av1" && str_add_word codecs "AV1"
    echo "$blob" | grep -qiE "image/jpeg" && str_add_word codecs "JPEG"
    echo "$blob" | grep -qiE "video/x-h263" && str_add_word codecs "H263"

    if echo "$blob" | grep -qiE "video/mpeg"; then
        echo "$blob" | grep -qiE "mpegversion=\(int\)2" && str_add_word codecs "MPEG2"
        echo "$blob" | grep -qiE "mpegversion=\(int\)4" && str_add_word codecs "MPEG4"
    fi

    echo "$codecs"
}

gst_backend_for_element() {
    local e=$1
    local e_lc
    e_lc=$(echo "$e" | tr '[:upper:]' '[:lower:]')
    if [[ "$e_lc" == *"rkmpp"* ]] || [[ "$e_lc" == mpp* ]]; then
        echo "rkmpp(gst)"
    elif [[ "$e_lc" == *"vpe"* ]]; then
        echo "vpe(gst)"
    else
        echo "gst"
    fi
}

detect_gstreamer_backends() {
    command -v gst-inspect-1.0 >/dev/null 2>&1 || return 0

    local candidates=(
        rkmppenc
        mpph264enc mpph265enc mppjpegenc
        vpeenc
    )

    local e info backend codecs dir codec
    for e in "${candidates[@]}"; do
        gst-inspect-1.0 "$e" >/dev/null 2>&1 || continue
        info=$(gst-inspect-1.0 "$e" 2>/dev/null || true)
        [ -z "$info" ] && continue
        codecs=$(gst_caps_to_codecs "$info")
        [ -z "$codecs" ] && continue

        backend=$(gst_backend_for_element "$e")
        dir="encode"
        [ -z "$dir" ] && continue

        for codec in $codecs; do
            codec_add_backend "$codec" "$dir" "$backend"
        done
    done
}

print_nodes_summary() {
    echo ""
    echo "============================================================================================================================"
    echo "                                                  设备节点探测                                                   "
    echo "============================================================================================================================"

    local nodes=(
        /dev/mpp_service
        /dev/rkvenc /dev/rkvenc2
        /dev/vpu_service /dev/vepu_service
        /dev/vpe /dev/vpe0 /dev/vpe1
    )

    local found=false
    local n
    for n in "${nodes[@]}"; do
        if [ -e "$n" ]; then
            echo "$n"
            found=true
        fi
    done

    if [ "$found" = false ]; then
        echo "--"
    fi

    if [ -r /proc/modules ]; then
        local key="rockchip|rkv|mpp|vpu|venc|vpe"
        if [ -n "$key" ]; then
            local mods
            mods=$(grep -Ei "$key" /proc/modules 2>/dev/null | head -n 8 || true)
            if [ -n "$mods" ]; then
                echo ""
                echo "模块提示:"
                echo "$mods" | awk '{print $1}' | paste -sd ' ' -
            fi
        fi
    fi
}

collect_runtime_backends() {
    detect_soc_vendor
    detect_ffmpeg_backends
    detect_gstreamer_backends
}

print_codec_summary() {
    build_codec_summary

    echo ""
    echo "============================================================================================================================"
    echo "                                        编码能力汇总 (基于 V4L2，如存在设备)                                         "
    echo "============================================================================================================================"
    printf "%-12s | %-18s | %-18s\n" "格式" "编码:色深/色度" "编码:RAW(输入)"
    echo "----------------------------------------------------------------------------------------------------------------------------"

    local codec
    for codec in $(printf "%s\n" $ALL_CODECS | sort -u); do
        local encode_raw
        encode_raw="${CODEC_ENCODE_RAW[$codec]}"

        local encode_summary
        encode_summary="--/--"

        if [ -n "$encode_raw" ]; then
            IFS='|' read -r e_depths e_chromas < <(summarize_raw_set "$encode_raw")
            encode_summary="${e_depths}/${e_chromas}"
        fi

        printf "%-12s | %-18s | %-18s\n" "$(codec_label "$codec")" "${encode_summary:0:18}" "${encode_raw:0:18}"
    done
}

print_backend_summary() {
    echo ""
    echo "============================================================================================================================"
    echo "                                         编码后端汇总 (V4L2/FFmpeg/GStreamer)                                          "
    echo "============================================================================================================================"
    printf "%-12s | %-60s\n" "格式" "编码后端"
    echo "----------------------------------------------------------------------------------------------------------------------------"

    local codec
    for codec in $(printf "%s\n" $ALL_CODECS | sort -u); do
        local e
        e="${CODEC_ENCODE_BACKENDS[$codec]}"
        [ -z "$e" ] && e="--"
        printf "%-12s | %-60s\n" "$(codec_label "$codec")" "${e:0:60}"
    done
}

print_optional_runtime() {
    if command -v ffmpeg >/dev/null 2>&1; then
        echo ""
        echo "============================================================================================================================"
        echo "                                               FFmpeg 编码后端探测                                               "
        echo "============================================================================================================================"
        echo "可用 hwaccel:"
        ffmpeg -hide_banner -hwaccels 2>/dev/null | sed 's/^\s*//'
        echo ""
        echo "硬件相关 Encoder (rkmpp):"
        ffmpeg -hide_banner -encoders 2>/dev/null | grep -Ei "rkmpp" || true
    fi

    if command -v gst-inspect-1.0 >/dev/null 2>&1; then
        echo ""
        echo "============================================================================================================================"
        echo "                                            GStreamer 编码相关元素 (Rockchip)                                        "
        echo "============================================================================================================================"

        local any_found=false
        local e
        for e in rkmppenc mpph264enc mpph265enc mppjpegenc vpeenc; do
            if gst-inspect-1.0 "$e" >/dev/null 2>&1; then
                echo "$e"
                any_found=true
            fi
        done
        if [ "$any_found" = false ]; then
            echo "--"
        fi
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

print_platform_summary

install_rkmpp

print_rkmpp_summary

echo ""
echo "============================================================================================================================"
echo "                                      Rockchip 视频编码支持表 (VPU/VPE)                                       "
echo "============================================================================================================================"

if [ "$HAVE_V4L2" = true ]; then
    for dev in /dev/video*; do
        if [ ! -e "$dev" ]; then continue; fi
        
        v4l2-ctl -d "$dev" -D >/dev/null 2>&1 || continue

        parse_device_formats "$dev" "in" "输入(Input)" || true
        parse_device_formats "$dev" "out" "输出(Output)" || true
    done
fi
collect_runtime_backends
print_nodes_summary
if [ "$HAVE_V4L2" = true ]; then
    print_codec_summary
fi
print_backend_summary
print_optional_runtime

echo "说明:"
if [ "$HAVE_V4L2" = true ]; then
    echo "1. 编码器(venc)：输入应包含 NV12/YM12/P010 等 RAW，输出应包含 H264/HEVC/JPEG 等压缩流。"
else
    echo "1. 未启用/未检测到 V4L2 编码设备时，以后端汇总(FFmpeg/GStreamer/节点)为准。"
fi
echo "3. 本脚本由青团制作有事情请加群613835409。"
echo "============================================================================================================================"
