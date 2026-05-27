%define debug_package   %{nil}
%define _GOPATH         %{_builddir}/go

%global provider                github
%global provider_tld            com
%global project                 shatteredsilicon
%global repo                    percona-toolkit
%global import_path             %{provider}.%{provider_tld}/%{project}/%{repo}

Name:           %{repo}
Summary:        Percona Toolkit (Shattered Silicon Build)
Version:        %{_version}
Release:        %{_release}
License:        GPL-2.0
Vendor:         Percona LLC
URL:            https://percona.com
Source0:        https://%{import_path}/archive/%{_commit}/%{repo}-%{_commit}.tar.gz
BuildRequires:  golang

Requires: perl(DBI)
Requires: (perl(DBD::mysql) or perl(DBD::MariaDB))
Requires: perl(Time::HiRes)
Requires: perl(IO::Socket::SSL)
Requires: perl(Digest::MD5)
Requires: perl(Term::ReadKey)

Recommends: (perl(DBD::MariaDB) if MariaDB-common else perl(DBD::mysql))

%description
Percona Toolkit (Shattered Silicon Build)

%prep
%setup -q -n %{repo}-%{_commit}

%build
mkdir -p %{_GOPATH}/bin
export GOPATH=%{_GOPATH}
export GO111MODULE=off
export CGO_ENABLED=0

%{__mkdir_p} %{_GOPATH}/src/github.com/percona

ln -s %{_builddir}/%{repo}-%{_commit} %{_GOPATH}/src/github.com/percona/percona-toolkit

pushd %{_GOPATH}/src/github.com/percona/percona-toolkit
    go install -ldflags="-s -w" ./src/go/pt-*
popd
%{__cp} bin/* %{_GOPATH}/bin

strip %{_GOPATH}/bin/* || true

%install
install -m 0755 -d $RPM_BUILD_ROOT/usr/bin
install -m 0755 %{_GOPATH}/bin/pt-* $RPM_BUILD_ROOT/usr/bin/

%clean
rm -rf $RPM_BUILD_ROOT

%files
/usr/bin/pt-*
