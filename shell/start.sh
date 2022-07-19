#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

FILE=ipv4.txt
if [ -f "$FILE" ]; then
     echo "ipv4.txt 文件存在, 开始检测当前IP是否满足期望速度"
     # 先检查一下上一次的结果是否仍然满足需求
     export menu=3
     export ip=$(grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' ipv4.txt)                 # 要测试的IP地址,从ipv4.txt中获取
     export port=443             # 要测试的端口, 80/443
     IFS='=' read -ra ADDR <<< "$(grep 'bandwidth' .env)"
     export expect=${ADDR[1]} # 期望带宽 Mbps
     # 测量五次取平均值
     times=0
     sum=0
     while [ $times -lt 5 ]; do
          OUTPUT=$(./cf.sh)
          # 速度位于输出的第17个字符串
          ARRAYS=($OUTPUT)
          ((times++))
          sum=$((${ARRAYS[16]}+sum))
          sleep 1m
     done
     expect=$(($expect*1024/8))
     # 速度大于等于预期速度, 直接退出
     if [ "$(($sum/$times))" -ge "$expect" ]; then
          echo "当前IP ${ARRAYS[14]} 的速度为 ${ARRAYS[16]} Kbps 大于预期速度 $expect Kbps, 符合预期, 退出脚本"
          exit
     fi

     # 速度小于预期速度, 进行新一轮IP优选
     echo "当前IP ${ARRAYS[14]} 的速度为 ${ARRAYS[16]} Kbps 小于 预期速度 $expect Kbps, 不符合预期, 重新选择IP"
else
     echo "ipv4.txt 文件不存在, 开始筛选新IP"
fi

# 设置环境变量
unamestr=$(uname)
if [ "$unamestr" = 'Linux' ]; then
  export $(grep -v '^#' .env | xargs -d '\n')
elif [ "$unamestr" = 'FreeBSD' ]; then
  export $(grep -v '^#' .env | xargs -0)
fi

# Restart the network
sudo /etc/init.d/networking restart
./cf.sh

ip_with_delay=$(grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' ipv4.txt)
ip=(${ip_with_delay//,/ })

# Update the dns record using cloudflare api
curl -X PUT "https://api.cloudflare.com/client/v4/zones/${zones}/dns_records/${dns_records}" \
     -H "X-Auth-Email: ${X_Auth_Email}" \
     -H "X-Auth-Key: ${X_Auth_Key}" \
     -H "Content-Type: ${Content_Type}" \
     --data '{"type":"'${record_type}'","name":"'${name}'","content":"'${ip[0]}'","ttl":'${ttl}',"proxied":'${proxied}'}'
