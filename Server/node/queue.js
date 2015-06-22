'use strict';

/**
 * @fileOverview Defines the Queue prototype and its methods.
 */
module.exports = Queue;

var azure = require('azure');
var config = require('./config');

function Queue(queueName, callback) {
    var self = this;
    var log = this.log = config.log('Queue');
    var retry = new azure.LinearRetryPolicyFilter();
    log.BEGIN(queueName);
    this.queueName = queueName;
    this.qsvc = azure.createQueueService().withFilter(retry);
    this.qsvc.createQueueIfNotExists(queueName, function(err, result, response) {callback(err);});
};

Queue.prototype = {

    add: function(msg, timeoutInSeconds, callback) {
        var self = this;
        var log = this.log.child('add');
        var visibilityTimeout = timeoutInSeconds;
        var messagettl = (visibilityTimeout ? visibilityTimeout : 1) * 10;
        var options = {messagettl: 60 * 60, visibilityTimeout:timeoutInSeconds};
        log.BEGIN(msg, timeoutInSeconds);
        this.qsvc.createMessage(this.queueName, msg, options, function(err, result, response) { 
            log.info('createMessage:', err);
            callback(err, result);
            log.END();
        });
    },

    get: function(callback) {
        var self = this;
        var log = self.log.child('get');
        this.qsvc.getMessages(this.queueName, {visibilityTimeout:5, numOfMessages:1}, function(err, result, response) {
            if (err) {
                callback(err, null);
                log.END(err);
                return;
            }
            else if (result.length == 0) {
                callback(null, null);
            }
            else {
                var msg = result[0];
                log.info('msg:', msg);
                self.qsvc.deleteMessage(self.queueName, msg.messageid, msg.popreceipt, function(err, response) {
                    callback(err, msg.messagetext);
                });
            }
        });
    },

    clear: function(callback) {
        var self = this;
        this.qsvc.clearMessages(this.queueName, function(err, result) {
            callback(err, result);
        });
    }
};
