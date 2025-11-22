# 必读
以下脚本获取到root权限后再操作，获取root权限是执行 
```bash
sudo -i
```
### 关闭SWAP
```bash
sudo swapoff -a
sudo sed -i "s/.*swap.*/#&/" /etc/fstab
sudo rm -rf /swapfile
```
### 强改DNS
```bash
vim /etc/resolv.conf
```
### 将 ARC 最大内存限制设置为 16GB
```bash
options zfs zfs_arc_max=17179869184
```
crtl+x 保持 y enter回车确定保存

### 重新扫描一次quota （修复16BE）
```bash
btrfs quota rescan -w /vol2
```
### 无root查看gotty用户名密码
```bash
ps aux | grep -E "app|pkg|center"
```
