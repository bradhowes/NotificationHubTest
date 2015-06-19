"use strict";

var assert = require("assert");
var vows = require("vows");
var config = require("../config");

var suite = vows.describe('config');

suite.addBatch({
    'We can see APNs passphrase values': {
        topic: config.apns_passphrase,
        'apns_passphrase is defined': function (topic) {
            assert.isString(topic);
        }
    }
});

suite.addBatch({
    'We can see Azure storage access key': {
        topic: config.azure_storage_access_key,
        'azure_storage_access_key is defined': function (topic) {
            assert.isString(topic);
        },
        'azure_storage_access_key is not empty': function (topic) {
            assert.notEqual(topic.length, 0);
        }
    }
});

suite.export(module);
