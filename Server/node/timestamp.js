'use strict';

module.exports = timestamp;

function timestamp() {
    return new Date().getTime() / 1000.0;
}
