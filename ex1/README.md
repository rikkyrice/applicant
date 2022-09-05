# 課題1

任意のWebサーバをインストール・起動し、http://IPアドレス/ でアクセスした際、”AWS” と表示されるように設定をしてください。
また、OSを再起動した場合でも自動的にWebサーバが起動するように設定して下さい。

## 作業内容

1. Apache HTTP Serverをインストール @EC2
2. Apache HTTP Serverを起動 @EC2
3. Apache HTTP Serverの自動起動を有効化 @EC2
4. index.htmlファイルを作成 @EC2

## 工夫点

APIはJavaのSpring Bootで構築することを考えており、Apacheとの連携に関する記事がWEB上に豊富にあったため、WebサーバーにはApacheを採用。

## 作業ログ

### @EC2

```bash
[ec2-user@ip-172-31-16-38 ~]$ sudo yum -y install httpd # 2. Apache HTTP Serverをインストール
読み込んだプラグイン:extras_suggestions, langpacks, priorities, update-motd
amzn2-core                                                                          | 3.7 kB  00:00:00     
依存性の解決をしています
--> トランザクションの確認を実行しています。

... 省略 ...

  apr-util-bdb.x86_64 0:1.6.1-5.amzn2.0.2            generic-logos-httpd.noarch 0:18.0.0-4.amzn2          
  httpd-filesystem.noarch 0:2.4.54-1.amzn2           httpd-tools.x86_64 0:2.4.54-1.amzn2                  
  mailcap.noarch 0:2.1.41-2.amzn2                    mod_http2.x86_64 0:1.15.19-1.amzn2.0.1               

完了しました!
[ec2-user@ip-172-31-16-38 ~]$ sudo systemctl start httpd.service # 3. Apache HTTP Serverを起動
[ec2-user@ip-172-31-16-38 ~]$ sudo systemctl status httpd.service # statusを確認
● httpd.service - The Apache HTTP Server
   Loaded: loaded (/usr/lib/systemd/system/httpd.service; disabled; vendor preset: disabled)
   Active: active (running) since 木 2022-08-25 03:50:01 UTC; 10s ago
     Docs: man:httpd.service(8)

... 省略 ...

 8月 25 03:50:01 ip-172-31-16-38.ap-northeast-1.compute.internal systemd[1]: Starting The Apache HTTP S...
 8月 25 03:50:01 ip-172-31-16-38.ap-northeast-1.compute.internal systemd[1]: Started The Apache HTTP Se...
Hint: Some lines were ellipsized, use -l to show in full.
[ec2-user@ip-172-31-16-38 ~]$ sudo systemctl enable httpd.service # 4. Apache HTTP Serverの自動起動を有効化
Created symlink from /etc/systemd/system/multi-user.target.wants/httpd.service to /usr/lib/systemd/system/httpd.service.
[ec2-user@ip-172-31-16-38 ~]$ sudo vim /var/www/html/index.html # 5. index.htmlファイルを作成
[ec2-user@ip-172-31-16-38 ~]$ cat /var/www/html/index.html # 作成したファイルを確認
AWS
[ec2-user@ip-172-31-16-38 ~]$ 
```
