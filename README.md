## Installation

```bash
$ yarn install
```

## Running the app

```bash
# development
$ yarn start

# production mode
$ yarn start:prod

# build
$ yarn build
```

## ENV

```bash
# development
$ export DB_HOST=localhost
# port
$ export DB_PORT=5432
# name postgres db
$ export DB_DATABASE=essence_report
# User
$ export DB_USERNAME=s_uc
# Password DB
$ export DB_PASSWORD=s_uc
# minimum connect pool db
$ export DB_POOL_MAX=5
# minimum connect pool db
$ export DB_POOL_MIN=1
# http port listener
$ export ESSENCE_REPORT_PORT=8020
```

# Centos chrome PDF
```
yum install pango.x86_64 libXcomposite.x86_64 libXcursor.x86_64 libXdamage.x86_64 libXext.x86_64 libXi.x86_64 libXtst.x86_64 cups-libs.x86_64 libXScrnSaver.x86_64 libXrandr.x86_64 GConf2.x86_64 alsa-lib.x86_64 atk.x86_64 gtk3.x86_64 -y

yum install ipa-gothic-fonts xorg-x11-fonts-100dpi xorg-x11-fonts-75dpi xorg-x11-utils xorg-x11-fonts-cyrillic xorg-x11-fonts-Type1 xorg-x11-fonts-misc -y
```

## Docker
```bash
docker build -t essence-report:dev .
docker run --name some-essence-report -p 8020:8020 -d essence-report:dev 
``` 

## License

essence-report Service is [MIT licensed](LICENSE).