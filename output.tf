output "web_app_ip" {
  value = aws_instance.web_app.public_ip
}