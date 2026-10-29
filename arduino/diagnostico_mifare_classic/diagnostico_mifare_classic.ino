/*
 * Diagnóstico de solo lectura para MIFARE Classic 1K / RC522.
 *
 * Arduino Mega 2560, SPI compartido:
 *                 Lector 1   Lector 2
 *   SDA / SS      D53         D49
 *   RST           D5          D6
 *   SCK           D52         D52
 *   MOSI          D51         D51
 *   MISO          D50         D50
 *   3.3V          3.3V        3.3V   (nunca 5V)
 *
 * No escribe, formatea ni cambia claves. Solo intenta leer sectores con las
 * claves públicas típicas de MIFARE/NFC Forum y muestra los bloques legibles.
 * Abrir el Monitor Serie a 115200 baudios y acercar una tarjeta por vez.
 */

#include <SPI.h>
#include <MFRC522.h>

constexpr byte ACTIVE_READER_COUNT = 1;
constexpr byte READER_SS[ACTIVE_READER_COUNT] = {53};
constexpr byte READER_RST[ACTIVE_READER_COUNT] = {5};
constexpr unsigned long REPEAT_DELAY_MS = 2000;

MFRC522 readers[ACTIVE_READER_COUNT] = {
  MFRC522(READER_SS[0], READER_RST[0]),
};

String lastUids[ACTIVE_READER_COUNT];
unsigned long lastReadAts[ACTIVE_READER_COUNT] = {};

const byte KNOWN_KEYS[][MFRC522::MF_KEY_SIZE] = {
  {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF}, // Clave de fábrica habitual.
  {0xD3, 0xF7, 0xD3, 0xF7, 0xD3, 0xF7}, // Clave A pública NFC Forum.
  {0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5}, // Clave MAD pública.
};
constexpr byte KNOWN_KEY_COUNT = sizeof(KNOWN_KEYS) / sizeof(KNOWN_KEYS[0]);

String uidToString(MFRC522 &rfid) {
  String uid;
  for (byte index = 0; index < rfid.uid.size; index++) {
    if (rfid.uid.uidByte[index] < 0x10) uid += '0';
    uid += String(rfid.uid.uidByte[index], HEX);
  }
  uid.toUpperCase();
  return uid;
}

void printHex(const byte *data, byte length) {
  for (byte index = 0; index < length; index++) {
    if (data[index] < 0x10) Serial.print('0');
    Serial.print(data[index], HEX);
    if (index + 1 < length) Serial.print(' ');
  }
}

void printAscii(const byte *data, byte length) {
  Serial.print('"');
  for (byte index = 0; index < length; index++) {
    const char character = char(data[index]);
    Serial.print(character >= 32 && character <= 126 ? character : '.');
  }
  Serial.print('"');
}

int authenticateSector(MFRC522 &rfid, byte sector) {
  const byte trailerBlock = sector * 4 + 3;
  MFRC522::MIFARE_Key key;
  for (byte candidate = 0; candidate < KNOWN_KEY_COUNT; candidate++) {
    for (byte index = 0; index < MFRC522::MF_KEY_SIZE; index++) {
      key.keyByte[index] = KNOWN_KEYS[candidate][index];
    }
    if (rfid.PCD_Authenticate(MFRC522::PICC_CMD_MF_AUTH_KEY_A, trailerBlock, &key, &(rfid.uid))
        == MFRC522::STATUS_OK) {
      return candidate;
    }
  }
  return -1;
}

void dumpClassic1K(MFRC522 &rfid) {
  Serial.println(F("[Diagnóstico] Tipo MIFARE Classic: inspeccionando sectores 0 a 15."));
  Serial.println(F("[Diagnóstico] Solo se muestran claves públicas/conocidas; no se intenta adivinar claves."));
  for (byte sector = 0; sector < 16; sector++) {
    const int keyIndex = authenticateSector(rfid, sector);
    Serial.print(F("Sector "));
    Serial.print(sector);
    if (keyIndex < 0) {
      Serial.println(F(": sin acceso con claves conocidas."));
      continue;
    }
    Serial.print(F(": acceso con clave #"));
    Serial.println(keyIndex + 1);
    for (byte offset = 0; offset < 3; offset++) { // Evita el trailer de claves.
      const byte block = sector * 4 + offset;
      byte buffer[18];
      byte size = sizeof(buffer);
      const MFRC522::StatusCode result = rfid.MIFARE_Read(block, buffer, &size);
      Serial.print(F("  Bloque "));
      Serial.print(block);
      Serial.print(F(": "));
      if (result != MFRC522::STATUS_OK) {
        Serial.println(rfid.GetStatusCodeName(result));
        continue;
      }
      printHex(buffer, 16);
      Serial.print(F("  "));
      printAscii(buffer, 16);
      if (buffer[0] == 0x03) Serial.print(F("  <-- posible inicio TLV NDEF"));
      Serial.println();
    }
    rfid.PCD_StopCrypto1();
  }
}

void diagnoseReader(MFRC522 &rfid, byte readerId, String &lastUid, unsigned long &lastReadAt) {
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) return;
  const String uid = uidToString(rfid);
  const unsigned long now = millis();
  if (uid == lastUid && now - lastReadAt < REPEAT_DELAY_MS) {
    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();
    return;
  }

  const MFRC522::PICC_Type type = rfid.PICC_GetType(rfid.uid.sak);
  Serial.println();
  Serial.print(F("========== LECTOR "));
  Serial.print(readerId);
  Serial.println(F(" =========="));
  Serial.print(F("UID: "));
  Serial.println(uid);
  Serial.print(F("Tipo: "));
  Serial.println(rfid.PICC_GetTypeName(type));

  if (type == MFRC522::PICC_TYPE_MIFARE_1K) {
    dumpClassic1K(rfid);
  } else {
    Serial.println(F("Este diagnóstico está dirigido a MIFARE Classic 1K."));
  }
  Serial.println(F("================================"));
  lastUid = uid;
  lastReadAt = now;
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}

void setup() {
  Serial.begin(115200);
  SPI.begin();
  for (byte index = 0; index < ACTIVE_READER_COUNT; index++) {
    pinMode(READER_SS[index], OUTPUT);
    digitalWrite(READER_SS[index], HIGH);
  }
  for (byte index = 0; index < ACTIVE_READER_COUNT; index++) {
    readers[index].PCD_Init();
    delay(4);
  }
  Serial.println(F("Diagnóstico MIFARE Classic listo. Acercá una tarjeta."));
}

void loop() {
  for (byte index = 0; index < ACTIVE_READER_COUNT; index++) {
    diagnoseReader(readers[index], index + 1, lastUids[index], lastReadAts[index]);
  }
}
