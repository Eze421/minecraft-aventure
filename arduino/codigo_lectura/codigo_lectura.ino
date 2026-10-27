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
 * Ese es el formato que NfcEventSource.parse_serial_message() ya entiende.
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

    // Línea estable para el juego y para serial_nfc_bridge.py.
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
