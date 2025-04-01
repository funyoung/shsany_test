#!/bin/bash

# 1. 测试网卡
function test_network() {
    echo "测试网卡..." | tee -a $LOG_FILE
    ping -c 4 8.8.8.8 &> /dev/null
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

# 主测试流程
function main() {
    declare -A test_results
    local tests=("network" "m2_ssd" "sata" "usb" "typec" "rtc")
    
    echo "========================================"
    echo "  RK3588 外设综合测试套件"
    echo "========================================"
    
    local LOG_FILE="rk3588_test.log"
    echo "RK3588 外设接口自动化测试" | tee $LOG_FILE
    echo "测试开始时间: $(date)" | tee -a $LOG_FILE

    # 遍历执行所有测试
    for test in "${tests[@]}"; do
        echo -e "\n▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌"
        "test_$test"
        test_results[$test]=$?
        sleep 1
    done

#    # 依次执行测试
#    test_network
#    test_m2_ssd
#    test_sata
#    test_usb
#    test_typec
#    test_rtc

    echo "测试结束时间: $(date)" | tee -a $LOG_FILE
    echo "所有测试完成" | tee -a $LOG_FILE


    # 生成测试报告
    echo -e "\n\n========================================"
    echo "          测试报告"
    echo "========================================"
    
    for test in "${!test_results[@]}"; do
        local result="❌ FAIL"
        [ ${test_results[$test]} -eq 0 ] && result="✅ PASS"
        printf "%-12s %s\n" "${test}测试:" "$result"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ${test}测试: $result" >> $LOG_FILE
    done
    
    # 总体结果判断
    [[ "${test_results[@]}" =~ 1 ]] && return 1 || return 0
}

# 执行主程序
main
exit $?
