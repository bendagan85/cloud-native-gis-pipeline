# --- AZs Data Source ---
data "aws_availability_zones" "available" {
  state = "available"
}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment}-vpc"
  }
}

# --- Internet Gateway (For Public Access) ---
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-igw"
  }
}

# --- Public Subnets ---
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true 

  tags = {
    Name = "${var.environment}-public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

# --- Private Subnets ---
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.environment}-private-subnet-${count.index + 1}"
    Type = "Private"
  }
}

# --- Route Table (Public) ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- NAT Gateway Setup (Required for Private Nodes) ---

# 1. כתובת IP קבועה ל-NAT
resource "aws_eip" "nat" {
  domain = "vpc"
  
  tags = {
    Name = "${var.environment}-nat-eip"
  }
}

# 2. ה-NAT Gateway עצמו (יושב ברשת ציבורית ומתווך עבור הפרטיות)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # שמים אותו באחת הרשתות הציבוריות

  tags = {
    Name = "${var.environment}-nat-gateway"
  }

  # מחכים שה-IGW ייווצר קודם
  depends_on = [aws_internet_gateway.igw]
}

# --- Route Table (Private) - With NAT ---
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # ניתוב כל התעבורה היוצאת דרך ה-NAT Gateway
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.environment}-private-rt"
  }
}

# שיוך הרשתות הפרטיות לטבלה החדשה
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}