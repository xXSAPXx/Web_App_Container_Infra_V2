
# Dockerfile for the frontend service using Apache HTTP Server:
FROM httpd:2.4-alpine

# Copy the public directory files to the Apache document root:
COPY ./public /usr/local/apache2/htdocs/

# Copy the custom httpd configuration file:
COPY httpd.conf /usr/local/apache2/conf/httpd.conf

# Expose port 80 for the HTTP server: 
EXPOSE 80
