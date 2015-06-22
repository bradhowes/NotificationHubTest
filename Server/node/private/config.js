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
    apns_dev_passphrase: D('8CyUsb8m0T8E+2iUgKAw6A=='),
    apns_prod_passphrase: D('8CyUsb8m0T8E+2iUgKAw6A=='),
    azure_storage_access_key: D('8EGOTSsgFoxTDEVRQAq6xJhXgRFJPQuzP5SLlOSATgL4ZCuv64mITantG+Z28lSZuzZ7VSU8ZslPf9HviZ4r1L3JQ5XMVPnrCLi8NaLOBs5c107qU0297HV/QRRDIctI'),
    azure_servicebus_access_key: D('kgk2NtN+GhTXh1oZ7wUyyH5CSkxhZ1jupAzleJUSvMhARTdtE+Ugx0HL4hSU+ilZ')
};
