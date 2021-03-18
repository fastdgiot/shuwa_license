#!/bin/bash

#1. 保存环境变量
export PATH=$PATH:/usr/local/bin
workdir=`pwd`
echo  $workdir

yum -y install gcc gcc-c++ libstdc++-devel
yum -y install openssl-devel
yum -y install c-ares-devel
yum -y install uuid-devel
yum -y install libuuid-devel

#setup mosquitto
rm mosquitto* -rf
if [ ! -f /tmp/mosquitto-1.6.7.tar.gz ]; then
    wget http://ci.iotn2n.com/shuwa/package/oem/mosquitto-1.6.7.tar.gz /tmp/mosquitto-1.6.7.tar.gz
fi
tar xvf mosquitto-1.6.7.tar.gz
cd  mosquitto-1.6.7
make uninstall
make clean
make install
sudo ln -s /usr/local/lib/libmosquitto.so.1 /usr/lib/libmosquitto.so.1
ldconfig
cd ..

#make 
cd $workdir/
wget http://ci.iotn2n.com/shuwa/package/shuwa_demon
chmod 777 shuwa_demon
cp $workdir/shuwa_demon /usr/sbin -rf
cd $workdir

systemctl stop shuwa_demon
rm /usr/lib/systemd/system/shuwa_demon.service  -rf
cat > /lib/systemd/system/shuwa_demon.service << "EOF"
[Unit]
Description=shuwa_demon_service
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/shuwa_demon {{host}} {{appid}} {{appsecret}}
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
KillSignal=SIGINT
TimeoutSec=300
OOMScoreAdjust=-1000
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable shuwa_demon
systemctl start shuwa_demon
