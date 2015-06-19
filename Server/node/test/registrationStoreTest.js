"use strict";

var config = require('../config');

var assert = require("assert");
var vows = require("vows");

var RegistrationStore = require("../registrationStore");
var store = null;

var suite = vows.describe('registrationStore');
suite.addBatch({
    'create an empty table': {
        topic: function () {
            store = new RegistrationStore('registrationstest', this.callback);
        },
        'succeeds without error': function (err, created, response) {
            assert.equal(err, null);
        }
    }
});

suite.addBatch({
    'add registration': {
        topic: function () {
            store.set({userId:'br.howes', deviceId:'mydevice', templateVersion:'1.0', templateLanguage:'en-us',
                       routes:[{service:'wns', 'name':'*', 'token':'123', 'secondsToLive':86400}]},
                      this.callback);
        },
        'succeeds without error': function (err, entity) {
            assert.isNull(err);
        },
        'and returns the registration entity': function (err, entity) {
            assert.isObject(entity);
        }
    }
});

suite.addBatch({
    'fetch registrations': {
        topic: function () {
            store.get('br.howes', null, this.callback);
        },
        'succeeds without error': function (err, found) {
            assert.isNull(err);
        },
        'found 1 match': function (err, found) {
            assert.equal(found.length, 1);
        },
        'match contains myregistration': function (err, found) {
            var registration = found[0];
            assert.equal(registration.templateVersion, '1.0');
            assert.equal(registration.templateLanguage, 'en-us');
            var route = registration.routes[0];
            assert.equal(route.service, 'wns');
            assert.equal(route.name, '*');
            assert.equal(route.token, '123');
        }
    }
});

suite.addBatch({
    'delete registration': {
        topic: function () {
            store.del('br.howes', 'mydevice', this.callback);
        },
        'succeeds without error': function (err, found) {
            console.log('err:', err);
            assert.isNull(err);
        }
    }
});

suite.addBatch({
    'then fetch non-existant registration': {
        topic: function () {
            store.get('br.howes', null, this.callback);
        },
        'succeeds without error': function (err, found) {
            assert.isNull(err);
        },
        'found 0 matches': function (err, found) {
            assert.equal(found.length, 0);
        }
    }
});

suite.export(module);
