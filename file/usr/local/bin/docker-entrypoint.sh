#!/bin/sh

/sbin/sshd

sleep 1

AUTH_LOCK_FILE=/var/log/docker_init_auth.lock

if [ ! -z "${PUBLIC_STR}" ]; then
    if [ -f ${AUTH_LOCK_FILE} ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S") [信息] 跳过添加公钥"
    else
        echo "${PUBLIC_STR}" >>/root/.ssh/authorized_keys

        if [ $? -eq 0 ]; then
            echo "$(date "+%Y-%m-%d %H:%M:%S") [信息] 公钥添加成功"
            echo $(date "+%Y-%m-%d %H:%M:%S") >${AUTH_LOCK_FILE}
        else
            echo "$(date "+%Y-%m-%d %H:%M:%S") [错误] 公钥添加失败"
            exit 1
        fi
    fi
fi

PW=$(pwgen -1 20)
echo "$(date +"%Y-%m-%d %H:%M:%S") [信息] Root用户密码：${PW}"
echo "root:${PW}" | chpasswd

# 使用容器内部的用户组重置目录权限：解决容器启动映射卷导致的宿主权限和容器权限不同步问题
chown -R mysql:mysql /var/log/mysql
chown -R xxl-job-executor:xxl-job-executor /var/log/xxl-job/executor
chown -R xxl-job-admin:xxl-job-admin /var/log/xxl-job/admin

# 为支持容器映射目录，只在启动时初始化数据目录和导入SQL文件
test -d /var/lib/mysql/mysql || /usr/libexec/mariadb-prepare-db-dir mysql mysql

/usr/libexec/mariadbd --basedir=/usr --user=mysql &

sleep 3

mkdir -p /var/lock/docker
LOCK_FILE=/var/lock/docker/xxl-job_init.lock

if [ -f ${LOCK_FILE} ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") [信息] 跳过初始化MySQL密码和初始化XXLJOB数据库"
else
    MYSQL_ROOT_PASSWORD=$(pwgen -1 20)
    echo "$(date "+%Y-%m-%d %H:%M:%S") [信息] MySQL新密码："${MYSQL_ROOT_PASSWORD}

    # 因MariaDB默认启用unix_socket，本地root连接MySQL的root用户无需密码
    mysqladmin -uroot password ${MYSQL_ROOT_PASSWORD}

    if [ $? -eq 0 ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S") [信息] MySQL密码修改成功"
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S") [错误] MySQL密码修改失败"
        exit 1
    fi

    mysql -e 'CREATE DATABASE xxl_job DEFAULT CHARACTER SET utf8mb4 DEFAULT COLLATE utf8mb4_unicode_ci;'
    mysql -e 'show databases;'
    mysql xxl_job </var/lib/xxl-job/init_xxl_job.sql

    if [ $? -eq 0 ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S") [信息] 导入XXL-JOB SQL文件成功"
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S") [错误] 导入XXL-JOB SQL文件失败"
        exit 1
    fi

    TOKEN=$(pwgen -1 20)
    # 容器如果使用挂载映射，只能直接修改文件，不能替换，否则出现错误 "[Errno 16] Device or resource busy"
    # 必须配合 --inplace 参数
    crudini --set --inplace --existing /var/lib/xxl-job/admin/etc/application.properties "" spring.datasource.password "${MYSQL_ROOT_PASSWORD}" &&
        crudini --set --inplace --existing /var/lib/xxl-job/admin/etc/application.properties "" xxl.job.accessToken "${TOKEN}" &&
        crudini --set --inplace --existing /var/lib/xxl-job/executor/etc/application.properties "" xxl.job.accessToken "${TOKEN}"

    if [ $? -eq 0 ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S") [信息] XXL-JOB配置文件更新成功"
        echo $(date "+%Y-%m-%d %H:%M:%S") >${LOCK_FILE}
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S") [错误] XXL-JOB配置文件更新失败"
        exit 1
    fi
fi

echo "$(date "+%Y-%m-%d %H:%M:%S") [信息] XXL-JOB Admin启动中......"
/usr/sbin/runuser -u xxl-job-admin -g xxl-job-admin -- /usr/bin/java -Dlogback.configurationFile=​/var/lib/xxl-job/admin/etc/logback.xml -Dspring.config.location=/var/lib/xxl-job/admin/etc/application.properties -jar /var/lib/xxl-job/admin/bin/xxl-job-admin-latest.jar &

sleep 10

echo "$(date "+%Y-%m-%d %H:%M:%S") [信息] XXL-JOB Executor启动中......"
/usr/sbin/runuser -u xxl-job-executor -g xxl-job-executor -- /usr/bin/java -Dlogback.configurationFile=​/var/lib/xxl-job/executor/etc/logback.xml -Dspring.config.location=/var/lib/xxl-job/executor/etc/application.properties -jar /var/lib/xxl-job/executor/bin/xxl-job-executor-springboot-latest.jar &

# 目录降级读写权限，主要降级宿主映射卷
chmod 755 /var/log/xxl-job/admin /var/log/xxl-job/executor /var/log/xxl-job/executor/jobhandler /var/lib/mysql /var/lock/docker
chmod 644 /var/lib/xxl-job/admin/etc/application.properties /var/lib/xxl-job/executor/etc/application.properties

# 保持前台运行，不退出
while true; do
    sleep 3600
done
