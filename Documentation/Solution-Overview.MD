# How the system works
## Odroid Board
The Odroid board is setup with three main Cron jobs that are run on boot up:
* boot.py
* button-script.py
* execute_test_final.py

boot.py is the script that is run on boot-up in order to provide a countdown until the tester has booted and is ready to perform the test. This is currently hardcoded at 30 seconds.
The button-script.py is needed to execute an infinite while loop that is listening for changes on the Odroid pins. In other words when the buttons are pressed on the screen.
Depending on the button the script will either be restarted or display the boards MAC address.
Finally the script that actually performs the line test is execute_test_final.py. During the testing process there are various screen prompts. All can be found in Documentation.

The script will perform the following checks to ensure adequate connectivity before performing the test:

* ICMP test to the hostname of the IPerf test server.
* Socket establishment to SSH port 22 to ensure SCP will work correctly.
* Socket establishment to IPerf port 5201 to ensure the IPerf server is available.

Once all three checks pass the IPerf test is performed. The Odroid board will perform the following command line IPerf command:
```Python
iperf3 -c hostname -J -t 15
```
The above will run an iperf test with the server specified by the hostname on port 5201 for 15 seconds. -J signifies that we want the output of the test to be outputted into a file containing JSON information. We use this information in extracting the necessary values we would like. By default we use a user on the Odroid board called Iperf. Therefore the default location for the log files is /home/iperf. One of the main requirements is being able to later retrieve the results of a line test. As such we need a way to distinguish between the logs. For this we read in the contents of a particular log output, generate a hash from this data, and use that
hash for the filename. As no two tests will be the same, for example timestamps differ, the hash should always be different. Due to the size of the MD5 hash we decided to take 10 characters of the hash only for the unique identification of each log.

There is also some information that we wanted to add the JSON output that we need to use for the tests. Specifically:

* Gateway MAC Address
* Hash
* MAC Address of the Board

The gateway MAC is used for some requirements to determine device mappings. The hash is needed to identify the test later and the MAC address of the board is needed to map to the engineer in the backend.

After the test is complete the test will be copied over to the IPerf server. For added security we make use of SCP for the file transfer. The script pulls the log from /home/iperf and uploads the files to the IPerf server, specifically /home/test-logs/<hashed-filename>. After this the script will display the upload and download speeds indefinetly until either the board is rebooted or the left button is pressed to restart the test.
## IPerf Server
The actual IPerf server has a relatively simple role. The Cron job that runs will ensure that the IPerf3 server daemon is running causing the server to listen on port 5201 for connection requests from the Odroid boards. The Odroid boards will be the ones copying the files onto the server. The IPerf server has a public address to ensure a proper test is performed.

One service that we are running on the IPerf server is the whats my IP address page. In order to obtain the information on the switch a particular tester is connected to we needed a fallback for when we cannot get the MAC address of CPEs outside interface. Therefore we utilise the whats my ip service to determine what the IP address is before any NAT translations so we can pass this to our API that will return the switch information. There are two methods that were done for this. The first made use of PHP and Apache to provide a webpage that when visted would display the address of the request in JSON format. The second makes use of Flask and Python that performs the same thing providing the IP address in JSON format for the request.

In order for the Flask application to work better we made use of WSGI (Web Server Gateway Interface) for Apache. Using flask by default will cause a development WSGI instance to be run which can only handle a single request at a time. Therefore moving to WSGI allows for a better application. WSGI can be installed seperately using apt-get install libapache2-mod-wsgi. The app will run whenever Apache is run.

## IPerf Log Server
The IPerf log server is the final storage location for the test logs. We use a number of different cron jobs to perform the various tasks required of the server. In order to get the logs we used a handful of cron jobs for RCP that will copy logs every 10 seconds. The IPerf log server will copy the logs files from /home/test-logs on the IPerf server to the /home/iperf directory on the IPerf log server. In order to save space on the IPerf test server we remove the files once copied.

Once on the IPerf log server another cron job runs that executes the json_server_side.py script. This script does all the necessary processing required to extract the information from the log file containing the JSON information and inserting this into the database. There is an ubundunce of information from the test so we only extract the information that we would like. We also determine what the peak utilisation was by taking each 1 second interval from the log and working out the largest of those. Once processed the log files are copied to /home/test-logs where they are stored permanently. While we have extracted the information we want the raw JSON output can be downloaded from the front-end.

Specific to the environment we are running in we wanted to be able to obtain the switch information from the test. The Odroid board using some ARP magic obtains the gateways MAC address. We then have an API that we feed this MAC in and get returned the switch information that we stored with the logs in the database. The switch information can take a while to be obtainable via the API and might not be available at the time the speed test is run. As such we perform a check for an empty response from the API. In this case we will place the log and the gateway MAC address into a table. We have a 5 minute cron job that is run that will take anything from this table and query them again against the API. If successful they are removed from this table and the log updated with the switch information. If the information is not available it is left in the table where it is checked against the API is another 5 minutes.

The last thing that the board will do is email the test results over after inserting them into the database. In the backend we link an engineer to a boards MAC address and use that information to decipher which engineer performed the test and grab their email. The email will show the download, upload, and peak utilisation.
