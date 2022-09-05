FROM amazonlinux:2

# install amazon-linux-extras install
RUN amazon-linux-extras install -y

# yum update & install
RUN yum update -y && \
    yum -y install systemd-sysv sudo httpd java-11-amazon-corretto.x86_64 postgresql-server.x86_64

COPY ./ex2/httpd.conf /etc/httpd/conf/httpd.conf
COPY ./ex1/index.html /var/www/html/
COPY ./ex2/secret /var/www/html/
COPY ./ex2/etc/httpd/conf/.digestpass /etc/httpd/conf/
COPY ./ex3/etc/httpd/conf.d/proxy-ajp.conf /etc/httpd/conf.d/
COPY ./api.jar /root/
COPY ./init.sql /

# create user
RUN useradd "ec2-user" && echo "ec2-user ALL=NOPASSWD: ALL" >> /etc/sudoers

EXPOSE 80

CMD ["/sbin/init"]
