# 課題2

http://IPアドレス/secret へアクセスした際、下記の情報でダイジェスト認証を行った場合のみ、SUCCESS と表示するように設定してください。

## 作業内容

1. Dockerコンテナ作成のため、EC2のOS情報確認
2. 擬似的なLinuxコンテナで検証 @ローカルPC
3. Digest認証用のユーザーを作成 @EC2
4. Digest認証の設定をApacheに追加 @EC2
5. Apache HTTP Serverを再起動 @EC2
6. Digest認証によってのみアクセスできるsecretファイル作成 @EC2

## 工夫点

ApacheによるDigest認証設定は経験がなかったため、EC2サーバーにて作業する前に、ローカル環境にて擬似的なEC2のLinuxコンテナを立ち上げて検証を行った。

## 作業ログ

### @ローカルPC

```bash
# 2. 擬似的なLinuxコンテナで検証 @ローカルPC
$ docker pull amazonlinux:2
2: Pulling from library/amazonlinux
5e0be87f98fb: Pull complete 
Digest: sha256:3535ab19660e96ed538ae7814f12eda76606064e40e2b8775aa74613bc8e6592
Status: Downloaded newer image for amazonlinux:2
docker.io/library/amazonlinux:2

$ docker run --name ec2 -itd -p 8080:80 amazonlinux:2
777c93ba23db25af3fb6f5104c3ec9623ca4806765dede2913b49cbe98bf63f9

$ docker exec -it ec2 bash
bash-4.2# 
bash-4.2# 
bash-4.2# cat /etc/os-release 
NAME="Amazon Linux"
VERSION="2"
ID="amzn"
ID_LIKE="centos rhel fedora"
VERSION_ID="2"
PRETTY_NAME="Amazon Linux 2"
ANSI_COLOR="0;33"
CPE_NAME="cpe:2.3:o:amazon:amazon_linux:2"
HOME_URL="https://amazonlinux.com/"
bash-4.2# 

$ docker build -t ec2 .                                 
Sending build context to Docker daemon  19.97kB
Step 1/6 : FROM amazonlinux:2
 ---> f341032df1f7
Step 2/6 : RUN amazon-linux-extras install -y
 ---> Using cache
 ---> 061e0c5ccf6d
Step 3/6 : RUN yum update -y &&     yum -y install systemd-sysv sudo httpd
 ---> Running in 146b8366f7e0
Loaded plugins: ovl, priorities
Resolving Dependencies
--> Running transaction check
---> Package glibc.x86_64 0:2.26-59.amzn2 will be updated
---> Package glibc.x86_64 0:2.26-60.amzn2 will be an update
---> Package glibc-common.x86_64 0:2.26-59.amzn2 will be updated

... 省略 ...

================================================================================
 Package                      Arch    Version                 Repository   Size
================================================================================
Installing:
 httpd                    
  systemd-libs.x86_64 0:219-78.amzn2.0.18                                       
  ustr.x86_64 0:1.0.4-16.amzn2.0.3                                              
  util-linux.x86_64 0:2.30.2-2.amzn2.0.7                                        

Complete!
Removing intermediate container 146b8366f7e0
 ---> 35c8cddc82cd
Step 4/6 : RUN useradd "ec2-user" && echo "ec2-user ALL=NOPASSWD: ALL" >> /etc/sudoers
 ---> Running in c351d60e5c97
Removing intermediate container c351d60e5c97
 ---> 19f853022ba2
Step 5/6 : EXPOSE 80
 ---> Running in b68b47cfdc83
Removing intermediate container b68b47cfdc83
 ---> c0a43771ba98
Step 6/6 : CMD ["/sbin/init"]
 ---> Running in e38ee07e7a32
Removing intermediate container e38ee07e7a32
 ---> da02e62d8a9b
Successfully built da02e62d8a9b
Successfully tagged ec2:latest

$ docker run --name ec2 --privileged -itd -p 8080:80 ec2
521c4425c3a292308c15e7cabc54e77d6bae677811a4baf6529eeaed972139de

$ docker exec -it ec2 bash -c "su - ec2-user"           
[ec2-user@521c4425c3a2 ~]$ sudo systemctl start httpd.service
[ec2-user@521c4425c3a2 ~]$ sudo vi /var/www/html/index.html
[ec2-user@521c4425c3a2 ~]$ curl http://localhost:80/
AWS
[ec2-user@521c4425c3a2 ~]$ sudo vi /etc/httpd/conf/httpd.conf 
[ec2-user@521c4425c3a2 ~]$ sudo htdigest -c /var/www/html/secret/password/passwords "Staff Only" aws
Adding password for aws in realm Staff Only.
New password: 
Re-type new password: 
[ec2-user@521c4425c3a2 ~]$ cat /var/www/html/secret/password/passwords 
aws:Staff Only:2ac839ae4e5a869ea478e917090d5564
[ec2-user@521c4425c3a2 ~]$ sudo vi /etc/httpd/conf/httpd.conf 
[ec2-user@521c4425c3a2 ~]$ sudo systemctl restart httpd.service
[ec2-user@521c4425c3a2 ~]$ curl http://localhost:80/secret
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>301 Moved Permanently</title>
</head><body>
<h1>Moved Permanently</h1>
<p>The document has moved <a href="http://localhost/secret/">here</a>.</p>
</body></html>
[ec2-user@521c4425c3a2 ~]$ curl http://localhost:80/secret/index.html
SUCCESS
[ec2-user@521c4425c3a2 ~]$ curl http://localhost:80                  
AWS
[ec2-user@521c4425c3a2 ~]$ sudo vi /var/www/html/secret/index.html
[ec2-user@521c4425c3a2 ~]$ sudo vi /etc/httpd/conf/httpd.conf 
[ec2-user@521c4425c3a2 ~]$ curl http://localhost:80/secret
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>401 Unauthorized</title>
</head><body>
<h1>Unauthorized</h1>
<p>This server could not verify that you
are authorized to access the document
requested.  Either you supplied the wrong
credentials (e.g., bad password), or your
browser doesnt understand how to supply
the credentials required.</p>
</body></html>
[ec2-user@521c4425c3a2 ~]$ curl --digest -u aws:candidate http://localhost:80/secret/
SUCCESS
[ec2-user@521c4425c3a2 ~]$ curl http://localhost:80/secret/
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>401 Unauthorized</title>
</head><body>
<h1>Unauthorized</h1>
<p>This server could not verify that you
are authorized to access the document
requested.  Either you supplied the wrong
credentials (e.g., bad password), or your
browser doesnt understand how to supply
the credentials required.</p>
</body></html>
[ec2-user@521c4425c3a2 ~]$ ls -l /var/www/html/
index.html  password/   secret/     
[ec2-user@521c4425c3a2 ~]$ ls -l /var/www/html/^C
[ec2-user@521c4425c3a2 ~]$ sudo vi /var/www/html/secret.html
[ec2-user@521c4425c3a2 ~]$ sudo rm -rf /var/www/html/secret
[ec2-user@521c4425c3a2 ~]$ curl http://localhost:80/secret
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>404 Not Found</title>
</head><body>
<h1>Not Found</h1>
<p>The requested URL was not found on this server.</p>
</body></html>
[ec2-user@521c4425c3a2 ~]$ curl http://localhost:80/secret.html
SUCCESS
[ec2-user@521c4425c3a2 ~]$ curl http://localhost:80/           
AWS
[ec2-user@521c4425c3a2 ~]$ sudo rm -rf /var/www/html/secret^C
[ec2-user@521c4425c3a2 ~]$ sudo mv /var/www/html/secret.html /var/www/html/secret
[ec2-user@521c4425c3a2 ~]$ curl http://localhost:80/secret.html
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>404 Not Found</title>
</head><body>
<h1>Not Found</h1>
<p>The requested URL was not found on this server.</p>
</body></html>
[ec2-user@521c4425c3a2 ~]$ curl http://localhost:80/secret     
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>401 Unauthorized</title>
</head><body>
<h1>Unauthorized</h1>
<p>This server could not verify that you
are authorized to access the document
requested.  Either you supplied the wrong
credentials (e.g., bad password), or your
browser doesnt understand how to supply
the credentials required.</p>
</body></html>
[ec2-user@521c4425c3a2 ~]$ curl --digest -u aws:candidate http://localhost:80/secret 
SUCCESS
[ec2-user@521c4425c3a2 ~]$ 
```

