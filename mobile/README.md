# MediGo mobile

## Run on a physical Android device

The phone and computer must be connected to the same Wi-Fi network. Start the
backend from the repository root:

```sh
npm run dev
```

Then run the app from a second terminal:

```sh
cd mobile
flutter run
```

The Android app defaults to the computer's current LAN address,
`http://192.168.100.4:5001/api`; the backend listens on all network interfaces.
If the computer's address changes, find its Wi-Fi IPv4 address with
`hostname -I`, then pass it when launching Flutter:

```sh
cd mobile
flutter run --dart-define=API_BASE_URL=http://<COMPUTER_LAN_IP>:5001/api
```

Use the computer's Wi-Fi address, not `127.0.0.1`, `localhost`, or a Docker
address such as `172.17.x.x`. If the connection still fails, allow inbound TCP
port 5001 through the computer's firewall. An Android emulator can use
`http://10.0.2.2:5001/api` instead.
