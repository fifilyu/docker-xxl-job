# docker-xxl-job

分布式任务调度平台（XXL-JOB） Docker镜像

## 一、构建镜像

```bash
git clone https://github.com/fifilyu/docker-xxl-job.git
cd docker-xxl-job
docker buildx build -t fifilyu/xxl-job:latest .
```

## 二、开放端口

* sshd->22
* xxl-job->8080

## 三、启动容器（数据分离）

### 3.1 预先准备开放权限的数据和日志目录

```bash
sudo mkdir -p /data/xxl-job/admin/var/log
sudo mkdir -p /data/xxl-job/executor/var/log
sudo mkdir -p /data/xxl-job/mysql
sudo chmod -R 777 /data/xxl-job/admin/var/log /data/xxl-job/executor/var/log /data/xxl-job/mysql
sudo chmod -R 777 /data/xxl-job/admin/etc/application.properties /data/xxl-job/admin/etc/logback.xml /data/xxl-job/executor/etc/application.properties /data/xxl-job/executor/etc/logback.xml
```

### 3.2 启动带目录映射的容器

```bash
docker run -d \
    --env LANG=en_US.UTF-8 \
    --env TZ=Asia/Shanghai \
    -e PUBLIC_STR="$(<~/.ssh/fifilyu@archlinux.pub)" \
    -p 1022:22 \
    -p 1808:8080 \
    -v /data/xxl-job/admin/etc/application.properties:/var/lib/xxl-job/admin/etc/application.properties \
    -v /data/xxl-job/admin/etc/logback.xml:/var/lib/xxl-job/admin/etc/logback.xml \
    -v /data/xxl-job/admin/var/log:/var/log/xxl-job/admin \
    -v /data/xxl-job/executor/etc/application.properties:/var/lib/xxl-job/executor/etc/application.properties \
    -v /data/xxl-job/executor/etc/logback.xml:/var/lib/xxl-job/executor/etc/logback.xml \
    -v /data/xxl-job/executor/var/log:/var/log/xxl-job/executor \
    -v /data/xxl-job/mysql/data:/var/lib/mysql \
    -v /data/xxl-job/lock:/var/lock/docker \
    -h xxl-job \
    --name xxl-job \
    fifilyu/xxl-job:latest
```

### 3.3 重置目录权限

```bash
# 目录降级读写权限
sudo chmod 755 /data/xxl-job/admin/var/log /data/xxl-job/executor/var/log /data/xxl-job/mysql /data/xxl-job/mysql/data
sudo chmod 755 /data/xxl-job/admin/etc/application.properties /data/xxl-job/admin/etc/logback.xml /data/xxl-job/executor/etc/application.properties /data/xxl-job/executor/etc/logback.xml

# 使用容器内的xxl-job用户和组的id重置目录用户组
admin_uid=$(docker exec -it xxl-job bash -c 'id -u xxl-job-admin' | tr -d '\r')
admin_gid=$(docker exec -it xxl-job bash -c 'id -g xxl-job-admin' | tr -d '\r')
sudo chown -R ${admin_uid}:${admin_gid} /data/xxl-job/admin/var/log

executor_uid=$(docker exec -it xxl-job bash -c 'id -u xxl-job-executor' | tr -d '\r')
executor_gid=$(docker exec -it xxl-job bash -c 'id -g xxl-job-executor' | tr -d '\r')
sudo chown -R ${executor_uid}:${executor_gid} /data/xxl-job/executor/var/log

# 确认重置效果
ls -dln /data/xxl-job/admin/var/log /data/xxl-job/executor/var/log /data/xxl-job/mysql/data

ls -aln /data/xxl-job/admin/var/log /data/xxl-job/executor/var/log /data/xxl-job/mysql/data
```

### 3.4 重启容器

*必须重启容器，否则容器无法读写映射目录*

```bash
docker restart xxl-job
```

## 四、访问XXL-JOB

* 访问地址：http://localhost:1808/xxl-job-admin
* 用户名称： admin
* 用户密码： 123456