#!/bin/bash


PROGNAME=$(basename $0)
ami='ami-047bb4163c506cd98'
region='eu-west-1'
domain='av-test-fake-domain.ie'
instance_id=
elastic_ip=
hosted_zone_id=
name=

usage(){
    echo "Welcome to the avtest. The below are optional arguments:"
    echo "-a | --ami      : the ami id (e.g. ami-047bb4163c506cd98)"
    echo "-r | --region   : the region (e.g. eu-west-1)"
    echo "-d | --domain   : the domain for Route 53 (e.g. fakesite.ie)"
    echo "-n | --name     : the domain name for Route 53 (e.g. avtest -> avtest.fakesite.ie)"
    echo "-h | --help     : details these arguments"
}

# set command line args
while [ "$1" != "" ]; do
    case $1 in
        -a | --ami )            shift
                                ami=$1
                                ;;
        -r | --region )         shift
                                region=$1
                                ;;
        -d | --domain )         shift
                                domain=$1
                                ;;                                
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

set_variable(){
    if [ $1 == 'instance_id' ]; then
        instance_id=$2
    elif [ $1 == 'elastic_ip' ]; then
        elastic_ip=$2
    elif [ $1 == 'hosted_zone_id' ]; then
        hosted_zone_id=$2
    fi
}

launch_instance(){
    # expects ami as arg
    echo "Creating instance..."
    aws ec2 describe-images --image-id $1 && \
    local id=$(aws ec2 run-instances --image-id $1 --count 1 --instance-type t2.micro --output table | awk 'FNR == 15 {print $4}')
    if [ $? -eq 0 ]; then
        set_variable 'instance_id' $id
    fi
}

create_and_associate_elastic_ip(){
    # expects instance id as arg
    echo "Creating elastic ip and associating it with instance $1..."
    local instance_status=
    # wait for instance to be running
    echo "Wait for instance to be running..."
    while [ "$instance_status" != 'running' ]; do
        instance_status=$(aws ec2 describe-instances --instance-id $1 --query 'Reservations[*].Instances[*].[State.Name]' --output text)
    done
    local ip=$(aws ec2 allocate-address --output text | awk '{print $3}') && \
    aws ec2 associate-address --instance-id $1 --public-ip $ip
    local rc=$?
    if [ $rc == 0 ]; then
        set_variable 'elastic_ip' $ip
    fi
    return $rc
    }

create_hz_route_53(){
    # expects domain name as arg
    echo "Creating hosted zone for domain name $1..."
    id=$(aws route53 create-hosted-zone --name $1 --caller-reference $(date '+%s') --output text | \
    awk 'FNR == 7 {print $3}' |  awk -F'/' '{print $3}')
    if [ $? == 0 ]; then
        set_variable 'hosted_zone_id' $id
    fi
}

update_record_route_53(){
    # expects hosted zone id, IPv4 address, and action. Can also pass name parameter if required.
    # create a tempfile for the batch file
    tmpfile=$(mktemp)
    cp resource_record_set.json $tmpfile
    sed -i "s/IPv4_address/$2/g" "$tmpfile"
    sed -i "s/ACTION_VAR/$3/g" "$tmpfile"
    if [ -n $4 ]; then
        sed -i "s/avtest/$4/g" "$tmpfile"
    fi
    echo "Updating the record set for hosted zone $1"
    aws route53 get-hosted-zone --id $1 && \
    aws route53 change-resource-record-sets --hosted-zone-id $1 --change-batch file://$tmpfile
    if [ $? != 0 ]; then
        rm "$tmpfile"
        return 1
    fi
    rm "$tmpfile"
    
}

delete_route_53_hz(){
    # expects hosted zone id as arg
    echo "Deleting hosted zone $1"
    aws route53 delete-hosted-zone --id $1
}

disassociate_and_release_elastic_ip(){
    # expects ip address as arg
    local allocation_id=$(aws ec2 describe-addresses --public-ips $1 --output text | awk '{print $2}')
    aws ec2 release-address --allocation-id $allocation_id
}

terminate_instance(){
    aws ec2 terminate-instances --instance-ids $1 
}

clean(){
    if [ -n $hosted_zone_id ]; then
        if [ -n $elastic_ip ]; then 
            update_record_route_53 $hosted_zone_id $elastic_ip 'DELETE' $name
        fi
        delete_route_53_hz $hosted_zone_id
    fi
    if [ -n $elastic_ip ]; then
        disassociate_and_release_elastic_ip $elastic_ip
    fi
    if [ -n $instance_id ]; then
        terminate_instance $instance_id
    fi
    
    exit $1
}

trap clean_up SIGHUP SIGINT SIGTERM

error_exit() {

	# Display error message and exit
	echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
	clean 1
}


main(){

# launch instance
if [ -n $ami ]; then
    launch_instance $ami
else error_exit "No image specified"
fi

# associate elastic ip
if [ -n "$instance_id" ]; then
    create_and_associate_elastic_ip $instance_id
else error_exit "No instance id supplied for elastic ip association - possible error on instance creation"
fi

# create hosted zone in the required domain
if [ $? == 0 ]; then
    create_hz_route_53 $domain
else error_exit "An error has occurred associating the elastic ip association"
fi

# create the record
if [ -n "$hosted_zone_id" ] && [ -n "$elastic_ip" ]; then
    update_record_route_53 $hosted_zone_id $elastic_ip 'CREATE' $name
    if [ $? != 0 ]; then
        error_exit "An error has occurred creating the Route 53 record for instance $instance_id on domain $domain"
    fi
else error_exit "Hosted zone id of elastic ip is not set - cannot create the Route 53 record for instance $instance_id on domain $domain"
fi

# cleanup
echo "An instance has been created from the ami $ami in the region $region; it has been assigned the Elastic IP $elastic_ip;
 and an entry has been created in Route 53 on the $domain domain with this Elastic IP."
sleep 2
echo
echo "We will now begin terminating the EC2 instance and all of it's resources."
clean
}

main

