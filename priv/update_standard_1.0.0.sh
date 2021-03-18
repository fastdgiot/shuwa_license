#!/bin/bash

#1. 保存环境变量
export PATH=$PATH:/usr/local/bin
workdir=`pwd`
#7. 部署shuwa_iot
cd /data
randtime=`date +%F_%T`
echo $randtime

if [ -d /data/{{shuwa_iot}} ]; then
   mv /data/{{shuwa_iot}}/ /data/{{shuwa_iot}}_bk_$randtime
fi

if [ ! -f  /data/{{shuwa_iot_software}} ]; then
  wget http://www.iotn2n.com/package/{{shuwa_iot_software}} -O /data/{{shuwa_iot_software}}
fi

tar xf {{shuwa_iot_software}}
cd  /data/shuwa_iot

count=`ps -ef |grep beam.smp |grep -v "grep" |wc -l`
if [ 0 == $count ];then
   echo $count
  else
   killall -9 beam.smp
fi

#配置licens
sed -i '/^shuwa_auth.license/cshuwa_auth.license = {{standard_shuwa_license}}' /data/{{shuwa_iot}}/etc/plugins/shuwa_license.conf

#parse 连接 配置
sed -i '/^parse.parse_server/cparse.parse_server = http://{{standard_private_ip}}:{{parse_server_port}}' /data/{{shuwa_iot}}/etc/plugins/shuwa_parse.conf
sed -i '/^parse.parse_path/cparse.parse_path = /parse/' /data/{{shuwa_iot}}/etc/plugins/shuwa_parse.conf
sed -i '/^parse.parse_appid/cparse.parse_appid = {{parse_server_appid}}' /data/{{shuwa_iot}}/etc/plugins/shuwa_parse.conf
sed -i '/^parse.parse_master_key/cparse.parse_master_key = {{parse_server_master_key}}' /data/{{shuwa_iot}}/etc/plugins/shuwa_parse.conf
sed -i '/^parse.parse_js_key/cparse.parse_js_key = {{parse_server_js_key}}' /data/{{shuwa_iot}}/etc/plugins/shuwa_parse.conf
sed -i '/^parse.parse_rest_key/cparse.parse_rest_key = {{parse_server_rest_key}}' /data/{{shuwa_iot}}/etc/plugins/shuwa_parse.conf

#修改emq.conf
sed -i '/^node.name/cnode.name = shuwa_iot@{{standard_public_ip}}' /data/shuwa_iot/etc/emqx.conf
mv /data/{{shuwa_iot}}/data/loaded_plugins /data/{{shuwa_iot}}/data/loaded_plugins_bk
cat > /data/{{shuwa_iot}}/data/loaded_plugins << "EOF"
{emqx_management, true}.
{emqx_recon, true}.
{emqx_retainer, true}.
{emqx_dashboard, true}.
{emqx_rule_engine, true}.
{emqx_bridge_mqtt, true}.
{emqx_cube, false}.
{shuwa_statsd, true}.
{shuwa_license, true}.
{shuwa_public, true}.
{shuwa_mqtt, true}.
{shuwa_framework, true}.
{shuwa_device_shadow, true}.
{shuwa_parse, true}.
{shuwa_web_manager,true}.
{shuwa_bridge,true}.
{shuwa_modbus,true}.
EOF

systemctl stop {{shuwa_iot}}

/data/{{shuwa_iot}}/bin/shuwa_iot start

rm /usr/lib/systemd/system/{{shuwa_iot}}.service  -rf
cat > /lib/systemd/system/{{shuwa_iot}}.service << "EOF"
[Unit]
Description={{shuwa_iot}}_service
After=network.target {{parse_server}}.service
Requires={{parse_server}}.service

[Service]
Type=forking
Environment=HOME=/data/{{shuwa_iot}}/erts-10.3
ExecStart=/bin/sh /data/{{shuwa_iot}}/bin/shuwa_iot start
LimitNOFILE=1048576
ExecStop=/bin/sh data/{{shuwa_iot}}/bin/shuwa_iot stop
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
systemctl enable {{shuwa_iot}}
systemctl start {{shuwa_iot}}

##应用部署和安装验证
wget http://127.0.0.1:5080/install/iot

content=`wget -q -O -  http://127.0.0.1:5080/iotapi/health`
if [ ${content} == 'ok' ]; then
    psql -U postgres -d parse -c "alter table \"License\" drop constraint \"License_pkey\";"
    psql -U postgres -d parse -c "alter table \"License\" add primary key(key);"
    psql -U postgres -d parse -c "alter table \"App\" drop constraint \"App_pkey\";"
    psql -U postgres -d parse -c "alter table \"App\" add primary key(name);"
    psql -U postgres -d parse -c "alter table \"Project\" drop constraint \"Project_pkey\";"
    psql -U postgres -d parse -c "alter table \"Project\" add primary key(title);"
    psql -U postgres -d parse -c "alter table \"Product\" drop constraint \"Product_pkey\";"
    psql -U postgres -d parse -c " alter table \"Product\" add primary key(name,\"devType\");"
    psql -U postgres -d parse -c "alter table \"Device\" drop constraint \"Device_pkey\";"
    psql -U postgres -d parse -c "alter table \"Device\" add primary key(product,devaddr);"
    psql -U postgres -d parse -c "alter table \"Channel\" drop constraint \"Channel_pkey\";"
    psql -U postgres -d parse -c "alter table \"Channel\" add primary key(name,\"cType\");"
    psql -U postgres -d parse -c "alter table \"Crond\" drop constraint \"Crond_pkey\";"
    psql -U postgres -d parse -c "alter table \"Crond\" add primary key(name,type);"
    psql -U postgres -d parse -c "alter table \"Department\" drop constraint \"Department_pkey\";"
    psql -U postgres -d parse -c "alter table \"Department\" add primary key(name,org_type);"
    wget "http://{{license_host}}:5080/iotapi/setup_result?license={{standard_shuwa_license}}&result=installed"
else
    wget "http://{{license_host}}:5080/iotapi/setup_result?license={{standard_shuwa_license}}&result=install_fail"
fi

systemctl restart {{td_bridge_name}}
systemctl restart shuwa_demon

