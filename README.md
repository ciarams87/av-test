# av-test
This is a short technical test that should take no more than 3-4 hours to complete.

1. Create your own github repository and fork this project.
2. Create an AWS account if you do not already have one (this is free)
3. Create a project using bash that, given an AWS region and AWS AMI ID, it should:
   * Deploy the AMI in an EC2 instance.
   * Create an entry in Route 53 with the Elastic IP that has been assigned to the EC2 instance.
   * Stop the EC2 instance.
   * Destroy the EC2 instance and all of it's resources.
You will probably need to install the AWS cli to do this task.

What we are looking for:
   * Code syntax
   * Error control and handling
   * Reliability in your code
