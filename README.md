# MIKEKA APP — FLUTTER MOBILE APPLICATION

Programu kamili ya simu ya Mikeka ya Leo Tanzania (Single-File Complete Flutter App).
Huu mradi umejengwa kwa kutumia faili kamili la Dart (`lib/main.dart`) linalounganishwa na REST API ya moja kwa moja kwenye:
`https://mikekaapp.co.tz/api.php` (inayoelekeza kwenye `https://mikekaapp.co.tz/api`).

---

## 📱 Miundombinu ya Flutter (Flutter Architecture)

- **Faili la Dart**: `/lib/main.dart` (ina mistari 1,000+ ya msimbo kamili bila kuhitaji faili zingine).
- **Faili la Configuration**: `/pubspec.yaml` (ina dependencies zote zinazohitajika: `http`, `flutter_secure_storage`, `shared_preferences`, `url_launcher`, `device_info_plus`, `flutter_local_notifications`).
- **Web Simulation & Preview**: Programu ya React/Vite inayoiga na kuendesha UI, API calls, na tabia za Flutter kwa 100%.

---

## 🚀 Jinsi ya Kuendesha kwenye Flutter (Run with Flutter)

Ili kujenga na kuendesha APK ya Android au toleo la iOS/Web kwa kutumia Flutter CLI:

```bash
# 1. Hakikisha una Flutter SDK iliyowekwa
flutter --version

# 2. Pakua package zote
flutter pub get

# 3. Endesha kwenye kifaa kilichounganishwa (au Emulator)
flutter run

# 4. Kujenga APK ya Android:
flutter build apk --release
```

---

## ✨ Vipengele Muhimu Vilivyojumuishwa (Features Included)

1. **Tipsters Tab**:
   - Orodha ya Tipsters maarufu Tanzania (Fundi majamvi, Master Mikeka Tz, KIBOKO YA MUHINDI, MZEE WA TRENI, GWIJI WA MIKEKA, n.k.)
   - Alama za uhakiki (Blue verified check)
   - Ukadiriaji wa nyota (Star rating)
   - Asilimia ya ushindi (Win rate %) na idadi ya tips
   - Kufuata / Kutofuata (Follow / Following toggle)
   - Ukurasa maalum wa taarifa za Tipster (`TipsterDetailScreen`)

2. **Mikeka ya Leo Tab**:
   - Orodha ya mikeka ya VIP na ya siku
   - Booking code zilizofichwa kwa wasio na kifurushi (`***`) na wazi kwa waliolipia
   - Nakili booking code (1-click copy)
   - Odds na takwimu za mechi
   - Vifurushi:
     - **NORMAL**: TSh 3,000/= (Siku 1 / Masaa 24)
     - **TANZANITE**: TSh 5,000/= (Siku 3 / Masaa 72)
     - **VIP**: TSh 10,000/= (Siku 7 / Wiki 1)
     - **VVIP**: TSh 30,000/= (Siku 30 / Mwezi 1)

3. **Single Slips Tab**:
   - Mikeka ya kununua mmoja mmoja kwa bei nafuu
   - Malipo ya moja kwa moja kwa kila mkeka
   - Orodha ya "Mikeka Yangu ya Single" iliyonunuliwa

4. **Profile Tab**:
   - Taarifa za akaunti na namba ya simu
   - Kaunta ya muda uliobaki wa kifurushi
   - Kubadilisha namba ya simu
   - Historia ya malipo yote (Completed / Pending)
   - Kiungo cha ukurasa wa washindi (`users.php`)
   - Kutoka kwenye akaunti (Logout)

5. **Malipo na USSD**:
   - Usaidizi wa mitandao yote: Vodacom, YAS, Airtel, Halotel
   - Uthibitishaji wa USSD push ("Angalia Simu Yako")
   - Polling ya hadhi ya malipo kila sekunde 2
   - Dirisha maalum la pongezi ya ushindi na malipo (Victory celebration)

6. **Tahadhari & Ushindi**:
   - Uchunguzi wa ushindi kila baada ya sekunde 20 (`check_new_win`)
   - Onyesho la kombe la dhahabu 🏆 ("UMESHINDA!")
   - Tahadhari za akaunti na usalama wa session (`check_session`)
