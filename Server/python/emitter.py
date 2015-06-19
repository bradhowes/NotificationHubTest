import Logger
gLog = Logger.gLog
import array, base64, itertools, binascii
from datetime import datetime
import os
import socket
import ssl
import struct
import time
import traceback

gLog.setLevel(gLog.kDebug)

def unixTime():
    when = datetime.utcnow()
    delta = when - datetime.utcfromtimestamp(0)
    return delta.total_seconds()

def tohex(s):
    return ":".join("{:02x}".format(ord(c)) for c in s)

class APNs(object):

    kServiceHost = 'gateway.sandbox.push.apple.com'
    # kServiceHost = 'gateway.push.apple.com'
    kServicePort = 2195

    kRootCertificateFile = 'EntrustRootCertificationAuthority.pem'
    kClientKeyFile = 'apn-nhtest-dev-key.pem'
    kClientCertFile = 'apn-nhtest-dev-cert.pem'

    kPayloadTemplate = '{{"aps":{{"alert":"Id {0}","content-available":1}},"id":{0},"when":"{1}"}}'

    # payload = '{"aps":{"alert":"Id %d","content-available":1},"id":%d,"when":"%d"}' % (seqId, seqId, unixTime())
    # payload = '{"aps":{"alert":"Id %d"},"id":%d,"when":"%d"}' % (seqId, seqId, unixTime())

    def __init__(self):
        gLog.begin()
        self.__service = None
        self.__identifier = 1
        gLog.end()

    def generatePayload(self, seqId):
        return self.kPayloadTemplate.format(seqId, unixTime())

    def connect_to_service(self):
        gLog.begin()

        #
        # Create underlying TCP socket to use for notification transport to Apple
        #
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM, 0)

        #
        # Turn off any Nagel algorithm buffering. Use TCP keepalive packets.
        #
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
        pwd = os.getcwd()
        self.__service = ssl.wrap_socket(sock, 
                                         keyfile = os.path.join(pwd, self.kClientKeyFile ),
                                         certfile = os.path.join(pwd, self.kClientCertFile),
                                         ssl_version = ssl.PROTOCOL_TLSv1)
        try:
            self.__service.connect((self.kServiceHost, self.kServicePort))
            gLog.info('connected to', self.kServiceHost, self.kServicePort)
        except:
            traceback.print_exc()
            gLog.error('failed to connect to', self.kServiceHost, self.kServicePort)
            self.__service = None
        gLog.end()

    def post(self, deviceToken, seqId, retries = 0):
        gLog.begin(len(deviceToken))
        if len(deviceToken) != 32:
            gLog.error('invalid device token')
            gLog.end()
            return

        if self.__service == None:
            self.connect_to_service()

        payload = self.generatePayload(seqId)

        size = len(payload)
        gLog.info('size:', size)
        gLog.debug('payload:', payload)

        expiry = socket.htonl(int(time.time()) + 120)

        frameItem = struct.pack('!BH', 1, 32) + deviceToken
        print 1, tohex(frameItem)
        frame = frameItem

        frameItem = struct.pack('!BH', 2, len(payload)) + payload
        print 2, tohex(frameItem)
        frame += frameItem

        frameItem = struct.pack('!BHI', 3, 4, self.__identifier)
        print 3, tohex(frameItem)
        frame += frameItem
        
        frameItem = struct.pack('!BHI', 4, 4, expiry)
        print 4, tohex(frameItem)
        #frame += frameItem

        priority = 5
        frameItem = struct.pack('!BHB', 5, 1, priority)
        print 5, tohex(frameItem)
        frame += frameItem

        msg = struct.pack('!BI', 2, len(frame)) + frame
        #print tohex(msg)

        self.__identifier += 1

        try:
            self.__service.write(msg)
            gLog.info('sent')
            msg = None
        except:
            traceback.print_exc()
            self.__service = None
            if retries == 0:
                self.post(deviceToken, seqId, retries + 1)

        if msg != None:
            gLog.error('failed to send', payload)
            
        gLog.end()
