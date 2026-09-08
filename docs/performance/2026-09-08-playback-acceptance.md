# 初回編集・CPU負荷・曲全体の再生確認

## 結論

Chrome 148からWSLgのRDPSinkへ出力する条件で、初回再生と初回編集、
CPU負荷下の編集、原曲全体の再生・終了・再スタートを確認した。
準備や適用に伴う出力欠落は再現せず、Worker移行を必須とする根拠は増えなかった。
再生APIのレビューを進められる検証結果である。

**物理スピーカーでの聴取と低遅延品質の合格を意味しない。**
RDPSinkはWindows側へ転送する仮想出力であり、スピーカー出力を録音してはいない。
統計には最大約1.416秒の出力遅延も記録された。欠落0と低遅延は別の評価軸であり、
その遅延を準備処理が引き起こしたとも、この試験からは判断できない。

## 環境と対象

- Google Chrome 148.0.7778.215、GUIあり、Playwrightの既定のmuteを除去。
- デフォルトの `playbackStats` を使用。実験フラグは不要だった。
- AudioContext: 48 kHz、128 samples、interactive latency、master gain 0.1。
- PulseAudio: WSLg `RDPSink`、2ch、44.1 kHz。試験中にChromeのsink input接続を確認。
- ブラウザが報告するlogical processor数は8。負荷条件は4個のbusy-loop Web Worker。
- PR #233の `d7a69754f91e04bc98afa190bdc9835212267272` を基点とするrelease WASM。
- ご提示の12セクション・240 cyclesの曲を120 BPMで再生。fixtureは
  `scripts/worklet-measurement/orbit.cjs`。共通文字列を組み立てるJSはテスト補助であり、
  新しい作曲言語構文ではない。

本体の処理を計測用subclassで呼ぶ方式を維持した。製品の再生コードは変更していない。
時間はAudioWorklet内の `Date.now()` による1ms単位の観測。
render計測には出力peakを記録する計測側の走査も含まれる。

## 結果

[測定データ](2026-09-08-playback-acceptance.json)には各試験の統計、準備時間、
再生位置、通知、出力peakを保存した。

| 確認項目 | 結果 |
|---|---|
| 新しいAudioContextで初回適用→初回編集、3回 | 欠落0。各回2回の準備の最大時間は3 / 1 / 1ms |
| 4 Worker負荷下の通常再生、3回 | 欠落0 |
| 同じ負荷下で24回編集、3回 | 欠落0。準備p95・最大とも各回1ms |
| 原曲を最後まで再生 | 約121秒、45,416 renderブロックを検証。欠落0 |
| 曲中の編集 | 20回の継続適用が成功。再生位置は単調増加 |
| 終端 | 5,811,584 samplesまで進み、最後の出力peakは0 |
| 終了後の再スタート | `appliedAtSample=0`、適用済みrevision 20を使用 |
| 再スタート後の発音 | 97,024 samples時点でpeak約0.05077。DSP出力が非ゼロに戻った |

初回条件はWASMコンパイル後、新しいAudioContextごとに準備のウォームアップをせず実行した。
ブラウザプロセスは共通であり、ページロードやWASMコンパイルを含む完全なcold startの
総時間を測ったものではない。2回しかない準備サンプルのp95を統計的な保証には使わない。

CPU負荷条件は全CPUを飽和させる試験ではない。編集条件は各適用の完了通知を待つため、
通常再生より測定窓が少し長い。欠落件数はどちらも0だが、処理時間や負荷耐性の
厳密な速度比較には使わない。背景負荷は各条件終了時に必ず停止する。

原曲の全セクションを通過し、編集では主題のgainを0.105と0.104の間で変更した。
セクションの長さ・配置とテンポは維持する。曲としての聴感・音色の良し悪しや、
出力波形の全サンプルが期待通りであることまでは評価していない。

## 欠落検出の校正

同じChrome・出力経路で100msの意図的な停止を24回入れたところ、
138イベント・1,604.25msの欠落を報告した。通常再生・準備のみ・準備して適用は0だった。
[校正データ](2026-09-08-playback-acceptance-calibration.json)を集計器で検証し、
`calibrated: true`を確認した。欠落0は、統計が停止していた結果ではない。

この校正は短い停止に対する検出感度や、Windows側以降の物理出力を保証しない。
[Web Audioの出力統計仕様](https://webaudio.github.io/web-audio-api/#audioplaybackstats)
では欠落と遅延を別の値として扱う。今回も両者を区別する。

## 再実行

GUIと音声出力のある環境で実行する。約3分間の再生と、別途約40秒の校正を行う。

```bash
NEW_MOON_MOD=0 moon build browser --target wasm-gc --release
WORKLET_ACCEPTANCE=1 WORKLET_SYSTEM_CHROME=1 WORKLET_HEADED=1 WORKLET_UNMUTED=1 \
  node scripts/measure-worklet-preparation.cjs /tmp/acceptance.json 1
WORKLET_SYSTEM_CHROME=1 WORKLET_HEADED=1 WORKLET_UNMUTED=1 \
  node scripts/measure-worklet-preparation.cjs /tmp/calibration.json 1
node scripts/worklet-measurement/analyze.cjs /tmp/calibration.json
```

acceptanceモードの試験回数は内部で固定されている。構文チェック、集計器テスト、
10個のacceptance試験、4条件の校正が完了した。本体コードを変更していないため、
この測定で製品全体のテストを再実行したとは主張しない。

## 残る確認と進め方

再生APIのレビューと、名前付きパターンなどの作曲機能の実装へ進める。
Worker移行は、準備に伴う欠落や遅延が再現した場合に再検討する。
物理出力での聴取と遅延測定は未完了として残す。特にRDPSinkで観測された大きな遅延は、
直接接続した音声装置と同じだと見なさず、通常再生と編集の両方で比較する必要がある。
