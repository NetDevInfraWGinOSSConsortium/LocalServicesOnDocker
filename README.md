# LocalServicesOnDocker
このフォルダのコンテンツを実行するには、

当該リポジトリをクローンした後、
```
git clone https://github.com/daisukenishino2/EvaluateAspNetCoreOnDocker.git
```

このフォルダに移動し、
```
>cd ...\EvaluateAspNetCoreOnDocker\LocalServices
```

以下のコマンドでコンテナを起動する。
```
>docker-compose up -d
```

以下のコマンドでコンテナが停止する。
```
>docker-compose down
```

テストを行う場合は、

以下のtestフォルダに移動し、
```
>cd ...\LocalServices\test\nodejs
```

以下のbatファイルを実行する。
```
>install.bat
>start.bat
```

.NETの接続文字列に関しては、以下の通り。

- RDB
  - "ConnectionString_SQL": "Data Source=localhost;Initial Catalog=Northwind;User ID=sa;Password=seigi@123;",
  - "ConnectionString_MCN": "Server=localhost;Database=test;User Id=root;Password=seigi@123",
  - "ConnectionString_NPS": "HOST=localhost;DATABASE=postgres;USER ID=postgres;PASSWORD=seigi@123;"
- NoSQL
  - redis : localhost
  - mongodb : mongodb://seigi:seigi%40123@localhost:27017
