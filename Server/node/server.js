'use strict';

// NOTE: be sure to add CONFIG_PASSWORD key to the "app settings" section of the CONFIGURE tab of the Azure Portal. The
// value must be the same one that was used to encrypt the private/config.js file.
//
// process.env.CONFIG_PASSWORD = 'PASSWORD';

var config = require('./config');
var App = require('./app');

process.on('uncaughtException', function (err) {
  console.error((new Date).toUTCString() + ' uncaughtException:', err.message);
  console.error(err.stack);
  process.exit(1);
});

var log = config.log('server');
var app = new App();
var port = process.env.PORT || 4465;

app.initialize(function(errors, service) {
    if (errors !== null) {
        log.error('failed to start due to errors during initialization: ', errors);
    }
    else {

        // Uff -- ping Azure storage queue for any notifications to fire
        //
        setInterval(function() {app.registrar.checkForEmission(function(err, msg) {});}, 1 * 1000);

        log.info('starting server on port', port);
        service.listen(port);
    }
});
