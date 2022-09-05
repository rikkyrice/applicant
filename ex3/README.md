# 課題3

簡単な商品在庫管理システムを考えます。以下のような在庫の追加、販売、チェックなどの機能を実装してください。

## 作業内容

1. API仕様書作成 @ローカルPC
2. DB設計 @ローカルPC
3. 開発用にPostgreSQLのDBコンテナ作成 @ローカルPC
4. API設計 @ローカルPC
5. API開発 @ローカルPC
6. 擬似的なLinuxコンテナで結合テスト @ローカルPC
7. PostgreSQL Serverをインストール @EC2
8. データベースセットアップ @EC2
9. ローカルでのデータベースへのクライアントアクセス方法をMD5に変更 @EC2
10. PostgreSQL Serverの自動起動を有効化 @EC2
11. PostgreSQL Serverを起動 @EC2
12. テーブル追加用のSQLスクリプトをEC2に送信 @ローカルPC
13. postgresユーザーに切り替えてPostgreSQL Serverにログイン @EC2
14. PostgreSQL Serverのpostgresユーザーのパスワード変更とデータベース作成 @EC2
15. テーブル追加用のSQLスクリプト実行 @EC2
16. PostgreSQL Server再起動 @EC2
17. tomcatと連携するため、Apache HTTP ServerのAJP設定追加 @EC2
18. Apache HTTP Server再起動 @EC2
19. java-11-amazon-correttoをインストール @EC2
20. 最新のapi.jarをビルド @ローカルPC
21. api.jarをEC2に送信 @ローカルPC
22. api.jarをバックグラウンドで実行 @EC2

## 工夫点

### API仕様書作成

まずは要件整理のため、API仕様書をOpenAPI仕様で作成した。  
その中で、仕様として定義されていない項目は以下の様に整理した。

* priceはDecimal型とする
* 販売する対象の商品が存在しない場合、販売APIは、`{"message":"ERROR"}`を出力する
* 販売する対象の商品の在庫が十分でない場合、販売APIは、`{"message":"ERROR"}`を出力する
* 販売する対象の商品の価格は、小数点指定可能とする
* 売上が存在しない場合、売上チェックAPIは、`{"message":"ERROR"}`を出力する
* 削除APIのステータスコードは`204 No Content`とする

### DB設計

DBは普段使い慣れているPostgreSQLを採用した。  
テーブル定義は以下のように整理した。

```sql
--------------------------------------------------
-- STOCKS
--  在庫情報テーブル
--------------------------------------------------
create table Stocks (
    name varchar(8) not null,
    amount int not null,

    primary key (name)
);

--------------------------------------------------
-- SALES
--  売上情報テーブル
--------------------------------------------------
create table Sales (
    customer_id varchar(15) not null,
    price decimal not null,

    primary key (customer_id)
);
```

基本的にはAPI仕様に従い、各項目は取り得るデータに沿った型を定義した。  
在庫情報テーブルはAPI仕様の観点から商品名が一意であることが確認できるため、`name`を主キーとした。
売上情報テーブルは今後の拡張性を考慮し、ユーザーごとに販売情報を格納できるように`customer_id`を主キーとした。

### 開発用にPostgreSQLのDBコンテナ作成

作業を簡略化するため、PostgreSQLのDBコンテナを作成し、立ち上げて開発をおこなった。

### API設計

APIにはJavaのSpring Bootを採用した。  
プライベートでよくAPIを開発する際に利用しているフレームワークであることと、tomcatが内蔵されているためアプリケーションサーバーの構築が不要であり、開発すればすぐにAPIサーバーとして起動することができるからである。  
またプロパティファイルにより、サーバーとしての構成をコードと分割して管理することができるので、拡張性が高く今後の要件にも柔軟に対応可能である。

アーキテクチャは、オニオンアーキテクチャを採用した。  
各コンポーネントを、アプリケーションのインターフェースを担うUI層、アプリケーションの機能を担うアプリケーション層、データベースとのやり取りを担うインフラストラクチャ層、そしてビジネスロジックを集約させたドメイン層の4つの層に分割するアーキテクチャであり、かつドメイン層を他のどの層にも依存させない様にするため、開発するアプリケーションの業務知識を一点に集約して管理できるアーキテクチャである。
これにより、今後本格開発が開始された場合でも、業務ロジックを表すドメインモデルがあらかじめ定義されるため、機能追加に柔軟に対応することができる。  
また各コンポーネントの依存関係はDIを利用して切り離し、疎結合とした。  
こうすることで、要件変更によるコードの改修を最小限に抑えられる。  

### API実装

アプリケーションサーバーはSpringBootに内蔵されているtomcatを利用するので、server.xmlもコードに埋め込む形で定義した。  
中でもAJP設定をコードに埋め込み、Apacheが受け付ける`/v1`パスに対する通信はすべてtomcatにリダイレクトするように設定した。

#### UI層

リクエストボディの項目入力チェックに関しては、JavaEEのBeanValidationを利用し、各項目のNotNull制約や文字数判定などを包括的に判定するようロジックを実装した。

在庫は正の整数としてチェックする必要がある。
そこで型をIntegerとして定義したが、そうすると在庫が小数を含む値を受け付けてもエラーとならず、小数以下を切り捨てた整数値として値を保持してしまった。  
そうなると、格納後は整数値となるため、クライアントが小数を含めて送ってきたかどうかがチェックができなかった。  
そのためあえてDoubleで定義して小数値を受け付けることで、ドメイン層のオブジェクトに変換する際に小数を含む値かどうかを判定できるように実装した。  
整数チェックは、対象の値が1で割り切れるかどうかで判断し、割り切れる場合はIntegerに変換、割り切れない場合はBadRequestParamsExceptionとして400エラーを返すように実装した。

価格の型はすべてBigDecimalとして定義した。  
BigDecimalは、setScaleメソッドを呼び出すことで、保持する小数部分の位を指定することが可能であり、小数第三位を切り上げて小数第二位までを出力対象とする要件を満たすことができる。

在庫チェックAPIは、名前の部分一致やソートキーの指定など、今後の拡張性を考慮し、`StockQueryCondition`や`SortCondition`などのクラスを定義して、そこに知識を持たせた。

#### アプリケーション層

アプリケーション層には、UI層から受け取ったドメインオブジェクトが業務処理可能な状態かどうかを判断し、必要に応じて例外を発生させる役割を持たせた。  
例えば、販売APIが呼び出された場合、アプリケーション層はUI層から販売対象となる商品オブジェクトを受け取り、ドメイン層にその商品オブジェクトの現在の在庫数を問い合わせる。  
UI層から受け取った商品の販売個数が現在の在庫数よりも上回る場合は、在庫不十分として例外とした。  
これはアプリケーション層が持つ在庫販売機能としての知識であり、他の層が持つべき知識ではないからである。

#### ドメイン層

ドメイン層はビジネスロジックの知識が集約された層であるため、コンストラクタに項目のバリデーションを行う処理を実装し、インスタンス化されたオブジェクトが必ず業務上の制約を守っていることを担保させた。

#### インフラストラクチャ層