### @EC2

```bash
[ec2-user@ip-172-31-16-38 ~]$ cat /etc/os-release # 1, Dockerコンテナ作成のため、EC2のOS情報確認
NAME="Amazon Linux"
VERSION="2"
ID="amzn"
ID_LIKE="centos rhel fedora"
VERSION_ID="2"
PRETTY_NAME="Amazon Linux 2"
ANSI_COLOR="0;33"
CPE_NAME="cpe:2.3:o:amazon:amazon_linux:2"
HOME_URL="https://amazonlinux.com/"
[ec2-user@ip-172-31-16-38 ~]$ sudo htdigest -c /etc/httpd/conf/.digestpass "Digest Auth" aws # 3. Digest認証用のユーザーを作成 @EC2
Adding password for aws in realm Digest Auth.
New password: 
Re-type new password: 
[ec2-user@ip-172-31-16-38 ~]$ sudo vim /etc/httpd/conf/httpd.conf # 4. Digest認証の設定をApacheに追加
[ec2-user@ip-172-31-16-38 ~]$ cat /etc/httpd/conf/httpd.conf 
#
# This is the main Apache HTTP server configuration file.  It contains the
# configuration directives that give the server its instructions.
# See <URL:http://httpd.apache.org/docs/2.4/> for detailed information.
# In particular, see 

... 省略 ...

<Directory "/var/www/html/secret">
    AuthType Digest
    AuthName "Digest Auth"
    AuthUserFile "/etc/httpd/conf/.digestpass"
    Require valid-user
</Directory>

... 省略 ...

</IfModule>


# Supplemental configuration
#
# Load config files in the "/etc/httpd/conf.d" directory, if any.
IncludeOptional conf.d/*.conf
[ec2-user@ip-172-31-16-38 ~]$ sudo systemctl restart httpd # 5. Apache HTTP Serverを再起動 @EC2
[ec2-user@ip-172-31-16-38 ~]$ sudo vim /var/www/html/secret # 6. Digest認証によってのみアクセスできるsecretファイル作成 @EC2
[ec2-user@ip-172-31-16-38 ~]$ cat /var/www/html/secret
SUCCESS
[ec2-user@ip-172-31-16-38 ~]$ curl http://35.76.27.8/secret
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>401 Unauthorized</title>
</head><body>
<h1>Unauthorized</h1>
<p>This server could not verify that you
are authorized to access the document
requested.  Either you supplied the wrong
credentials (e.g., bad password), or your
browser doesn't understand how to supply
the credentials required.</p>
</body></html>
[ec2-user@ip-172-31-16-38 ~]$ curl --digest -u aws:candidate http://35.76.27.8/secret
SUCCESS
[ec2-user@ip-172-31-16-38 ~]$ 
```
