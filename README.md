# XXX-Photos

```
 ██╗  ██╗██╗  ██╗██╗  ██╗    ██████╗ ██╗  ██╗ ██████╗ ████████╗ ██████╗ ███████╗
 ╚██╗██╔╝╚██╗██╔╝╚██╗██╔╝    ██╔══██╗██║  ██║██╔═══██╗╚══██╔══╝██╔═══██╗██╔════╝
  ╚███╔╝  ╚███╔╝  ╚███╔╝     ██████╔╝███████║██║   ██║   ██║   ██║   ██║███████╗
  ██╔██╗  ██╔██╗  ██╔██╗     ██╔═══╝ ██╔══██║██║   ██║   ██║   ██║   ██║╚════██║
 ██╔╝ ██╗██╔╝ ██╗██╔╝ ██╗    ██║     ██║  ██║╚██████╔╝   ██║   ╚██████╔╝███████║
 ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝    ╚═╝     ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ╚══════╝
```

アルバムアプリ  

よくわからん理由での垢BAN、あと単に高い(￥)とか、、やだな～から作成  

コスト＆パフォーマンスを追いつつ気ままに遊んだり

---

## コマンド（開発用）

```bash
docker compose build
```

```bash
docker compose run --rm app bundle install
```

```bash
docker compose run --rm app rails db:create
```

```bash
docker compose run --rm app rails db:migrate
```

```bash
docker compose run --rm app rails db:migrate:reset
```

```bash
docker compose up
```

```bash
docker exec -it app rails c
```

## テスト用
```bash
docker compose run --rm app rails db:migrate RAILS_ENV=test
```

```bash
docker compose run --rm app bundle exec rspec spec/requests/illustrations_spec.rb

docker compose run --rm app bundle exec rspec spec/requests/illustrations_spec.rb --format html --out rspec_results.html
```



---

## ドキュメント

### ER図

![ER図](docs/public/database-schema.svg)