データベースとのやり取りはすべてこの層に集約させている。  
また、在庫一覧取得に関してはクエリを自由に組み立てて発行できる実装としているため、今後の機能追加や要件変更に柔軟に対応できるように実装した。

### 擬似的なLinuxコンテナで結合テスト

開発が完了した後は、あまり時間がなかったためテストコードの実装はせず、課題2で構築した擬似的なEC2のLinuxコンテナにPostgreSQLとJavaをインストールしてDBセットアップとAPIサーバーの実行を行なったのち、APIの結合テストを行なった。  
課題に記載されている実行例のリクエストを発行し、想定されるレスポンスを検証することを結合テストのシナリオとし、すべてパスすることを確認した。

## 作業ログ

### @ローカルPC

```bash
$ docker run --name ec2 --privileged -itd -p 8080:80 ec2
da091344ddc5107560bf76024f350f55a0d1e51807ef624904bb289b723acf96

$ docker cp work/api-test/build/libs/api.jar ec2:/root/ 

$ docker exec -it ec2 bash -c "su - ec2-user"           
[ec2-user@da091344ddc5 ~]$ sudo su -
-bash-4.2# vi /etc/httpd/conf.d/proxy-ajp.conf
-bash-4.2# ls
api.jar
-bash-4.2# vi /etc/httpd/conf.d/proxy-ajp.conf
-bash-4.2# systemctl start httpd
-bash-4.2# java -jar api.jar &
[1] 213
-bash-4.2# 
  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::        (v2.3.2.RELEASE)'`

2022/08/27 17:40:48.698  INFO [main] : Starting ApiApplication on da091344ddc5 with PID 213 (/root/api.jar started by root in /root)

... 省略 ...

