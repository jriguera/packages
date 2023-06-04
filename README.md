# Ubuntu / Debian Repository

Package repository using github pages

This is the repository that I use for publishing application packages.

List of current [packages](PACKAGES.md) in the repositories.

## Ubuntu

| version | name   |
|---------|--------|
| 22.04   | jammy  |

## Debian

|version|name|
|------|------|
|11|bullseye|

## Setup Repository

```
    sudo apt-get install apt-transport-https
    wget -qO - https://jose.riguera.es/packages/gpg | sudo apt-key add -
    echo "deb https://jose.riguera.es/packages/apt debian main" | sudo tee /etc/apt/sources.list.d/my-packages.list
```

