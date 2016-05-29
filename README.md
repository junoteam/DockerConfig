# DockerConfig
Docker config file for Python App

Inside container:
- Centos7 - basic image
- Nginx - web server
- uWSGI - for Python proccessing 
- Supervisor - for process managment inside container 
- Tini - a tiny but valid init for container
- Flask as framework
- SSL config for Nginx 
- OpenSSH server inside container for simple development 
- Git - for code managment
- executor.sh - is entry point
