aws_region  = "us-east-1"
aws_profile = "kwiki-test"

domain_name             = "home-project.example.com"
additional_domain_names = []
app_subdomain           = "app"
app_container_image     = "public.ecr.aws/nginx/nginx:latest"
app_container_port      = 80
app_desired_count       = 2
app_cpu                 = "512"
app_memory              = "1024"
app_health_check_path   = "/"
app_assign_public_ip    = false
app_environment = {
  ENVIRONMENT = "dev"
}

db_identifier        = "app-db-dev"
db_name              = "appdb"
db_username          = "appuser"
db_password          = "ChangeMe123!"
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20

redis_name               = "app-cache-dev"
redis_node_type          = "cache.t3.micro"
redis_engine_version     = "7.1"
redis_num_cache_clusters = 1
redis_auth_token         = "ChangeMeRedis123!"
