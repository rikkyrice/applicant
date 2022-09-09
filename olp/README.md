# 質問例

## 質問

### 自己紹介

橋木陸と申します。
2020年に同志社大学の理工学部情報システムデザイン学科を卒業した後、日本IBM株式会社のCloud Application Devepment部署にITスペシャリストとして入社しました。
大学では遺伝的アルゴリズムを用いたスタッフスケジューリングの最適化を題材に研究を行いました。
入社後は、銀行様の渉外業務を効率化させるタブレットアプリケーションの開発にバックエンドチームとして参画しました。
1年目はJavaを用いたAPI開発やGo言語を用いたProxyサーバーの構築、バッチアプリケーションの開発を主に行っておりました。
2年目からはチームメンバーのコードレビューやAPI設計、他社開発チームとの結合テストなども任されるようになり、チームの中でも幅広い役割を担いました。
現在は3年目で、一部機能の要件調整と設計、開発をリードしています。
プロジェクト外ではIBMの新入社員向けクラウド研修の講師を担当しております。
本日は貴重なお時間をいただきまして、誠にありがとうございます。
よろしくお願いいたします。

### なぜ前職を辞めるのか

元々なぜIBMを志望したか？

前職では業界業種を問わないお客様に対してクラウド技術を浸透させて変革を与えられる経験ができることに魅力を感じており、これからの地球を支えていくクラウド技術に関わり、世界の変革に大きく貢献したいと思っていたので入社を決めました。
しかし、幅広いお客様がいる中で、キャリアアップするためには一つの業界に絞った知識が必要となっており、横断的に学ぶことはやや難しいのが現状であった。

### なぜAWSに入社したいのか

AWSではCustomer Supportという仕事柄、一つの業界に絞って関わることなく、幅広い業界にリーチし、経験を積むことができる。
また、まさしくクラウド技術を生み出したような革新性と先見的な知識を持つ企業であり、私もその中の一人として世界に変革を起こしていきたいと同時に、新人研修やアプリケーション開発で培った専門性を活かして御社及びお客様に貢献していきたい。

また、学生時代にSeattleに留学した時に感じた、先進的な風土と、そこに住む人々の知識の豊富さに魅了され、ここで同じように成長したいと思ったことも相まって、AWSのSeattleへの異動に大変興味がある。

### あなたは、今までお客様の利益を最大化させるような経験をしたことがありますか？

私が参画していたプロジェクトは、元々分散管理されていた顧客データを統合的に管理し、更なるビジネス機会の創出につなげるためのプラットフォームが目的でした。
私がちょうどIBMに入社して2年目が終わり3年目になる頃、そのプラットフォームの一機能の開発リードを任されました。
私が担当することになった機能は、顧客の資産負債情報に関わるデータの取得、追加、更新、削除を行うAPIの開発でした。
お客様が管理する資産負債情報はデータの種類が多く、かつそれぞれのデータ構造が大きく異なっているため、当初はそれぞれのデータ構造ごとにAPIの開発を行うように工数が組まれていました。
しかし、リリースまで3スプリントほどしかなく、他のタスクにかかる工数に影響を与えており、リリースターゲットが見直されつつありました。

私はリリースターゲットの削減に伴って縮小されてしまうお客様の利益に対して何とか対策を打とうと、データ構造の見直しを始めました。

まずはお客様と会話し、要件の確認を行いました。
その中で、資産負債情報はデータ構造は異なっているが、データの扱われ方に関しては共通している部分があるということを理解しました。
それは、画面上最も頻繁に確認されるのは、共通して金額であるということです。
その他の情報は、あくまで捕捉的な情報であり、金額が最も重要で価値のあるデータでした。
そこで、データの中でどのデータ構造にも共通している金額情報を抜き出して共通テーブルとして定義し、各資産負債テーブルにはその他個別の情報を格納して、共通テーブルの外部キー参照を持たせました。
API設計では、共通テーブルを表す親エンティティに、その他個別の情報を格納した子エンティティを紐づかせることで、資産負債情報のエンティティとしてはあくまで親エンティティとして共通化させ、同一のAPIで取得、追加、更新、削除処理を行うことに成功しました。

結果的には、開発するAPIの数が当初の想定よりも88%削減されました。
そのため工数が大きく減り、その他のより多くの開発に時間を割くことが可能になったため、リリースターゲットも縮小する必要がなくなり、お客様から感謝の言葉をいただくことができました。

### あなたは、今まで主体的にプロジェクトを行なったことがありますか？

新人研修

### あなたは、自分自身を向上させるために努力していることはありますか？

その能力がないのに希望を言いたくないから、努力する。

### 苦労したエピソード

開発チームに入って初めての業務がGo言語でのProxyサーバーの構築だった。

### 厳しい評価を食らった経験

イノベーション活動が欠けていた

### 一番大きな成果を上げた経験

新人研修

### その中で意見の衝突を対処した経験

最初は評価が低く、初心者向きじゃなかった

### 期待以上の成果を上げた経験

新人研修

### 物事の原因を深掘りした経験

Itestの大幅な性能改善

### データが少ない状態で決断した経験

性能？

### 困っている人を助けた経験

新人研修

## 逆質問

### 平均的な1週間の業務を大まかに教えてください

### 休日の対応がどれくらいの頻度で発生するか教えてください

### 4年以内に昇給するためにどれくらいの業務外活動が必要なのか教えてください

### 海外異動を視野に入れています。どれくらいの頻度で異動があるのでしょうか？そのフローはどういったものなのでしょうか？

### 学習環境について教えてください。例えばAWSを試せる環境がどれくらい整っているのか

### 個人の裁量が評価されるのはどういった場面でしょうか？お客様へのヘルプ以外にどういったことが挙げられますでしょうか？

### やりがいについて教えてください。例えば現職ではプロアクティブに活動し開発した機能が評価された時にやりがいを感じますが、CSEではどういった時にやりがいを感じますか？