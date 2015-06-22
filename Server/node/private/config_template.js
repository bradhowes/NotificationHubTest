'use strict';

var crypto = require('crypto');

var D = function(value) {
    var password = process.env.CONFIG_PASSWORD;
    var cipher = crypto.createDecipher('aes256', password);
    if (typeof password == 'undefined' || password.length == 0) {
        throw new Error('No password found in CONFIG_PASSWORD environment variable');
    }
    return Buffer.concat([cipher.update(new Buffer(value, 'base64')), cipher.final()]).toString('utf8');
};

module.exports = {
    apns_dev_passphrase: D('@@apns_dev_passphrase@@'),
    apns_prod_passphrase: D('@@apns_prod_passphrase@@'),
    azure_storage_access_key: D('@@azure_storage_access_key@@'),
    azure_servicebus_access_key: D('@@azure_servicebus_access_key@@')
};
