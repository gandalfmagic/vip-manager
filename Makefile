NAME=vip-manager
DEB_NAME=$(shell head -1 package/DEBIAN/changelog | sed -re 's/^(.*) \(.*\) .*; .*$$/\1/')
DEB_VERSION=$(shell head -1 package/DEBIAN/changelog | sed -re 's/^.* \((.*)-.*\) .*; .*$$/\1/')
DEB_ITERATION=$(shell head -1 package/DEBIAN/changelog | sed -re 's/^.* \(.*-(.*)\) .*; .*$$/\1/')
DEB_DIST=$(shell head -1 package/DEBIAN/changelog | sed -re 's/^.* \(.*\) (.*); .*$$/\1/')
DEB_ARCH=amd64
RPM_ARCH=x86_64
DESTDIR=tmp
LICENSE="BSD 2-Clause License"
MAINTAINER="Ants Aasma <ants@cybertec.at>"
DESCRIPTION="Manages a virtual IP based on state kept in etcd/consul."
HOMEPAGE="http://www.cybertec.at/"
GIT="git://github.com/cybertec-postgresql/vip-manager.git"
GITBROWSER="https://github.com/cybertec-postgresql/vip-manager"


all: vip-manager


vip-manager: *.go */*.go
	go build -mod=vendor -ldflags="-s -w" .


.PHONY: install
install: vip-manager
	install -d $(DESTDIR)/usr/bin
	install vip-manager $(DESTDIR)/usr/bin/vip-manager
	install -d $(DESTDIR)/lib/systemd/system
	install package/scripts/vip-manager.service $(DESTDIR)/lib/systemd/system/vip-manager.service
	install -d $(DESTDIR)/etc/init.d/
	install package/scripts/vip-manager.bash $(DESTDIR)/etc/init.d/vip-manager
	install -d $(DESTDIR)/etc/default
	install vipconfig/vip-manager.yml $(DESTDIR)/etc/default/vip-manager.yml


$(DEB_NAME)_$(DEB_VERSION)-$(DEB_ITERATION)_$(DEB_ARCH).deb: vip-manager package/DEBIAN/changelog
	install -d $(DESTDIR)/usr/bin
	install vip-manager $(DESTDIR)/usr/bin/vip-manager
	install -d $(DESTDIR)/usr/share/doc/$(NAME)
	install --mode=644 package/DEBIAN/copyright $(DESTDIR)/usr/share/doc/$(NAME)/copyright
	fpm -f -s dir -t deb -n $(DEB_NAME) -v $(DEB_VERSION) --iteration $(DEB_ITERATION) -C $(DESTDIR) \
	--license $(LICENSE) \
	--maintainer $(MAINTAINER) \
	--vendor $(MAINTAINER) \
	--description $(DESCRIPTION) \
	--url $(HOMEPAGE) \
	--deb-dist $(DEB_DIST) \
	--deb-field 'Vcs-Git: $(GIT)' \
	--deb-field 'Vcs-Browser: $(GITBROWSER)' \
	--deb-upstream-changelog package/DEBIAN/changelog \
	--deb-no-default-config-files \
	--deb-default vipconfig/vip-manager.yml \
	--deb-systemd package/scripts/vip-manager.service \
	usr/bin usr/share/doc/


$(DEB_NAME)-$(DEB_VERSION)-$(DEB_ITERATION).$(RPM_ARCH).rpm: $(DEB_NAME)_$(DEB_VERSION)-$(DEB_ITERATION)_$(DEB_ARCH).deb
	fpm -f -s deb -t rpm -n $(DEB_NAME) -v $(DEB_VERSION) --iteration $(DEB_ITERATION) -C $(DESTDIR) \
	$(DEB_NAME)_$(DEB_VERSION)-$(DEB_ITERATION)_$(DEB_ARCH).deb


.PHONY: package
package: package-deb package-rpm


.PHONY: package-deb
package-deb: $(DEB_NAME)_$(DEB_VERSION)-$(DEB_ITERATION)_$(DEB_ARCH).deb


.PHONY: package-rpm
package-rpm: $(DEB_NAME)-$(DEB_VERSION)-$(DEB_ITERATION).$(RPM_ARCH).rpm


clean:
	rm -f vip-manager
	rm -f vip-manager*.deb
	rm -f vip-manager*.rpm
	rm -fr $(DESTDIR)
