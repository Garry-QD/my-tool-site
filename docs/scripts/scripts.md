# 必读
以下脚本获取到root权限后再操作，获取root权限是执行 
```bash
sudo -i
```
##
### 飞牛依赖修复脚本 <small> [作者:谢观如院长](https://club.fnnas.com/forum.php?mod=viewthread&tid=33052)</small>
官方出品修复依赖的脚本，如果你更新不了，FN开启不了，经常出现小问题（网络环境正常的情况下）请执行它
这不是补药，没问题请不要乱用
```bash
curl http://qdnas.icu/fixapt.sh | bash
```

##
### 飞牛docker重置脚本  <small>[作者:七月七夕](https://github.com/qiyueqixi/fnos) </small>
虽然删除掉/etc/docker/daemon.json的配置文件也能重置，但是总归没脚本操作方便
```bash
curl http://qdnas.icu/docker_reset.sh | bash
```

##
### 重新开启SWAP脚本 <small> [作者:七月七夕](https://github.com/qiyueqixi/fnos) </small>
重新开启SWAP，这个脚本是给用服务器做飞牛的人用的，理论上其他debian系的都可以用。
```bash
curl http://qdnas.icu/swap_manage.sh | bash
```

##
### 飞牛聚合脚本 <small> [作者:又菜又爱玩的小朱猪](https://gitee.com/xiao-zhu245/fnscript) </small>

  一个比较齐全执行脚本的集合库，可以修复上述的问题，推荐使用他的一键开启IOMMU直通和网络诊断
```bash
git clone https://gitee.com/xiao-zhu245/fnscript.git
cd fnscript/
python3 menu.py
```
![图片描述，用于无障碍](/pig.png)

##
### GPU编解码能力检测 <small>[作者:青团](https://club.fnnas.com/forum.php?mod=viewthread&tid=39199) </small>
直接查询你的NAS硬件和软件支持的视频格式
```bash
curl -sSL http://qdnas.icu/check_gpu.sh | sed 's/\r$//' | bash
```
![图片描述，用于无障碍](/check_gpu.png)

