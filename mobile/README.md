# MediGo mobile

## Production API

The app defaults to the public Railway backend over HTTPS:
`https://medical-suivi-api-production.up.railway.app/api`.

Build a release APK with:

```sh
cd mobile
flutter build apk --release
```

The APK is written to
`build/app/outputs/flutter-apk/app-release.apk`.

## Local development

For local development, start the backend from the repository root:

```sh
npm run dev
```

Then run the app with your computer's LAN address:

```sh
cd mobile
flutter run --dart-define=API_BASE_URL=http://<COMPUTER_LAN_IP>:5001/api
```

Use the computer's Wi-Fi address, not `127.0.0.1`, `localhost`, or a Docker
address such as `172.17.x.x`. If the connection fails, allow inbound TCP port
5001 through the computer's firewall. An Android emulator can use
`http://10.0.2.2:5001/api`.
