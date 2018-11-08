# av-test
This project uses bash to:
   * Deploy an AMI in an EC2 instance.
   * Create an entry in Route 53 with the Elastic IP that has been assigned to the EC2 instance.
   * Stop the EC2 instance.
   * Terminate the EC2 instance and all of it's resources.

To run:
Run avtest.sh.
Optional command line arguments are:

-a | --ami      : the ami id (e.g. ami-047bb4163c506cd98)
-r | --region   : the region (e.g. eu-west-1)
-d | --domain   : the domain for Route 53 (e.g. fakesite.ie)
-n | --name     : the domain name for Route 53 (e.g. avtest -> avtest.fakesite.ie)
-h | --help     : details the above arguments

Assumptions:
- AWS credentials are already set.
- AWS CLI has been installed.
- A domain name is required for full fuctionality