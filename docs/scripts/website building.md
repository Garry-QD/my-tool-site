## NGNIX 
万能的NGINIX
* 第一步：安装 Nginx
```bash
sudo apt update # 更新软件源
sudo apt install nginx -y  #执行安装
```
* 第二步 启动并设置开机自启
```bash
sudo systemctl start nginx # 启动 Nginx
sudo systemctl enable nginx # 设置开机自动启动
```
* 第三步：检查运行状态
```bash
sudo systemctl status nginx
```
如果有防火墙记得放行
```bash
sudo ufw allow 'Nginx Full'
```
## Zfile(一个存储管理项目)
* 拥有本地挂载 网盘挂载 oss cos r2等多种挂载方式，下载脚本到本地并执行
```bash
curl -sSL https://docs.zfile.vip/install.sh -o install.sh && chmod +x install.sh && ./install.sh
```
* 修改配置文件
application.properties是配置文件，前面路径可以自己指定，vim和nano都可以编辑
```bash
nano /root/zfile/application.properties
```
