"use strict";

var config = require('../config');
var assert = require("assert");
var vows = require("vows");

var TableStore = require("../tableStore");
var store = null;

var suite = vows.describe('tableStore');
suite.addBatch({
    'create an empty table': {
        topic: function () {
            store = new TableStore('tableStoreTest', this.callback);
        },
        'succeeds without error': function (err, created, response) {
            assert.equal(err, null);
        }
    }
});

suite.addBatch({
    'create an empty table again': {
        topic: function () {
            store = new TableStore('tableStoreTest', this.callback);
        },
        'succeeds without error': function (err, created, response) {
            assert.equal(err, null);
        }
    }
});

suite.addBatch({
    'add entry': {
        topic: function () {
            store.set('foo', {a:{'_':'123'}}, this.callback);
        },
        'succeeds without error': function (err, entity) {
            assert.isNull(err);
        },
        'and returns the registration entity': function (err, entity) {
            assert.isObject(entity);
        },
        'and has same values': function (err, entity) {
            assert.equal(entity.a._, '123');
        },
        'add again with different values': {
            topic: function () {
                store.set('foo', {a:{'_':'456'}}, this.callback);
            },
            'succeeds without error': function (err, entity) {
                assert.isNull(err);
            },
            'and returns the registration entity': function (err, entity) {
                assert.isObject(entity);
            },
            'and has new values': function (err, entity) {
                assert.equal(entity.a._, '456');
            }
        }
    }
});

suite.addBatch({
    'get registration': {
        topic: function () {
            store.get('foo', this.callback);
        },
        'succeeds without error': function (err, found) {
            assert.isNull(err);
        },
        'match contains data from last insert': function (err, found) {
            assert.equal(found.a._, '456');
        }
    }
});

suite.addBatch({
    'delete registration': {
        topic: function () {
            store.del('foo', this.callback);
        },
        'succeeds without error': function (err, found) {
            assert.isNull(err);
        },
        'delete registration again': {
            topic: function () {
                store.del('foo', this.callback);
            },
            'fails with error': function (err, found) {
                assert.isNotNull(err);
            }
        }
    }
});

suite.addBatch({
    'fetch deleted entry': {
        topic: function () {
            store.get('foo', this.callback);
        },
        'fails with error': function (err, found) {
            assert.isNotNull(err);
        }
    }
});

suite.export(module);
