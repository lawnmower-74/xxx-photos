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


## コマンド

```bash
docker compose run --rm app rails new . --force -d mysql --skip-bundle
```

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