"use strict";

var config = require('../config');
var TableStore = require('../tableStore');
var Queue = require('../queue');
var Registrar = require('../registrar');

var assert = require("assert");
var vows = require("vows");

var queue;
var tableStore;
var registrar;
var suite = vows.describe('registrar');
var tmp;

suite.addBatch({
    'create a queue': {
        topic: function () {
            queue = new Queue('queuetest', this.callback);
        },
        'succeeds without error': function (err, created, response) {
            assert.isNull(err);
        },
        'and empty': {
            topic: function () {
                queue.clear(this.callback);
            },
            'succeeds without error': function (err, created, response) {
                assert.isNull(err);
            }
        }
    }
});

suite.addBatch({
    'create an empty table': {
        topic: function () {
            tableStore = new TableStore('tableStoreTest', this.callback);
        },
        'succeeds without error': function (err, created, response) {
            assert.isNull(err);
        }
    }
});

suite.addBatch({
    'create registrar': {
        topic: function () {
            registrar = new Registrar(tableStore, queue, this.callback);
            registrar.apnProdConnection.sendNotification = function(notification) {};
        },
        'succeeds without error': function (err, created, response) {
            assert.isNull(err);
        }
    }
});

suite.addBatch({
    'create entry': {
        topic: function () {
            registrar.add('123', 0, false, false, this.callback);
        },
        'succeeds without error': function (err, created, response) {
            assert.isNull(err);
        }
    }
});

suite.addBatch({
    'check for emission': {
        topic: function () {
            registrar.checkForEmission(this.callback);
        },
        'succeeds without error': function (err, msg, response) {
            assert.isNull(err);
        },
        'found msg': function (err, msg, response) {
            assert.isNotNull(msg);
        },
        'identifier == 0': function (err, msg, response) {
            var bits = msg.split('@');
            assert.equal(bits[1], '123');
            assert.equal(bits[2], '0');
        },
        'check for a new emission with incremented identifier': {
            topic: function () {
                registrar.checkForEmission(this.callback);
            },
            'succeeds without error': function (err, msg, response) {
                assert.isNull(err);
            },
            'nothing found': function (err, msg, response) {
                assert.isNotNull(msg);
            },
            'identifier == 1': function (err, msg, response) {
                var bits = msg.split('@');
                assert.equal(bits[1], '123');
                assert.equal(bits[2], '1');
            }
        }
    }
});

suite.addBatch({
    'delete registration': {
        topic: function () {
            registrar.del('123', this.callback);
        },
        'succeeds without error': function (err, created, response) {
            assert.isNull(err);
        },
        'and queue is left empty': {
            topic: function () {
                queue.clear(this.callback);
            },
            'succeeds without error': function (err, created, response) {
                assert.isNull(err);
            }
        }
    }
});

suite.export(module);
