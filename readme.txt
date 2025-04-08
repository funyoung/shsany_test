1. File list:
piano2-CoolEdit.mp3 -- 声音播放测试用音频文件
readme.txt          -- 本帮助文件
rk3588_test.log     -- 运行测试shsany_test.sh生成日志文件
shsany_test.sh      -- 测试脚本程序
test.conf           -- 测试配置文件

2. 运行程序
拷贝文件到开发板，以root用户运行测试脚本
#./shsany_test.sh

a) 测试执行过程中，自动完成的测试用例依次执行完毕
b) 然后依次执行手动测试用例，每个用例等待控制台输入测试结果'y'表示测试通过，其他任意键表示测试未通过。

3. 测试配置
修改test.conf文件，每个测试项一行，以"测试名称:1“，或者"测试名称:0“, 配置该测试项执行或者跳过不执行。
测试项名称与测试脚本中字符串严格匹配，不能修改，只修改冒号后的0或1.

4. 测试报告
列出没想测试执行结果，测试名称 : 结果(通过为PASS，失败为FAIL，遇到位置情况为执行为 UNKNOWN）

========================================
          测试报告
========================================
network测试: ❓ UNKNOWN
m2_ssd测试: ❌ FAIL
sata测试:  ❌ FAIL
tfcard测试: ❌ FAIL
usb2测试:  ✅ PASS
usb3测试:  ✅ PASS
typec测试: ❌ FAIL
rtc测试:   ❌ FAIL
hdmiin测试: ❌ FAIL
camera测试: ❌ FAIL
mipi测试:  ❌ FAIL
audio测试: ❌ FAIL


5. 测试日志
测试执行过程日志和最后的测试报告全部保存在rk3588_test.log文件中
