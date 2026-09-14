# Woher `sprecher.onnx` kommt

Die Datei ist **umbenannt**, nicht verändert. Das Original heißt
`wespeaker_en_voxceleb_CAM++_LM.onnx`; die beiden Pluszeichen im Namen
sind in Asset-Pfaden und Build-Systemen ein Ärgernis, deshalb hier ein
schlichter Name — und deshalb diese Datei, damit trotzdem nachvollziehbar
bleibt, was drinsteckt.

| | |
|---|---|
| Quelle | https://github.com/k2-fsa/sherpa-onnx/releases/tag/speaker-recongition-models |
| Datei | `wespeaker_en_voxceleb_CAM++_LM.onnx` |
| Größe | 28 MB |
| SHA-256 | `e197af7e9d473030cf486b3124149a19bf37014d0e4485e4c70c483b0ec10cb2` |
| Lizenz | Apache-2.0 (sherpa-onnx / WeSpeaker) |
| Geholt am | 14.09.2026 |

## Was das Modell laut eigenen Angaben ist

Aus den Metadaten der Datei selbst:

    framework     wespeaker
    language      English
    sample_rate   16000
    output_dim    512

`output_dim` ist der Grund, warum an jeder Stimmprobe im Server die
Vektorlänge mitsteht: tauscht jemand dieses Modell gegen ein anderes,
sind alle vorhandenen Proben nicht falsch, sondern **unvergleichbar** —
und das soll auffallen, statt still niemanden mehr zu erkennen.

Die Abtastrate passt zum Weckwort-Modell unter `assets/kws/`, das
ebenfalls 16 kHz erwartet. Beide bekommen denselben Strom.

## Warum ein englisches Modell für einen deutschen Haushalt

Sprecher-Embeddings beschreiben die **Stimme**, nicht die Sprache: was sie
unterscheiden, steckt im Stimmapparat und nicht im Wortschatz. Solche
Modelle arbeiten deshalb sprachübergreifend, und für die Aufgabe hier —
eine Handvoll Personen im selben Haushalt auseinanderhalten — reicht das
mit Abstand.

**Ehrlich dazu:** ganz umsonst ist der Sprachwechsel nicht. Auf einer
Sprache, auf der ein Modell nicht trainiert wurde, fällt die Genauigkeit
messbar ab. Bei fünf Personen mit je drei Proben fällt das kaum ins
Gewicht; sollte die Erkennung im Alltag danebenliegen, ist ein Wechsel auf
`3dspeaker_speech_campplus_sv_zh_en_16k-common_advanced.onnx` (26 MB,
zweisprachig trainiert) der nächste Versuch — dann müssen alle Proben neu
eingelernt werden, siehe `output_dim` oben.

## Warum CAM++ und nicht ResNet

Bei gleicher Größe (25–28 MB) ist CAM++ das neuere Verfahren und rechnet
deutlich sparsamer als ResNet34 — auf einem Küchentablet zählt das. Die
Variante `_LM` ist die nachtrainierte („large margin"), die Sprecher
sauberer trennt als die Grundfassung.

Größere Modelle gibt es (bis 210 MB). Sie lohnen sich, wenn Hunderte
Stimmen zu unterscheiden sind — nicht bei einem Haushalt.
