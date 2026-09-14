package ar.edu.nfcbridge;

import android.nfc.NdefMessage;
import android.nfc.NdefRecord;
import android.nfc.NfcAdapter;
import android.nfc.Tag;
import android.nfc.tech.Ndef;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.TextView;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Lector NDEF de texto para enviar tarjetas a Godot por Wi-Fi. */
public class MainActivity extends android.app.Activity {
    private static final String DEFAULT_ENDPOINT = "http://192.168.100.48:8080/nfc";
    private static final CardPreset[] CARD_PRESETS = {
            new CardPreset("Madera", "CARD_001", "Madera", "wood"),
            new CardPreset("Piedra", "CARD_002", "Piedra", "stone"),
            new CardPreset("Hierro", "CARD_003", "Hierro", "iron")
    };
    private NfcAdapter nfcAdapter;
    private EditText endpointInput;
    private EditText cardIdInput;
    private EditText cardNameInput;
    private EditText cardTypeInput;
    private TextView status;
    private TextView payloadView;
    private Button continuousButton;
    private boolean readerModeEnabled = false;
    private volatile Mode mode = Mode.NONE;
    private String pendingWritePayload = "";
    private String lastTagSignature = "";
    private long lastReadAt = 0;
    private final ExecutorService network = Executors.newSingleThreadExecutor();

    private enum Mode { NONE, READ_ONCE, CONTINUOUS, WRITE }

    private static class CardPreset {
        final String label;
        final String id;
        final String name;
        final String type;

        CardPreset(String label, String id, String name, String type) {
            this.label = label;
            this.id = id;
            this.name = name;
            this.type = type;
        }

        @Override public String toString() { return label + " · " + id; }
    }

