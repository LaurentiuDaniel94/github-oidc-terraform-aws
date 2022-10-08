
data "aws_ami" "lvu-ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

output "ec2-ip" {
  value       = aws_instance.lvu-main.*.public_ip
  description = "Prints ec2 IP address"
}

resource "random_id" "node_id" {
  byte_length = 2
  count       = var.main_instance_count
}

resource "aws_instance" "lvu-main" {
  count         = var.main_instance_count
  instance_type = var.main_instance_type
  ami           = data.aws_ami.lvu-ami.id
  # key_name = ""
  vpc_security_group_ids = [aws_security_group.lvu-sg.id]
  user_data              = templatefile("./main-userdata.tpl", { new_hostname = "mtc-main-${random_id.node_id[count.index].dec}" })
  subnet_id              = aws_subnet.lvu_public_subnet[count.index].id
  root_block_device {
    volume_size = var.main_vol_size
  }

  tags = {
    "Name" = "lvu-ec2-${random_id.node_id[count.index].dec}"
  }

  provisioner "local-exec" {

    command = "printf '\n${self.public_ip}' >> aws_hosts"

  }
}

