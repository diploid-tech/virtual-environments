#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

usage() { echo "Usage: $0
    -l <location>
    -p <install_password>
	" 1>&2; exit 1; }

show_header() { echo "
****************************************************************************************
$( echo "$1" | awk '{print toupper($0)}' )
****************************************************************************************
"; }

declare location=""
declare github_feed_token=""
declare resource_group_name="avanti-platform-global"
declare service_principal_name="packer"
declare shared_image_gallery_name="avanti_images"
declare shared_image_definition="bastion-windows2019"
declare publisher="DiploidTech"
declare offer="AvantiVirtualEnvBastion"
declare sku="2021R1"
declare debug="false"
declare azAppPassword=""
declare azAppId=""
declare install_password=""

cat banner.txt
show_header "Create Windows 2019 Bastion VM Image"

# Initialize parameters specified from command line
while getopts ":t:l:d:r:i:p:" arg; do
	case "${arg}" in
        l)
			location=${OPTARG}
            ;;
        t)
            github_feed_token=${OPTARG}
            ;;
        d)
            debug="true"
            ;;
        r)
            resource_group_name="avanti-tenant-${OPTARG}"
            ;;
        i)
            shared_image_gallery_name=${OPTARG}
            ;;
        p)
            install_password=${OPTARG}
		esac
done
shift $((OPTIND-1))

if [ -z "$location" ] || [ -z "$install_password" ]; then
	echo "Not all parameters are filled!"
	usage
fi

#login to azure using your credentials
az account show 1> /dev/null

if [ $? != 0 ]; then
    echo "Make sure that you are logged in with the Azure CLI, use 'az login'!"
fi

set +e

echo "Create service principal for image creation"
subscription_id=$(az account show | jq -r '.id')
tenant_id=$(az account show | jq -r '.tenantId')
resource_group_name=${resource_group_name}

azAppId=$(az ad sp list --display-name $service_principal_name --query "[].appId" -o tsv)

if [ -n "$azAppId" ]; then
    az ad sp delete --id $azAppId
fi

echo "Creating Service Principal for Packer..."
azAppOutput=$(az ad sp create-for-rbac -n "$service_principal_name" --role Contributor --scopes /subscriptions/$subscription_id --output json)
azAppId=$(json_data="$azAppOutput" jq -r -n 'env.json_data | fromjson.appId')
azAppPassword=$(json_data="$azAppOutput" jq -r -n 'env.json_data | fromjson.password')
sleep 30s
if [ $? != 0 ]; then
    exit 1
fi

az group show --name $resource_group_name 1> /dev/null

if [ $? != 0 ]; then
	echo "Resource group with name" $resource_group_name "could not be found. Creating new resource group.."
    az group create \
        --name $resource_group_name \
        --location $location
else
	echo "Using existing resource group with name" $resource_group_name "..."
fi

shared_image_gallery=$(az sig show --gallery-name $shared_image_gallery_name --resource-group $resource_group_name)
if [ "$( echo ${shared_image_gallery} | jq '. | length' )" == 0 ] || [ -z "$shared_image_gallery" ]; then
	show_header "Creating shared image gallery '$shared_image_gallery_name'..."
    az sig create --resource-group $resource_group_name --location $location --gallery-name $shared_image_gallery_name
else
	echo "Already created shared image gallery '$shared_image_gallery_name'..."
fi

image_definition=$(az sig image-definition show --gallery-image-definition $shared_image_definition --gallery-name $shared_image_gallery_name --resource-group $resource_group_name)
if [ "$( echo ${image_definition} | jq '. | length' )" == 0 ] || [ -z "$image_definition" ]; then
	show_header "Creating image definition '$image_definition'..."

    az sig image-definition create \
        --resource-group $resource_group_name \
        --location $location \
        --gallery-name $shared_image_gallery_name \
        --gallery-image-definition $shared_image_definition \
        --publisher $publisher \
        --offer $offer \
        --sku $sku \
        --os-type Windows
else
	echo "Already created image definition '$image_definition'..."
fi

echo "Using new Azure service principal with id $azAppId."

echo "Generate image using Packer"
(
    if [ "$debug" == "true" ]; then
        set -x
    fi
    docker run -i -v $(pwd):/tmp \
        hashicorp/packer:1.6.5 build -on-error=ask \
        -var resource_group=$resource_group_name \
        -var client_id=$azAppId \
        -var client_secret=$azAppPassword \
        -var subscription_id=$subscription_id \
        -var tenant_id=$tenant_id \
        -var location=$location \
        -var gallery_name=$shared_image_gallery_name \
        -var managed_image_name=$shared_image_definition \
        -var github_feed_token=$github_feed_token \
        -var install_password=$install_password \
        /tmp/images/win/windows2019_bastion.json
)

echo "Deleting Azure service principal with id $azAppId."
az ad sp delete --id $azAppId
