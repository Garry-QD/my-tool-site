# 必读
以下脚本获取到root权限后再操作，获取root权限是执行 
```bash
sudo -i
```
##
### 飞牛依赖修复脚本 <small> 源自 http://static2.fnnas.com/aptfix/fixapt.sh 作者:谢观如院长</small>
官方出品修复依赖的脚本，如果你更新不了，FN开启不了，经常出现小问题请执行它
```bash
curl http://localhost:5173/fixapt.sh | bash
```

##
### 飞牛docker重置脚本 <small> 源自 https://github.com/qiyueqixi/fnos 作者:七月七夕 </small>
虽然删除掉/etc/docker/daemon.json的配置文件也能重置，但是总归没脚本操作方便
```bash
curl http://localhost:5173/docker_reset.sh | bash
```

##
### 重新开启SWAP脚本 <small> 源自 https://github.com/qiyueqixi/fnos 作者:七月七夕 </small>
重新开启SWAP，这个脚本是给用服务器做飞牛的人用的，理论上其他debian系的都可以用。
```bash
curl http://localhost:5173/swap_manage.sh | bash
```

##
### 飞牛聚合脚本 <small> 源自 https://gitee.com/xiao-zhu245/fnscript 作者:又菜又爱玩的小朱猪 </small>
![图片描述，用于无障碍](http://localhost:5173/小猪脚本.png)

  一个比较齐全执行脚本的集合库，可以修复上述的问题，推荐使用他的一键开启IOMMU直通和网络诊断
```bash
git clone https://gitee.com/xiao-zhu245/fnscript.git
cd fnscript/
python3 menu.py
```

