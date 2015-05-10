import Logger
gLog = Logger.gLog
import array, base64, itertools
import calendar, datetime
import os
import socket
import ssl
import struct
import time
import traceback

gLog.setLevel(gLog.kDebug)

class APNs(object):

    kServiceHost = 'gateway.sandbox.push.apple.com'
    kServicePort = 2195

    kRootCertificateFile = 'EntrustRootCertificationAuthority.pem'
    kClientKeyFile = 'apn-nhtest-dev-key.pem'
    kClientCertFile = 'apn-nhtest-dev-cert.pem'

    kPayloadTemplate = '{"aps":{"content-available":1},"id":%i,"when":"%f"}'

    def __init__(self):
        gLog.begin()
        self.__service = None
        self.__identifier = 1
        gLog.end()

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

    def post(self, deviceToken, payload):
        gLog.begin(len(deviceToken))
        if len(deviceToken) != 32:
            gLog.error('invalid device token')
            gLog.end()
            return

        size = len(payload)
        gLog.info('size:', size)
        gLog.debug('payload:', payload)

        expiry = socket.htonl(int(time.time()) + 120)
        msg = struct.pack('!BIIH32sH', 1, self.__identifier, expiry, 32, deviceToken, 
                          size) + str(payload)
        self.__identifier += 1

        for attempts in range(2):
            if self.__service == None:
                self.connect_to_service()
            try:
                self.__service.write(msg)
                gLog.info('sent', payload)
                msg = None
                break
            except:
                traceback.print_exc()
                self.__service = None

        if msg != None:
            gLog.error('failed to send', payload)
            
        gLog.end()
