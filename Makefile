BUILDDIR	?= /tmp/ssmbuild
VERSION		?=
RELEASE		?= 2

SOURCE_COMMIT = fd77686af847cb44a9966b7eacce32dc9668d96e

.PHONY: all
all:

ifeq (0, $(shell hash dpkg 2>/dev/null; echo $$?))
ARCH := $(shell dpkg --print-architecture)
all: sdeb deb
else
ARCH := $(shell rpm --eval "%{_arch}")
all: srpm rpm
endif

SRPM_FILE	:= $(BUILDDIR)/results/SRPMS/percona-toolkit-$(VERSION)-$(RELEASE).src.rpm
RPM_FILE	:= $(BUILDDIR)/results/RPMS/percona-toolkit-$(VERSION)-$(RELEASE).$(ARCH).rpm
SDEB_FILES	:= $(BUILDDIR)/results/SDEBS/percona-toolkit_$(VERSION)-$(RELEASE).dsc $(BUILDDIR)/results/SDEBS/percona-toolkit_$(VERSION)-$(RELEASE).tar.gz
DEB_FILES	:= $(BUILDDIR)/results/DEBS/percona-toolkit_$(VERSION)-$(RELEASE)_$(ARCH).deb $(BUILDDIR)/results/DEBS/percona-toolkit_$(VERSION)-$(RELEASE)_$(ARCH).changes

.PHONY: srpm
srpm: $(SRPM_FILE)

$(SRPM_FILE):
	mkdir -vp $(BUILDDIR)/rpmbuild/{SOURCES,SPECS,BUILD,SRPMS,RPMS}
	mkdir -vp $(shell dirname $(SRPM_FILE))

	cp percona-toolkit.spec $(BUILDDIR)/rpmbuild/SPECS/percona-toolkit.spec
	sed -i -E 's/%\{\??_version\}/$(VERSION)/g' $(BUILDDIR)/rpmbuild/SPECS/percona-toolkit.spec
	sed -i -E 's/%\{\??_release\}/$(RELEASE)/g' $(BUILDDIR)/rpmbuild/SPECS/percona-toolkit.spec
	sed -i -E 's/%\{\??_commit\}/$(SOURCE_COMMIT)/g' $(BUILDDIR)/rpmbuild/SPECS/percona-toolkit.spec
	spectool -C $(BUILDDIR)/rpmbuild/SOURCES -g $(BUILDDIR)/rpmbuild/SPECS/percona-toolkit.spec

	tar -C $(BUILDDIR)/rpmbuild/SOURCES/ -zxf $(BUILDDIR)/rpmbuild/SOURCES/percona-toolkit-$(SOURCE_COMMIT).tar.gz
	cd $(BUILDDIR)/rpmbuild/SOURCES/percona-toolkit-$(SOURCE_COMMIT) && GOTOOLCHAIN=auto go mod vendor && tar -czf $(BUILDDIR)/rpmbuild/SOURCES/percona-toolkit-$(SOURCE_COMMIT).tar.gz -C $(BUILDDIR)/rpmbuild/SOURCES percona-toolkit-$(SOURCE_COMMIT)

	rpmbuild -bs --define "debug_package %{nil}" --define "_topdir $(BUILDDIR)/rpmbuild" $(BUILDDIR)/rpmbuild/SPECS/percona-toolkit.spec
	mv $(BUILDDIR)/rpmbuild/SRPMS/$(shell basename $(SRPM_FILE)) $(SRPM_FILE)

.PHONY: rpm
rpm: $(RPM_FILE)

$(RPM_FILE): $(SRPM_FILE)
	mkdir -vp $(BUILDDIR)/mock $(shell dirname $(RPM_FILE))
	mock -r ssm-9-$(ARCH) --resultdir $(BUILDDIR)/mock --rebuild $(SRPM_FILE)
	mv $(BUILDDIR)/mock/$(shell basename $(RPM_FILE)) $(RPM_FILE)

.PHONY: sdeb
sdeb: $(SDEB_FILES)

$(SDEB_FILES):
	mkdir -vp $(BUILDDIR)/debbuild/SDEB/percona-toolkit-$(VERSION)-$(RELEASE)
	cp -r debian $(BUILDDIR)/debbuild/SDEB/percona-toolkit-$(VERSION)-$(RELEASE)/debian
	curl -sL -o $(BUILDDIR)/debbuild/SDEB/percona-toolkit-$(VERSION)-$(RELEASE)/percona-toolkit.tar.gz https://github.com/shatteredsilicon/percona-toolkit/archive/$(SOURCE_COMMIT)/percona-toolkit-$(SOURCE_COMMIT).tar.gz
	cd $(BUILDDIR)/debbuild/SDEB/percona-toolkit-$(VERSION)-$(RELEASE) && \
		tar -zxf percona-toolkit.tar.gz && \
		cd percona-toolkit-$(SOURCE_COMMIT) && \
			GOTOOLCHAIN=auto go mod vendor && \
			cd .. && \
		tar -czf percona-toolkit.tar.gz percona-toolkit-$(SOURCE_COMMIT)

	cd $(BUILDDIR)/debbuild/SDEB/percona-toolkit-$(VERSION)-$(RELEASE)/; \
		sed -i "s/%{_version}/$(VERSION)/g"  debian/control; \
		sed -i "s/%{_release}/$(RELEASE)/g"  debian/control; \
		sed -i "s/%{_commit}/$(SOURCE_COMMIT)/g"  debian/control; \
		sed -i "s/%{_version}/$(VERSION)/g"  debian/rules; \
		sed -i "s/%{_release}/$(RELEASE)/g"  debian/rules; \
		sed -i "s/%{_commit}/$(SOURCE_COMMIT)/g"  debian/rules; \
		sed -i "s/%{_version}/$(VERSION)/g"  debian/changelog; \
		sed -i "s/%{_release}/$(RELEASE)/g"  debian/changelog; \
		sed -i "s/%{_commit}/$(SOURCE_COMMIT)/g"  debian/changelog; \
		dpkg-buildpackage -S -us

	for sdeb_file in $(SDEB_FILES); do \
		mkdir -vp $$(dirname $${sdeb_file}); \
		mv -f $(BUILDDIR)/debbuild/SDEB/$$(basename $${sdeb_file}) $${sdeb_file}; \
	done

.PHONY: deb
deb: $(DEB_FILES)

$(DEB_FILES): $(SDEB_FILES)
	mkdir -vp $(BUILDDIR)/debbuild/DEB/percona-toolkit-$(VERSION)-$(RELEASE)
	for sdeb_file in $(SDEB_FILES); do \
		cp -r $${sdeb_file} $(BUILDDIR)/debbuild/DEB/percona-toolkit-$(VERSION)-$(RELEASE)/; \
	done

	cd $(BUILDDIR)/debbuild/DEB/percona-toolkit-$(VERSION)-$(RELEASE)/; \
		rm -rf percona-toolkit-$(VERSION); \
		dpkg-source -x -sp percona-toolkit_$(VERSION)-$(RELEASE).dsc; \
		cd percona-toolkit-$(VERSION); \
			dpkg-buildpackage -b -uc

	for deb_file in $(DEB_FILES); do \
		mkdir -vp $$(dirname $${deb_file}); \
		mv -f $(BUILDDIR)/debbuild/DEB/percona-toolkit-$(VERSION)-$(RELEASE)/$$(basename $${deb_file}) $${deb_file}; \
	done

.PHONY: clean
clean:
	rm -rf $(BUILDDIR)/{rpmbuild,mock,results}
