# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...


# 実行コマンド

docker compose run --rm app rails new . --force -d mysql --skip-bundle

docker compose build

docker compose run --rm app rails db:create


docker compose run --rm app rails g scaffold Illustration illustrator_name:string shot_at:datetime

docker compose run --rm app rails active_storage:install

docker compose run --rm app rails db:migrate

docker compose up

docker compose run --rm app bundle install

docker compose run --rm app rails db:migrate:reset

docker compose run --rm app rails db:drop db:create

docker compose run --rm app rails g model Illustrator name:string:uniq