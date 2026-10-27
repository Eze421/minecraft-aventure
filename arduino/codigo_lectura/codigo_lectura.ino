/*
 * Lector RC522 para Minecraft Aventure.
 *
 * Placa Arduino Mega 2560 -> RC522 (SPI):
 *   SDA/SS  -> D53
 *   SCK     -> D52
 *   MOSI    -> D51
 *   MISO    -> D50
 *   RST     -> D5
 *   3.3V    -> 3.3V  (NO conectar a 5V)
 *   GND     -> GND
 *
 * Instalá desde el Library Manager la biblioteca "MFRC522" de Miguel Balboa.
 * Cada lectura se imprime como: READER=1;UID=04A1B2C3D4
 * Ese es el formato que NfcEventSource.parse_serial_message() ya entiende.
 */

#include <SPI.h>
#include <MFRC522.h>

constexpr byte SS_PIN = 53;
constexpr byte RST_PIN = 5;
constexpr byte READER_ID = 1;
constexpr unsigned long REPEAT_DELAY_MS = 1200;

MFRC522 rfid(SS_PIN, RST_PIN);
String lastUid = "";
unsigned long lastReadAt = 0;

String readUid() {
  String uid;
  for (byte index = 0; index < rfid.uid.size; index++) {
    if (rfid.uid.uidByte[index] < 0x10) uid += '0';
    uid += String(rfid.uid.uidByte[index], HEX);
  }
  uid.toUpperCase();
  return uid;
}

void setup() {
  Serial.begin(115200);
  SPI.begin();
  rfid.PCD_Init();
  Serial.println(F("[RC522] Lector iniciado a 115200 baudios."));
  Serial.println(F("[RC522] Acerque una tarjeta NFC/RFID al lector."));
  Serial.println(F("READY"));
  Serial.println(F("READER_CONNECTED"));
}

void loop() {
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) return;

  const String uid = readUid();
  const MFRC522::PICC_Type type = rfid.PICC_GetType(rfid.uid.sak);
  const unsigned long now = millis();
  if (uid != lastUid || now - lastReadAt >= REPEAT_DELAY_MS) {
    // Mensajes legibles para el Monitor Serie.
    Serial.println(F("\n[RC522] Tarjeta detectada"));
    Serial.print(F("[RC522] UID: "));
    Serial.println(uid);
    Serial.print(F("[RC522] Tipo: "));
    Serial.println(rfid.PICC_GetTypeName(type));

    // Línea estable para el juego y para serial_nfc_bridge.py.
    Serial.print(F("READER="));
    Serial.print(READER_ID);
    Serial.print(F(";UID="));
    Serial.println(uid);

    lastUid = uid;
    lastReadAt = now;
  } else {
    Serial.println(F("[RC522] Misma tarjeta ignorada temporalmente."));
  }

  // Libera la tarjeta y la autenticación; no se leen ni escriben sus sectores.
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}