    @Override public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        buildInterface();
        nfcAdapter = NfcAdapter.getDefaultAdapter(this);
        if (nfcAdapter == null) showStatus("Este teléfono no dispone de NFC.");
        else if (!nfcAdapter.isEnabled()) showStatus("Activá NFC en Ajustes y volvé a la app.");
        else showStatus("Lista. Tocá «Leer tarjeta» y luego acercá una tarjeta NDEF.");
    }

    private void buildInterface() {
        int pad = (int) (20 * getResources().getDisplayMetrics().density);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(pad, pad, pad, pad);
        layout.setGravity(Gravity.CENTER_HORIZONTAL);

        TextView title = new TextView(this);
        title.setText("Puente NFC → Godot");
        title.setTextSize(26);
        layout.addView(title);

        TextView hint = new TextView(this);
        hint.setText("Dirección del juego (PC en la misma Wi-Fi):");
        hint.setPadding(0, pad, 0, 0);
        layout.addView(hint);

        endpointInput = new EditText(this);
        endpointInput.setSingleLine(true);
        endpointInput.setText(getPreferences(MODE_PRIVATE).getString("endpoint", DEFAULT_ENDPOINT));
        layout.addView(endpointInput, new LinearLayout.LayoutParams(-1, -2));

        Button save = new Button(this);
        save.setText("Guardar dirección");
        save.setOnClickListener(v -> {
            getPreferences(MODE_PRIVATE).edit().putString("endpoint", endpointInput.getText().toString().trim()).apply();
            showStatus("Dirección guardada. Ya podés leer una tarjeta.");
        });
        layout.addView(save);

        Button read = new Button(this);
        read.setText("Leer tarjeta");
        read.setOnClickListener(v -> startReading(Mode.READ_ONCE));
        layout.addView(read);

        continuousButton = new Button(this);
        continuousButton.setText("Iniciar lectura continua");
        continuousButton.setOnClickListener(v -> toggleContinuousReading());
        layout.addView(continuousButton);

        TextView writeTitle = new TextView(this);
        writeTitle.setText("Grabado rápido de tarjeta NDEF");
        writeTitle.setTextSize(20);
        writeTitle.setPadding(0, pad, 0, 0);
        layout.addView(writeTitle);

        cardIdInput = createInput("ID interno", "CARD_001");
        cardNameInput = createInput("Nombre", "Madera");
        cardTypeInput = createInput("Tipo", "wood");

        TextView chooserHint = new TextView(this);
        chooserHint.setText("Elegí el ítem que querés grabar:");
        layout.addView(chooserHint);
        Spinner presetSelector = new Spinner(this);
        ArrayAdapter<CardPreset> presetAdapter = new ArrayAdapter<>(this,
                android.R.layout.simple_spinner_item, CARD_PRESETS);
        presetAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        presetSelector.setAdapter(presetAdapter);
        presetSelector.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                applyPreset(CARD_PRESETS[position]);
            }
            @Override public void onNothingSelected(AdapterView<?> parent) { }
        });
        layout.addView(presetSelector, new LinearLayout.LayoutParams(-1, -2));

        layout.addView(cardIdInput, new LinearLayout.LayoutParams(-1, -2));
        layout.addView(cardNameInput, new LinearLayout.LayoutParams(-1, -2));
        layout.addView(cardTypeInput, new LinearLayout.LayoutParams(-1, -2));

        Button write = new Button(this);
        write.setText("Grabar tarjeta con estos datos");
        write.setOnClickListener(v -> startWriting());
        layout.addView(write);

        status = new TextView(this);
        status.setTextSize(18);
        status.setPadding(0, pad, 0, 0);
        layout.addView(status);

        payloadView = new TextView(this);
        payloadView.setTextSize(15);
        payloadView.setPadding(0, pad, 0, 0);
        layout.addView(payloadView);
        setContentView(layout);
    }

    private EditText createInput(String hint, String value) {
        EditText input = new EditText(this);
        input.setSingleLine(true);
        input.setHint(hint);
        input.setText(value);
        return input;
    }

    private void applyPreset(CardPreset preset) {
        cardIdInput.setText(preset.id);
        cardNameInput.setText(preset.name);
        cardTypeInput.setText(preset.type);
    }

    @Override public void onPause() {
        stopReading();
        super.onPause();
    }

    private void startReading(Mode requestedMode) {
        if (nfcAdapter == null || !nfcAdapter.isEnabled()) {
            showStatus("NFC no está disponible. Activá NFC y probá nuevamente.");
            return;
        }
        stopReading();
        mode = requestedMode;
        payloadView.setText("");
        showStatus(requestedMode == Mode.CONTINUOUS
                ? "Lectura continua activa. Acercá tarjetas; tocá detener para finalizar."
                : "Esperando tarjeta… acercala ahora a la parte trasera del teléfono.");
        nfcAdapter.enableReaderMode(this, tag -> onTagRead(tag),
                NfcAdapter.FLAG_READER_NFC_A | NfcAdapter.FLAG_READER_NFC_B, null);
        readerModeEnabled = true;
    }

    private void toggleContinuousReading() {
        if (mode == Mode.CONTINUOUS) {
            stopReading();
            showStatus("Lectura continua detenida.");
            continuousButton.setText("Iniciar lectura continua");
        } else {
            startReading(Mode.CONTINUOUS);
            continuousButton.setText("Detener lectura continua");
        }
    }

    private void startWriting() {
        if (cardIdInput.getText().toString().trim().isEmpty()
                || cardNameInput.getText().toString().trim().isEmpty()
                || cardTypeInput.getText().toString().trim().isEmpty()) {
            showStatus("Completá ID, nombre y tipo antes de grabar.");
            return;
        }
        if (nfcAdapter == null || !nfcAdapter.isEnabled()) {
            showStatus("NFC no está disponible. Activá NFC y probá nuevamente.");
            return;
        }
        try {
            JSONObject data = new JSONObject();
            data.put("v", 1);
            data.put("id", cardIdInput.getText().toString().trim());
            data.put("name", cardNameInput.getText().toString().trim());
            data.put("type", cardTypeInput.getText().toString().trim());
            pendingWritePayload = data.toString();
        } catch (Exception error) {
            showStatus("No se pudieron preparar los datos de la tarjeta.");
            return;
        }
        stopReading();
        mode = Mode.WRITE;
        payloadView.setText("");
        showStatus("Listo para grabar. Acercá una tarjeta NFC ahora.");
        nfcAdapter.enableReaderMode(this, tag -> onTagRead(tag),
                NfcAdapter.FLAG_READER_NFC_A | NfcAdapter.FLAG_READER_NFC_B, null);
        readerModeEnabled = true;
    }

    private void stopReading() {
        if (nfcAdapter != null && readerModeEnabled) {
            nfcAdapter.disableReaderMode(this);
            readerModeEnabled = false;
        }
        mode = Mode.NONE;
    }

    private void onTagRead(Tag tag) {
        if (mode == Mode.WRITE) {
            writeNdefText(tag);
            return;
        }
        String payload = readNdefText(tag);
        String signature = bytesToHex(tag.getId());
        runOnUiThread(() -> handlePayload(payload, signature));
    }

    private void handlePayload(String payload, String signature) {
        long now = System.currentTimeMillis();
        if (mode == Mode.CONTINUOUS && signature.equals(lastTagSignature) && now - lastReadAt < 1800) return;
        lastTagSignature = signature;
        lastReadAt = now;
        if (mode != Mode.CONTINUOUS) stopReading();
        if (payload == null) {
            showStatus("No encontré un registro NDEF de texto en esta tarjeta.");
            return;
        }
        try {
            JSONObject data = new JSONObject(payload);
            if (!data.has("v") || !data.has("id")) throw new Exception();
        } catch (Exception error) {
            showStatus("El texto NDEF debe ser JSON e incluir v e id.");
            return;
        }
        payloadView.setText("Información leída:\n" + payload);
        showStatus("Tarjeta leída. Enviando a Godot...");
        sendToGodot(payload);
    }

    private void writeNdefText(Tag tag) {
        String json = pendingWritePayload;
        try {
            Ndef ndef = Ndef.get(tag);
            if (ndef == null) throw new Exception("La tarjeta no acepta NDEF.");
            NdefMessage message = new NdefMessage(new NdefRecord[]{NdefRecord.createTextRecord("es", json)});
            ndef.connect();
            if (!ndef.isWritable()) throw new Exception("La tarjeta está bloqueada contra escritura.");
            if (message.toByteArray().length > ndef.getMaxSize()) throw new Exception("No hay espacio suficiente en la tarjeta.");
            ndef.writeNdefMessage(message);
            ndef.close();
            String result = json;
            runOnUiThread(() -> {
                stopReading();
                showStatus("✓ Tarjeta grabada correctamente.");
                payloadView.setText("Información escrita:\n" + result);
            });
        } catch (Exception error) {
            String message = error.getMessage() == null ? "No se pudo grabar la tarjeta." : error.getMessage();
            runOnUiThread(() -> {
                stopReading();
                showStatus("Error de grabado: " + message);
            });
        }
    }

    private String readNdefText(Tag tag) {
        if (tag == null) return null;
        Ndef ndef = Ndef.get(tag);
        if (ndef == null) return null;
        try {
            ndef.connect();
            NdefMessage message = ndef.getNdefMessage();
            ndef.close();
            if (message == null) return null;
            for (NdefRecord record : message.getRecords()) {
                if (record.getTnf() == NdefRecord.TNF_WELL_KNOWN && java.util.Arrays.equals(record.getType(), NdefRecord.RTD_TEXT)) {
                    byte[] bytes = record.getPayload();
                    int languageLength = bytes[0] & 0x3F;
                    return new String(bytes, languageLength + 1, bytes.length - languageLength - 1, StandardCharsets.UTF_8);
                }
            }
        } catch (Exception ignored) { }
        return null;
    }

    private void sendToGodot(String json) {
        String endpoint = endpointInput.getText().toString().trim();
        getPreferences(MODE_PRIVATE).edit().putString("endpoint", endpoint).apply();
        network.execute(() -> {
            try {
                String separator = endpoint.contains("?") ? "&" : "?";
                HttpURLConnection connection = (HttpURLConnection) new java.net.URL(endpoint + separator + "d=" + URLEncoder.encode(json, "UTF-8")).openConnection();
                connection.setConnectTimeout(3500);
                connection.setReadTimeout(3500);
                int code = connection.getResponseCode();
                BufferedReader reader = new BufferedReader(new InputStreamReader(code < 400 ? connection.getInputStream() : connection.getErrorStream()));
                String response = reader.readLine();
                reader.close();
                runOnUiThread(() -> {
                    showStatus(code == 200 ? "✓ Enviado a Godot." : "Godot respondió error " + code);
                    payloadView.setText("Información enviada:\n" + json + "\n\nRespuesta de Godot:\n" + response);
                });
                connection.disconnect();
            } catch (Exception error) {
                runOnUiThread(() -> {
                    showStatus("No se pudo conectar con Godot. Revisá IP, Wi-Fi y firewall.");
                    payloadView.setText("Información leída (no enviada):\n" + json);
                });
            }
        });
    }

    private void showStatus(String text) { status.setText(text); }

    private String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte value : bytes) result.append(String.format(Locale.US, "%02X", value));
        return result.toString();
    }

    @Override protected void onDestroy() {
        network.shutdown();
        super.onDestroy();
    }
}
