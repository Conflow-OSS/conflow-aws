resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-aurora"
  subnet_ids = var.subnet_ids
}
