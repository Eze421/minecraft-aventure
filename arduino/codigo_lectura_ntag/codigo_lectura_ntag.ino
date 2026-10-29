/* RC522 + NTAG213/215 (NFC Type 2) para uso futuro.
 * Mega: L1 SDA/RST=53/5, L2=49/6; SPI SCK=52 MOSI=51 MISO=50.
 * Lee el texto NDEF físico y emite READER=n;NDEF={"v":1,...}.
 * Usar junto a ../serial_ndef_bridge.py. No es para MIFARE Classic.
 */
#include <SPI.h>
#include <MFRC522.h>

constexpr byte ACTIVE_READER_COUNT = 2;
constexpr byte SS_PINS[] = {53, 49};
constexpr byte RST_PINS[] = {5, 6};
constexpr unsigned long REPEAT_DELAY_MS = 1200;
MFRC522 readers[] = {MFRC522(53, 5), MFRC522(49, 6)};
String lastUids[ACTIVE_READER_COUNT];
unsigned long lastReadAts[ACTIVE_READER_COUNT] = {};

String uidOf(MFRC522 &rfid) {
  String uid;
  for (byte index = 0; index < rfid.uid.size; index++) {
    if (rfid.uid.uidByte[index] < 0x10) uid += '0';
    uid += String(rfid.uid.uidByte[index], HEX);
  }
  uid.toUpperCase();
  return uid;
}

bool parseNdefText(const byte *data, uint16_t count, String &text) {
  uint16_t cursor = 0;
  while (cursor < count && data[cursor] == 0x00) cursor++;
  if (cursor >= count || data[cursor++] != 0x03 || cursor >= count) return false;
  uint16_t ndefLength = data[cursor++];
  if (ndefLength == 0xFF) {
    if (cursor + 1 >= count) return false;
    ndefLength = (uint16_t(data[cursor]) << 8) | data[cursor + 1];
    cursor += 2;
  }
  if (cursor + ndefLength > count || ndefLength < 5) return false;
  const uint16_t end = cursor + ndefLength;
  const byte header = data[cursor++];
  const byte typeLength = data[cursor++];
  if (!(header & 0x10) || cursor >= end) return false; // Solo short-record.
  uint16_t payloadLength = data[cursor++];
  if (typeLength != 1 || cursor + typeLength + payloadLength > end || data[cursor] != 'T') return false;
  cursor += typeLength;
  if (payloadLength < 1) return false;
  const byte languageLength = data[cursor++] & 0x3F;
  if (payloadLength < 1 + languageLength || cursor + languageLength > end) return false;
  cursor += languageLength;
  payloadLength -= 1 + languageLength;
  if (cursor + payloadLength > end) return false;
  text = "";
  for (uint16_t index = 0; index < payloadLength; index++) text += char(data[cursor + index]);
  return text.startsWith("{") && text.endsWith("}");
}

bool readNtagNdef(MFRC522 &rfid, String &text) {
  constexpr uint16_t MAX_BYTES = 160;
  byte data[MAX_BYTES];
  uint16_t count = 0;
  for (byte page = 4; count < MAX_BYTES; page += 4) {
    byte buffer[18];
    byte size = sizeof(buffer);
    if (rfid.MIFARE_Read(page, buffer, &size) != MFRC522::STATUS_OK) return false;
    for (byte index = 0; index < 16 && count < MAX_BYTES; index++) data[count++] = buffer[index];
  }
  return parseNdefText(data, count, text);
}

void setup() {
  Serial.begin(115200);
  SPI.begin();
  for (byte index = 0; index < ACTIVE_READER_COUNT; index++) {
    pinMode(SS_PINS[index], OUTPUT);
    digitalWrite(SS_PINS[index], HIGH);
  }
  for (byte index = 0; index < ACTIVE_READER_COUNT; index++) { readers[index].PCD_Init(); delay(4); }
  Serial.println(F("READY"));
  Serial.println(F("READER_CONNECTED"));
}

void scan(MFRC522 &rfid, byte readerId, String &lastUid, unsigned long &lastReadAt) {
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) return;
  const String uid = uidOf(rfid);
  const unsigned long now = millis();
  if (uid != lastUid || now - lastReadAt >= REPEAT_DELAY_MS) {
    String payload;
    if (readNtagNdef(rfid, payload)) {
      Serial.print(F("READER=")); Serial.print(readerId); Serial.print(F(";NDEF=")); Serial.println(payload);
    } else Serial.println(F("[NTAG] No se encontró NDEF de texto JSON."));
    lastUid = uid; lastReadAt = now;
  }
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}

void loop() {
  for (byte index = 0; index < ACTIVE_READER_COUNT; index++) scan(readers[index], index + 1, lastUids[index], lastReadAts[index]);
}
