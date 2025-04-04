#!/bin/bash

# 配置文件路径
CONFIG_FILE="test.conf"

# 日志文件路径
LOG_FILE="rk3588_test.log"

# 1. 测试网卡
function test_network() {
    echo "测试网卡..." | tee -a $LOG_FILE
#    ping -c 4 8.8.8.8 &> /dev/null
    local distro=""
    local nic1=""
    local nic2=""
    local ip1="192.168.1.10"
    local ip2="192.168.1.11"
    
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
function test_m2_ssd() {
    echo "测试 M.2 硬盘..." | tee -a $LOG_FILE
    lsblk | grep nvme
}

# 3. 测试 SATA 硬盘
function test_sata() {
    echo "测试 SATA 硬盘..." | tee -a $LOG_FILE
    lsblk | grep sata
}

# 4. 测试 USB2.0 & USB3.0
function test_usb() {
    echo "测试 USB 设备..." | tee -a $LOG_FILE
    lsusb | tee -a $LOG_FILE
}

# 5. 测试 Type-C
function test_typec() {
    echo "测试 Type-C 端口..." | tee -a $LOG_FILE
    dmesg | grep -i "type-c"
}

# 6. 测试 RTC
function test_rtc() {
    echo "测试 RTC..." | tee -a $LOG_FILE
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
    local auto_tests=("network" "m2_ssd" "sata" "usb" "typec" "rtc")
    local manual_tests=("hdmiin" "camera" "mipi" "audio" "40pin")
    local tests=("${auto_tests[@]}" "${manual_tests[@]}")
    
    # 加载配置文件
    load_config
    
    echo "========================================"
    echo "  RK3588 外设综合测试套件"
    echo "========================================"
    
    local LOG_FILE="rk3588_test.log"
    echo "RK3588 外设接口自动化测试" | tee $LOG_FILE
    echo "测试开始时间: $(date)" | tee -a $LOG_FILE

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

    echo "测试结束时间: $(date)" | tee -a $LOG_FILE
    echo "所有测试完成" | tee -a $LOG_FILE

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

## 主测试流程
#function main() {
#    declare -A test_results
#    declare -a test_order  # 存储测试执行顺序
#    local auto_tests=("network" "m2_ssd" "sata" "usb" "typec" "rtc")
#    local manual_tests=("hdmiin" "camera" "mipi" "audio" "40pin")
#    local tests=("${auto_tests[@]}" "${manual_tests[@]}")
#
#    echo "========================================"
#    echo "  RK3588 外设综合测试套件"
#    echo "========================================"
#
#    local LOG_FILE="rk3588_test.log"
#    echo "RK3588 外设接口自动化测试" | tee $LOG_FILE
#    echo "测试开始时间: $(date)" | tee -a $LOG_FILE
#
#    # 遍历执行所有测试
#    for test in "${tests[@]}"; do
#        echo -e "\n▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌"
#        "test_$test"
#        test_results[$test]=$?
#        test_order+=("$test")  # 按顺序记录测试项
#        sleep 1
#    done
#
#    echo "测试结束时间: $(date)" | tee -a $LOG_FILE
#    echo "所有测试完成" | tee -a $LOG_FILE
#
#    # 生成测试报告
#    echo -e "\n\n========================================"
#    echo "          测试报告"
#    echo "========================================"
#    
#    for test in "${test_order[@]}"; do
#        local result="❌ FAIL"
#        [ ${test_results[$test]} -eq 0 ] && result="✅ PASS"
#        printf "%-12s %s\n" "${test}测试:" "$result"
#        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ${test}测试: $result" >> $LOG_FILE
#    done
#
#    # 总体结果判断
#    [[ "${test_results[@]}" =~ 1 ]] && return 1 || return 0
#}
#
## 执行主程序
#main
#exit $?
