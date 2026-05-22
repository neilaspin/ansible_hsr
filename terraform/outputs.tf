output "primary_public_ip" {
  value = aws_instance.hana_primary.public_ip
}

output "secondary_public_ip" {
  value = aws_instance.hana_secondary.public_ip
}

output "primary_private_ip" {
  value = aws_instance.hana_primary.private_ip
}

output "secondary_private_ip" {
  value = aws_instance.hana_secondary.private_ip
}
