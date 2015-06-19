'use strict';

var apn = require('apn');
var config = require('./config');
var timestamp = require('./timestamp');

module.exports = Registrar;

function Registration(deviceToken, emitInterval, resendUntilFetched) {
    this.log = config.log('Registration');
    if (typeof deviceToken === 'object') {
        var entity = deviceToken;
        this.uuid = entity.uuid._;
        this.deviceToken = entity.deviceToken._;
        this.emitInterval = entity.emitInterval._;
        this.resendUntilFetched = entity.resendUntilFetched._;
    }
    else {
        var now = Date.now();
        this.uuid = '' + Date.now();
        this.deviceToken = deviceToken;
        this.emitInterval = emitInterval;
        this.resendUntilFetched = resendUntilFetched;
    }
};

Registration.prototype = {

    toEntity: function() {
        var entity = {};
        entity.uuid = {'_':this.uuid,'$':'Edm.String'};
        entity.deviceToken = {'_':this.deviceToken,'$':'Edm.String'};
        entity.emitInterval = {'_':this.emitInterval,'$':'Edm.Int32'};
        entity.resendUntilFetched = {'_':this.resendUntilFetched,'$':'Edm.Int32'};
        return entity;
    }
};

function Registrar(tableStore, queue, callback) {
    this.log = config.log('Registrar');
    this.tableStore = tableStore;
    this.queue = queue;

    this.apnConnection = new apn.Connection({
        "cert": config.apns_client_certificate_file,
        "key": config.apns_client_private_key_file,
        "passphrase": config.apns_passphrase.length ? config.apns_passphrase : null,
        "gateway": config.apns_service_host,
        "port": config.apns_service_port
    });

    var log = config.log('APN');
    this.apnConnection.on('connected', function() {
        log.warn('connected');
    });
    
    this.apnConnection.on('transmitted', function() {
        log.warn('sent notification');
    });

    this.apnConnection.on('timeout', function() {
        log.warn('connection timeout');
    });

    this.apnConnection.on('disconnected', function() {
        log.warn('disconnected');
    });

    this.apnConnection.on('transmissionError', function(err, notification, device) {
        log.error('Error: ' + err + ' for device ', device, notification);
        if (err === 8) {
            log.error('invalid device token');
        }
    });

    this.apnConnection.on('socketError', console.error);

    if (callback) callback(null);
};

Registrar.prototype = {

    makeQueueKey: function(reg, identifier) {
        return reg.uuid + '@' + reg.deviceToken + '@' + identifier;
    },
    
    add: function(deviceToken, emitInterval, resendUntilFetch, callback) {
        var self = this;
        var log = this.log.child('add');
        var reg = null;
        log.BEGIN(emitInterval, resendUntilFetch);

        reg = new Registration(deviceToken, emitInterval, resendUntilFetch);
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
        this.queue.add(this.makeQueueKey(reg, identifier), reg.emitInterval, function(error, result) {
            if (! error) {
                self.emit(reg.deviceToken, identifier);
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

    emit: function(deviceToken, identifier) {
        var log = this.log.child('emit');
        var alert = 'ID ' + identifier;
        var payload = {'aps':{'alert':alert, 'content-available':1}, 'id':identifier, 'when':0};
        var notification;
        log.BEGIN('payload:', payload);
        notification = new apn.Notification();
        notification.device = new apn.Device(new Buffer(deviceToken, 'base64'));
        payload.when = timestamp();
        notification.payload = payload;
        this.apnConnection.sendNotification(notification);
        log.END();
    },

    checkForEmission: function(callback) {
        var self = this;
        var log = this.log.child('checkForEmission');
        var proc = function(error, msg) {
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

            log.info(msg);
            bits = msg.split('@');
            uuid = bits[0];
            deviceToken = bits[1];
            identifier = parseInt(bits[2], 10);

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
        };

        this.queue.get(proc);
    }
};
