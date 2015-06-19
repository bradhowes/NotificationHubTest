"use strict";

/**
 * @fileOverview Defines the configuration parameters for the service.
 */
module.exports = undefined;

var fs = require('fs');
// Load in sensitive parameters
var priv = require('./private/config');
var LoggerUtils = require('./loggerUtils');

/**
 * Configuration module.
 *
 * @class config
 *
 * Configuration parameters for the notifier service.
 */
function Config () {

    var log4js = require('log4js');

    /**
     * Logging configuration for the server.
     */
    log4js.configure(
        {
            // Define the log appenders to use. These apply to all loggers.
            "appenders": [
                {
                    "type": "file",
                    "filename": "notifier.log",
                    "layout": { "type": "basic" }
                },
                {
                    "type": "console",
                    "layout": { "type": "basic" }
                }
            ]
        }
    );

    /**
     * Shortcut to log4js.getLogger procedure. Allows other modules to do ```config.log('moduleName')```
     * @type {Function}
     */
    this.log = log4js.getLogger;

    /**
     * The FQDN of the host to use to deliver APNs notifcation payloads.
     * @type {String}
     */
    this.apns_service_host = 'gateway.sandbox.push.apple.com'; // or 'gateway.push.apple.com'

    /**
     * The port of the host to connect to for APNs notifications.
     * @type {Number}
     */
    this.apns_service_port = 2195;

    /**
     * The file holding the root certificate used to authenticate the remote server.
     * @type {String}
     */
    this.apns_root_certificate_file = 'private/EntrustRootCertificationAuthority.pem';

    /**
     * The file holding the private key certificate used to authenticate to the remote server.
     * @type {String}
     */
    this.apns_client_private_key_file = 'private/apn-nhtest-dev-key.pem';

    /**
     * The file holding the credentials used to authenticate to the remote server for application notifications.
     * @type {String}
     */
    this.apns_client_certificate_file = 'private/apn-nhtest-dev-cert.pem';

    /**
     * The passphrase to decrypt to APNs key file.
     * @type {String}
     */
    this.apns_passphrase = priv.apns_passphrase;

    /**
     * The Azure storage account access key to use.
     * @type {String}
     */
    this.azure_storage_account = 'brhemitter';
    this.azure_storage_access_key = priv.azure_storage_access_key;

    /**
     * The Azure ServiceBus account access key to use.
     * @type {String}
     */
    this.azure_servicebus_namespace = 'brhemitter';
    this.azure_servicebus_access_key = priv.azure_servicebus_access_key;

    // Make sure our environment reflects these Azure settings.
    process.env.AZURE_STORAGE_ACCOUNT = this.azure_storage_account;
    process.env.AZURE_STORAGE_ACCESS_KEY = this.azure_storage_access_key;

    process.env.AZURE_SERVICEBUS_NAMESPACE = this.azure_servicebus_namespace;
    process.env.AZURE_SERVICEBUS_ACCESS_KEY = this.azure_servicebus_access_key;
}

module.exports = new Config();
