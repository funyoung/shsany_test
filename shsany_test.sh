#!/bin/bash

# 配置文件路径
CONFIG_FILE="test.conf"

# 日志文件路径
LOG_FILE="rk3588_test.log"

log() {
    echo "[TEST_LOG] $1" | tee -a $LOG_FILE
}

# 1. 测试网卡
function test_network() {
    log "测试网卡..."
#    ping -c 4 8.8.8.8 &> /dev/null
    local distro=""
    local nic1=""
    local nic2=""
    local ip1="192.168.1.100"
    local ip2="192.168.1.101"
    
    # 检测发行版
    if grep -qi "debian" /etc/os-release; then
        distro="debian"
        nic1="end0"
        nic2="end1"
    elif grep -qi "ubuntu" /etc/os-release; then
        distro="ubuntu"
        nic1="eth0"
        nic2="eth1"
    else
        echo "Unsupported distribution"
        return 1
    fi
    
    # 检查网卡是否存在
    if ! ip link show "$nic1" >/dev/null 2>&1 || ! ip link show "$nic2" >/dev/null 2>&1; then
        echo "One or both network interfaces ($nic1, $nic2) not found"
        return 2
    fi
    
    # 设置IP地址
    echo "Configuring $nic1 with $ip1 and $nic2 with $ip2"
    sudo ip addr add "$ip1"/24 dev "$nic1"
    sudo ip addr add "$ip2"/24 dev "$nic2"
    
    # 验证设置
    if ip addr show "$nic1" | grep -q "$ip1" && ip addr show "$nic2" | grep -q "$ip2"; then
        echo "IP addresses configured successfully"
        return 0
    else
        echo "Failed to configure IP addresses"
        return 3
    fi
}

# 2. 测试 M.2 硬盘
M2_DEVICE=""
M2_MOUNT_POINT="/mnt/m2disk"
M2_TEST_FILE="m2_test_file.txt"
M2_TEST_STRING="RK3588_M2_DISK_TEST"
function find_m2_device() {
    for dev in /dev/nemv0n1 /dev/sd[a-z]; do
        if [ -b "$dev" ]; then
            log "找到M.2硬盘设备: $dev"
            M2_DEVICE=$dev
            return 0
        fi
    done
    return 1
}
function mount_m2_disk() {
    mkdir -p "$M2_MOUNT_POINT"
    if mount | grep -q "$M2_MOUNT_POINT"; then
        umount "$M2_MOUNT_POINT"
    fi
    mount "${M2_DEVICE}p1" "$M2_MOUNT_POINT" 2>/dev/null || mount "${M2_DEVICE}" "$M2_MOUNT_POINT"
    return $?
}

function rw_test_m2() {
    echo "$M2_TEST_STRING" > "$M2_MOUNT_POINT/$M2_TEST_FILE"
    read_back=$(cat "$M2_MOUNT_POINT/$M2_TEST_FILE")
    if [ "$read_back" == "$M2_TEST_STRING" ]; then
        log "读写测试通过"
        return 0
    else
        log "读写测试失败"
        return 1
    fi
}

# 清理挂载
function cleanup_m2() {
    umount "$M2_MOUNT_POINT" 2>/dev/null
    rm -rf "$M2_MOUNT_POINT"
}

function test_m2_ssd() {
    log "测试 M.2 硬盘..."
    #lsblk | grep nvme;
    if ! find_m2_device; then
        log "未检测到M.2设备"
        return 1
    fi

    if ! mount_m2_disk; then
        log "M.2磁盘挂载失败"
        cleanup_m2
        return 2
    fi
    
    if rw_test_m2; then
        log "M.2磁盘测试成功 ✅"
        cleanup_m2
        return 0
    else
        log "M.2磁盘测试失败 ❌"
        cleanup_m2
        return 3
    fi
    
}

# 查找SATA设备
function find_sata_device() {
    for dev in /dev/sd[a-z]; do
        if [ -b "$dev" ]; then
            log "找到M.2硬盘设备: $dev"
            M2_DEVICE=$dev
            return 0
        fi
    done
    return 1
}

