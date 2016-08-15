#!/bin/sh
#build directory
export d="/opt/houstack"
alias sd="cd /opt/houstack-source"

export PATH=$PATH:$d/sbin:$d/bin:/usr/sbin
export HOME=/root
LDFLAGS="-L$d/lib -Wl,-rpath,$d/lib $LDFLAGS"
#LDFLAGS="-L/opt/houstack/lib -Wl,-rpath,/opt/houstack/lib -ljemalloc $LDFLAGS"
export LDFLAGS

CXXFLAGS="-I$d/include $CXXFLAGS"
CFLAGS=$CXXFLAGS
CPPFLAGS=$CXXFLAGS

export CXXFLAGS
export CFLAGS
export CPPFLAGS

PKG_CONFIG_PATH="$d/lib/pkgconfig"
export PKG_CONFIG_PATH

alias c="./configure --prefix=${d}"
alias ch="./configure --help"
alias m="make -j96 install"

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias vi=vim
alias ll='ls -l --color=auto'
alias his='history | cut -c 8-'

function confmake(){
	cd $1 && ./configure --prefix=$d $2 && make -j96 install && sd;
}
function phpmake(){
	cd $1 && phpize && ./configure $2 && make install && sd;
}
function tarmake(){
	wc=`tar tf $1 |cut -d "/" -f1|uniq|wc -l`;echo "$wc file in $1";if [ "x$wc" = "x1" ];then echo "start make $1"; tar xf $1 && cd `tar tf $1 |cut -d "/" -f1|uniq`;./configure --prefix=$d $2 && m && cd ..;else echo "ERROR: not one directory in $1";fi
}

PS1="\[\e[37;40m\][\[\e[32;40m\]\u\[\e[37;40m\]@\h \[\e[35;40m\]\W\[\e[0m\]]\\$ "
export PROMPT_COMMAND='{ msg=$(history 1 | { read x y; echo $y; });user=$(whoami); echo $(date "+%Y-%m-%d %H:%M:%S"):$user:`pwd`/:$msg; } >> /tmp/`whoami`.bashlog'
