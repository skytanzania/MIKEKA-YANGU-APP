# Network logos

Put the official mobile-money logos here as PNG files (transparent or white
background, about 200 px wide). The file name must match the network code:

| File            | Network         |
|-----------------|-----------------|
| `vodacom.png`   | M-Pesa          |
| `yas.png`       | Mixx by Yas     |
| `airtel.png`    | Airtel Money    |
| `halotel.png`   | HaloPesa        |

Commit and push; the next APK and web build include them.
If a file is missing, the app shows a coloured badge with the wallet name.

You can also send logos from the server instead: add `logo_url` to each item
in `networks` in `GET config` — that takes priority over these files.
