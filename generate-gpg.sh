#!/bin/bash
#
# https://jon.sprig.gs/blog/post/2835
# https://earthly.dev/blog/creating-and-hosting-your-own-deb-packages-and-apt-repo/
#

cat > pgp-key.batch << 'END'
%echo Generating PGP key for repository
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Jose Riguera
Name-Email: jriguera@users.noreply.github.com
Expire-Date: 0
%no-ask-passphrase
%no-protection
# Do a commit here, so that we can later print "done" :-)
%commit
END

export GNUPGHOME="$(mktemp -d /tmp/pgpkeys-XXXXXX)"
trap "echo Cleaning ${GNUPGHOME}; rm -Rf ${GNUPGHOME}" EXIT SIGINT SIGTERM SIGKILL
gpg --no-tty --batch --full-gen-key pgp-key.batch
gpg --list-secret-keys --with-subkey-fingerprint
gpg --armor --export --output pgp-key.public 'jriguera@users.noreply.github.com'
gpg --armor --export-secret-keys --output pgp-key.private 'jriguera@users.noreply.github.com'
gpg --armor --export-secret-subkeys --output pgp-subkey.private 'jriguera@users.noreply.github.com'
