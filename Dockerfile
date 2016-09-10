FROM alpine:3.4

RUN apk update
RUN apk upgrade
RUN apk add --virtual builddeps \
  gcc \
  g++ \
  make \
  curl \
  ruby-dev \
  ruby-rake \
  bison \
  perl \
  git 
RUN apk add --virtual rundeps \
  pcre-dev \
  zlib-dev

# nginx with lua module
ENV NGINX_VERSION="1.10.1"
ENV NGX_DEVEL_KIT_VERSION="0.3.0"
ENV NGX_MRUBY_VERSION="1.18.4"

RUN mkdir -p /usr/src
WORKDIR /usr/src

# ngx_devel_kit
RUN curl -SL https://github.com/simpl/ngx_devel_kit/archive/v$NGX_DEVEL_KIT_VERSION.tar.gz > ngx_devel_kit-v$NGX_DEVEL_KIT_VERSION.tar.gz
RUN tar zxvf ngx_devel_kit-v$NGX_DEVEL_KIT_VERSION.tar.gz

# ngx_mruby
RUN curl -SL https://github.com/matsumoto-r/ngx_mruby/archive/v$NGX_MRUBY_VERSION.tar.gz > ngx_mruby-v$NGX_MRUBY_VERSION.tar.gz
RUN tar zxvf ngx_mruby-v$NGX_MRUBY_VERSION.tar.gz

# nginx
RUN curl -SL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz > nginx-$NGINX_VERSION.tar.gz
RUN tar zxvf nginx-$NGINX_VERSION.tar.gz

# prepare for ngx_mruby
WORKDIR /usr/src/ngx_mruby-$NGX_MRUBY_VERSION
COPY build_config.rb ./
RUN ./configure --with-ngx-src-root=/usr/src/nginx-$NGINX_VERSION
RUN make build_mruby
RUN make generate_gems_config

# build nginx with mruby
WORKDIR /usr/src/nginx-$NGINX_VERSION
RUN ./configure \
  --prefix=/usr/local \
  --add-module=/usr/src/ngx_mruby-$NGX_MRUBY_VERSION \
  --add-module=/usr/src/ngx_devel_kit-$NGX_DEVEL_KIT_VERSION
RUN make
RUN make install

COPY root /
EXPOSE 80

# clean up
RUN apk del builddeps
RUN rm -rf /usr/src

# test nginx.conf
RUN /usr/local/sbin/nginx -t -c /etc/nginx/nginx.conf

CMD ["/usr/local/sbin/nginx", "-g", "daemon off;", "-c", "/etc/nginx/nginx.conf"]
