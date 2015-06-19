'use strict';

// NOTE: be sure to add CONFIG_PASSWORD key to the "app settings" section of the CONFIGURE tab of the Azure Portal. The
// value must be the same one that was used to encrypt the private/config.js file.
//
// process.env.CONFIG_PASSWORD = 'PASSWORD';

var express = require('express');
var bodyParser = require('body-parser');
var config = require('./config');
var timestamp = require('./timestamp');

var Registrar = require('./registrar');
var TableStore = require('./tableStore');
var Queue = require('./queue');

var app = express();
var jsonParser = bodyParser.json();
var port = process.env.PORT || 4465;
var log = config.log('main');

app.set('view engine', 'jade');

app.post('/register', jsonParser, function(req, res) {
    var startTime = timestamp();
    var log = config.log('/register');
    var deviceToken, emitInterval, resendUntilFetched;

    if (! req.body) {
        log.error('invalid body');
        return res.sendStatus(400).end();
    }

    deviceToken = req.body.deviceToken;
    if (! deviceToken) {
        log.error('no deviceToken');
        return res.sendStatus(400).end();
    }

    emitInterval = req.body.interval;
    if (! emitInterval) {
        log.error('no emitInterval');
        return res.sendStatus(400).end();
    }

    resendUntilFetched = req.body.retryUntilFetched ? 1 : 0;

    app.registrar.add(deviceToken, emitInterval, resendUntilFetched, function(err, result) {
        var endTime = timestamp();
        log.info(err);
        res.set('X-StartTime', startTime);
        res.set('X-EndTime', endTime);
        res.status(200).json({startTime:startTime,endTime:endTime});
    });
});

app.post('/unregister', jsonParser, function(req, res) {
    var startTime = timestamp();
    var log = config.log('/unregister');
    var deviceToken;

    if (! req.body) {
        log.error('invalid body');
        return res.sendStatus(400).end();
    }

    deviceToken = req.body.deviceToken;
    if (! deviceToken) {
        log.error('no deviceToken');
        return res.sendStatus(400).end();
    }

    app.registrar.del(deviceToken, function(err, result) {
        var endTime = timestamp();
        log.info(err);
        res.set('X-StartTime', startTime);
        res.set('X-EndTime', endTime);
        res.status(200).json({startTime:startTime,endTime:endTime});
    });
});

app.get('/fetch/:deviceToken/:identifier', function(req, res) {
    var startTime = timestamp();
    var endTime;
    var log = config.log('/fetch');
    var deviceToken = req.params.deviceToken;
    var identifier = req.params.identifier;
    var registration;

    if (typeof deviceToken === 'undefined' || deviceToken == null) {
        log.error('no deviceToken');
        return res.sendStatus(400).end();
    }

    if (typeof identifier === 'undefined' || identifier == null) {
        log.error('no identifier');
        return res.sendStatus(400).end();
    }

    identifier = parseInt(identifier);
    log.info('identifier:', identifier);

    endTime = timestamp();
    res.set('X-StartTime', startTime);
    res.set('X-EndTime', endTime);
    res.status(200).json({startTime:startTime,endTime:endTime,msg:'this is a test'});
});

process.on('uncaughtException', function (err) {
  console.error((new Date).toUTCString() + ' uncaughtException:', err.message);
  console.error(err.stack);
  process.exit(1);
});

function initialize(callback) {
    var errors = null;
    var awaiting = 2;
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
            app.registrar = new Registrar(tableStore, queue);
            callback(errors);
            clog.END();
            return;
        }

        clog.END('awaiting:', awaiting);
    };

    log.BEGIN();

    tableStore = new TableStore('brhemitter', function(err) {
        continuation('registrationStore', err);
    });

    queue = new Queue('brhemitter', function(err) {
        continuation('queue', err);
    });
}

initialize(function(errors) {
    if (errors !== null) {
        log.error('failed to start due to errors during initialization: ', errors);
    }
    else {

        // Uff -- ping Azure storage queue for any notifications to fire
        //
        setInterval(function() {app.registrar.checkForEmission(function(err, msg) {});}, 1 * 1000);

        log.info('server started on port', port);
        app.listen(port);
    }
});
