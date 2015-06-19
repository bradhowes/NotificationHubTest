import os, Logger, base64, emitter, json, time, threading
from datetime import datetime
from flask import Flask, jsonify, request

gLog = Logger.gLog
gLog.setLevel(gLog.kDebug)

app = Flask(__name__)
app.registrations = {}
app.emitter = emitter.APNs()

def unixTime():
    when = datetime.utcnow()
    delta = when - datetime.utcfromtimestamp(0)
    return delta.total_seconds()

def emitNotification(registration):
    app.emitter.post(registration.deviceToken, registration.sequenceId)
    registration.sequenceId += 1
    registration.timer = threading.Timer(registration.interval, emitNotification, [registration])
    registration.timer.daemon = True
    registration.timer.start()

class Registration(object):

    def __init__(self, deviceToken, interval):
        self.deviceToken = base64.b64decode(deviceToken)
        self.sequenceId = 0
        self.interval = interval
        self.timer = threading.Timer(1.0, emitNotification, [self])
        self.timer.daemon = True
        self.timer.start()

@app.route('/')
def hello():
    gLog.info('hello')
    return 'Hello world!'

@app.route('/register', methods = ['POST'])
def register():
    startTime = unixTime()
    gLog.info('register')
    data = request.json

    deviceToken = data['deviceToken']
    interval = data['interval']
    gLog.info('interval:', interval)
    if interval < 1: interval = 1;

    registration = app.registrations.get(deviceToken)
    if registration:
        registration.timer.cancel()
        registration.timer.join()
        del app.registrations[deviceToken]
    registration = Registration(deviceToken, interval)

    app.registrations[deviceToken] = registration

    return ('', 200, {'X-StartTime': startTime, 'X-EndTime': unixTime()})

@app.route('/fetch/<deviceToken>/<sequenceId>', methods = ['GET'])
def fetch(deviceToken, sequenceId):
    startTime = unixTime()
    gLog.info('fetch', sequenceId)
    return (json.dumps({'msg':'ID {0}'.format(sequenceId)}), 200, {'X-StartTime': startTime, 'X-EndTime': unixTime()})

@app.route('/update/<deviceToken>', methods = ['GET'])
def update(deviceToken):
    startTime = unixTime()
    return (json.dumps([{'msg':'ID 1'},{'msg':'ID 2'}]), 200, {'X-StartTime': startTime, 'X-EndTime': unixTime()})

@app.route('/unregister', methods = ['POST'])
def unregister():
    startTime = unixTime()
    gLog.info()
    data = request.json
    deviceToken = data['deviceToken']
    registration = app.registrations.get(deviceToken)
    if registration:
        registration.timer.cancel()
        registration.timer.join()
        del app.registrations[deviceToken]
    return ('', 200, {'X-StartTime': startTime, 'X-EndTime': unixTime()})

if __name__ == '__main__':
    app.run(host=os.getenv('IP', '0.0.0.0'), port=int(os.getenv('PORT', 8080)))
