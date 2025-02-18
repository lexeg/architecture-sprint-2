#!/bin/bash

###
# Подключаемся к серверу конфигурации, чтобы проинициализировать
###
docker compose exec -T configSrv mongosh --port 27017 <<EOF
rs.initiate(
{
  _id : "config_server",
     configsvr: true,
  members: [
    { _id : 0, host : "configSrv:27017" }
  ]
}
);
exit();
EOF

###
# Инициализируем шарды
###
docker compose exec -T shard1-1-n1 mongosh --port 27018 <<EOF
rs.initiate(
  {
    _id : "shard1-1",
    members: [
      { _id : 0, host : "shard1-1-n1:27018" },
      { _id : 1, host : "shard1-1-n2:27028" },
      { _id : 2, host : "shard1-1-n3:27038" }
    ]
  }
);
exit();
EOF

docker compose exec -T shard1-2-n1 mongosh --port 27019 <<EOF
rs.initiate(
  {
    _id : "shard1-2",
    members: [
      { _id : 0, host : "shard1-2-n1:27019" },
      { _id : 1, host : "shard1-2-n2:27029" },
      { _id : 2, host : "shard1-2-n3:27039" }
    ]
  }
);
exit();
EOF

###
# Инцициализация роутера
###
docker compose exec -T mongo_router mongosh --port 27020 <<EOF
sh.addShard( "shard1-1/shard1-1-n1:27018");
sh.addShard( "shard1-2/shard1-2-n1:27019");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
exit();
EOF

###
# Инициализируем бд
###
docker compose exec -T mongo_router mongosh --port 27020 <<EOF
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
exit();
EOF

###
# Выводим общее количество документов В БД somedb
###
docker compose exec -T mongo_router mongosh --port 27020 <<EOF
use somedb
db.helloDoc.countDocuments()
exit();
EOF

###
# Выводим количество документов В БД somedb инстанса shard1-1
###
docker compose exec -T shard1-1-n1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
exit();
EOF

###
# Выводим количество документов В БД somedb инстанса shard1-2
###
docker compose exec -T shard1-2-n1 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
exit();
EOF

###
# Выводим количество реплик инстанса shard1-1
###
docker compose exec -T shard1-1-n1 mongosh --port 27018 --quiet <<EOF
rs.status();
exit();
EOF

###
# Выводим количество реплик инстанса shard1-2
###
docker compose exec -T shard1-2-n1 mongosh --port 27019 --quiet <<EOF
rs.status();
exit();
EOF

###
# Получаем информацию о Redis
###
docker compose exec -T redis_1 bash <<EOF
redis-cli cluster nodes;
EOF