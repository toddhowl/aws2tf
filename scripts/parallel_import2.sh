#!/bin/bash
if [ "$1" == "" ]; then
    echo "must specify resource type (ttft)"
    exit
fi
if [ "$2" == "" ]; then
    echo "must specify resource name (cname)"
    exit
fi
ttft=`echo $1 | tr -d '"'`
cname=`echo $2 | tr -d '"'`
rname=${cname//:/_} && rname=${rname//./_} && rname=${rname//\//_}
#echo "parallel list check"
(terraform state list 2> /dev/null | grep ${ttft}.${rname}) > /dev/null 
if [[ $? -ne 0 ]];then

    #echo "Import $rname"
    #terraform state rm $ttft.$rname > /dev/null
    rm -rf pi2
    mkdir -p pi2 && cd pi2

    #cp ../aws.tf .
    ls ../.terraform > /dev/null
    if [[ $? -eq 0 ]];then 
        echo "pi2 using root provider"
        ln -s ../aws.tf aws.tf  2> /dev/null
        ln -s ../.terraform .terraform 2> /dev/null
        ln -s ../.terraform.lock.hcl .terraform.lock.hcl 2> /dev/null
    else
        echo "pi2 using initing TF provider"
        sl=`echo $((1 + $RANDOM % 15))`
        terraform init -no-color > /dev/null
        if [ $? -ne 0 ]; then
            echo "init backoff & retry for $rname"
            sleep 10
            terraform init -no-color > /dev/null
            if [ $? -ne 0 ]; then
                    echo "init long backoff & retry with full errors for $rname"
                    sleep 20
                    terraform init -no-color > /dev/null
            fi
        fi
    fi
    sl=`echo $((1 + $RANDOM % 4))`
    sleep $sl
    printf "resource \"%s\" \"%s\" {}" $ttft $rname > $ttft.$rname.tf


    #echo "Importing..."  
    sl=`echo $((1 + $RANDOM % 15))`         
    nice -n $sl terraform import $ttft.$rname "$cname" > /dev/null
    if [ $? -ne 0 ]; then
        echo "Import backoff & retry for $rname"
        sl=`echo $((1 + $RANDOM % 10))`
        sleep $sl
        nice -n $sl terraform -state $ttft.$rname.tfstate import $ttft.$rname "$cname" > /dev/null
        if [ $? -ne 0 ]; then
                echo "Import long backoff & retry with full errors for $rname"
                sl=`echo $((2 + $RANDOM % 20))`
                sleep $sl
                nice -n $sl terraform -state $ttft.$rname.tfstate import $ttft.$rname "$cname" > /dev/null
        fi
    fi
    #echo "local state list"
    #terraform state list -no-color

    printf "terraform -state $ttft.$rname.tfstate import %s.%s %s" $ttft $rname "$cname" > ../data/import_$ttft_$rname.sh

    terraform -state $ttft.$rname.tfstate state show $ttft.$rname | perl -pe 's/\x1b.*?[mGKH]//g' > $ttft-$rname-1.txt 
    rm $ttft.$rname.tf

else
    echo "State $ttft.$rname already exists skipping import ..."
    terraform state show $ttft.$rname | perl -pe 's/\x1b.*?[mGKH]//g' > $ttft-$rname-1.txt
    ls $ttft*-1.txt

fi

rm -f terr*.backup
#rm -rf $ttft-$rname/.terraform*
# rmdir $ttft-$rname
#rm -f $ttft-$rname-1.txt
#echo "top level state list"
#terraform state list | grep $ttft.$rname
echo "exit parallel import $rname"