# HouStack简介

`HouStack`是一个模仿[XAMPP](https://www.apachefriends.org/zh_cn/index.html)的运行环境，解压即用。

在开发[寓悦](https://www.houpix.com)APP的过程中，我们后端主要用到了PHP、java、python、nodejs、go等语言，开发、测试、灰度、线上环境有一个基本的要求是程序运行环境必需一致，应该杜绝因为类似PHP版本不一致导致的人为bug。一开始我们用`yum groupinstall 'Development Tools'`的方法在每台机器上安装编译环境，然后下载对应版本的源代码进行编译，这样基本上可以解决问题，但是太low了，因为每台机器上都要编译，而且不好移植，有时候每次编译都有可能遇到各种各样的问题。`XAMPP`给了我们灵感，我们想做一个通用的64位Linux上运行的环境，只需要解压缩，所有的环境就都有了。

这样，我们的服务器被分成以下几个部分：

```
+-----------+-------------+
|           |             |
|           |             |
|           |             |
|           |             |
|           |             |
| 配置文件   |  应用层      |
|           |             |
|           |             |
|           |             |
|           |             |
+-----------+-------------+
|                         |
|                         |
|        HouStack层       |
|                         |
+-------------------------+
|                         |
|                         |
|        操作系统层        |
|                         |
+-------------------------+


```

正如某位伟人所说：

> Any problem  in computer science can be solved by anther layer of indirection.

为了增加应用层的可移植性，我们在操作系统上面添加了一个HouStack层，用来屏蔽各个发行版本的区别。这并没有什么稀奇的，因为各个运行环境都是跨平台的。HouStack的意义在于，它本身解压就能用，除了基础的libc以外，基本上没有更多依赖。

在开发、测试、生产环境中，应用层的东西是完全一样的，没有任何区别。差别仅在于“配置文件”层。开发环境是DEBUG模式，有更详细的日志，测试和生产保持完全一致(除了机器配置以外，完全一样，[参考](http://www.gfzj.us/2016/07/11/info-in-url.html))。

当然，你也可以用Docker保证各个运行环境保持一致。但是Docker根本不适合开发环境，而且在微服务的情况下，各种依赖，各种语言，非常不适合开发。

还记得为什么Google把所有代码放到一个仓库里面吗？[谷歌的代码管理](http://www.ruanyifeng.com/blog/2016/07/google-monolithic-source-repository.html)

我们所有语言，所有项目都放在应用层的目录里面，开发环境中可以很方便的把所有的服务都启动，一个虚拟机可以跑通所有的服务。但是这并不代表我们的应用不是分布式的，我们部署的时候，只需要根据需要配置访问路径和负载均衡就可以了。

当然，除了一个完整的解压就可以用的HouStack压缩包以外，这里主要还提供了构建的方法，可以给大家参考。

##编译日志：

#初始化一个编译环境

```bash
export myroot=/data/chroot/houstack
mkdir /data/chroot/houstack
mkdir -p $myroot/var/lib/rpm
rpm --root $myroot --initdb
yumdownloader --destdir=/tmp centos-release
rpm --root $myroot -ivh --nodeps /tmp/centos-release-*.rpm
mkdir $myroot/root
cp .bashrc $myroot/root/.bashrc
yum -y --installroot=$myroot groupinstall 'Development Tools'
yum -y --installroot=$myroot install cmake vim nc
#openssl使用，否则mysql启动不起来
touch $myroot/dev/{ramdom,urandom}
mount --bind /dev/random $myroot/dev/ramdom
mount --bind /dev/urandom $myroot/dev/urandom
touch $myroot/proc
mount -o bind /proc $myroot/proc

mkdir $myroot/opt/houstack-source
find /data/chroot/centos7/opt/houstack-source -maxdepth 1 -type f -exec cp {} $myroot/opt/houstack-source \;
chroot $myroot env -i /bin/bash


mkdir -pv ${d}/{log,etc,data}/{nginx,mysql,redis,fastdfs,php}
mkdir $d/tmp
chmod 777 $d/tmp

groupadd houstack
useradd houstack -g houstack -m
```

# fastdfs
我们编译出无依赖的fastdfs，然后cp到我们的$d/bin目录就可以了。但是中间需要调整几个参数。因为./make.sh是写死的

```bash
//TODO:fork一个出来改成./configure模式编译
sd
unzip libfastcommon.zip
cd libfastcommon-master

vi src/Makefile.in
修改：
$(COMPILE) -c -fPIC -o $@ $<  $(INC_PATH)
install -m 755 $(STATIC_LIBS) $(DESTDIR)/usr/$(LIB_VERSION)
install -m 755 $(STATIC_LIBS) $(DESTDIR)/usr/lib
./make.sh DEBUG_FLAG=0
./make.sh install

这样编译出静态链接库，fastdfs编译出来就没有依赖了。
sd
unzip fastdfs.zip
cd fastdfs-master
vi make.sh
修改
DEBUG_FLAG=0
CFLAGS='-lm -Wall -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE'
ENABLE_STATIC_LIB=1
ENABLE_SHARED_LIB=0

然后就是
find . -name Makefile.in
vi common/Makefile
增加-fPIC
./make.sh
./make.sh install

然后把产物复制出来
mkdir $d/bin
cp /usr/bin/fdfs_* $d/bin
cp /etc/fdfs/* $d/etc/fastdfs/
```

# openresty

```bash
//警惕.so是否编译成功
sd
tar xf openssl-1.0.2h.tar.gz
cd openssl-1.0.2h.tar.gz
cd openssl-1.0.2h
//openssl -fPIC参数太重要了。如果不想要.so，那么.a必须加fPIC参数，否则mysql编译失败
./config --prefix=$d -fPIC
m && make install


sd
tarmake pcre-8.39.tar.gz --enable-jit
tarmake zlib-1.2.8.tar.gz
tarmake jemalloc-4.2.1.tar.bz2

tar xf openresty-1.9.15.1.tar.gz


c  \
--with-openssl=../openssl-1.0.2h \
--with-ld-opt="-L${d}/lib -Wl,-rpath,${d}/lib -ljemalloc" \
--with-cc-opt="-O2 -I${d}/include" \
--with-http_ssl_module \
--with-pcre-opt=-DSUPPORT_UTF  \
--with-pcre-jit  \
--with-ipv6  \
--with-stream  \
--with-stream_ssl_module  \
--with-http_v2_module  \
--without-mail_pop3_module  \
--without-mail_imap_module  \
--without-mail_smtp_module  \
--with-http_stub_status_module  \
--with-http_realip_module  \
--with-http_addition_module  \
--with-http_auth_request_module  \
--with-http_secure_link_module  \
--with-http_random_index_module  \
--with-http_gzip_static_module  \
--with-http_sub_module  \
--with-http_flv_module  \
--with-http_mp4_module  \
--with-http_gunzip_module  \
--with-threads  \
--with-file-aio  \
--with-ld-opt="-ljemalloc" \
--http-log-path="$d/log/nginx/access.log" \
--error-log-path="$d/log/nginx/error.log" \
--sbin-path="$d/bin" \
--conf-path="$d/etc/nginx/nginx.conf" \
--user=houstack \
--group=houstack \
--http-client-body-temp-path=$d/tmp/nginx-http-client-body \
--http-proxy-temp-path=$d/tmp/nginx-proxy-temp \
--http-fastcgi-temp-path=$d/tmp/nginx-fastcgi-temp \
--http-uwsgi-temp-path=$d/tmp/nginx-uwsgi-temp \
--http-scgi-temp-path=$d/tmp/nginx-scgi-temp \
&&m && sd
```

# mysql

```bash
tar xf boost_1_59_0.tar.gz
tarmake ncurses-6.0.tar.gz --with-shared

export CFLAGS="-I$d/include/ncurses $CFLAGS"
tarmake libedit-20160618-3.1.tar.gz


tar xf libaio-0.3.110-1.tar.gz
cd libaio-0.3.110-1
make prefix=$d install
rm -f $d/lib/libaio.so*
sd

tar xf percona-server-5.7.13-6.tar.gz
cd percona-server-5.7.13-6
rm -f CMakeCache.txt && cmake . \
-DCMAKE_INSTALL_PREFIX=$d \
--debug-output \
-DWITH_BOOST=../boost_1_59_0/ \
-DCURSES_INCLUDE_PATH=$d/include \
-DWITH_READLINE=no \
-DWITH_EDITLINE=bundled \
-DCMAKE_BUILD_TYPE=RelWithDebInfo \
-DBUILD_CONFIG=mysql_release \
-DCURSES_CURSES_LIBRARY=$d/lib/libncurses.so \
-DCURSES_INCLUDE_DIR=$d/include \
-DWITH_MYISAM_STORAGE_ENGINE=1 \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_PARTITION_STORAGE_ENGINE=1 \
-DWITH_FEDERATED_STORAGE_ENGINE=1 \
-DEXTRA_CHARSETS=all \
-DDEFAULT_CHARSET=utf8mb4 \
-DDEFAULT_COLLATION=utf8mb4_general_ci \
-DWITH_EMBEDDED_SERVER=0 \
-DENABLED_LOCAL_INFILE=1 \
-DCMAKE_BUILD_TYPE=RelWithDebInfo \
-DBUILD_CONFIG=mysql_release \
-DWITH_SSL=$d \
-DMYSQL_DATADIR=$d/data/mysql

m
sd
```

# php

```bash
tar xf openresty-1.9.15.1.tar.gz
cd openresty-1.9.15.1

tarmake libmcrypt-2.5.8.tar.gz
tarmake libxml2-2.9.4.tar.gz --without-python
tarmake curl-7.50.0.tar.gz

tar xf php-7.0.9.tar.gz
cd php-7.0.9

./configure --prefix=$d \
--enable-fpm \
--enable-sigchild \
--enable-bcmath \
--enable-calendar \
--enable-exif \
--enable-ftp \
--enable-mbstring \
--enable-pcntl \
--enable-shmop \
--enable-soap \
--enable-sockets \
--enable-sysvmsg \
--enable-sysvsem \
--enable-sysvshm \
--enable-wddx \
--enable-zip=$d \
--enable-mysqlnd \
--with-pcre-regex \
--with-zlib=$d \
--with-mcrypt=$d \
--with-mhash \
--without-readline \
--with-libedit=$d \
--with-xmlrpc \
--with-curl=$d \
--with-gettext \
--with-libxml-dir=$d \
--with-openssl=$d \
--with-mysqli=mysqlnd \
--with-pdo-mysql=mysqlnd \
--with-fpm-user=houstack \
--with-fpm-group=houstack \
--with-config-file-path=$d/etc 

make -j8 install //job太多的话，很容易失败



安装PHP扩展
sd
tarmake jpegsrc.v9b.tar.gz
tarmake libwebp-0.5.1.tar.gz
tarmake libpng-1.6.23.tar.xz
tarmake libgd-2.2.3.tar.gz --enable-werror=no
tarmake freetype-2.6.5.tar.bz2

phpmake php-7.0.9/ext/gd/ "--with-webp-dir=$d --with-jpeg-dir=$d --with-png-dir=$d --with-zlib-dir=$d --with-freetype-dir=$d"
//多个参数，记得加引号

tar xf icu4c-57_1-src.tgz
confmake icu/source


phpmake php-7.0.9/ext/intl/
phpmake fastdfs-master/php_client/
tar xf XDEBUG_2_4_1.tar.gz
phpmake xdebug-XDEBUG_2_4_1/

tarmake libmemcached-1.0.18.tar.gz
phpmake php-memcached-php7 "--with-zlib-dir=$d --disable-memcached-sasl"
tar xf phpredis-3.0.0.tar.gz
phpmake phpredis-3.0.0
```

# memcache

```bash

tarmake libevent-2.0.22-stable.tar.gz
tarmake memcached-1.4.29.tar.gz

```

# redis

```bash

unset CXXFLAGS
unset CFLAGS
unset CPPFLAGS
unset LDFLAGS
unset PKG_CONFIG_PATH
tar xf redis-3.2.1.tar.gz
cd redis-3.2.1
make -j96 PREFIX=$d install
source ~/.bashrc
sd
```

# 其他工具
```bash
tar xf ntp-4.2.8p8.tar.gz
cd ntp-4.2.8p8
LDFLAGS="$LDFLAGS -ldl" && c && m
sd


tar xf p7zip_16.02_src_all.tar.bz2
cd p7zip_16.02
make -j96
cp bin/7za $d/bin

sd
tar xf keepalived-1.2.23.tar.gz 
cd keepalived-1.2.23
c && make -j96 && make install && sd


tarmake sqlite-autoconf-3130000.tar.gz
```

#配置etc目录
tmp目录存放pid、sock和各种临时文件。最后可以直接丢弃，不用迁移。
```bash
fastdfs

mysql初始化
mysqld --no-defaults --explicit_defaults_for_timestamp --initialize  --datadir=$d/data/mysql --lc-messages-dir=$d/share/ --lc-messages=en_US
chown -R houstack:houstack $d/{data,log}

tar czfv houstack-0.0.1.tar.gz houstack/{app,bin,data,etc,lib,log,lua*,nginx,php,pod,sbin,share,tmp,var}
```
#部署
```bash

curl http://192.168.50.24:9999/houstack-0.0.1.tar.gz|tar xzfv -
groupadd houstack
useradd houstack -g houstack -m
echo "export PATH=$PATH:/opt/houstack/bin:/opt/houstack/sbin" >> ~/.bashrc
source ~/.bashrc


php-fpm
nginx
redis-server /opt/houstack/etc/redis/redis.conf
memcached -u houstack -d
fdfs_trackerd /opt/houstack/etc/fastdfs/tracker.conf
fdfs_storaged /opt/houstack/etc/fastdfs/storage.conf
mysqld_safe --defaults-file=/opt/houstack/etc/mysql/my.cnf &

```

#rc.local
chmod +x /etc/rc.d/rc.local
```bash
/opt/houstack/bin/nginx
/opt/houstack/sbin/php-fpm
/opt/houstack/bin/redis-server /opt/houstack/etc/redis/redis.conf
/opt/houstack/bin/fdfs_trackerd /opt/houstack/etc/fastdfs/tracker.conf
/opt/houstack/bin/fdfs_storaged /opt/houstack/etc/fastdfs/storage.conf
/opt/houstack/bin/mysqld_safe --defaults-file=/opt/houstack/etc/mysql/my.cnf &
```