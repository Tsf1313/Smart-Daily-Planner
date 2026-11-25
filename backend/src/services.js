const { MysqlStore } = require("./store/mysql");

function createStore() {
  return new MysqlStore();
}

module.exports = { createStore };
