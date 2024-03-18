# Sample Terraform Configurations
This repository includes Terraform configurations to deploy and manage some common resources on AWS.
## AWS Client VPN Endpoint
Sample configuration to deploy a client VPN endpoint to AWS.

### Authentication certificates
Generate CA certificate and key.
```shell
# Generate the CA private key
openssl genpkey -algorithm RSA -out vpn_ca.key -pkeyopt rsa_keygen_bits:2048

# Create the CA certificate
openssl req -x509 -new -nodes \
-key vpn_ca.key \
-sha256 -days 1825 \
-out vpn_ca.pem \
-subj "/C=<COUNTRY>/ST=<PROVINCE>/L=<CITY>/O=<ORGANIZATION>/CN=VPN CA"
```
Generate a key and certificate for a user and sign the certificate using the CA certificate.
```shell
# Generate the client private key
openssl genpkey -algorithm RSA -out vpn_client.key -pkeyopt rsa_keygen_bits:2048

# Create a CSR for the Client Certificate
openssl req -new \
-key vpn_client.key \
-out vpn_client.csr \
-subj "/C=<COUNTRY>/ST=<PROVINCE>/L=<CITY>/O=<ORGANIZATION>/CN=<USER_NAME>"

# Sign the CSR with your CA
openssl x509 -req \
-in vpn_client.csr \
-CA vpn_ca.pem \
-CAkey vpn_ca.key \
-CAcreateserial -out vpn_client.crt -days 1024 -sha256
```
### Deployment
Deploy the `vpn.tf` as a stand-alone terraform configuration or add it as a terraform module to an existing setup.
```hcl
module "vpn" {
  source = "./client_vpn_endpoint"
  count  = var.setup_vpn == true && var.main_domain_zone_id != "" ? 1 : 0

  private_subnet_id_az1         = aws_subnet.private_subnet_az1.id
  private_subnet_id_az2         = aws_subnet.private_subnet_az2.id
  private_subnet_cidr_block_az1 = aws_subnet.private_subnet_az1.cidr_block
  private_subnet_cidr_block_az2 = aws_subnet.private_subnet_az2.cidr_block
  main_zone_id                  = var.main_domain_zone_id
  vpc_id                        = aws_vpc.main.id
  vpn_client_cidr_block         = "10.1.0.0/16"
}
```
Note that `main_zone_id` variable is only used to generate a valid server certificate using a subdomain named `vpn` in the domain hosted zone.

## AWS Aurora PostgreSQL integrated into Lambda 

Create a serverless RDS cluster using Aurora PostgreSQL and add a Proxy on top of it. This module also includes the necessary integration resources to use this DB in a Lambda function.

### Development
While developing you may find the need to connect to the deployed DB from your localhost.
To directly connect to the DB:
```shell
psql -h <RDS_DB_ENDPOINT> \
-p 5432 \
-U <DB_USER> \
-d <DB_NAME>
```

To connect to the DB via the deployed proxy:
```shell
DB_PROXY_ENDPOINT=<RDS_PROXY_ENDPOINT>

PGPASSWORD=$(aws rds generate-db-auth-token \
--region <REGION> \
--hostname "$DB_PROXY_ENDPOINT" \
--port 5432 \
--username <DB_USER>) \
psql -h "$DB_PROXY_ENDPOINT" \
-p 5432 \
-U <DB_USER> \
-d <DB_NAME>
```
Since the cluster is deployed to private subnets with restricted security groups, in order to connect locally, you need to:
* Have network access to the private subnets using the VPN module provided in this repository
* Temporary allow PostgreSQL traffic from a wide private subnets CIDR like `10.0.0.0/16` in the cluster/proxy security group from AWS Console/CLI
