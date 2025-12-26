Name:           baru
Version:        1.0
Release:        1%{?dist}
Summary:        baru
License:        GPLv3

Source0:        baru
Source1:        org.sunaipa.baru.png
Source2:        org.sunaipa.baru.desktop
Source3:        data.tar.gz

%description
baru

%prep
# Nothing for binary
# If you have data.tar.gz
tar -xzf %{SOURCE3}

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/usr/bin/
install -m 755 %{SOURCE0} %{buildroot}/usr/bin/

# copy extracted data/lib if tar.gz
cp -r data lib %{buildroot}/usr/bin/

mkdir -p %{buildroot}/usr/share/icons/hicolor/256x256/apps/
install -m 644 %{SOURCE1} %{buildroot}/usr/share/icons/hicolor/256x256/apps/
mkdir -p %{buildroot}/usr/share/applications/
install -m 644 %{SOURCE2} %{buildroot}/usr/share/applications/

%files
/usr/bin/baru
/usr/bin/data
/usr/bin/lib
/usr/share/icons/hicolor/256x256/apps/org.sunaipa.baru.png
/usr/share/applications/org.sunaipa.baru.desktop
