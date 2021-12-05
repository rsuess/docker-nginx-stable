FROM nginx:stable
MAINTAINER "cytopia" <cytopia@everythingcli.org>

LABEL \
	name="cytopia's nginx stable image" \
	image="devilbox/nginx-stable" \
	vendor="devilbox" \
	license="MIT"


###
### Build arguments
###
ARG VHOST_GEN_GIT_REF=1.0.3
ARG WATCHERD_GIT_REF=v1.0.2
ARG CERT_GEN_GIT_REF=0.7

ENV BUILD_DEPS \
	git \
	make \
	wget

ENV RUN_DEPS \
	ca-certificates \
#	python-yaml \
	supervisor


###
### Runtime arguments
###
ENV MY_USER=nginx
ENV MY_GROUP=nginx
ENV HTTPD_START="/usr/sbin/nginx"
ENV HTTPD_RELOAD="nginx -s stop"


###
### Install required packages
###
RUN set -x \
	&& apt-get update 

RUN apt -y install curl
RUN  apt -y install ca-certificates
RUN apt-get -y install python3
RUN apt-get -y install python3-distutils
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
RUN python3 get-pip.py
RUN ln -s /usr/bin/python3 /usr/bin/python & \
    ln -s /usr/bin/pip3 /usr/bin/pip
RUN pip install pyyaml

RUN apt-get install --no-install-recommends --no-install-suggests -y \
		${BUILD_DEPS} \
		${RUN_DEPS} \
	\
	# Install vhost-gen
	&& git clone https://github.com/rsuess/vhost-gen \
	&& cd vhost-gen \
	&& git checkout "${VHOST_GEN_GIT_REF}" \
	&& make install \
	&& cd .. \
	&& rm -rf vhost*gen* \
	\
	# Install cert-gen
	&& wget --no-check-certificate -O /usr/bin/ca-gen https://raw.githubusercontent.com/devilbox/cert-gen/${CERT_GEN_GIT_REF}/bin/ca-gen \
	&& wget --no-check-certificate -O /usr/bin/cert-gen https://raw.githubusercontent.com/devilbox/cert-gen/${CERT_GEN_GIT_REF}/bin/cert-gen \
	&& chmod +x /usr/bin/ca-gen \
	&& chmod +x /usr/bin/cert-gen \
	\
	# Install watcherd
	&& wget --no-check-certificate -O /usr/bin/watcherd https://raw.githubusercontent.com/devilbox/watcherd/${WATCHERD_GIT_REF}/watcherd \
	&& chmod +x /usr/bin/watcherd \
	\
	# Clean-up
	&& apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $fetchDeps \
		${BUILD_DEPS} \
	&& rm -rf /var/lib/apt/lists/*


###
### Create directories
###
# /docker-entrypoint.d/10-ipv6* was added by nginx to do some IPv6 magic (which breaks the image)
RUN set -x \
	&& rm -rf /docker-entrypoint.d || true \
	&& mkdir -p /etc/httpd-custom.d \
	&& mkdir -p /etc/httpd/conf.d \
	&& mkdir -p /etc/httpd/vhost.d \
	&& mkdir -p /var/www/default/htdocs \
	&& mkdir -p /shared/httpd \
	&& chmod 0775 /shared/httpd \
	&& chown ${MY_USER}:${MY_GROUP} /shared/httpd


###
### Copy files
###
COPY ./data/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./data/vhost-gen/main.yml /etc/vhost-gen/main.yml
COPY ./data/vhost-gen/mass.yml /etc/vhost-gen/mass.yml
COPY ./data/vhost-gen/templates-main /etc/vhost-gen/templates-main
COPY ./data/create-vhost.sh /usr/local/bin/create-vhost.sh
COPY ./data/docker-entrypoint.d /docker-entrypoint.d
COPY ./data/docker-entrypoint.sh /docker-entrypoint.sh


###
### Ports
###
EXPOSE 80
EXPOSE 443


###
### Volumes
###
VOLUME /shared/httpd
VOLUME /ca


###
### Signals
###
STOPSIGNAL SIGTERM


###
### Entrypoint
###
ENTRYPOINT ["/docker-entrypoint.sh"]