# 3. 测试 SATA 硬盘
function test_sata() {
    log "测试 SATA 硬盘..."
    #lsblk | grep sata

    if ! find_sata_device; then
        log "未检测到SATA设备"
        return 1
    fi

    if ! mount_m2_disk; then
        log "SATA磁盘挂载失败"
        cleanup_m2
        return 2
    fi
    
    if rw_test_m2; then
        log "SATA磁盘测试成功 ✅"
        cleanup_m2
        return 0
    else
        log "SATA磁盘测试失败 ❌"
        cleanup_m2
        return 3
    fi
}

TF_DEVICE=""
TF_MOUNT_POINT="/mnt/tfcard"
TF_TEST_FILE="tfcard_test_file.txt"
TF_TEST_STRING="RK3588_TFCARD_TEST"

# 查找TF卡设备（通常是 /dev/mmcblk1 或类似）
find_tfcard_device() {
    for dev in /dev/mmcblk1 /dev/mmcblk0; do
        if [ -b "$dev" ]; then
            log "找到TF卡块设备: $dev"
            TF_DEVICE=$dev
            return 0
        fi
    done
    return 1
}

# 自动挂载TF卡
mount_tfcard() {
    mkdir -p "$TF_MOUNT_POINT"
    if mount | grep -q "$TF_MOUNT_POINT"; then
        umount "$TF_MOUNT_POINT"
    fi
    mount "${TF_DEVICE}p1" "$TF_MOUNT_POINT" 2>/dev/null || mount "$TF_DEVICE" "$TF_MOUNT_POINT"
    return $?
}

# 测试写入和读取
rw_test() {
    echo "$TF_TEST_STRING" > "$TF_MOUNT_POINT/$TF_TEST_FILE"
    read_back=$(cat "$TF_MOUNT_POINT/$TF_TEST_FILE")
    if [ "$read_back" == "$TF_TEST_STRING" ]; then
        log "读写测试通过"
        return 0
    else
        log "读写测试失败"
        return 1
    fi
}

# 清理环境
cleanup() {
    umount "$TF_MOUNT_POINT" 2>/dev/null
    rm -rf "$TF_MOUNT_POINT"
}

function test_tfcard() {
    # 主流程
    log "开始TF卡接口测试..."
    
    if ! find_tfcard_device; then
        log "未检测到TF卡设备"
        return 1
    fi
    
    if ! mount_tfcard; then
        log "TF卡挂载失败"
        cleanup
        return 2
    fi
    
    if rw_test; then
        log "TF卡接口测试成功 ✅"
        cleanup
        return 0
    else
        log "TF卡接口测试失败 ❌"
        cleanup
        return 3
    fi
}

# 4. 测试 USB2.0 & USB3.0
function test_usb_speed() {
    local target_speed=$1

    log "测试 USB 设备及其速度..."

    # 获取 usb-devices 输出
    usb_info=$(usb-devices)
    echo "$usb_info" >> $LOG_FILE

    log "检测到以下设备速度信息："
    log "$usb_info" | grep "Spd="

    if echo "$usb_info" | grep -q "Spd=$target_speed"; then
        case "$target_speed" in
            480)
                log "检测到 USB 2.0 设备"
                ;;
            5000)
                log "检测到 USB 3.0 设备"
                ;;
            *)
                log "检测到速度为 $target_speed 的 USB 设备"
                ;;
        esac
        return 0
    else
        log "未检测到速度为 $target_speed 的 USB 设备"
        return 1
    fi
}
function test_usb2() {
    test_usb_speed 480
}

function test_usb3() {
    test_usb_speed 5000
}

# 5. 测试 Type-C
function test_typec() {
    log "测试 Type-C 端口..."
    dmesg | grep -i "type-c"
}

# 6. 测试 RTC
function test_rtc() {
    log "测试 RTC..."
    hwclock -r
}

# 用户确认函数
function get_user_confirmation() {
    local test_name=$1
    while true; do
        read -p "请确认${test_name}测试结果 [y/N]：" -n 1 -r
        echo
        
        case $REPLY in
            [Yy]) 
                echo "PASS"
                return 0
                ;;
            [Nn]|"") 
                echo "FAIL"
                return 1
                ;;
            *) 
                echo "无效输入，请使用 y/Y 或 n/N"
                ;;
        esac
    done
}

