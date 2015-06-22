"use strict";

var config = require('../config');
var assert = require("assert");
var vows = require("vows");

var TableStore = require("../tableStore");
var store = null;

var suite = vows.describe('tableStore');
var entity1 = {uuid:{_:'1434835002961','$':'Edm.String'},
               deviceToken:{_:'rg3JI5M24AisWd0gUjPh//MincgSv3glnI1t1eYl8tg=','$': 'Edm.String'},
               emitInterval:{_:15,'$':'Edm.Int32'},
               resendUntilFetched:{_:1,'$':'Edm.Int32'},
               useSandbox:{_:0,'$':'Edm.Int32'}};
var entity2 = {uuid:{_:'123123123','$':'Edm.String'},
               deviceToken:{_:'rg3JI5M24AisWd0gUjPh//MincgSv3glnI1t1eYl8tg=','$': 'Edm.String'},
               emitInterval:{_:30,'$':'Edm.Int32'},
               resendUntilFetched:{_:0,'$':'Edm.Int32'},
               useSandbox:{_:1,'$':'Edm.Int32'}};

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
            store.set('foo', entity1, this.callback);
        },
        'succeeds without error': function (err, entity) {
            assert.isNull(err);
        },
        'and returns the registration entity': function (err, entity) {
            assert.isObject(entity);
        },
        'and has same values': function (err, entity) {
            assert.equal(entity.uuid._, entity1.uuid._);
        },
        'add again with different values': {
            topic: function () {
                store.set('foo', entity2, this.callback);
            },
            'succeeds without error': function (err, entity) {
                assert.isNull(err);
            },
            'and returns the registration entity': function (err, entity) {
                assert.isObject(entity);
            },
            'and has new values': function (err, entity) {
                assert.equal(entity.uuid._, entity2.uuid._);
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
            assert.equal(found.uuid._, entity2.uuid._);
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