2022/08/27 17:40:57.538  INFO [main] : Spring Data repositories initialized!
2022/08/27 17:40:57.584  INFO [main] : Started ApiApplication in 10.99 seconds (JVM running for 12.251)
2022/08/27 17:41:00.427  INFO [ajp-nio2-127.0.0.1-8009-exec-2] : Initializing Spring DispatcherServlet 'dispatcherServlet'
2022/08/27 17:41:00.430  INFO [ajp-nio2-127.0.0.1-8009-exec-2] : Initializing Servlet 'dispatcherServlet'
2022/08/27 17:41:00.448  INFO [ajp-nio2-127.0.0.1-8009-exec-2] : Completed initialization in 18 ms
2022/08/27 17:41:00.495  INFO [ajp-nio2-127.0.0.1-8009-exec-2] : REQUEST:{path=/stocks, method=GET, header={host=localhost:8080, user-agent=curl/7.79.1, accept=*/*}, params={}}
Hibernate: select stockentit0_.name as name1_1_, stockentit0_.amount as amount2_1_ from stocks stockentit0_ where stockentit0_.amount>=1 order by stockentit0_.name asc
2022/08/27 17:41:01.214  INFO [ajp-nio2-127.0.0.1-8009-exec-2] : com.aws.jp.web.test.api.ui.stocks.StocksResource#getStocks:705 ms
2022/08/27 17:41:01.274  INFO [ajp-nio2-127.0.0.1-8009-exec-2] : RESPONSE:{headers={Content-Type=application/json}, body={xxx=50}, status=200}
^C
-bash-4.2# cat /etc/httpd/conf.d/proxy-ajp.conf
<Location /v1/>
  ProxyPass ajp://127.0.0.1:8009/v1/
</Location>
-bash-4.2# 
-bash-4.2# yum install -y postgresql-server.x86_64
Loaded plugins: ovl, priorities
amzn2-core                                                                                                                               | 3.7 kB  00:00:00     
Resolving Dependencies
--> Running transaction check
---> Package postgresql-server.x86_64 0:9.2.24-6.amzn2 will be installed
--> Finished Dependency Resolution

... 省略 ...

Installed:
  postgresql-server.x86_64 0:9.2.24-6.amzn2                                                                                                                     

Complete!
-bash-4.2# postgresql-setup initdb
Initializing database ... OK

-bash-4.2# systemctl enable postgresql.service
Created symlink from /etc/systemd/system/multi-user.target.wants/postgresql.service to /usr/lib/systemd/system/postgresql.service.
-bash-4.2# systemctl start postgresql.service
-bash-4.2# su - postgres
-bash-4.2$ psql -l 
                             List of databases
   Name    |  Owner   | Encoding  | Collate | Ctype |   Access privileges   
-----------+----------+-----------+---------+-------+-----------------------
 postgres  | postgres | SQL_ASCII | C       | C     | 
 template0 | postgres | SQL_ASCII | C       | C     | =c/postgres          +
           |          |           |         |       | postgres=CTc/postgres
 template1 | postgres | SQL_ASCII | C       | C     | =c/postgres          +
           |          |           |         |       | postgres=CTc/postgres
(3 rows)

-bash-4.2$ exit
logout
-bash-4.2# systemctl start postgresql.service
-bash-4.2# vi /var/lib/pgsql/data/pg_hba.conf 
-bash-4.2# systemctl restart postgresql.service
-bash-4.2# su - postgres
-bash-4.2$ psql -U postgres -f /init.sql 
psql:/init.sql:10: NOTICE:  CREATE TABLE / PRIMARY KEY will create implicit index "stocks_pkey" for table "stocks"
CREATE TABLE
psql:/init.sql:21: NOTICE:  CREATE TABLE / PRIMARY KEY will create implicit index "sales_pkey" for table "sales"
CREATE TABLE
-bash-4.2$ 
-bash-4.2$ exit
logout
-bash-4.2# nohup java -jar api.jar &
[1] 330
-bash-4.2# nohup: ignoring input and appending output to 'nohup.out'

-bash-4.2# curl http://localhost:80/v1/healthcheck/db/status
{"message":"OK"}-bash-4.2# 
-bash-4.2# exit

$

$ scp -i ~/.ssh/aws-ec2-test init.sql ec2-user@35.76.27.8:/tmp/ # 12. テーブル追加用のSQLスクリプトをEC2に送信 @ローカルPC
init.sql                                                                                             100%  506    42.0KB/s   00:00    

$ ./gradlew build # 20. 最新のapi.jarをビルド @ローカルPC
... 省略 ...

$ scp -i ~/.ssh/aws-ec2-test api.jar ec2-user@35.76.27.8:/tmp/ # 21. api.jarをEC2に送信 @ローカルPC
api.jar                                                                                              100%   46MB   3.2MB/s   00:14    

$
```

### @EC2

```bash
$ ssh -i ~/.ssh/aws-ec2-test ec2-user@35.76.27.8

Last login: Thu Aug 25 10:26:42 2022 from i121-114-149-64.s41.a013.ap.plala.or.jp

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

https://aws.amazon.com/amazon-linux-2/
[ec2-user@ip-172-31-16-38 ~]$ sudo yum install -y postgresql-server.x86_64 # 7. PostgreSQL Serverをインストール @EC2
読み込んだプラグイン:extras_suggestions, langpacks, priorities, update-motd
amzn2-core                                                                                                                               | 3.7 kB  00:00:00     
amzn2extra-docker                                                                                                                        | 3.0 kB  00:00:00     
依存性の解決をしています
--> トランザクションの確認を実行しています。
---> パッケージ postgresql-server.x86_64 0:9.2.24-6.amzn2 を インストール
--> 依存性の処理をしています: postgresql-libs(x86-64) = 9.2.24-6.amzn2 のパッケージ: postgresql-server-9.2.24-6.amzn2.x86_64

... 省略 ...                                                                                        

依存性関連をインストールしました:
  postgresql.x86_64 0:9.2.24-6.amzn2                                           postgresql-libs.x86_64 0:9.2.24-6.amzn2                                          

完了しました!
[ec2-user@ip-172-31-16-38 ~]$ sudo postgresql-setup initdb # 8. データベースセットアップ @EC2
Initializing database ... OK

[ec2-user@ip-172-31-16-38 ~]$ sudo vim /var/lib/pgsql/data/pg_hba.conf # 9. ローカルでのデータベースへのクライアントアクセス方法をMD5に変更 @EC2
[ec2-user@ip-172-31-16-38 ~]$ sudo cat /var/lib/pgsql/data/pg_hba.conf
... 省略 ...

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
host    all             all             127.0.0.1/32            md5
# IPv6 local connections:
host    all             all             ::1/128                 ident
# Allow replication connections from localhost, by a user with the
# replication privilege.
#local   replication     postgres                                peer
#host    replication     postgres        127.0.0.1/32            ident
#host    replication     postgres        ::1/128                 ident
[ec2-user@ip-172-31-16-38 ~]$ sudo systemctl enable postgresql.service # 10. PostgreSQL Serverの自動起動を有効化 @EC2
Created symlink from /etc/systemd/system/multi-user.target.wants/postgresql.service to /usr/lib/systemd/system/postgresql.service.
[ec2-user@ip-172-31-16-38 ~]$ sudo systemctl start postgresql.service # 11. PostgreSQL Serverを起動 @EC2
[ec2-user@ip-172-31-16-38 ~]$ sudo su - postgres # 13. postgresユーザーに切り替えてPostgreSQL Serverにログイン @EC2
-bash-4.2$ psql
psql (9.2.24)
Type "help" for help.

postgres=# alter role postgres with password 'candidate'; # 14. PostgreSQL Serverのpostgresユーザーのパスワード変更とデータベース作成 @EC2
ALTER ROLE
postgres=# create database awsdb;
CREATE DATABASE
postgres=# ^\Quit
-bash-4.2$ psql -U postgres -d awsdb -f /tmp/init.sql # 15. テーブル追加用のSQLスクリプト実行 @EC2
psql:/tmp/init.sql:10: NOTICE:  CREATE TABLE / PRIMARY KEYはテーブル"stocks"に暗黙的なインデックス"stocks_pkey"を作成します
CREATE TABLE
psql:/tmp/init.sql:21: NOTICE:  CREATE TABLE / PRIMARY KEYはテーブル"sales"に暗黙的なインデックス"sales_pkey"を作成します
CREATE TABLE
-bash-4.2$ exit
logout
[ec2-user@ip-172-31-16-38 ~]$ sudo systemctl restart postgresql.service # 16. PostgreSQL Server再起動 @EC2
[ec2-user@ip-172-31-16-38 ~]$ sudo vim /etc/httpd/conf.d/proxy-ajp.conf # 17. tomcatと連携するため、Apache HTTP ServerのAJP設定追加 @EC2
[ec2-user@ip-172-31-16-38 ~]$ sudo systemctl restart httpd # 18. Apache HTTP Server再起動 @EC2
[ec2-user@ip-172-31-16-38 ~]$ sudo yum install -y java-11-amazon-corretto.x86_64 # 19. java-11-amazon-correttoをインストール @EC2
読み込んだプラグイン:extras_suggestions, langpacks, priorities, update-motd
依存性の解決をしています
--> トランザクションの確認を実行しています。
---> パッケージ java-11-amazon-corretto.x86_64 1:11.0.16+9-1.amzn2 を インストール
--> 依存性の処理をしています: java-11-amazon-corretto-headless(x86-64) = 1:11.0.16+9-1.amzn2 のパッケージ: 1:java-11-amazon-corretto-11.0.16+9-1.amzn2.x86_64

... 省略 ...                                 

依存性関連をインストールしました:
  alsa-lib.x86_64 0:1.1.4.1-2.amzn2             dejavu-fonts-common.noarch 0:2.33-6.amzn2          dejavu-sans-fonts.noarch 0:2.33-6.amzn2                    
  dejavu-sans-mono-fonts.noarch 0:2.33-6.amzn2  dejavu-serif-fonts.noarch 0:2.33-6.amzn2           fontconfig.x86_64 0:2.13.0-4.3.amzn2                       
  fontpackages-filesystem.noarch 0:1.44-8.amzn2 giflib.x86_64 0:4.1.6-9.amzn2.0.2                  java-11-amazon-corretto-headless.x86_64 1:11.0.16+9-1.amzn2
  libICE.x86_64 0:1.0.9-9.amzn2.0.2             libSM.x86_64 0:1.2.2-2.amzn2.0.2                   libX11.x86_64 0:1.6.7-3.amzn2.0.2                          
  libX11-common.noarch 0:1.6.7-3.amzn2.0.2      libXau.x86_64 0:1.0.8-2.1.amzn2.0.2                libXext.x86_64 0:1.3.3-3.amzn2.0.2                         
  libXi.x86_64 0:1.7.9-1.amzn2.0.2              libXinerama.x86_64 0:1.1.3-2.1.amzn2.0.2           libXrandr.x86_64 0:1.5.1-2.amzn2.0.3                       
  libXrender.x86_64 0:0.9.10-1.amzn2.0.2        libXt.x86_64 0:1.1.5-3.amzn2.0.2                   libXtst.x86_64 0:1.2.3-1.amzn2.0.2                         
  libxcb.x86_64 0:1.12-1.amzn2.0.2              log4j-cve-2021-44228-hotpatch.noarch 0:1.3-7.amzn2

完了しました!
[ec2-user@ip-172-31-16-38 ~]$ cp -p /tmp/api.jar ~/
[ec2-user@ip-172-31-16-38 ~]$ ls -l
合計 46808
-rw-r--r-- 1 ec2-user ec2-user 47930499  8月 28 14:28 api.jar
[ec2-user@ip-172-31-16-38 ~]$ nohup java -jar api.jar & # 22. api.jarをバックグラウンドで実行 @EC2
[1] 29157
[ec2-user@ip-172-31-16-38 ~]$ nohup: 入力を無視し、出力を `nohup.out` に追記します

[ec2-user@ip-172-31-16-38 ~]$ 
```

## プログラムコード

今回開発したプログラムコードは、すべて`api.tar.gz`に圧縮して`ec2-user`のホームディレクトリ直下に配置しました。

### resource

* application.yml

```yml:application.yml
server:
  port: 8080
  servlet:
    context-path: /v1
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/awsdb
    username: postgres
    password: candidate
    driverClassName: org.postgresql.Driver
  jpa:
    hibernate:
      ddl-auto: none
    database: POSTGRESQL
    show-sql: true
    open-in-view: true
  jmx:
    default-domain: v1
```

### UI層

#### stocks

* api/ui/stocks/StocksResource.java

```java:api/ui/stocks/StocksResource.java
package com.aws.jp.web.test.api.ui.stocks;

import java.net.URI;
import java.util.LinkedHashMap;
import java.util.Optional;
import javax.inject.Inject;
import com.aws.jp.web.test.api.application.SalesService;
import com.aws.jp.web.test.api.application.StocksService;
import com.aws.jp.web.test.api.common.log.Logging;
import com.aws.jp.web.test.api.domain.Stock;
import com.aws.jp.web.test.api.domain.query.SortCondition;
import com.aws.jp.web.test.api.domain.query.StockQueryCondition;
import com.aws.jp.web.test.api.domain.query.StockQueryResult;
import com.aws.jp.web.test.api.ui.validation.BeanValidateHelper;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.UriComponentsBuilder;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("stocks")
@RequiredArgsConstructor
public class StocksResource {
  @Inject private final StocksService stockService;
  @Inject private final SalesService salesService;

  /** 在庫の更新、作成API */
  @PostMapping(
      produces = { "application/json" })
  @Logging
  public ResponseEntity<PostStockResponse> post(
      @RequestBody PostStockRequestBody body,
      UriComponentsBuilder uriComponentsBuilder) {
    
    // リクエストボディの入力チェック
    BeanValidateHelper.validate(body);
    
    // 在庫更新、作成実行
    // リクエストボディはドメイン層の在庫オブジェクトに変換
    final Stock response = stockService.post(body.convert());

    // ロケーションを作成
    final URI location = uriComponentsBuilder
        .path("vi/stocks/{name}")
        .buildAndExpand(response.getName())
        .toUri();
      
    final HttpHeaders headers = new HttpHeaders();
    headers.setLocation(location);

    return new ResponseEntity<PostStockResponse>(new PostStockResponse(body.getName(), body.getAmount()), headers, HttpStatus.OK);
  }

  /** 在庫取得API */
  @GetMapping(
      value = {"", "{name}"},
      produces = { "application/json" })
  @Logging
  public ResponseEntity<LinkedHashMap<String, Integer>> getStocks(
      @PathVariable("name") Optional<String> params1) {

    // パスパラメーターが存在する場合は、nameをキーにした在庫取得を実行
    if (params1.isPresent()) {
      final Stock response = stockService.get(params1.get());
      return new ResponseEntity<LinkedHashMap<String, Integer>>(new StocksResponse(response).getStockMap(), HttpStatus.OK);
    }
    // クエリオブジェクトを作成
    // 今後の機能追加に柔軟に対応するためにビルダーを実装、今回は在庫が1つ以上存在する商品を取得するため在庫の最少数1を格納
    final StockQueryCondition condition = StockQueryCondition.builder().min(1).build();
    // ソート要件は今後も増えることを考慮し、ソートキーと順序を自由に変更できるようにオブジェクト化
    final SortCondition sortCondition = new SortCondition(true, "name");
    // クエリ実行
    final StockQueryResult response = stockService.query(condition, sortCondition);

    return new ResponseEntity<LinkedHashMap<String, Integer>>(new StocksResponse(response).getStockMap(), HttpStatus.OK);
  }

  /** 全削除 */
  @DeleteMapping(
      produces = { "application/json" })
  @Logging
  public ResponseEntity<Object> deleteAll() {
    // 在庫、売り上げを全削除
    stockService.deleteAll();
    salesService.deleteAll();

    return new ResponseEntity<Object>(HttpStatus.NO_CONTENT);
  }
}

```

* api/ui/stocks/PostStockRequestBody.java

```java:api/ui/PostStockRequestBody.java
package com.aws.jp.web.test.api.ui.stocks;

import java.util.Objects;
import javax.validation.constraints.Min;
import javax.validation.constraints.NotNull;
import javax.validation.constraints.Size;
import com.aws.jp.web.test.api.common.validation.Alpha;
import com.aws.jp.web.test.api.domain.Stock;
import com.aws.jp.web.test.api.ui.error.BadRequestParamsException;
import com.aws.jp.web.test.api.ui.validation.BeanValidationTarget;
import lombok.Data;

@Data
public class PostStockRequestBody implements BeanValidationTarget {
  @NotNull
  @Size(max = 8, min = 1)
  @Alpha
  private String name;

  // 小数点が来たときに入力エラーとするためにDoubleで受け付ける
  @Min(1)
  private Double amount;

  public Stock convert() {
    // amountの指定がない場合は1を初期値とする。
    if (Objects.isNull(amount)) {
      return new Stock(name, 1);
    }
    // 整数でない場合はエラーとする。
    if (!(amount % 1 == 0)) {
      throw new BadRequestParamsException("ERROR");
    }
    // amountは整数値を渡す。
    return new Stock(name, amount.intValue());
  }

  public Integer getAmount() {
    // amountが存在しない場合はnullを返す
    if (Objects.isNull(amount)) {
      return null;
    }
    // 整数でない場合はエラーとする。
    if ((Objects.nonNull(amount)) && !(amount % 1 == 0)) {
      throw new BadRequestParamsException("ERROR");
    }
    return amount.intValue();
  }
}

```

* api/ui/stocks/PostStockResponse.java

```java:api/ui/stocks/PostStockResponse.java
package com.aws.jp.web.test.api.ui.stocks;

import javax.validation.constraints.NotNull;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.aws.jp.web.test.api.common.validation.ValidateHelper;
import lombok.Getter;

@Getter
@JsonInclude(JsonInclude.Include.NON_EMPTY)
public class PostStockResponse {
  @NotNull private final String name;

  private final Integer amount;

  public PostStockResponse(String name, Integer amount) {
    this.name = name;
    this.amount = amount;
    ValidateHelper.validate(this);
  }
}

```

* api/ui/stocks/StocksResponse.java

```java:api/ui/stocks/StocksResponse.java
package com.aws.jp.web.test.api.ui.stocks;

import java.util.LinkedHashMap;
import javax.validation.constraints.NotNull;
import com.aws.jp.web.test.api.common.validation.ValidateHelper;
import com.aws.jp.web.test.api.domain.Stock;
import com.aws.jp.web.test.api.domain.query.StockQueryResult;
import lombok.Getter;

@Getter
public class StocksResponse {
  // レスポンスの仕様がmapであり、かつソート要件を満たすためLinkedHashMapを定義
  @NotNull private final LinkedHashMap<String, Integer> stockMap;
  
  public StocksResponse(StockQueryResult result) {
    final LinkedHashMap<String, Integer> stockMap = new LinkedHashMap<>();
    result.getStocks().stream().forEach(s -> stockMap.put(s.getName(), s.getAmount()));;
    this.stockMap = stockMap;
    ValidateHelper.validate(this);
  }

  public StocksResponse(Stock stock) {
    final LinkedHashMap<String, Integer> stockMap = new LinkedHashMap<>();
    stockMap.put(stock.getName(), stock.getAmount());
    this.stockMap = stockMap;
    ValidateHelper.validate(this);
  }
}

```

#### sales

* api/ui/sales/SalesResource.java

```java:api/ui/sales/SalesResource.java
package com.aws.jp.web.test.api.ui.sales;

import java.math.BigDecimal;
import java.net.URI;
import java.util.Objects;
import javax.inject.Inject;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.UriComponentsBuilder;
import com.aws.jp.web.test.api.application.SalesService;
import com.aws.jp.web.test.api.application.StocksService;
import com.aws.jp.web.test.api.common.log.Logging;
import com.aws.jp.web.test.api.domain.Sales;
import com.aws.jp.web.test.api.domain.Stock;
import com.aws.jp.web.test.api.ui.validation.BeanValidateHelper;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("sales")
@RequiredArgsConstructor
public class SalesResource {
  @Inject private final StocksService stockService;
  @Inject private final SalesService salesService;

  /** 販売 */
  @PostMapping(
      produces = { "application/json" })
  @Logging
  public ResponseEntity<PostSalesResponse> post(
      @RequestBody PostSalesRequestBody body,
      UriComponentsBuilder uriComponentsBuilder) {
    
    // リクエストボディの入力チェック
    BeanValidateHelper.validate(body);
    
    // 在庫情報を更新
    final Stock stock = stockService.buy(body.getStock());
    // リクエストボディから価格を取得
    final BigDecimal price = body.getPrice();
    // 価格がnullでない場合は売り上げを作成
    if (Objects.nonNull(price)) {
      // 今回の要件ではユーザーによる売上の管理はないので、仮に"aws"というユーザーによる要求として処理
      final String customerId = "aws";
      salesService.post(customerId, body.getStock().getAmount(), price);
    }

    // ロケーションを作成
    final URI location = uriComponentsBuilder
        .path("vi/stocks/{name}")
        .buildAndExpand(stock.getName())
        .toUri();
    final HttpHeaders headers = new HttpHeaders();
    headers.setLocation(location);

    return new ResponseEntity<PostSalesResponse>(new PostSalesResponse(body.getName(), body.getAmount(), price), headers, HttpStatus.OK);
  }

  /** 売上チェック */
  @GetMapping(
      produces = { "application/json" })
  @Logging
  public ResponseEntity<SalesResponse> getTotalSales() {

    // 今回の要件では"aws"ユーザーの売上のみ考慮するため、"aws"を指定
    final String customerId = "aws";
    // 売り上げをユーザーIDをキーにして取得
    final Sales response = salesService.getByName(customerId);

    return new ResponseEntity<SalesResponse>(new SalesResponse(response), HttpStatus.OK);
  }
}

```

* api/ui/sales/PostSalesRequestBody.java

```java:api/ui/sales/PostSalesRequestBody.java
package com.aws.jp.web.test.api.ui.sales;

import java.math.BigDecimal;
import java.util.Objects;
import javax.validation.constraints.Min;
import javax.validation.constraints.NotNull;
import javax.validation.constraints.Size;
import com.aws.jp.web.test.api.common.validation.Alpha;
import com.aws.jp.web.test.api.domain.Stock;
import com.aws.jp.web.test.api.ui.error.BadRequestParamsException;
import com.aws.jp.web.test.api.ui.validation.BeanValidationTarget;
import lombok.Data;

@Data
public class PostSalesRequestBody implements BeanValidationTarget {
  @NotNull
  @Size(max = 8, min = 1)
  @Alpha
  private String name;

  // 小数点が来たときに入力エラーとするためにDoubleで受け付ける
  @Min(1)
  private Double amount;

  // 小数の指定に対応するためBigDecimalを定義
  @Min(0)
  private BigDecimal price;

  public Stock getStock() {
    // amountの指定がない場合は1を初期値とする。
    if (Objects.isNull(amount)) {
      return new Stock(name, 1);
    }
    // 整数でない場合はエラーとする。
    if (!(amount % 1 == 0)) {
      throw new BadRequestParamsException("ERROR");
    }
    return new Stock(name, amount.intValue());
  }

  public Integer getAmount() {
    // amountが存在しない場合はnullを返す
    if (Objects.isNull(amount)) {
      return null;
    }
    // 整数でない場合はエラーとする。
    if ((Objects.nonNull(amount)) && !(amount % 1 == 0)) {
      throw new BadRequestParamsException("ERROR");
    }
    return amount.intValue();
  }
}

```

* api/ui/sales/PostSalesResponse.java

```java:api/ui/sales/PostSalesResponse.java
package com.aws.jp.web.test.api.ui.sales;

import java.math.BigDecimal;
import java.util.Objects;
import javax.validation.constraints.NotNull;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.aws.jp.web.test.api.common.validation.ValidateHelper;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@JsonInclude(JsonInclude.Include.NON_EMPTY)
public class PostSalesResponse {
  @NotNull private final String name;

  private final Integer amount;

  private BigDecimal price;

  public PostSalesResponse(String name, Integer amount, BigDecimal price) {
    this.name = name;
    this.amount = amount;
    // 整数の場合は整数として表示する
    if ((Objects.nonNull(price)) && (price.doubleValue() % 1 == 0)) {
      this.price = price.setScale(0);
    } else {
      this.price = price;
    }
    ValidateHelper.validate(this);
  }
}

```

* api/ui/sales/SalesResponse.java

```java:api/ui/sales/SalesResponse.java
package com.aws.jp.web.test.api.ui.sales;

import java.math.BigDecimal;
import java.math.RoundingMode;
import javax.validation.constraints.NotNull;
import com.aws.jp.web.test.api.common.validation.ValidateHelper;
import com.aws.jp.web.test.api.domain.Sales;
import lombok.Getter;

@Getter
public class SalesResponse {
  // 小数の指定に対応するためBigDecimalを定義
  @NotNull private final BigDecimal sales;

  public SalesResponse(Sales sales) {
    final BigDecimal priceBd = sales.getPrice();
    // 小数第三位を切り上げて第二位までを保持するように指定
    this.sales = priceBd.setScale(2, RoundingMode.CEILING);
    ValidateHelper.validate(this);
  }
}

```

#### error

* api/ui/error/BadRequestParamsException.java

```java:api/ui/error/BadRequestParamsException.java
package com.aws.jp.web.test.api.ui.error;

import lombok.Getter;

public class BadRequestParamsException extends RuntimeException {
  private static final long serialVersionUID = -2870980956809763545L;
  @Getter private final String message;

  public BadRequestParamsException(String message) {
    super();
    this.message = message;
  }
}

```

* api/ui/error/BadRequestParamsExceptionHandler.java

```java:api/ui/error/BadRequestParamsExceptionHandler.java
package com.aws.jp.web.test.api.ui.error;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;
import lombok.extern.slf4j.Slf4j;

@RestControllerAdvice
@Slf4j
public class BadRequestParamsExceptionHandler extends ResponseEntityExceptionHandler {
  
  @ExceptionHandler(BadRequestParamsException.class)
  public ResponseEntity<ErrorResponse> handleException(BadRequestParamsException e) {
    log.error("E400-001", e);
    return ErrorResponse.build("E400-001");
  }
}

```

* api/ui/error/ErrorResource.java

```java:api/ui/error/ErrorResource.java
package com.aws.jp.web.test.api.ui.error;

import javax.servlet.RequestDispatcher;
import javax.servlet.http.HttpServletRequest;
import org.springframework.boot.web.servlet.error.ErrorController;
import org.springframework.data.crossstore.ChangeSetPersister.NotFoundException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import lombok.extern.slf4j.Slf4j;

@RestController
@Slf4j
public class ErrorResource implements ErrorController {

  @ResponseStatus(HttpStatus.NOT_FOUND)
  @ExceptionHandler({ NotFoundException.class })
  public ResponseEntity<ErrorResponse> handle404() {
    log.error("404 Not Found");
    return ErrorResponse.build("E404-001");
  }
  
  @RequestMapping("/error")
  public ResponseEntity<ErrorResponse> handleError(HttpServletRequest request) {
    Object statusCode = request.getAttribute(RequestDispatcher.ERROR_STATUS_CODE);
    if (statusCode != null && statusCode.toString().equals("404")) {
      log.error("404 Not Found");
      return ErrorResponse.build("E404-001");
    }
    log.error("想定しないエラーが発生しました。");
    return ErrorResponse.build("E500-001");
  }

  @Override
  @Deprecated
  public String getErrorPath() {
    return null;
  }
}

```

* api/ui/error/ErrorResponse.java

```java:api/ui/error/ErrorResponse.java
package com.aws.jp.web.test.api.ui.error;

import javax.json.bind.annotation.JsonbProperty;
import com.aws.jp.web.test.api.common.config.Properties;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.Setter;
import lombok.ToString;

@EqualsAndHashCode
@AllArgsConstructor
@ToString
public final class ErrorResponse {

  @Setter
  @Getter
  @JsonbProperty("message")
  private String message;

  private ErrorResponse() {};

  @SuppressWarnings("PMD.ShortMethodName")
  public static ErrorResponse of(String message) {
    final ErrorResponse response = new ErrorResponse();
    response.setMessage(message);
    return response;
  }

  public static ResponseEntity<ErrorResponse> build(String code) {
    final int statusCode = Properties.API_ERRORCODE.getValueInt(code, 0);
    final String message = Properties.API_ERRORCODE.getValue(code, 1);
    return new ResponseEntity<ErrorResponse>(of(message), HttpStatus.valueOf(statusCode));
  }
}
```

#### validation

* api/ui/validation/BeanValidationHelper.java

```java:api/ui/validation/BeanValidationHelper.java
package com.aws.jp.web.test.api.ui.validation;

import java.util.HashSet;
import java.util.Objects;
import java.util.Set;
import com.aws.jp.web.test.api.ui.error.BadRequestParamsException;
import javax.validation.ConstraintViolation;
import javax.validation.Validation;
import javax.validation.Validator;
import javax.validation.ValidatorFactory;

public final class BeanValidateHelper {
  private static final ValidatorFactory factory = Validation.buildDefaultValidatorFactory();
  private static final Validator validator = factory.getValidator();

  private BeanValidateHelper() {}

  /** Validation Beanによる各項目の検証を行う */
  public static void validate(final BeanValidationTarget... targets) {
    final Set<ConstraintViolation<BeanValidationTarget>> violations = new HashSet<>();
    for (final BeanValidationTarget target : targets) {
      if (Objects.nonNull(target)) {
        // Bean Validationのvalidateを実行
        violations.addAll(validator.validate(target));
      }
    }
    // 問題がある場合はBadRequestParamsExceptionをthrow
    if (!violations.isEmpty()) {
      throw new BadRequestParamsException("ERROR");
    }
  }
}

```

* api/ui/validation/BeanValidationTarget.java

```java:api/ui/validation/BeanValidationTarget.java
package com.aws.jp.web.test.api.ui.validation;

public interface BeanValidationTarget {}

```

### アプリケーション層

* api/application/StocksService.java

```java:api/application/StocksService.java
package com.aws.jp.web.test.api.application;

import java.util.Objects;
import javax.inject.Inject;import com.aws.jp.web.test.api.domain.Stock;
import com.aws.jp.web.test.api.domain.StockRepository;
import com.aws.jp.web.test.api.domain.query.SortCondition;
import com.aws.jp.web.test.api.domain.query.StockQueryCondition;
import com.aws.jp.web.test.api.domain.query.StockQueryResult;
import com.aws.jp.web.test.api.ui.error.BadRequestParamsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.annotation.ApplicationScope;
import lombok.RequiredArgsConstructor;

@Service
@Transactional
@ApplicationScope
@RequiredArgsConstructor
public class StocksService {
  @Inject private final StockRepository repository;

  public Stock post(final Stock stock) {
    final Stock currentStock = repository.findByName(stock.getName()).orElse(null);
    // エンティティが存在しない場合は新規に作成する
    if (Objects.isNull(currentStock)) {
      return repository.create(stock);
    }
    // すでにエンティティが存在する場合は在庫を更新する
    final Stock updatedStock = currentStock.updateAmount(currentStock.getAmount() + stock.getAmount());
    return repository.update(updatedStock);
  }

  public Stock get(final String name) {
    // 在庫を名前をキーにして取得する
    // 在庫が存在しない場合は在庫数を0とした在庫オブジェクトを返す
    final Stock stock = repository.findByName(name).orElse(new Stock(name, 0));
    return stock;
  }

  public StockQueryResult query(StockQueryCondition condition, SortCondition sortCondition) {
    // 在庫情報のクエリを実行
    final StockQueryResult result = repository.query(condition, sortCondition);
    return result;
  }

  public Stock buy(final Stock stock) {
    // 在庫がない場合は販売不可能なのでエラーを返す
    final Stock currentStock = repository.findByName(stock.getName()).orElseThrow(() -> new BadRequestParamsException("ERROR"));
    // 在庫が販売数よりも少ない場合は販売不可能なのでエラーを返す
    if (currentStock.getAmount() < stock.getAmount()) {
      throw new BadRequestParamsException("ERROR");
    }
    // 在庫を更新する
    final Stock updatedStock = currentStock.updateAmount(currentStock.getAmount() - stock.getAmount());
    return repository.update(updatedStock);
  }

  public void deleteAll() {
    // 在庫情報を全削除する
    repository.deleteAll();
  }
}

```

* api/application/SalesService.java

```java:api/application/SalesService.java
package com.aws.jp.web.test.api.application;

import java.math.BigDecimal;
import java.util.Objects;
import javax.inject.Inject;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.annotation.ApplicationScope;
import com.aws.jp.web.test.api.domain.Sales;
import com.aws.jp.web.test.api.domain.SalesRepository;
import com.aws.jp.web.test.api.ui.error.BadRequestParamsException;
import lombok.RequiredArgsConstructor;

@Service
@Transactional
@ApplicationScope
@RequiredArgsConstructor
public class SalesService {
  @Inject private final SalesRepository repository;

  public Sales post(final String customerId, final Integer amount, final BigDecimal price) {
    // ユーザーIDをキーにして売り上げ情報を取得する。
    // 売り上げ情報が存在しない場合はnullを返す
    final Sales currentSales = repository.findByCustomerId(customerId).orElse(null);
    final BigDecimal totalPrice = price.multiply(new BigDecimal(amount));
    // エンティティが存在しない場合は新規に作成する
    if (Objects.isNull(currentSales)) {
      return repository.create(Sales.of(customerId, totalPrice));
    }
    // すでにエンティティが存在する場合は売上を更新する
    final Sales updatedStock = currentSales.updatePrice(totalPrice.add(currentSales.getPrice()));
    return repository.update(updatedStock);
  }

  public Sales getByName(final String customerId) {
    // 売り上げがない場合はエラーを返す
    final Sales sales = repository.findByCustomerId(customerId).orElseThrow(() -> new BadRequestParamsException("ERROR"));
    return sales;
  }

  public void deleteAll() {
    // 売り上げ情報を全削除する
    repository.deleteAll();
  }
}

```

### ドメイン層

* api/domain/Stock.java

```java:api/domain/Stock.java
package com.aws.jp.web.test.api.domain;

import javax.validation.constraints.Min;
import javax.validation.constraints.NotNull;
import javax.validation.constraints.Size;
import com.aws.jp.web.test.api.common.validation.Alpha;
import com.aws.jp.web.test.api.common.validation.ValidateHelper;
import lombok.Getter;

@Getter
public class Stock {
  // 商品名
  @NotNull
  @Size(max = 8)
  @Alpha
  private final String name;

  // 在庫
  @NotNull
  @Min(0)
  private final Integer amount;

  public Stock(String name, Integer amount) {
    this.name = name;
    this.amount = amount;
    ValidateHelper.validate(this);
  }

  /** 在庫を更新した新しいオブジェクを返却 */
  public Stock updateAmount(Integer amount) {
    return new Stock(this.name, amount);
  }
}

```

* api/domain/StockRepository.java

```java:api/domain/StockRepository.java
package com.aws.jp.web.test.api.domain;

import java.util.Optional;
import com.aws.jp.web.test.api.domain.query.SortCondition;
import com.aws.jp.web.test.api.domain.query.StockQueryCondition;
import com.aws.jp.web.test.api.domain.query.StockQueryResult;

public interface StockRepository {

  // 商品在庫をクエリ検索
  StockQueryResult query(StockQueryCondition condition, SortCondition pCondition);
  
  // 商品名をキーとして在庫を取得
  Optional<Stock> findByName(String name);

  // 在庫を作成
  Stock create(Stock stock);

  // 在庫を更新
  Stock update(Stock stock);

  // 全削除
  void deleteAll();
}

```

* api/domain/Sales.java

```java:api/domain/Sales.java
package com.aws.jp.web.test.api.domain;

import java.math.BigDecimal;
import javax.validation.constraints.Min;
import javax.validation.constraints.NotNull;
import javax.validation.constraints.Size;
import com.aws.jp.web.test.api.common.validation.ValidateHelper;
import lombok.Getter;

@Getter
public class Sales {
  // ユーザーID
  @NotNull
  @Size(max = 15)
  private final String customerId;

  // 売り上げ
  // 小数の指定に対応するためBigDecimalを定義
  @NotNull
  @Min(0)
  private final BigDecimal price;

  public Sales(String customerId, BigDecimal price) {
    this.customerId = customerId;
    this.price = price;
    ValidateHelper.validate(this);
  }

  public static Sales of(String customerId, BigDecimal price) {
    return new Sales(customerId, price);
  }

  /** 売り上げを更新した新しいオブジェクを返却 */
  public Sales updatePrice(BigDecimal price) {
    return new Sales(this.customerId, price);
  }
}

```

* api/domain/SalesRepository.java

```java:api/domain/SalesRepository.java
package com.aws.jp.web.test.api.domain;

import java.util.Optional;

public interface SalesRepository {
  // ユーザーIDをキーに売り上げを取得
  Optional<Sales> findByCustomerId(String customerId);

  // 売り上げを作成
  Sales create(Sales sales);

  // 売り上げを更新
  Sales update(Sales sales);

  // 全削除
  void deleteAll();
}

```

#### query

* api/domain/query/StockQueryCondition.java

```java:api/domain/query/StockQueryCondition.java
package com.aws.jp.web.test.api.domain.query;

import java.util.Optional;
import lombok.Builder;

@Builder
public class StockQueryCondition {
  // 価格の最小値
  private final Integer min;

  public Optional<Integer> getMin() {
    return Optional.ofNullable(min);
  }
}

```

* api/domain/query/SortCondition.java

```java:api/domain/query/SortCondition.java
package com.aws.jp.web.test.api.domain.query;

import lombok.Getter;

@Getter
public class SortCondition {
  // 昇順でソートするかどうか
  private final boolean isAscending;

  // ソートキー
  private final String sort;

  public SortCondition(boolean isAscending, String sort) {
    this.isAscending = isAscending;
    this.sort = sort;
  }
}

```

* api/domain/query/StockQueryResult.java

```java:api/domain/query/StockQueryResult.java
package com.aws.jp.web.test.api.domain.query;

import java.util.List;
import com.aws.jp.web.test.api.domain.Stock;
import lombok.Getter;

@Getter
public class StockQueryResult {
  private final List<Stock> stocks;

  public StockQueryResult(List<Stock> stocks) {
    this.stocks = stocks;
  }
}

```

### インフラストラクチャ層

* api/infrastructure/StockEntity.java

```java:api/infrastructure/StockEntity.java
package com.aws.jp.web.test.api.infrastructure;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.NamedQueries;
import javax.persistence.NamedQuery;
import javax.persistence.Table;
import javax.validation.constraints.NotNull;
import com.aws.jp.web.test.api.common.validation.ValidateHelper;
import com.aws.jp.web.test.api.domain.Stock;
import lombok.Data;
import lombok.NoArgsConstructor;

@NoArgsConstructor
@Entity
@Data
@Table(name = "Stocks")
@NamedQueries({
  @NamedQuery(name = "deleteAllStocks", query = "DELETE FROM StockEntity s")
})
public class StockEntity {
  // 商品名
  @Id
  @Column(name = "NAME")
  private String name;

  // 在庫
  @Column(name = "AMOUNT")
  @NotNull
  private int amount;

  private StockEntity(String name, int amount) {
    this.name = name;
    this.amount = amount;
    ValidateHelper.validate(this);
  }

  public static StockEntity of(Stock stock) {
    return new StockEntity(stock.getName(), stock.getAmount());
  }

  public Stock convert() {
    return new Stock(name, amount);
  }
}

```

* api/infrastructure/StockRepositoryImpl.java

```java:api/infrastructure/StockRepositoryImpl.java
package com.aws.jp.web.test.api.infrastructure;

import java.util.Objects;
import java.util.Optional;
import javax.persistence.EntityManager;
import javax.persistence.PersistenceContext;
import com.aws.jp.web.test.api.domain.Stock;
import com.aws.jp.web.test.api.domain.StockRepository;
import com.aws.jp.web.test.api.domain.query.SortCondition;
import com.aws.jp.web.test.api.domain.query.StockQueryCondition;
import com.aws.jp.web.test.api.domain.query.StockQueryResult;
import org.springframework.stereotype.Repository;
import org.springframework.web.context.annotation.ApplicationScope;
import lombok.RequiredArgsConstructor;

@Repository
@ApplicationScope
@RequiredArgsConstructor
public class StockRepositoryImpl implements StockRepository {
  @PersistenceContext private EntityManager manager;

  @Override
  public StockQueryResult query(
      StockQueryCondition condition, SortCondition pCondition) {
    final StockQueryAgent agent =
        new StockQueryAgent(manager, condition, pCondition);
    return new StockQueryResult(agent.getStocks());
  }
  
  @Override
  public Optional<Stock> findByName(String id) {
    final StockEntity stockEntity =
        manager.find(StockEntity.class, id);
    return Objects.nonNull(stockEntity) ? Optional.of(stockEntity.convert()) : Optional.empty();
  }

  @Override
  public Stock create(Stock stock) {
    final StockEntity entity = StockEntity.of(stock);
    manager.persist(entity);
    return entity.convert();
  }

  @Override
  public Stock update(Stock stock) {
    final StockEntity entity = StockEntity.of(stock);
    manager.merge(entity);
    return entity.convert();
  }

  @Override
  public void deleteAll() {
    manager.createNamedQuery("deleteAllStocks").executeUpdate();
  }
}

```

* api/infrastructure/StockQueryAgent.java

```java:api/infrastructure/StockQueryAgent.java
package com.aws.jp.web.test.api.infrastructure;

import java.util.List;
import java.util.stream.Collectors;
import javax.persistence.EntityManager;
import javax.persistence.criteria.CriteriaBuilder;
import javax.persistence.criteria.CriteriaQuery;
import javax.persistence.criteria.Predicate;
import javax.persistence.criteria.Root;
import com.aws.jp.web.test.api.domain.Stock;
import com.aws.jp.web.test.api.domain.query.SortCondition;
import com.aws.jp.web.test.api.domain.query.StockQueryCondition;

public class StockQueryAgent {
  
  private final EntityManager manager;
  private final StockQueryCondition condition;
  private final SortCondition sortCondition;

  public StockQueryAgent(
      EntityManager manager,
      StockQueryCondition condition,
      SortCondition sortCondition) {
    this.manager = manager;
    this.condition = condition;
    this.sortCondition = sortCondition;
  }

  protected List<Stock> getStocks() {
    final CriteriaBuilder cb = manager.getCriteriaBuilder();
    final CriteriaQuery<StockEntity> cq = cb.createQuery(StockEntity.class);
    final Root<StockEntity> stocks = cq.from(StockEntity.class);
    
    // クエリのwhere句とorder句を作成
    cq.where(where(cb, stocks))
      .orderBy(sortCondition.isAscending()
          ? cb.asc(stocks.get(sortCondition.getSort()).as(String.class))
          : cb.desc(stocks.get(sortCondition.getSort()).as(String.class)));

    return manager
        .createQuery(cq)
        .getResultList()
        .stream()
        .map(s -> s.convert())
        .collect(Collectors.toList());
  }

  private Predicate where(CriteriaBuilder cb, Root<StockEntity> stocks) {
    final Integer min = condition.getMin().orElse(0);
    final Predicate predicate = cb.ge(stocks.get("amount"), min);
    return predicate;
  }
}

```

* api/infrastructure/SalesEntity.java

```java:api/infrastructure/SalesEntity.java
package com.aws.jp.web.test.api.infrastructure;

import java.math.BigDecimal;
import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.NamedQueries;
import javax.persistence.NamedQuery;
import javax.persistence.Table;
import javax.validation.constraints.NotNull;
import com.aws.jp.web.test.api.common.validation.ValidateHelper;
import com.aws.jp.web.test.api.domain.Sales;
import lombok.Data;
import lombok.NoArgsConstructor;

@NoArgsConstructor
@Entity
@Data
@Table(name = "Sales")
@NamedQueries({
    @NamedQuery(name = "deleteAllSales", query = "DELETE FROM SalesEntity s")
})
public class SalesEntity {
  // ユーザーID
  @Id
  @Column(name = "CUSTOMER_ID")
  private String customerId;

  // 売り上げ
  @Column(name = "PRICE")
  @NotNull
  private BigDecimal price;

  private SalesEntity(String customerId, BigDecimal price) {
    this.customerId = customerId;
    this.price = price;
    ValidateHelper.validate(this);
  }

  public static SalesEntity of(Sales sales) {
    return new SalesEntity(sales.getCustomerId(), sales.getPrice());
  }

  public Sales convert() {
    return new Sales(customerId, price);
  }
}

```

* api/infrastructure/SalesRepositoryImpl.java

```java:api/infrastructure/SalesRepositoryImpl.java
package com.aws.jp.web.test.api.infrastructure;

import java.util.Objects;
import java.util.Optional;
import javax.persistence.EntityManager;
import javax.persistence.PersistenceContext;
import org.springframework.stereotype.Repository;
import org.springframework.web.context.annotation.ApplicationScope;
import com.aws.jp.web.test.api.domain.Sales;
import com.aws.jp.web.test.api.domain.SalesRepository;
import lombok.RequiredArgsConstructor;

@Repository
@ApplicationScope
@RequiredArgsConstructor
public class SalesRepositoryImpl implements SalesRepository {
  @PersistenceContext private EntityManager manager;

  @Override
  public Optional<Sales> findByCustomerId(String customerId) {
    final SalesEntity entity = manager.find(SalesEntity.class, customerId);
    return Objects.nonNull(entity) ? Optional.of(entity.convert()) : Optional.empty();
  }

  @Override
  public Sales create(Sales sales) {
    final SalesEntity entity = SalesEntity.of(sales);
    manager.persist(entity);
    return entity.convert();
  }

  @Override
  public Sales update(Sales sales) {
    final SalesEntity entity = SalesEntity.of(sales);
    manager.merge(entity);
    return entity.convert();
  }

  @Override
  public void deleteAll() {
    manager.createNamedQuery("deleteAllSales").executeUpdate();
  }
}

```

### AJP設定

* api/config/TomcatConfiguration.java

```java:api/config/TomcatConfiguration.java
package com.aws.jp.web.test.api.config;

import org.apache.catalina.connector.Connector;
import org.apache.coyote.ajp.AjpNio2Protocol;
import org.springframework.boot.web.embedded.tomcat.TomcatServletWebServerFactory;
import org.springframework.boot.web.server.WebServerFactoryCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
 
@Configuration
public class TomcatConfiguration {

  @Bean
  public WebServerFactoryCustomizer<TomcatServletWebServerFactory> servletContainer() {
    final Connector connector = new Connector("org.apache.coyote.ajp.AjpNio2Protocol");
    connector.setScheme("http");
    connector.setPort(8009);
    connector.setRedirectPort(8443);
    connector.setSecure(false);
    connector.setAllowTrace(false);
    final AjpNio2Protocol protocol = (AjpNio2Protocol) connector.getProtocolHandler();
    protocol.setSecretRequired(false);  // secretを使わない
    return factory -> factory.addAdditionalTomcatConnectors(connector);
  }
}
```
