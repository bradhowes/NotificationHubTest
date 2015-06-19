'use strict';

/**
 * Collection of values to encrypt. The attribute names will be used to satisfy substitutions in the contents of the
 * config_template.js file.
 *
 * *NOTE*: do not commit to source code control with the raw, unencrypted values
 *
 * To use, rename this file as raw_config.js and add the proper unencrypted values for all of the attributes listed
 * below. When done, run the command
 *
 * `node gen_config.js PASSWORD`
 *
 * where PASSWORD is the password to use when encrypting the private values below. This will generate the file
 * `config.js` with the encrypted values.
 */

module.exports = {
    /* Passphrase to use to decrypt the cert used for APNs connectivity */
    apns_passphrase: 'REPLACE ME',
    /* The access key for the Azure storage account being used */
    azure_storage_access_key: 'REPLACE ME',
    /* The access key for the Azure ServiceBus being used */
    azure_servicebus_access_key: 'REPLACE ME'
};