# HDMI输入测试
function test_hdmiin() {
    echo -e "\n[HDMI输入测试]"
    local device="/dev/video0"
    
    # 设备检测
    if [ ! -e "$device" ]; then
        echo "❌ 未检测到HDMI设备"
        return 1
    fi
    
    # 格式检测
    v4l2-ctl -d $device --info 2>&1 | sed 's/^/    /'
    echo "请观察外接显示设备..."
    
    # 用户确认
    get_user_confirmation "HDMI输入"
    return $?
}

# 摄像头测试
function test_camera() {
    echo -e "\n[摄像头测试]"
    local device="/dev/video11"
    
    if [ ! -e "$device" ]; then
        echo "❌ 未检测到摄像头设备"
        return 1
    fi
    
    echo "正在捕获测试图像...按[CTRL + C]退出图像捕获"
    # 这里可以添加实际采集命令
    timeout 15s gst-launch-1.0 v4l2src device="$device" ! video/x-raw,format=NV12,width=3840,height=2160,framerate=30/1 ! videoconvert ! autovideosink
    get_user_confirmation "摄像头"
    return $?
}

# MIPI屏幕测试
function test_mipi() {
    echo -e "\n[MIPI屏幕测试]"
    echo "正在显示测试图案..."
    # 添加显示测试图案命令
    get_user_confirmation "MIPI屏幕"
    return $?
}

# 音频测试
function test_audio() {
    echo -e "\n[音频测试]"
    echo "正在播放测试音..."
    # 添加音频播放命令
    play ./piano2-CoolEdit.mp3
    get_user_confirmation "音频输出"
    return $?
}

# 40Pin接口测试
function test_40pin() {
    echo -e "\n[40Pin接口测试]"
    echo "执行GPIO环路测试..."
    # 添加GPIO测试命令
    get_user_confirmation "40Pin接口"
    return $?
}


# 读取配置文件
function load_config() {
    declare -gA config
    while IFS=':' read -r key value; do
        # 去除空格和注释
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        config["$key"]="$value"
    done < "$CONFIG_FILE"
}

# 主测试流程
function main() {
    declare -A test_results
    declare -a test_order  # 存储测试执行顺序
    local auto_tests=("network" "m2_ssd" "sata" "tfcard" "usb2" "usb3" "typec" "rtc")
    local manual_tests=("hdmiin" "camera" "mipi" "audio" "40pin")
    local tests=("${auto_tests[@]}" "${manual_tests[@]}")
    
    # 加载配置文件
    load_config
    
    echo "========================================"
    echo "  RK3588 外设综合测试套件"
    echo "========================================"
    
    local LOG_FILE="rk3588_test.log"
    log "RK3588 外设接口自动化测试"
    log "测试开始时间: $(date)"

    # 遍历执行所有测试
    for test in "${tests[@]}"; do
        # 检查配置是否启用
        if [[ "${config[$test]}" == "1" ]]; then
            echo -e "\n▌执行测试：$test"
            "test_$test"
            test_results[$test]=$?
            test_order+=("$test")  # 按顺序记录测试项
            sleep 1
        else
            echo -e "\n▌跳过测试：$test (配置禁用)"
            test_results[$test]="SKIP"
        fi
    done

    log "测试结束时间: $(date)"
    log "所有测试完成"

    # 生成测试报告
    echo -e "\n\n========================================"
    echo "          测试报告"
    echo "========================================"
    
    for test in "${test_order[@]}"; do
        case "${test_results[$test]}" in
            0)
                result="✅ PASS"
                ;;
            1)
                result="❌ FAIL"
                ;;
            "SKIP")
                result="⏸️ SKIP"
                ;;
            *)
                result="❓ UNKNOWN"
                ;;
        esac
        printf "%-12s %s\n" "${test}测试:" "$result"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ${test}测试: $result" >> $LOG_FILE
    done
    
    # 总体结果判断（只统计实际执行的测试）
    local final_result=0
    for test in "${!test_results[@]}"; do
        if [[ "${test_results[$test]}" =~ ^[01]$ && ${test_results[$test]} -ne 0 ]]; then
            final_result=1
        fi
    done
    
    return $final_result
}

# 执行主程序
main
exit $?
