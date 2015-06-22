'use strict';

/**
 * @fileOverview Defines the TableStore prototype and its methods.
 */
module.exports = TableStore;

var escape = require('querystring').escape;
var azure = require('azure');
var config = require('./config');

/**
 * TableStore constructor.
 *
 * @class TableStore
 */
function TableStore(tableName, callback) {
    var self = this;
    var log = this.log = config.log('TableStore');
    var retry = new azure.LinearRetryPolicyFilter();

    log.BEGIN(tableName);

    self.tableName = tableName;
    self.store = azure.createTableService().withFilter(retry);
    self.store.createTableIfNotExists(tableName, function(error, result, response) {callback(error);});
}

/**
 * TableStore prototype.
 *
 * Defines the methods available to a TableStore instance.
 */
TableStore.prototype = {

    set: function(key, entity, callback) {
        var self = this;
        var log = self.log.child('set');
        key = escape(key);
        log.BEGIN(key, entity);
        entity.PartitionKey = this.makePartitionKey(key);
        entity.RowKey = this.makeRowKey(key);
        self.store.insertOrReplaceEntity(self.tableName, entity, function (error, result, response) {
            log.info('insertOrReplaceEntity:', error);
            callback(error, entity);
            log.END();
	});
    },

    get: function(key, callback) {
        var self = this;
        var log = self.log.child('get');
        key = escape(key);
        log.BEGIN(key);
        this.store.retrieveEntity(this.tableName, key, key, function(error, result, response) {
            callback(error, result);
            log.END();
        });
    },

    del: function(key, callback) {
        var log = this.log.child('del');
        var entity = {};
        key = escape(key);
        log.BEGIN('key:', key);
        entity.PartitionKey = this.makePartitionKey(key);
        entity.RowKey = this.makeRowKey(key);
        this.store.deleteEntity(this.tableName, entity, function (err) {
            log.info('deleteEntity:', err);
            callback(err);
            log.END();
        });
    },

    makePartitionKey: function (value) {
        return {'_' :value,'$':'Edm.String'}; // new Buffer(value).toString('base64');
    },

    makeRowKey: function (value) {
        return {'_':value,'$':'Edm.String'}; // new Buffer(value).toString('base64');
    }
};
