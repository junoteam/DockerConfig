############################################################
# Dockerfile to run Upods Backend container
# Based on Centos7 64Bit Image
# Version #2
############################################################

# Set the base image to use to Centos7 64bit
FROM library/centos

# Set the file maintainer (your name - the file's author)
MAINTAINER Alex Berber <berber.it@gmail.com>

# root password settings
RUN yum -y install passwd
RUN echo 'root:root' | chpasswd

# Update the default application repository sources list
RUN yum update -y
RUN yum install epel-release -y
RUN yum install tar vim rsync git curl wget net-tools libffi-devel bmon telnet htop -y
RUN yum install openssl openssl-devel -y
RUN yum install gcc -y

# Add Nginx repository
ADD nginx/nginx.repo /etc/yum.repos.d/nginx.repo

# Add MySQL repository
RUN yum install https://dev.mysql.com/get/mysql57-community-release-el7-8.noarch.rpm -y
ADD mysql/mysql-community.repo /etc/yum.repos.d/mysql-community.repo

# Update and install Nginx server and Mysql Client
RUN yum update -y
RUN yum install nginx -y
RUN yum install mysql-community-client -y

# Give root to Nginx
RUN useradd -m uwsgi
RUN usermod -a -G uwsgi nginx

# Remove default host and adding mine
RUN rm -rf /etc/nginx/conf.d/*
RUN mkdir /etc/nginx/ssl/

# Copy a configuration file from the current directory
ADD nginx/nginx.conf /etc/nginx/
ADD nginx/ssl/nginx.crt /etc/nginx/ssl
ADD nginx/ssl/nginx.key /etc/nginx/ssl
ADD nginx/conf.d/* /etc/nginx/conf.d/

# Create logs directories
RUN mkdir -p /var/log/nginx/upods
RUN mkdir -p /var/log/upods

# Create logs
RUN touch /var/log/nginx/upods/error.log
RUN touch /var/log/nginx/upods/access.log
RUN touch /var/log/upods/debug.log
RUN touch /var/log/supervisord.log

# Set permissions for logs
RUN chown -R nginx:nginx /var/log/nginx
RUN chmod -R 0750 /var/log/nginx
RUN chmod -R 0750 /var/log/upods

# Install Python and Basic Python Tools
RUN yum install -y python python-pip python-devel

# Install flask, uWSGI, virtualenv
RUN pip install --upgrade pip
RUN pip install 'requests[security]' --upgrade
RUN pip install virtualenv
RUN pip install uWSGI uwsgitop 
RUN pip install pymongo 
RUN pip install requests gitpython
RUN pip install flask && pip install flask --upgrade
RUN pip install flask_restful requests_oauthlib OAuth
RUN yum install MySQL-python -y

# Installing SuperVisor
RUN yum install supervisor -y
ADD supervisor/supervisord.conf /etc/supervisor/supervisord.conf

# Install SSH Server
RUN yum install openssh-server openssh-clients openssh -y

# SSH fix. Otherwise user is kicked off after login
RUN mkdir /var/run/sshd
RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -t dsa -f /etc/ssh/ssh_host_ecdsa_key
RUN ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ed25519_key
RUN sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# uWcgi config file
RUN mkdir -p /etc/uwsgi
RUN mkdir -p /var/run/upods
ADD uwsgi/uwsgi.ini /etc/uwsgi/uwsgi.ini
RUN chown -R uwsgi:nginx /var/run/upods

# Create the default data directory
RUN mkdir -p /var/www/html
RUN mkdir -p /var/upods_api
RUN mkdir -p /var/upods_api/flask_project/static

# Set permissions for upods dir and static dir
RUN chmod -R 0755 /var/upods_api
RUN chown -R nginx:nginx /var/upods_api/flask_project/static
RUN chmod -R 0775 /var/upods_api/flask_project/static

# Add Tini
# Use tini as valid init for Docker containers
ENV TINI_VERSION v0.9.0
ENV TINI_SHA fa23d1e20732501c3bb8eeeca423c89ac80ed452
RUN curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static -o /bin/tini && chmod +x /bin/tini \
&& echo "$TINI_SHA  /bin/tini" | sha1sum -c -

# Prepare SSH for Git repository
RUN mkdir -p /root/.ssh
ADD ssh_deployment_keys/* /root/.ssh/
RUN chmod 0700 /root/.ssh
RUN chmod 0600 /root/.ssh/*
RUN echo "StrictHostKeyChecking no" >> /root/.ssh/config

# Get GIT repo from BitBucket
RUN git --work-tree=/var/upods_api/flask_project --git-dir=/var/upods_api/flask_project/.git init
RUN git --work-tree=/var/upods_api/flask_project --git-dir=/var/upods_api/flask_project/.git remote add origin git@bitbucket.org:chickkenkiller/upods-backend.git
RUN git --work-tree=/var/upods_api/flask_project --git-dir=/var/upods_api/flask_project/.git pull origin master

# Usage: WORKDIR /path
WORKDIR /var/www/html/

# Adding Executor Script
COPY executor.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/executor.sh

# Creating Alias for uwsgitop
RUN echo "alias uwsgitop='TERM=linux TERMINFO=/etc/terminfo uwsgitop /var/run/upods/uwsgi-stats.sock'" >> ~/.bashrc
RUN echo "export TERM=linux" >> ~/.bashrc
RUN echo "export TERMINFO=/etc/terminfo" >> ~/.bashrc

# Expose port
EXPOSE 22 80 443

# Run executor as EntryPoint
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/executor.sh"]
