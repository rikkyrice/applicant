# 構築手順

## postgresql構築

@ec2

```bash
# postgresql serverインストール
$ sudo yum install -y postgresql-server.x86_64

# データベースセットアップ
$ sudo postgresql-setup initdb

# 接続設定 - localをidentからtrustへ
$ sudo vim /var/lib/pgsql/data/pg_hba.conf

# postgresql server 自動起動
$ sudo systemctl enable postgresql.service

# postgresql server 起動
$ sudo systemctl start postgresql.service
```

@host

```bash
# init.sqlをec2にコピー
$ scp -i ~/.ssh/aws-ec2-test init.sql ec2-user@35.76.27.8:/tmp/
```

@ec2

```bash
# postgresに変更
$ sudo su - postgres

# init.sqlを実行
$ psql -U postgres -d awsdb -f /tmp/init.sql
```

# ajp設定

@ec2

```bash
# proxy-ajp.confを追加
$ sudo vim /etc/httpd/conf.d/proxy-ajp.conf

# httpdを再起動
$ sudo systemctl restart httpd
```

# java実行

@ec2

```bash
# javaをインストール
$ sudo yum install -y java-11-amazon-corretto.x86_64
```

@host

```bash
# api.jarをec2にコピー
$ scp -i ~/.ssh/aws-ec2-test api.jar ec2-user@35.76.27.8:/tmp/
```

@ec2

```bash
# api.jarをec2-usernのホームディレクトリに移動
$ cp -p /tmp/api.jar ~/

# api.jarを実行
$ nohup java -jar api.jar &
```
