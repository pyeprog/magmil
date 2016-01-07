#!/bin/zsh

if [ "$#" != "2" ]
then
  echo "No argument supplied"
  echo "usage: sh install.sh rootPassword magentoUserPassword"
  exit 1
fi

if [ -z "$1" ]
then
  echo "No root password for mysql"
  exit 1
fi

if [ -z "$2" ]
then
  echo "No password for user magento"
  exit 1
fi

#Install php mysql and nginx
yum remove mariadb\* -y
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
yum install php-fpm php-mhash php-mcrypt php-curl php-cli php-mysql php-gd php-xsl php-json php-intl php-pear php-dev php-common php-soap libcurl3 php-apc -y
yum install nginx -y
yum install http://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm -y
yum repolist enabled | grep "mysql.-community." 
yum install mysql-community-server -y

#Set auto start
systemctl enable php-fpm nginx mysqld

#Configure mysql
systemctl start mysqld
mysqladmin -u root password "$1"
mysql -u root -p"$1" -e"source createuser.sql"
mysqladmin -u magento password "$2"
mysql -u root -p"$1" -e"source createdb.sql"

#Configure nginx
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old
cp nginx.conf /etc/nginx/
sed -i -e "s/\(root \).*/\1\/www\/magento;/" /etc/nginx/nginx.conf
systemctl start nginx
nginx -s reload

#Configure php-fpm
sed -i -e "s/\(user = \).*/\1nginx/" \
  -e "s/\(^group = \).*/\1nginx/" /etc/php-fpm.d/www.conf
systemctl start php

#Make dir
mkdir -p /www/magento

#Decompress files
cp magento.tar.gz /www/magento
cd /www/magento
tar zxvf magento.tar.gz
rm magento.tar.gz
cd -

tar jxvf theme.tar.bz2
tar jxvf magento_add.tar.bz2
gzip -vd database.sql.gz

#Merge folders
rsync magento/* /www/magento -av
rsync theme/* /www/magento -av

#Chown and Chmod
chown nginx:nginx -R /www/magento
chmod 777 -R /www/magento/media /www/magento/var

