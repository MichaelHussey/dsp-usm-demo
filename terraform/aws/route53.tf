# ------------------------------------------------------------------------------
# Bootstrap endpoint DNS - Kafka cluster hostnames -> PrivateLink IPs
# Domain derived from confluent_kafka_cluster.enterprise.bootstrap_endpoint
# ------------------------------------------------------------------------------
resource "aws_route53_zone" "bootstrap" {
  name = confluent_access_point.ingress.aws_ingress_private_link_endpoint[0].dns_domain

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = {
    Name        = "${var.cluster_name}-confluent-bootstrap-dns"
    owner_email = var.owner_email
  }
}

# Wildcard CNAME record - *.domain resolves to non-zonal PrivateLink endpoint DNS name
resource "aws_route53_record" "bootstrap_wildcard" {
  zone_id = aws_route53_zone.bootstrap.zone_id
  name    = "*"
  type    = "CNAME"
  ttl     = 60
  records = [aws_vpc_endpoint.privatelink.dns_entry[0]["dns_name"]]
}
# Wildcard CNAME record - *.az_id.domain resolves to zonal PrivateLink endpoint DNS name
resource "aws_route53_record" "bootstrap_zonal" {
  count   = var.availability == "MULTI_ZONE" ? 3 : 1
  zone_id = aws_route53_zone.bootstrap.zone_id
  name    = "*.${data.aws_availability_zones.available.names[count.index]}"
  type    = "CNAME"
  ttl     = 60
  records = [aws_vpc_endpoint.privatelink.dns_entry[count.index + 1]["dns_name"]]
}

locals {
  ingress_privatelink_dns_domain = confluent_access_point.ingress.aws_ingress_private_link_endpoint[0].dns_domain
  ingress_privatelink_dns_labels = split(".", local.ingress_privatelink_dns_domain)
  # Interface VPC endpoint dns_entry length is only known after apply; it matches 1 regional + one per subnet (same as bootstrap_wildcard + bootstrap_zonal).
  privatelink_dns_entry_count = length(aws_subnet.private) + 1
}

# Private zone: apex = ingress PL dns_domain without its first label; api.<zone> matches Confluent API hostname pattern
resource "aws_route53_zone" "confluent_api_region" {
  name = var.usm_ccloud_endpoint
  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = {
    Name        = "${var.cluster_name}-confluent-api-${var.region}-dns"
    owner_email = var.owner_email
  }
}

resource "aws_route53_record" "usm_api" {
  zone_id         = aws_route53_zone.confluent_api_region.zone_id
  name            = "api"
  type            = "CNAME"
  ttl             = 60
  records         = [aws_vpc_endpoint.privatelink.dns_entry[0].dns_name]
  allow_overwrite = true
}
