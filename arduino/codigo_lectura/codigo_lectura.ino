/*
 * Lector RC522 para Minecraft Aventure.
 *
 * Placa Arduino Mega 2560 -> hasta 9 RC522 (SPI compartido):
 *
 *                L1    L2    L3    L4    L5    L6    L7    L8    L9
 *   SDA/SS       D53   D49   D47   D45   D43   D41   D39   D37   D35
 *   RST          D5    D6    D7    D8    D9    D10   D11   D12   D13
 *   SCK          D52   D52   D52   D52   D52   D52   D52   D52   D52
 *   MOSI         D51   D51   D51   D51   D51   D51   D51   D51   D51
 *   MISO         D50   D50   D50   D50   D50   D50   D50   D50   D50
 *   3.3V    -> 3.3V  (NO conectar a 5V)
 *   GND     -> GND
 *
 * Instalá desde el Library Manager la biblioteca "MFRC522" de Miguel Balboa.
 * Para activar más lectores, aumentá ACTIVE_READER_COUNT hasta un máximo de 9.
 * Cada lectura se imprime como: READER=1;UID=04A1B2C3D4
 * El puente local serial_nfc_bridge.py traduce esos UID a JSON NDEF para Godot.
 */

#include <SPI.h>
#include <MFRC522.h>

constexpr byte MAX_READER_COUNT = 9;
// Actualmente hay dos lectores cableados. Cambiar a 3..9 al conectar cada uno.
constexpr byte ACTIVE_READER_COUNT = 2;
constexpr unsigned long REPEAT_DELAY_MS = 1200;

struct ReaderConfig {
  byte ssPin;
  byte rstPin;
};

const ReaderConfig READER_CONFIGS[MAX_READER_COUNT] = {
  {53, 5},   // Lector 1: cableado actual.
  {49, 6},   // Lector 2: cableado actual.
  {47, 7},   // Lector 3: reservado.
  {45, 8},   // Lector 4: reservado.
  {43, 9},   // Lector 5: reservado.
  {41, 10},  // Lector 6: reservado.
  {39, 11},  // Lector 7: reservado.
  {37, 12},  // Lector 8: reservado.
  {35, 13},  // Lector 9: reservado.
};

MFRC522 readers[MAX_READER_COUNT] = {
  MFRC522(READER_CONFIGS[0].ssPin, READER_CONFIGS[0].rstPin),
  MFRC522(READER_CONFIGS[1].ssPin, READER_CONFIGS[1].rstPin),
  MFRC522(READER_CONFIGS[2].ssPin, READER_CONFIGS[2].rstPin),
  MFRC522(READER_CONFIGS[3].ssPin, READER_CONFIGS[3].rstPin),
  MFRC522(READER_CONFIGS[4].ssPin, READER_CONFIGS[4].rstPin),
  MFRC522(READER_CONFIGS[5].ssPin, READER_CONFIGS[5].rstPin),
  MFRC522(READER_CONFIGS[6].ssPin, READER_CONFIGS[6].rstPin),
  MFRC522(READER_CONFIGS[7].ssPin, READER_CONFIGS[7].rstPin),
  MFRC522(READER_CONFIGS[8].ssPin, READER_CONFIGS[8].rstPin),
};

String lastUids[MAX_READER_COUNT];
unsigned long lastReadAts[MAX_READER_COUNT] = {};

String readUid(MFRC522 &rfid) {
  String uid;
  for (byte index = 0; index < rfid.uid.size; index++) {
    if (rfid.uid.uidByte[index] < 0x10) uid += '0';
    uid += String(rfid.uid.uidByte[index], HEX);
  }
  uid.toUpperCase();
  return uid;
}

// Extrae el primer registro NDEF de texto del área de datos ya leída.
bool parseNdefText(const byte *data, uint16_t count, String &text) {
  uint16_t tlv = 0;
  while (tlv < count && data[tlv] == 0x00) tlv++;
  if (tlv >= count || data[tlv++] != 0x03) return false; // NDEF TLV
  uint16_t ndefLength = data[tlv++];
  if (ndefLength == 0xFF) {
    if (tlv + 1 >= count) return false;
    ndefLength = (uint16_t(data[tlv]) << 8) | data[tlv + 1];
    tlv += 2;
  }
  if (tlv + ndefLength > count || ndefLength < 5) return false;

  const uint16_t end = tlv + ndefLength;
  const byte header = data[tlv++];
  const byte typeLength = data[tlv++];
  uint32_t payloadLength = 0;
  if (header & 0x10) payloadLength = data[tlv++]; // Short Record
  else {
    if (tlv + 3 >= end) return false;
    payloadLength = (uint32_t(data[tlv]) << 24) | (uint32_t(data[tlv + 1]) << 16) |
                    (uint32_t(data[tlv + 2]) << 8) | data[tlv + 3];
    tlv += 4;
  }
  if (typeLength != 1 || tlv + typeLength + payloadLength > end || data[tlv] != 'T') return false;
  tlv += typeLength;
  if (payloadLength < 1) return false;
  const byte languageLength = data[tlv] & 0x3F;
  tlv += 1 + languageLength;
  payloadLength -= 1 + languageLength;
  if (tlv + payloadLength > end) return false;
  text = "";
  for (uint32_t index = 0; index < payloadLength; index++) text += char(data[tlv + index]);
  return text.startsWith("{") && text.endsWith("}");
}

