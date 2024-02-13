FROM fifilyu/centos9:latest

ENV TZ Asia/Shanghai
ENV LANG en_US.UTF-8
ENV PATH="$PATH:/usr/local/python3/bin"

##############################################
# buildx有缓存，注意判断目录或文件是否已经存在
##############################################
RUN dnf makecache

RUN dnf install -y expect

# YUM源中的MySQL8在Docker中运行有权限问题，故使用MariaDB
RUN dnf install -y mariadb-server mariadb

RUN dnf install -y java-11-openjdk java-11-openjdk-devel java-11-openjdk-headless

COPY file/var/lib/xxl-job /var/lib/xxl-job

# 执行器任务所需依赖
RUN dnf install -y git
RUN pip312 install --root-user-action=ignore -U rain_shell_scripter

##############################################
# 设置MariaDB
##############################################
# 默认MariaDB支持本地socket认证（无密码认证），此处显式开启仅为备忘
RUN crudini --set /etc/my.cnf.d/auth_gssapi.cnf mariadb unix_socket ON

RUN useradd --home-dir /var/lib/xxl-job/admin --no-create-home --shell /sbin/nologin --comment "XXL-JOB Admin" xxl-job-admin
RUN mkdir -p /var/log/xxl-job/admin
RUN chown -R xxl-job-admin:xxl-job-admin /var/log/xxl-job/admin

RUN useradd --home-dir /var/lib/xxl-job/executor --no-create-home --shell /bin/bash --comment "XXL-JOB Executor" xxl-job-executor
RUN mkdir -p /var/log/xxl-job/executor/jobhandler
RUN chown -R xxl-job-executor:xxl-job-executor /var/lib/xxl-job/executor

RUN dnf clean all

COPY file/usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

WORKDIR /root

EXPOSE 22 8080