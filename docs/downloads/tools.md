# 谢氏老中医馆下载站
---
- [下载 ufse.zip](http://qdnas.icu:18080/api/share/download/70fca4cb?path=%2Fufse.zip)
  * UFSE推荐磁盘放在主机环境下用WIN环境去使用会稳定。
  * 使用PE或硬盘盒不适合长时间高功耗工作环境
---
- [下载 MacroritDiskScanner693.zip](http://qdnas.icu:18080/api/share/download/f2c64c50?path=%2FMacroritDiskScanner693.zip)
  * MacroritDiskScanner693是个坏道修复工具不是扫盘回复数据的，谨慎使用+
---
- [下载 HDSentinel.rar](http://qdnas.icu:18080/api/share/download/9c86cc24?path=%2FHDSentinel.rar)
  * 检测硬盘SMART状态和一些简单信息的好工具
---
- [下载 DiskGenius.zip](http://qdnas.icu:18080/api/share/download/5c49703e?path=%2FDiskGenius.zip)
  * 一个老牌的硬盘分区管理工具
---

## 存储空间只读挂载 <small>[作者:飞牛技术同学](https://club.fnnas.com/forum.php?mod=viewthread&tid=14695) </small>
如果无法正常挂载回去存储空间，这将是你抢救数据的唯二办法，再往后只能扫盘（这是最后唯一的办法）
```bash
lsblk -fp
```
![alt text](/lsblk.png)

·找到我们需要挂载的存储空间正确的路径，例如我这里就是/dev/mapper/trim_f28ddd72_044a_4ad9_a20c_e8809a8c1cfc-0

·我们在路径前面加上mount -t btrfs -o ro,usebackuproot,rescue=all 组合成下列命令

```bash
mount -t btrfs -o ro,usebackuproot,rescue=all /dev/mapper/trim_f28ddd72_044a_4ad9_a20c_e8809a8c1cfc-0 /vol1
```
·重点说明 /vol1的意思是存储空间1，如果你本来的是存储空间4就用/vol4来表示

·只要执行后正常都会看到空间已经被挂载成了只读，这时候请抓紧机会把出局复制出来。

·如果没有挂载成功，在排除了命令的问题，那么你只能尝试使用[UFS](http://qdnas.icu:18080/share/70fca4cb)来扫盘恢复