// Lee NDEF de NTAG213/215 (NFC-A Type 2). MIFARE_Read devuelve 4 páginas
// consecutivas (16 bytes) desde la página indicada.
bool readType2NdefText(MFRC522 &rfid, String &text) {
  const uint16_t maxBytes = 160;
  byte data[maxBytes];
  uint16_t count = 0;
  for (byte page = 4; count < maxBytes; page += 4) {
    byte buffer[18];
    byte size = sizeof(buffer);
    if (rfid.MIFARE_Read(page, buffer, &size) != MFRC522::STATUS_OK) return false;
    for (byte index = 0; index < 16 && count < maxBytes; index++) data[count++] = buffer[index];
  }
  return parseNdefText(data, count, text);
}

// Lee MIFARE Classic 1K en formato NDEF. Android suele dejar la clave A por
// defecto o la clave pública NFC Forum (D3 F7 D3 F7 D3 F7) en los sectores
// NDEF. Solo se usan bloques de datos, nunca los trailers de sector.
bool authenticateClassicSector(MFRC522 &rfid, byte trailerBlock) {
  const byte keys[][MFRC522::MF_KEY_SIZE] = {
    {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF},
    {0xD3, 0xF7, 0xD3, 0xF7, 0xD3, 0xF7},
  };
  MFRC522::MIFARE_Key key;
  for (byte candidate = 0; candidate < 2; candidate++) {
    for (byte index = 0; index < MFRC522::MF_KEY_SIZE; index++) key.keyByte[index] = keys[candidate][index];
    if (rfid.PCD_Authenticate(MFRC522::PICC_CMD_MF_AUTH_KEY_A, trailerBlock, &key, &(rfid.uid))
        == MFRC522::STATUS_OK) return true;
  }
  return false;
}

bool readClassicNdefText(MFRC522 &rfid, String &text) {
  const uint16_t maxBytes = 256;
  byte data[maxBytes];
  uint16_t count = 0;

  for (byte sector = 1; sector < 16 && count < maxBytes; sector++) {
    const byte trailerBlock = sector * 4 + 3;
    if (!authenticateClassicSector(rfid, trailerBlock)) {
      continue;
    }
    for (byte offset = 0; offset < 3 && count < maxBytes; offset++) {
      byte buffer[18];
      byte size = sizeof(buffer);
      if (rfid.MIFARE_Read(sector * 4 + offset, buffer, &size) != MFRC522::STATUS_OK) continue;
      for (byte index = 0; index < 16 && count < maxBytes; index++) data[count++] = buffer[index];
    }
  }
  return parseNdefText(data, count, text);
}

bool readNdefText(MFRC522 &rfid, MFRC522::PICC_Type type, String &text) {
  if (type == MFRC522::PICC_TYPE_MIFARE_1K || type == MFRC522::PICC_TYPE_MIFARE_4K) {
    return readClassicNdefText(rfid, text);
  }
  return readType2NdefText(rfid, text);
}

void setup() {
  Serial.begin(115200);
  SPI.begin();

  // Mantiene todos los RC522 deseleccionados antes de inicializarlos.
  for (byte index = 0; index < ACTIVE_READER_COUNT; index++) {
    pinMode(READER_CONFIGS[index].ssPin, OUTPUT);
    digitalWrite(READER_CONFIGS[index].ssPin, HIGH);
  }
  for (byte index = 0; index < ACTIVE_READER_COUNT; index++) {
    readers[index].PCD_Init();
    delay(4);
  }

  Serial.print(F("[RC522] "));
  Serial.print(ACTIVE_READER_COUNT);
  Serial.println(F(" lector(es) iniciados a 115200 baudios."));
  Serial.println(F("[RC522] Acerque una tarjeta NFC/RFID a cualquier lector."));
  Serial.println(F("READY"));
  Serial.println(F("READER_CONNECTED"));
}

void scanReader(MFRC522 &rfid, byte readerId, String &lastUid, unsigned long &lastReadAt) {
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) return;

  const String uid = readUid(rfid);
  const MFRC522::PICC_Type type = rfid.PICC_GetType(rfid.uid.sak);
  const unsigned long now = millis();
  if (uid != lastUid || now - lastReadAt >= REPEAT_DELAY_MS) {
    // Mensajes legibles para el Monitor Serie.
    Serial.print(F("\n[RC522] Tarjeta detectada en lector "));
    Serial.println(readerId);
    Serial.print(F("[RC522] UID: "));
    Serial.println(uid);
    Serial.print(F("[RC522] Tipo: "));
    Serial.println(rfid.PICC_GetTypeName(type));

    // La ruta de MIFARE Classic actual usa el UID como clave de un mapa local.
    Serial.print(F("READER="));
    Serial.print(readerId);
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

void loop() {
  // Se consultan secuencialmente; cada uno informa READER=1..9.
  for (byte index = 0; index < ACTIVE_READER_COUNT; index++) {
    scanReader(readers[index], index + 1, lastUids[index], lastReadAts[index]);
  }
}
