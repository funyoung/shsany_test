#!/bin/bash

LOG_FILE="rk3588_test.log"
echo "RK3588 外设接口自动化测试" | tee $LOG_FILE
echo "测试开始时间: $(date)" | tee -a $LOG_FILE

# 1. 测试网卡
test_network() {
    echo "测试网卡..." | tee -a $LOG_FILE
    ping -c 4 8.8.8.8 &> /dev/null
    if [ $? -eq 0 ]; then
        echo "网卡测试通过" | tee -a $LOG_FILE
    else
        echo "网卡测试失败" | tee -a $LOG_FILE
    fi
}

# 2. 测试 M.2 硬盘
test_m2_ssd() {
    echo "测试 M.2 硬盘..." | tee -a $LOG_FILE
    lsblk | grep nvme
    if [ $? -eq 0 ]; then
        echo "M.2 硬盘检测通过" | tee -a $LOG_FILE
    else
        echo "M.2 硬盘未检测到" | tee -a $LOG_FILE
    fi
}

# 3. 测试 SATA 硬盘
test_sata() {
    echo "测试 SATA 硬盘..." | tee -a $LOG_FILE
    lsblk | grep sata
    if [ $? -eq 0 ]; then
        echo "SATA 硬盘检测通过" | tee -a $LOG_FILE
    else
        echo "SATA 硬盘未检测到" | tee -a $LOG_FILE
    fi
}

# 4. 测试 USB2.0 & USB3.0
test_usb() {
    echo "测试 USB 设备..." | tee -a $LOG_FILE
    lsusb | tee -a $LOG_FILE
}

# 5. 测试 Type-C
test_typec() {
    echo "测试 Type-C 端口..." | tee -a $LOG_FILE
    dmesg | grep -i "type-c"
    if [ $? -eq 0 ]; then
        echo "Type-C 端口检测通过" | tee -a $LOG_FILE
    else
        echo "Type-C 端口未检测到" | tee -a $LOG_FILE
    fi
}

# 6. 测试 RTC
test_rtc() {
    echo "测试 RTC..." | tee -a $LOG_FILE
    hwclock -r
    if [ $? -eq 0 ]; then
        echo "RTC 读取成功" | tee -a $LOG_FILE
    else
        echo "RTC 测试失败" | tee -a $LOG_FILE
    fi
}

# 依次执行测试
test_network
test_m2_ssd
test_sata
test_usb
test_typec
test_rtc

echo "测试结束时间: $(date)" | tee -a $LOG_FILE
echo "所有测试完成" | tee -a $LOG_FILE

