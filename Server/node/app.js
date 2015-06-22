'use strict';

// NOTE: be sure to add CONFIG_PASSWORD key to the "app settings" section of the CONFIGURE tab of the Azure Portal. The
// value must be the same one that was used to encrypt the private/config.js file.
//
// process.env.CONFIG_PASSWORD = 'PASSWORD';

/**
 * @fileOverview Main application. Provides three kinds of services: a registrar, a template manager, and a notifier.
 */
module.exports = App;

var express = require('express');
var bodyParser = require('body-parser');

var config = require('./config');
var timestamp = require('./timestamp');
var Registrar = require('./registrar');
var TableStore = require('./tableStore');
var Queue = require('./queue');

function App() {
    this.log = config.log('App');
}

App.prototype = {

    initialize: function(callback) {
        var log = this.log.child('initialize');
        var self = this;
        var errors = null;
        var awaiting = 2;
        var service = express();
        var port = process.env.PORT || 4465;
        var tableStore, queue, registrar;

        var continuation = function(key, err) {
            var clog = log.child('continuation');
            --awaiting;
            if (err != null) {
                clog.error(key, 'error:', err);
                if (errors === null) {
                    errors = {};
                }
                errors[key] = err;
            }

            if (awaiting === 0) {
                var jsonParser = bodyParser.json();
                self.registrar = new Registrar(tableStore, queue);

                service.post('/register', jsonParser, self.registerRequest.bind(self));
                service.post('/unregister', jsonParser, self.unregisterRequest.bind(self));
                service.get('/fetch/:deviceToken/:identifier', self.fetchRequest.bind(self));

                callback(errors, service);
                clog.END();
                return;
            }

            clog.END('awaiting:', awaiting);
        };

        log.BEGIN();
        service.set('view engine', 'jade');

        tableStore = new TableStore('brhemitter', function(err) {
            continuation('tableStore', err);
        });

        queue = new Queue('brhemitter', function(err) {
            continuation('queue', err);
        });
        
        log.END();
    },

    registerRequest: function(req, res) {
        var startTime = timestamp();
        var log = this.log.child('register');
        var deviceToken, emitInterval, resendUntilFetched, useSandbox;

        if (! req.body) {
            log.error('invalid body');
            res.sendStatus(400).end();
        }

        deviceToken = req.body.deviceToken;
        if (! deviceToken) {
            log.error('no deviceToken');
            res.sendStatus(400).end();
        }

        emitInterval = req.body.interval;
        if (! emitInterval) {
            log.error('no emitInterval');
            res.sendStatus(400).end();
        }

        resendUntilFetched = req.body.retryUntilFetched ? 1 : 0;
        useSandbox = req.body.useSandbox ? 1 : 0;

        this.registrar.add(deviceToken, emitInterval, resendUntilFetched, useSandbox, function(err, result) {
            var endTime = timestamp();
            log.info(err);
            res.set('X-StartTime', startTime);
            res.set('X-EndTime', endTime);
            res.status(200).json({startTime:startTime,endTime:endTime});
        });
    },

    unregisterRequest: function(req, res) {
        var startTime = timestamp();
        var log = this.log.child('unregister');
        var deviceToken;

        if (! req.body) {
            log.error('invalid body');
            res.sendStatus(400).end();
        }

        deviceToken = req.body.deviceToken;
        if (! deviceToken) {
            log.error('no deviceToken');
            res.sendStatus(400).end();
        }

        this.registrar.del(deviceToken, function(err, result) {
            var endTime = timestamp();
            log.info(err);
            res.set('X-StartTime', startTime);
            res.set('X-EndTime', endTime);
            res.status(200).json({startTime:startTime,endTime:endTime});
        });
    },

    fetchRequest: function(req, res) {
        var startTime = timestamp();
        var log = this.log.child('fetch');
        var endTime;
        var deviceToken = req.params.deviceToken;
        var identifier = req.params.identifier;
        var registration;

        if (typeof deviceToken === 'undefined' || deviceToken == null) {
            log.error('no deviceToken');
            res.sendStatus(400).end();
        }

        if (typeof identifier === 'undefined' || identifier == null) {
            log.error('no identifier');
            res.sendStatus(400).end();
        }

        identifier = parseInt(identifier);
        log.info('identifier:', identifier);

        endTime = timestamp();
        res.set('X-StartTime', startTime);
        res.set('X-EndTime', endTime);
        res.status(200).json({startTime:startTime,endTime:endTime,msg:'this is a test'});
    }
};
