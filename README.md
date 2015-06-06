# NotificationHubTest

Simple iOS client used for testing out Apple push notifications.

![graphs](https://raw.githubusercontent.com/bradhowes/NotificationHubTest/master/Images/graphs.png)

The app plots latencies seen from notification arrivals. The upper chart is the arrivals over time, and the lower one
is a bar chart showing a histogram of the latencies in 1 second bins. The app uses the excellent
[Core Plot](https://github.com/core-plot/core-plot) framework for generating the plots.

![logs](https://raw.githubusercontent.com/bradhowes/NotificationHubTest/master/Images/logs.png)

For later analysis, the program records most app-related events into a CSV file (events.csv). There is also a more
verbose log file (log.txt) that captures additional details such as HTTP responses when using the remote notification
server (see below).

![recordings](https://raw.githubusercontent.com/bradhowes/NotificationHubTest/master/Images/recordings.png)

You can access these files via iTunes when the iOS device is connected to a laptop or desktop machine, or you can enable
Dropbox uploading and have the device send you the files.

# Remote Server

The [Server](https://github.com/bradhowes/NotificationHubTest/tree/master/Server) folder contains a simple Python
application which operates with the NHTest app when configured to use it. An easy way to get set up is to run the
server on a laptop like so:

    % python app.py
    20150606.122451 emitter.py __init__ BEG self: <emitter.APNs object at 0x10c97d1d0> 
    20150606.122451 emitter.py __init__ END 
    * Running on http://0.0.0.0:8080/

Now enter NHTest Settings screen, select Remote Server for the Notification Driver setting, and in the Remote Server
Settings text fields enter the laptop's host name (eg *foobar.local*) and the port number *8080*. Pressing the
green start arrow should establish connectivity between NHTest and the server if everything is correct.

![driver](https://raw.githubusercontent.com/bradhowes/NotificationHubTest/master/Images/driver.png)

Of course you can run the remote service anywhere, including on [Cloud9](http://c9.io/):

![remote](https://raw.githubusercontent.com/bradhowes/NotificationHubTest/master/Images/remote.png)
