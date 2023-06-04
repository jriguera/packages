# Deb/RPM Repositories

Multi distribution package repository using Github Pages.

This is the repository that I use for publishing application packages.

Public GPG key is https://jose.riguera.es/packages/gpg

## Debian based distributions supported

|distribution   |version|codename     |
|---------------|-------|-------------|
|Debian         |11     |bullseye     |
|Ubuntu         |22.04  |jammy        |

List of current [packages](PACKAGES-deb.md) in the repositories.

### Setup Repositories

```
    sudo apt-get install apt-transport-https
    wget -qO - https://jose.riguera.es/packages/gpg | sudo apt-key add -
    echo "deb https://jose.riguera.es/packages/deb debian main" | sudo tee /etc/apt/sources.list.d/jackages.list
```

## RedHat based distributions

|name            |version         |
|----------------|----------------|
|Rocky Linux     |9               |

List of current [packages](PACKAGES-rpm.md) in the repositories.

### Setup Repositories

```
    sudo cat <<-EOF > /etc/yum/repos.d/jackages.repo
		[jackages]
		name=jackages repository
		baseurl=https://jose.riguera.es/packages/rpm/$releasever/$basearch
		enabled=1
		gpgkey=https://jose.riguera.es/packages/gpg
		gpgcheck=0
		repo_gpgcheck=1
		EOF
```
