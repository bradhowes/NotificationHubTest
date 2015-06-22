'use strict';

var apn = require('apn');
var querystring = require('querystring');
var config = require('./config');
var timestamp = require('./timestamp');

module.exports = Registrar;

function Registration(deviceToken, emitInterval, resendUntilFetched, useSandbox) {
    this.log = config.log('Registration');
    if (typeof deviceToken === 'object') {
        this.log.info('from entity');
        var entity = deviceToken;
        this.uuid = entity.uuid._;
        this.deviceToken = entity.deviceToken._;
        this.emitInterval = entity.emitInterval._;
        this.resendUntilFetched = entity.resendUntilFetched._;
        try {
            this.useSandbox = entity.useSandbox._;
        }
        catch (e) {
            this.useSandbox = 1;
        }
    }
    else {
        this.log.info('from values');
        var now = Date.now();
        this.uuid = '' + Date.now();
        this.deviceToken = deviceToken;
        this.emitInterval = emitInterval;
        this.resendUntilFetched = resendUntilFetched;
        this.log.info('useSandbox:', useSandbox);
        this.useSandbox = useSandbox;
    }
};

Registration.prototype = {

    toEntity: function() {
        var entity = {};
        entity.uuid = {'_':this.uuid,'$':'Edm.String'};
        entity.deviceToken = {'_':this.deviceToken,'$':'Edm.String'};
        entity.emitInterval = {'_':this.emitInterval,'$':'Edm.Int32'};
        entity.resendUntilFetched = {'_':this.resendUntilFetched,'$':'Edm.Int32'};
        entity.useSandbox = {'_':this.useSandbox,'$':'Edm.Int32'};
        return entity;
    }
};

function Registrar(tableStore, queue, callback) {
    this.log = config.log('Registrar');
    this.tableStore = tableStore;
    this.queue = queue;

    this.apnProdConnection = new apn.Connection({
        "cert": config.apns_prod_client_certificate_file,
        "key": config.apns_prod_client_private_key_file,
        "passphrase": config.apns_prod_passphrase.length ? config.apns_prod_passphrase : null,
        "gateway": config.apns_prod_service_host,
        "port": config.apns_prod_service_port
    });

    this.apnDevConnection = new apn.Connection({
        "cert": config.apns_dev_client_certificate_file,
        "key": config.apns_dev_client_private_key_file,
        "passphrase": config.apns_dev_passphrase.length ? config.apns_dev_passphrase : null,
        "gateway": config.apns_dev_service_host,
        "port": config.apns_dev_service_port
    });

    var log = config.log('APN');
    var addLog = function(tag, c) {
        var clog = log.child(tag);
        c.on('connected', function() {clog.warn('connected');});
        c.on('transmitted', function() {clog.warn('sent notification');});
        c.on('timeout', function() {clog.warn('connection timeout');});
        c.on('disconnected', function() {clog.warn('disconnected');});
        c.on('transmissionError', function(err, notification, device) {
            clog.error('Error: ' + err + ' for device ', device, notification);
            if (err === 8) {
                clog.error('invalid device token');
            }
        });
        c.on('socketError', console.error);
    };

    addLog('prod', this.apnProdConnection);
    addLog('dev', this.apnDevConnection);

    if (callback) callback(null);
};

Registrar.prototype = {

    makeQueueKey: function(reg, identifier) {
        return reg.uuid + '@' + querystring.escape(reg.deviceToken) + '@' + identifier;
    },

    add: function(deviceToken, emitInterval, resendUntilFetch, useSandbox, callback) {
        var self = this;
        var log = this.log.child('add');
        var reg = null;
        log.BEGIN(emitInterval, resendUntilFetch, useSandbox);

        reg = new Registration(deviceToken, emitInterval, resendUntilFetch, useSandbox);
        self.tableStore.set(deviceToken, reg.toEntity(), function(error, entity) {
            if (! error) {
                self.enqueueAndEmitNotification(reg, 0, callback);
            }
            else {
                callback(error, null);
            }
        });
    },

    enqueueAndEmitNotification: function(reg, identifier, callback) {
        var log = this.log.child('enqueueAndEmitNotification');
        var self = this;
        log.info(reg);
        log.info(identifier);
        this.queue.add(this.makeQueueKey(reg, identifier), reg.emitInterval, function(error, result) {
            if (! error) {
                self.emit(reg.deviceToken, reg.useSandbox, identifier);
            }
            callback(error, result);
            log.END(error);
        });
    },

    del: function(deviceToken, callback) {
        var log = this.log.child('delete');
        log.BEGIN();
        this.tableStore.del(deviceToken, function(error) {
            if (error) {
                log.warn('no registration for device token - ', deviceToken);
            }
            log.END(error);
            callback(error);
        });
    },

    emit: function(deviceToken, useSandbox, identifier) {
        var log = this.log.child('emit');
        var alert = 'ID ' + identifier;
        var payload = {'aps':{'alert':alert, 'content-available':1}, 'id':identifier, 'when':0};
        var notification;
        log.BEGIN('payload:', payload);
        notification = new apn.Notification();
        notification.device = new apn.Device(new Buffer(deviceToken, 'base64'));
        payload.when = timestamp();
        notification.payload = payload;
        if (useSandbox) {
            log.debug('sending sandbox notification');
            this.apnDevConnection.sendNotification(notification);
        }
        else {
            log.debug('sending production notification');
            this.apnProdConnection.sendNotification(notification);
        }
        log.END();
    },

    checkForEmission: function(callback) {
        var self = this;
        var log = this.log.child('checkForEmission');
        this.queue.get(function(error, msg) {
            var bits, uuid, deviceToken, identifier;
            if (error) {
                log.END(error);
                callback(error, null);
                return;
            }

            if (! msg) {
                callback(null, null);
                return;
            }

            log.info('msg:', msg);

            bits = msg.split('@');
            uuid = bits[0];
            deviceToken = querystring.unescape(bits[1]);
            identifier = parseInt(bits[2], 10);

            log.info('deviceToken:', deviceToken);
            self.tableStore.get(deviceToken, function(error, entity) {
                var reg;

                log.info(uuid, entity);
                if (error || ! entity || entity.uuid._ != uuid) {
                    log.info('no longer registered');
                    callback(null, null);
                    return;
                }

                reg = new Registration(entity);

                self.enqueueAndEmitNotification(reg, identifier + 1, function(error, result) {
                    if (error) log.error(error);
                    callback(error, msg);
                });
            });
        });
    }
};
