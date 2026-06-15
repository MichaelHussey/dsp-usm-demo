# dsp-usm-demo

Spins up a number of EC2 instances in order to demonstrate [Unified Stream Manager](https://docs.confluent.io/platform/current/usm/overview.html). Each instance runs a number of Confluent Platform components using Docker

- Confluent Server running in combined mode
- Confluent Enterprise Connect Worker with the following connectors deployed
    - Replicator
    - DataGen
- Confluent Schema Registry
- Confluent USM Agent

#Setup

Make a copy of the 'terraform/aws/terraform.tfvars.example' file and set your Confluent Cloud credientials, chose a deployment region, give the project a name etc.

````
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
````


Notice 
---
This repository is part of the Confluent organization on GitHub.
It is public and open to contributions from the community.

Please see the LICENSE file for contribution terms.
Please see the CHANGELOG.md for details of recent updates.

