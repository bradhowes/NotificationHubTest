"use strict";

var config = require('../config');
var assert = require("assert");
var vows = require("vows");

var Queue = require("../queue");
var queue = null;
var suite = vows.describe('queue');

suite.addBatch({
    'create a queue': {
        topic: function () {
            queue = new Queue('queuetest', this.callback);
        },
        'succeeds without error': function (err, created, response) {
            assert.equal(err, null);
        }
    }
});

suite.addBatch({
    'create again for kicks': {
        topic: function () {
            queue = new Queue('queuetest', this.callback);
        },
        'succeeds without error': function (err, created, response) {
            assert.equal(err, null);
        }
    }
});

suite.addBatch({
    'clear queue': {
        topic: function () {
            queue.clear(this.callback);
        },
        'succeeds without error': function (err, created, response) {
            assert.equal(err, null);
        }
    }
});

suite.addBatch({
    'add entry': {
        topic: function () {
            queue.add('1234567890', 0, this.callback);
        },
        'succeeds without error': function (err, entity) {
            assert.isNull(err);
        },
        'and returns an object': function (err, entity) {
            assert.isObject(entity);
        }
    }
});

suite.addBatch({
    'get': {
        topic: function () {
            queue.get(this.callback);
        },
        'succeeds without error': function (err, found) {
            assert.isNull(err);
        },
        'valid message': function (err, found) {
            assert.equal(found, '1234567890');
        },
        'another get returns null': {
            topic: function () {
                queue.get(this.callback);
            },
            'succeeds without error': function (err, found) {
                assert.isNull(err);
            },
            'but message is null': function (err, found) {
                assert.isNull(found);
            }
        }
    }
});

suite.addBatch({
    'add with large timeout hides entry from query': {
        topic: function () {
            queue.add('1234567890', 1, this.callback);
        },
        'succeeds without error': function (err, found) {
            assert.isNull(err);
        },
        'but get returns null': {
            topic: function () {
                queue.get(this.callback);
            },
            'succeeds without error': function (err, found) {
                assert.isNull(err);
            },
            'and message is null': function (err, found) {
                assert.isNull(found);
            },
            'until enough time has passed': {
                topic: function () {
                    var self = this;
                    var cb = function() {
                        queue.get(self.callback);
                    };
                    setTimeout(cb, 1 * 1000);
                },
                'succeeds without error': function (err, found) {
                    assert.isNull(err);
                },
                'and message is not null': function (err, found) {
                    assert.isNotNull(found);
                }
            }
        }
    }
});

suite.export(module);
