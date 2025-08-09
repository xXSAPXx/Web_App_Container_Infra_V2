
# LOGICAL FILE FOR THE RDS SCHEMA:
#
CREATE DATABASE CALC_APP_DB;

CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `username` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


# Connect to the RDS from a machine insidee the VPC:
mysql -h <TERRAFORM_RDS_ENDPOINT> -u admin -p